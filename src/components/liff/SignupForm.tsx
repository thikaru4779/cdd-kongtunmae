'use client';

import { useMemo, useState } from 'react';
import { useRouter } from 'next/navigation';

export interface DistrictWithVillages {
  id: number;
  nameTh: string;
  villages: { id: number; label: string }[];
}

export function SignupForm({ districts }: { districts: DistrictWithVillages[] }) {
  const router = useRouter();
  const [districtId, setDistrictId] = useState<number | ''>('');
  const [villageId, setVillageId] = useState<number | ''>('');
  const [role, setRole] = useState<'MEMBER' | 'COMMITTEE'>('MEMBER');
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const villages = useMemo(
    () => districts.find((d) => d.id === districtId)?.villages ?? [],
    [districts, districtId],
  );

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!villageId) {
      setError('กรุณาเลือกหมู่บ้าน');
      return;
    }

    setSubmitting(true);
    setError(null);

    try {
      const res = await fetch('/api/liff/complete-signup', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ villageId, role }),
      });
      const data = await res.json();
      if (!res.ok) {
        throw new Error(data?.error ?? 'บันทึกไม่สำเร็จ');
      }
      router.replace('/home');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'เกิดข้อผิดพลาดที่ไม่ทราบสาเหตุ');
      setSubmitting(false);
    }
  }

  return (
    <form onSubmit={handleSubmit} className="flex flex-col gap-5">
      <label className="flex flex-col gap-1.5">
        <span className="text-sm font-medium">อำเภอ</span>
        <select
          value={districtId}
          onChange={(e) => {
            setDistrictId(e.target.value ? Number(e.target.value) : '');
            setVillageId('');
          }}
          className="rounded-lg border border-gray-300 px-3 py-2 text-sm"
        >
          <option value="">— เลือกอำเภอ —</option>
          {districts.map((d) => (
            <option key={d.id} value={d.id}>
              {d.nameTh}
            </option>
          ))}
        </select>
      </label>

      <label className="flex flex-col gap-1.5">
        <span className="text-sm font-medium">หมู่บ้าน</span>
        <select
          value={villageId}
          onChange={(e) => setVillageId(e.target.value ? Number(e.target.value) : '')}
          disabled={!districtId}
          className="rounded-lg border border-gray-300 px-3 py-2 text-sm disabled:bg-gray-100"
        >
          <option value="">— เลือกหมู่บ้าน —</option>
          {villages.map((v) => (
            <option key={v.id} value={v.id}>
              {v.label}
            </option>
          ))}
        </select>
      </label>

      <fieldset className="flex flex-col gap-2">
        <legend className="text-sm font-medium">บทบาทของคุณ</legend>
        <label className="flex items-center gap-2 text-sm">
          <input
            type="radio"
            name="role"
            checked={role === 'MEMBER'}
            onChange={() => setRole('MEMBER')}
          />
          สมาชิก (ดูข้อมูลอย่างเดียว)
        </label>
        <label className="flex items-center gap-2 text-sm">
          <input
            type="radio"
            name="role"
            checked={role === 'COMMITTEE'}
            onChange={() => setRole('COMMITTEE')}
          />
          คณะกรรมการกองทุนแม่ (บันทึกกิจกรรมได้)
        </label>
      </fieldset>

      {error && <p className="text-sm text-red-600">{error}</p>}

      <button
        type="submit"
        disabled={submitting || !villageId}
        className="rounded-lg bg-emerald-600 px-4 py-2 text-sm font-medium text-white disabled:opacity-50"
      >
        {submitting ? 'กำลังบันทึก...' : 'เริ่มใช้งาน'}
      </button>
    </form>
  );
}
