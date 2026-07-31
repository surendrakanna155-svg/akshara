import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import {
  ApiError,
  apiFetch,
  clearApiSession,
  getApiSession,
  setApiSession,
  setSessionCallbacks,
} from './client';

/** Minimal Response stand-in — apiFetch only uses ok/status/statusText/text(). */
function res(status: number, body: unknown): Response {
  return {
    ok: status >= 200 && status < 300,
    status,
    statusText: String(status),
    text: async () => (body === undefined ? '' : JSON.stringify(body)),
  } as unknown as Response;
}

const OK = res(200, { data: { ok: true } });
const UNAUTHORIZED = () => res(401, { error: { code: 'UNAUTHORIZED', message: 'Invalid access token' } });
const REFRESHED = (n = 1) =>
  res(200, {
    data: {
      accessToken: `access-${n}`,
      refreshToken: `refresh-${n}`,
      expiresAt: new Date(Date.now() + 15 * 60_000).toISOString(),
      sessionId: 'sess-1',
    },
  });

function urlOf(input: unknown): string {
  return String(input);
}

let fetchMock: ReturnType<typeof vi.fn>;

beforeEach(() => {
  clearApiSession();
  setSessionCallbacks({});
  fetchMock = vi.fn();
  vi.stubGlobal('fetch', fetchMock);
});

afterEach(() => {
  clearApiSession();
  setSessionCallbacks({});
  vi.unstubAllGlobals();
});

describe('access-token refresh', () => {
  it('refreshes and replays the request when the server returns 401', async () => {
    setApiSession({ token: 'expired', refreshToken: 'r0' });
    fetchMock
      .mockResolvedValueOnce(UNAUTHORIZED()) // original call
      .mockResolvedValueOnce(REFRESHED()) // /auth/refresh
      .mockResolvedValueOnce(OK); // replay

    await expect(apiFetch('/sis/students')).resolves.toEqual({ ok: true });

    expect(fetchMock).toHaveBeenCalledTimes(3);
    expect(urlOf(fetchMock.mock.calls[1][0])).toContain('/auth/refresh');
    // The replay must carry the NEW bearer, not the dead one.
    const replayHeaders = fetchMock.mock.calls[2][1].headers as Headers;
    expect(replayHeaders.get('Authorization')).toBe('Bearer access-1');
  });

  it('stores the ROTATED refresh token (replaying a spent one trips reuse-detection)', async () => {
    setApiSession({ token: 'expired', refreshToken: 'r0' });
    fetchMock.mockResolvedValueOnce(UNAUTHORIZED()).mockResolvedValueOnce(REFRESHED(7)).mockResolvedValueOnce(OK);

    await apiFetch('/sis/students');

    expect(getApiSession().refreshToken).toBe('refresh-7');
    expect(getApiSession().token).toBe('access-7');
  });

  it('sends exactly ONE /auth/refresh for many concurrent 401s (single-flight)', async () => {
    setApiSession({ token: 'expired', refreshToken: 'r0' });
    let refreshCalls = 0;
    fetchMock.mockImplementation(async (input: unknown, init: { headers?: Headers }) => {
      if (urlOf(input).includes('/auth/refresh')) {
        refreshCalls += 1;
        // Hold the refresh open so every caller must queue behind it.
        await new Promise((r) => setTimeout(r, 10));
        return REFRESHED();
      }
      const auth = init?.headers?.get('Authorization');
      return auth === 'Bearer access-1' ? OK : UNAUTHORIZED();
    });

    const results = await Promise.all([
      apiFetch('/a'),
      apiFetch('/b'),
      apiFetch('/c'),
      apiFetch('/d'),
      apiFetch('/e'),
    ]);

    expect(refreshCalls).toBe(1);
    expect(results).toEqual([{ ok: true }, { ok: true }, { ok: true }, { ok: true }, { ok: true }]);
  });

  it('refreshes proactively when the access token is already expired', async () => {
    setApiSession({
      token: 'expired',
      refreshToken: 'r0',
      expiresAt: new Date(Date.now() - 60_000).toISOString(),
    });
    fetchMock.mockResolvedValueOnce(REFRESHED()).mockResolvedValueOnce(OK);

    await apiFetch('/sis/students');

    // No wasted 401 round-trip: refresh happened FIRST.
    expect(fetchMock).toHaveBeenCalledTimes(2);
    expect(urlOf(fetchMock.mock.calls[0][0])).toContain('/auth/refresh');
  });

  it('does not refresh while the access token is still valid', async () => {
    setApiSession({
      token: 'good',
      refreshToken: 'r0',
      expiresAt: new Date(Date.now() + 15 * 60_000).toISOString(),
    });
    fetchMock.mockResolvedValueOnce(OK);

    await apiFetch('/sis/students');

    expect(fetchMock).toHaveBeenCalledTimes(1);
    expect(urlOf(fetchMock.mock.calls[0][0])).not.toContain('/auth/refresh');
  });

  it('ends the session when the refresh token is rejected', async () => {
    const onSessionExpired = vi.fn();
    setSessionCallbacks({ onSessionExpired });
    setApiSession({ token: 'expired', refreshToken: 'dead' });
    fetchMock
      .mockResolvedValueOnce(UNAUTHORIZED())
      .mockResolvedValueOnce(res(401, { error: { code: 'REFRESH_INVALID', message: 'Invalid refresh token' } }));

    await expect(apiFetch('/sis/students')).rejects.toBeInstanceOf(ApiError);

    expect(onSessionExpired).toHaveBeenCalledTimes(1);
    expect(getApiSession().token).toBeUndefined();
    expect(getApiSession().refreshToken).toBeUndefined();
    // The original request is NOT replayed once the session is gone.
    expect(fetchMock).toHaveBeenCalledTimes(2);
  });

  it('keeps the session when refresh fails transiently (5xx / network)', async () => {
    const onSessionExpired = vi.fn();
    setSessionCallbacks({ onSessionExpired });
    setApiSession({ token: 'expired', refreshToken: 'r0' });
    fetchMock.mockResolvedValueOnce(UNAUTHORIZED()).mockResolvedValueOnce(res(503, { error: { code: 'SERVER_ERROR' } }));

    await expect(apiFetch('/sis/students')).rejects.toBeInstanceOf(ApiError);

    // A backend hiccup must not log a legitimate user out.
    expect(onSessionExpired).not.toHaveBeenCalled();
    expect(getApiSession().refreshToken).toBe('r0');
  });

  it('surfaces the 401 unchanged when there is no refresh token', async () => {
    setApiSession({ token: 'only-access' });
    fetchMock.mockResolvedValueOnce(UNAUTHORIZED());

    await expect(apiFetch('/sis/students')).rejects.toMatchObject({ status: 401 });
    expect(fetchMock).toHaveBeenCalledTimes(1);
  });

  it('never refreshes or retries the auth bootstrap endpoints', async () => {
    setApiSession({ refreshToken: 'r0' });
    fetchMock.mockResolvedValue(UNAUTHORIZED());

    await expect(apiFetch('/auth/login', { method: 'POST', body: {} })).rejects.toMatchObject({ status: 401 });
    expect(fetchMock).toHaveBeenCalledTimes(1);

    fetchMock.mockClear();
    await expect(apiFetch('/auth/verify-otp', { method: 'POST', body: {} })).rejects.toMatchObject({ status: 401 });
    expect(fetchMock).toHaveBeenCalledTimes(1);
  });

  it('replays the request at most once', async () => {
    setApiSession({ token: 'expired', refreshToken: 'r0' });
    fetchMock
      .mockResolvedValueOnce(UNAUTHORIZED())
      .mockResolvedValueOnce(REFRESHED())
      .mockResolvedValueOnce(UNAUTHORIZED()) // still 401 after a good refresh
      .mockResolvedValue(OK);

    await expect(apiFetch('/sis/students')).rejects.toMatchObject({ status: 401 });
    expect(fetchMock).toHaveBeenCalledTimes(3);
  });

  it('treats a refresh response without a rotated token as a dead session', async () => {
    const onSessionExpired = vi.fn();
    setSessionCallbacks({ onSessionExpired });
    setApiSession({ token: 'expired', refreshToken: 'r0' });
    fetchMock
      .mockResolvedValueOnce(UNAUTHORIZED())
      .mockResolvedValueOnce(res(200, { data: { accessToken: 'a1' } })); // no refreshToken

    await expect(apiFetch('/sis/students')).rejects.toBeInstanceOf(ApiError);
    expect(onSessionExpired).toHaveBeenCalledTimes(1);
  });

  it('reports the rotated tokens so the auth layer can persist them', async () => {
    const onTokensRefreshed = vi.fn();
    setSessionCallbacks({ onTokensRefreshed });
    setApiSession({ token: 'expired', refreshToken: 'r0' });
    fetchMock.mockResolvedValueOnce(UNAUTHORIZED()).mockResolvedValueOnce(REFRESHED(3)).mockResolvedValueOnce(OK);

    await apiFetch('/sis/students');

    expect(onTokensRefreshed).toHaveBeenCalledTimes(1);
    expect(onTokensRefreshed.mock.calls[0][0]).toMatchObject({ token: 'access-3', refreshToken: 'refresh-3' });
  });
});
