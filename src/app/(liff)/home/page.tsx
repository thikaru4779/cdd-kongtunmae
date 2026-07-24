import { redirect } from 'next/navigation';
import { getCurrentSession } from '@/lib/auth/current-user';
import { createServerClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';

const ROLE_LABEL_TH: Record<string, string> = {
  MEMBER: 'สมาชิก',
  COMMITTEE: 'คณะกรรมการกองทุนแม่',
  STAFF: 'พัฒนากร',
  DISTRICT_HEAD: 'พัฒนาการอำเภอ',
  PROVINCE_MGR: 'เจ้าหน้าที่จังหวัด',
  PROVINCE_HEAD: 'พัฒนาการจังหวัด',
  GOVERNOR: 'ผู้ว่าราชการจังหวัด',
};

export default async function HomePage() {
  const session = await getCurrentSession();
  if (!session) {
    redirect('/');
  }

  const { app_role: role, village_id: villageId, district_id: districtId } = session.app_metadata;

  if ((role === 'MEMBER' || role === 'COMMITTEE') && villageId === null) {
    redirect('/signup');
  }

  const supabase = await createServerClient();

  let placeName: string | null = null;
  if (villageId !== null) {
    const { data } = await supabase.from('village_master').select('name_th').eq('id', villageId).maybeSingle();
    placeName = data?.name_th ?? null;
  } else if (districtId !== null) {
    const { data } = await supabase.from('districts').select('name_th').eq('id', districtId).maybeSingle();
    placeName = data?.name_th ?? null;
  }

  return (
    <div className="flex flex-1 flex-col gap-6 p-6">
      <div>
        <h1 className="text-lg font-semibold">หน้าหลัก</h1>
        <p className="mt-1 text-sm text-gray-500">ยินดีต้อนรับเข้าสู่ระบบ CDD Kongtunmae</p>
      </div>

      <dl className="flex flex-col gap-3 rounded-xl border border-gray-200 p-4 text-sm">
        <div className="flex justify-between">
          <dt className="text-gray-500">บทบาท</dt>
          <dd className="font-medium">{ROLE_LABEL_TH[role] ?? role}</dd>
        </div>
        {placeName && (
          <div className="flex justify-between">
            <dt className="text-gray-500">{villageId !== null ? 'หมู่บ้าน' : 'อำเภอ'}</dt>
            <dd className="font-medium">{placeName}</dd>
          </div>
        )}
      </dl>

      {role === 'COMMITTEE' && (
        <a
          href="/activities/new"
          className="rounded-lg bg-emerald-600 px-4 py-3 text-center text-sm font-medium text-white"
        >
          บันทึกกิจกรรม
        </a>
      )}
    </div>
  );
}
