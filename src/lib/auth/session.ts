import { SignJWT, jwtVerify } from 'jose';
import type { UserRole } from '@/types/database.types';

export const SESSION_COOKIE_NAME = 'ck_session';
const ACCESS_TOKEN_TTL_SECONDS = 60 * 60 * 12; // 12h — a single field-visit session

function getSecretKey() {
  const secret = process.env.SUPABASE_JWT_SECRET;
  if (!secret) {
    throw new Error('SUPABASE_JWT_SECRET is not configured');
  }
  return new TextEncoder().encode(secret);
}

export interface SessionAppMetadata {
  app_role: UserRole;
  village_id: number | null;
  district_id: number | null;
  line_user_id: string;
}

export interface SessionClaims {
  sub: string; // public.users.id (uuid)
  app_metadata: SessionAppMetadata;
}

// "role": "authenticated" is the top-level claim PostgREST reads to decide which
// Postgres role to run queries as; app_metadata carries our own RBAC claims that
// the RLS policies in supabase/migrations/0002_rls.sql key off of.
export async function mintSessionToken(claims: SessionClaims): Promise<string> {
  return new SignJWT({ role: 'authenticated', app_metadata: claims.app_metadata })
    .setProtectedHeader({ alg: 'HS256' })
    .setSubject(claims.sub)
    .setIssuedAt()
    .setExpirationTime(`${ACCESS_TOKEN_TTL_SECONDS}s`)
    .setAudience('authenticated')
    .sign(getSecretKey());
}

export async function verifySessionToken(token: string): Promise<SessionClaims> {
  const { payload } = await jwtVerify(token, getSecretKey(), { audience: 'authenticated' });
  return payload as unknown as SessionClaims;
}
