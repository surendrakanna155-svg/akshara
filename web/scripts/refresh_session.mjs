// Mint a fresh access token from the captured refreshToken and re-stamp both the
// session file and the Playwright storageState. Keeps the ONE authenticated
// session alive across the certification without ever requesting another OTP.
// Exported for harness reuse; also runnable directly.
import fs from 'node:fs';

const API = process.env.API_BASE || 'https://api.nikshaos.in/functions/v1/api';
const SESSION = '/tmp/ak-web-session.json';
const STATE = '/tmp/ak-web-state.json';
const ORIGIN = process.env.BASE_URL || 'http://localhost:4350';

export function tokenExpiresInSec(token) {
  try {
    const p = JSON.parse(Buffer.from(token.split('.')[1], 'base64url').toString());
    return p.exp - Math.floor(Date.now() / 1000);
  } catch {
    return -1;
  }
}

/** Refreshes only when the token has under `minSec` left. Returns the session. */
export async function ensureFreshSession(minSec = 240) {
  const s = JSON.parse(fs.readFileSync(SESSION, 'utf8'));
  const left = tokenExpiresInSec(s.token);
  if (left > minSec) return s;
  if (!s.refreshToken) throw new Error('token expired and no refreshToken captured — re-run auth_ui_once.mjs');

  const r = await fetch(API + '/auth/refresh', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ refreshToken: s.refreshToken }),
  });
  const j = await r.json().catch(() => null);
  const token = j?.data?.accessToken || j?.data?.token;
  if (!token) throw new Error('refresh failed: ' + r.status + ' ' + JSON.stringify(j?.error));

  // Refresh tokens ROTATE (reuse is detected and revokes the family) — always
  // persist the new one.
  const next = { ...s, token, refreshToken: j.data.refreshToken ?? s.refreshToken };
  fs.writeFileSync(SESSION, JSON.stringify(next));

  const { refreshToken: _rt, ...appSession } = next;
  const state = {
    cookies: [],
    origins: [{ origin: ORIGIN, localStorage: [{ name: 'akshara.session', value: JSON.stringify(appSession) }] }],
  };
  fs.writeFileSync(STATE, JSON.stringify(state));
  return next;
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const s = await ensureFreshSession(Number(process.env.MIN_SEC || 240));
  console.log('session fresh: role=' + s.role + ' expires in ' + (tokenExpiresInSec(s.token) / 60).toFixed(1) + ' min');
}
