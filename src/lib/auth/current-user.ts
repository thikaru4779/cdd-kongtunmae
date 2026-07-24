import 'server-only';
import { cookies } from 'next/headers';
import { verifySessionToken, SESSION_COOKIE_NAME, type SessionClaims } from './session';

export async function getCurrentSession(): Promise<SessionClaims | null> {
  const cookieStore = await cookies();
  const token = cookieStore.get(SESSION_COOKIE_NAME)?.value;
  if (!token) return null;

  try {
    return await verifySessionToken(token);
  } catch {
    return null;
  }
}
