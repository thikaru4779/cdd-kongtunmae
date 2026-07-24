import { NextRequest, NextResponse } from 'next/server';
import { verifySessionToken, SESSION_COOKIE_NAME } from '@/lib/auth/session';

const COMMITTEE_ONLY_PREFIXES = ['/activities/new', '/health-check', '/action-plan'];
const STAFF_PLUS_ROLES = ['STAFF', 'DISTRICT_HEAD', 'PROVINCE_MGR', 'PROVINCE_HEAD', 'GOVERNOR'];

export async function proxy(request: NextRequest) {
  const { pathname } = request.nextUrl;
  const token = request.cookies.get(SESSION_COOKIE_NAME)?.value;

  const requiresCommittee = COMMITTEE_ONLY_PREFIXES.some((prefix) => pathname.startsWith(prefix));
  const requiresStaffPlus = pathname.startsWith('/dashboard');

  if (!requiresCommittee && !requiresStaffPlus) {
    return NextResponse.next();
  }

  if (!token) {
    return NextResponse.redirect(new URL('/', request.url));
  }

  try {
    const claims = await verifySessionToken(token);
    const role = claims.app_metadata.app_role;

    if (requiresCommittee && role !== 'COMMITTEE') {
      return NextResponse.redirect(new URL('/home', request.url));
    }
    if (requiresStaffPlus && !STAFF_PLUS_ROLES.includes(role)) {
      return NextResponse.redirect(new URL('/home', request.url));
    }
  } catch {
    return NextResponse.redirect(new URL('/', request.url));
  }

  return NextResponse.next();
}

export const config = {
  matcher: ['/activities/new', '/health-check/:path*', '/action-plan/:path*', '/dashboard/:path*'],
};
