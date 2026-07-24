import { redirect } from 'next/navigation';
import { getCurrentSession } from '@/lib/auth/current-user';
import { createServerClient } from '@/lib/supabase/server';
import { SignupForm, type DistrictWithVillages } from '@/components/liff/SignupForm';

export const dynamic = 'force-dynamic';

export default async function SignupPage() {
  const session = await getCurrentSession();
  if (!session) {
    redirect('/');
  }
  if (session.app_metadata.village_id !== null) {
    redirect('/home');
  }

  const supabase = await createServerClient();

  const [{ data: districts }, { data: subdistricts }, { data: villages }] = await Promise.all([
    supabase.from('districts').select('id, name_th').order('code'),
    supabase.from('subdistricts').select('id, district_id'),
    supabase
      .from('village_master')
      .select('id, name_th, moo_no, subdistrict_id')
      .eq('is_active', true)
      .order('moo_no'),
  ]);

  const subdistrictToDistrict = new Map((subdistricts ?? []).map((s) => [s.id, s.district_id]));

  const districtsWithVillages: DistrictWithVillages[] = (districts ?? []).map((district) => ({
    id: district.id,
    nameTh: district.name_th,
    villages: (villages ?? [])
      .filter((v) => subdistrictToDistrict.get(v.subdistrict_id) === district.id)
      .map((v) => ({ id: v.id, label: `หมู่ ${v.moo_no} ${v.name_th}` })),
  }));

  return (
    <div className="flex flex-1 flex-col gap-6 p-6">
      <div>
        <h1 className="text-lg font-semibold">สมัครสมาชิก</h1>
        <p className="mt-1 text-sm text-gray-500">เลือกหมู่บ้านและบทบาทของคุณเพื่อเริ่มใช้งาน</p>
      </div>
      <SignupForm districts={districtsWithVillages} />
    </div>
  );
}
