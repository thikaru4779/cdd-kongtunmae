// Verifies a LIFF ID token server-side via LINE's hosted verify endpoint —
// simpler and less error-prone than us fetching/rotating LINE's JWKS ourselves,
// and it's LINE's own documented approach for server-side verification.

export interface LineIdTokenProfile {
  iss: string;
  sub: string; // LINE userId — the authoritative identity, never trust a client-supplied value instead
  aud: string;
  exp: number;
  iat: number;
  name?: string;
  picture?: string;
}

export async function verifyLiffIdToken(idToken: string): Promise<LineIdTokenProfile> {
  const channelId = process.env.LIFF_CHANNEL_ID;
  if (!channelId) {
    throw new Error('LIFF_CHANNEL_ID is not configured');
  }

  const res = await fetch('https://api.line.me/oauth2/v2.1/verify', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ id_token: idToken, client_id: channelId }),
  });

  if (!res.ok) {
    throw new Error(`LINE ID token verification failed (${res.status})`);
  }

  const profile = (await res.json()) as LineIdTokenProfile;

  if (profile.aud !== channelId) {
    throw new Error('LINE ID token audience does not match this LIFF channel');
  }

  return profile;
}
