import { NextResponse } from 'next/server';
import { createAdminClient } from '@/lib/supabase/admin';
import { getCurrentSession } from '@/lib/auth/current-user';
import { mintSessionToken, SESSION_COOKIE_NAME } from '@/lib/auth/session';

const SELF_SELECTABLE_ROLES = ['MEMBER', 'COMMITTEE'] as const;

export async function POST(request: Request) {
  const session = await getCurrentSession();
  if (!session) {
    return NextResponse.json({ error: 'กรุณาเข้าสู่ระบบใหม่' }, { status: 401 });
  }

  const body = await request.json().catch(() => null);
  const villageId = Number(body?.villageId);
  const role = body?.role;

  if (!Number.isInteger(villageId) || !SELF_SELECTABLE_ROLES.includes(role)) {
    return NextResponse.json({ error: 'ข้อมูลที่ส่งมาไม่ถูกต้อง' }, { status: 400 });
  }

  const admin = createAdminClient();

  // Defense in depth: only MEMBER/COMMITTEE accounts may complete this step —
  // STAFF+ roles are assigned atomically from staff_whitelist at first login
  // and never go through village self-selection.
  const { data: currentUser, error: fetchError } = await admin
    .from('users')
    .select('id, role')
    .eq('id', session.sub)
    .single();

  if (fetchError || !currentUser || !SELF_SELECTABLE_ROLES.includes(currentUser.role as never)) {
    return NextResponse.json({ error: 'บัญชีนี้ไม่สามารถเลือกหมู่บ้านเองได้' }, { status: 403 });
  }

  const { data: village, error: villageError } = await admin
    .from('village_master')
    .select('id')
    .eq('id', villageId)
    .eq('is_active', true)
    .maybeSingle();

  if (villageError || !village) {
    return NextResponse.json({ error: 'ไม่พบหมู่บ้านที่เลือก' }, { status: 400 });
  }

  const { data: updated, error: updateError } = await admin
    .from('users')
    .update({ village_id: villageId, role })
    .eq('id', session.sub)
    .select('id, role, village_id, district_id')
    .single();

  if (updateError || !updated) {
    return NextResponse.json({ error: 'บันทึกข้อมูลไม่สำเร็จ กรุณาลองใหม่' }, { status: 500 });
  }

  const token = await mintSessionToken({
    sub: updated.id,
    app_metadata: {
      app_role: updated.role,
      village_id: updated.village_id,
      district_id: updated.district_id,
      line_user_id: session.app_metadata.line_user_id,
    },
  });

  const response = NextResponse.json({ ok: true });
  response.cookies.set(SESSION_COOKIE_NAME, token, {
    httpOnly: true,
    secure: true,
    sameSite: 'lax',
    path: '/',
    maxAge: 60 * 60 * 12,
  });

  return response;
}
