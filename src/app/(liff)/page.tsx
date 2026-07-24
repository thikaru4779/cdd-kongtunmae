'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';

type Status = 'initializing' | 'redirecting-to-line' | 'signing-in' | 'error';

export default function SplashPage() {
  const router = useRouter();
  const [status, setStatus] = useState<Status>('initializing');
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;

    async function run() {
      const liffId = process.env.NEXT_PUBLIC_LIFF_ID;
      if (!liffId) {
        setStatus('error');
        setErrorMessage('ระบบยังไม่ได้ตั้งค่า LIFF (NEXT_PUBLIC_LIFF_ID) กรุณาติดต่อผู้ดูแลระบบ');
        return;
      }

      try {
        const { default: liff } = await import('@line/liff');
        await liff.init({ liffId });

        if (!liff.isLoggedIn()) {
          if (cancelled) return;
          setStatus('redirecting-to-line');
          liff.login();
          return;
        }

        if (cancelled) return;
        setStatus('signing-in');

        const idToken = liff.getIDToken();
        if (!idToken) {
          throw new Error('ไม่พบ ID token จาก LINE');
        }

        const res = await fetch('/api/liff/callback', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ idToken }),
        });

        const data = await res.json();
        if (!res.ok) {
          throw new Error(data?.error ?? 'เข้าสู่ระบบไม่สำเร็จ');
        }

        if (cancelled) return;
        router.replace(data.hasVillage ? '/home' : '/signup');
      } catch (err) {
        if (cancelled) return;
        setStatus('error');
        setErrorMessage(err instanceof Error ? err.message : 'เกิดข้อผิดพลาดที่ไม่ทราบสาเหตุ');
      }
    }

    run();
    return () => {
      cancelled = true;
    };
  }, [router]);

  return (
    <div className="flex flex-1 flex-col items-center justify-center gap-4 p-6 text-center">
      <h1 className="text-xl font-semibold">CDD Kongtunmae</h1>

      {status !== 'error' && (
        <p className="text-sm text-gray-500">
          {status === 'initializing' && 'กำลังเตรียมระบบ...'}
          {status === 'redirecting-to-line' && 'กำลังพาไปเข้าสู่ระบบด้วย LINE...'}
          {status === 'signing-in' && 'กำลังเข้าสู่ระบบ...'}
        </p>
      )}

      {status === 'error' && (
        <div className="flex flex-col items-center gap-3">
          <p className="text-sm text-red-600">{errorMessage}</p>
          <button
            type="button"
            onClick={() => window.location.reload()}
            className="rounded-lg bg-emerald-600 px-4 py-2 text-sm font-medium text-white"
          >
            ลองใหม่อีกครั้ง
          </button>
        </div>
      )}
    </div>
  );
}
