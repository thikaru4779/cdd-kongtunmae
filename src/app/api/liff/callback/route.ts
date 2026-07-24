import { NextResponse } from 'next/server';
import { verifyLiffIdToken } from '@/lib/auth/liff-verify';
import { createAdminClient } from '@/lib/supabase/admin';
import { mintSessionToken, SESSION_COOKIE_NAME } from '@/lib/auth/session';

export async function POST(request: Request) {
  const body = await request.json().catch(() => null);
  const idToken = body?.idToken;

  if (typeof idToken !== 'string' || !idToken) {
    return NextResponse.json({ error: 'ไม่พบข้อมูลยืนยันตัวตนจาก LINE' }, { status: 400 });
  }

  let lineProfile;
  try {
    lineProfile = await verifyLiffIdToken(idToken);
  } catch {
    return NextResponse.json(
      { error: 'ยืนยันตัวตนกับ LINE ไม่สำเร็จ กรุณาลองเข้าสู่ระบบใหม่' },
      { status: 401 },
    );
  }

  const admin = createAdminClient();
  const lineUserId = lineProfile.sub;

  const { data: existingUser, error: lookupError } = await admin
    .from('users')
    .select('id, role, village_id, district_id, status')
    .eq('line_user_id', lineUserId)
    .maybeSingle();

  if (lookupError) {
    return NextResponse.json({ error: 'ระบบขัดข้อง กรุณาลองใหม่อีกครั้ง' }, { status: 500 });
  }

  let user = existingUser;

  if (!user) {
    // TODO: STAFF+ role elevation is supposed to match staff_whitelist by phone
    // number, but LINE's default profile scope doesn't include a phone number —
    // this is an open question inherited from the spec, not resolved by the
    // stack migration. New users default to MEMBER (the users table default)
    // until real whitelist provisioning is designed.
    const { data: created, error: insertError } = await admin
      .from('users')
      .insert({ line_user_id: lineUserId, display_name: lineProfile.name ?? null })
      .select('id, role, village_id, district_id, status')
      .single();

    if (insertError || !created) {
      return NextResponse.json({ error: 'สร้างบัญชีผู้ใช้ไม่สำเร็จ' }, { status: 500 });
    }
    user = created;
  }

  if (user.status === 'SUSPENDED') {
    return NextResponse.json(
      { error: 'บัญชีนี้ถูกระงับการใช้งาน กรุณาติดต่อแอดมิน' },
      { status: 403 },
    );
  }

  const token = await mintSessionToken({
    sub: user.id,
    app_metadata: {
      app_role: user.role,
      village_id: user.village_id,
      district_id: user.district_id,
      line_user_id: lineUserId,
    },
  });

  const response = NextResponse.json({
    role: user.role,
    hasVillage: user.village_id !== null,
  });

  response.cookies.set(SESSION_COOKIE_NAME, token, {
    httpOnly: true,
    secure: true,
    sameSite: 'lax',
    path: '/',
    maxAge: 60 * 60 * 12,
  });

  return response;
}
