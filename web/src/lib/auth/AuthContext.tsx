import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState } from 'react';
import { apiFetch, clearApiSession, setApiSession, setSessionCallbacks } from '@/lib/api/client';
import { IS_DEMO_AUTH } from '@/lib/api/config';
import { ROLE_META, type ErpRole } from './roles';

export interface AuthUser {
  id: string;
  name: string;
  role: ErpRole;
  email?: string;
  phone?: string;
  schoolName: string;
  schoolId: string;
  tenantId: string;
  avatarUrl?: string;
  /** Live bearer token (present only for real credential sign-in). */
  token?: string;
  /** Rotating refresh token — live sessions only. */
  refreshToken?: string;
  /** ISO expiry of the access token. */
  expiresAt?: string;
  sessionId?: string;
}

export interface OtpRequest {
  identifier: string;
  type: 'phone' | 'email';
  sessionId: string;
  /** Pilot/dev backends return the OTP in the response (no SMS). */
  devOtp?: string;
}

interface AuthContextValue {
  user: AuthUser | null;
  ready: boolean;
  /** Demo login: assume a role instantly (no backend). */
  loginAsRole: (role: ErpRole) => AuthUser;
  logout: () => void;
  /** Switch the active demo role while staying signed in. */
  switchRole: (role: ErpRole) => AuthUser;
  /** Live auth: request an OTP for a phone/email; returns the pending session. */
  requestOtp: (identifier: string, type?: 'phone' | 'email') => Promise<OtpRequest>;
  /** Live auth: verify the OTP for the pending session and sign in. */
  verifyOtp: (otp: string, scope?: string, schoolId?: string) => Promise<AuthUser>;
  pendingOtp: OtpRequest | null;
}

/** Tokens returned by /auth/verify-otp and /auth/refresh. */
interface SessionTokens {
  token: string;
  refreshToken?: string;
  expiresAt?: string;
  sessionId?: string;
}

/** Maps a live `/auth/me` payload to a web AuthUser. */
function mapMeToUser(me: Record<string, unknown>, tokens: SessionTokens): AuthUser {
  const token = tokens.token;
  const roleStr = String(me.role ?? me.erpRole ?? 'schoolAdmin');
  const role: ErpRole = ErpRoleFromName(roleStr);
  return {
    id: String(me.id ?? me.userId ?? 'me'),
    name: String(me.name ?? me.fullName ?? me.displayName ?? 'Signed in'),
    role,
    email: me.email as string | undefined,
    phone: me.phone as string | undefined,
    schoolName: String(me.schoolName ?? me.organizationName ?? 'NIKSHA OS'),
    schoolId: String(me.schoolId ?? ''),
    tenantId: String(me.organizationId ?? me.tenantId ?? ''),
    token,
    refreshToken: tokens.refreshToken,
    expiresAt: tokens.expiresAt,
    sessionId: tokens.sessionId,
  };
}
function ErpRoleFromName(v: string): ErpRole {
  const known: ErpRole[] = ['superAdmin', 'schoolAdmin', 'principal', 'vicePrincipal', 'management', 'financeAdmin', 'admissionsCounselor', 'teacher', 'parent', 'student', 'transportManager', 'hostelManager', 'librarian', 'inventoryManager', 'storekeeper'];
  return (known.includes(v as ErpRole) ? v : 'schoolAdmin') as ErpRole;
}

const AuthContext = createContext<AuthContextValue | null>(null);
const STORAGE_KEY = 'akshara.session';

/** Push a stored/minted user into the api client's request session. */
function applyApiSession(u: AuthUser) {
  setApiSession({
    token: u.token,
    refreshToken: u.refreshToken,
    expiresAt: u.expiresAt,
    sessionId: u.sessionId,
    tenantId: u.tenantId,
    schoolId: u.schoolId,
    userId: u.id,
  });
}

/**
 * A NEUTRAL preview identity for a role — NOT fabricated business data.
 * It carries only the role label (for the shell) + the NIKSHA OS brand name; it
 * invents no person, no institution, no records. Real identity is populated from
 * the live `/auth/me` endpoint once credential sign-in is wired.
 *
 * DEMO BUILDS ONLY. This is the one and only factory for a token-less identity,
 * so gating it here closes every route into the app that skips the backend.
 */
function buildPreviewUser(role: ErpRole): AuthUser {
  assertDemoAuth('buildPreviewUser');
  return {
    id: `role_${role}`,
    name: ROLE_META[role].label,
    role,
    schoolName: 'NIKSHA OS',
    schoolId: '',
    tenantId: '',
  };
}

/**
 * Fail-closed guard. In a live build there is no legitimate caller, so this
 * throws rather than silently returning — a preview identity reaching a
 * production session is a security defect, not a degraded experience.
 */
function assertDemoAuth(what: string): void {
  if (!IS_DEMO_AUTH) {
    throw new Error(`${what} is disabled in this build: demo sign-in is not available in production.`);
  }
}

/**
 * A stored session is only usable in a live build if it carries a real bearer
 * token. This rejects a demo/preview identity left in localStorage by a demo
 * build served from the same origin — otherwise it would rehydrate straight
 * into an authenticated-looking shell with no backend session behind it.
 */
function isUsableStoredSession(u: AuthUser | null): u is AuthUser {
  if (!u || typeof u !== 'object' || !u.role) return false;
  if (IS_DEMO_AUTH) return true;
  return typeof u.token === 'string' && u.token.length > 0;
}

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<AuthUser | null>(null);
  const [ready, setReady] = useState(false);
  const [pendingOtp, setPendingOtp] = useState<OtpRequest | null>(null);

  // `persist` is referenced by the session callbacks registered below, which are
  // installed before it is declared — a ref keeps that wiring order legal.
  const persistRef = useRef<(next: AuthUser | null) => void>(() => {});

  useEffect(() => {
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      if (raw) {
        const parsed = JSON.parse(raw) as AuthUser;
        if (isUsableStoredSession(parsed)) {
          setUser(parsed);
          applyApiSession(parsed);
        } else {
          // Token-less identity in a live build → drop it rather than trust it.
          localStorage.removeItem(STORAGE_KEY);
          clearApiSession();
        }
      }
    } catch {
      /* ignore */
    }
    setReady(true);
  }, []);

  // Keep the api client's refresh outcomes in sync with React state + storage,
  // so a token rotated during any data call is durably persisted and a dead
  // refresh token ends the session instead of leaving a zombie one behind.
  useEffect(() => {
    setSessionCallbacks({
      onTokensRefreshed: (t) => {
        setUser((prev) => {
          if (!prev) return prev;
          const next: AuthUser = {
            ...prev,
            token: t.token,
            refreshToken: t.refreshToken,
            expiresAt: t.expiresAt,
            sessionId: t.sessionId ?? prev.sessionId,
          };
          try {
            localStorage.setItem(STORAGE_KEY, JSON.stringify(next));
          } catch {
            /* ignore */
          }
          return next;
        });
      },
      onSessionExpired: () => persistRef.current(null),
    });
    return () => setSessionCallbacks({});
  }, []);

  // Cross-tab: refresh tokens are single-use, so a tab holding a stale copy
  // would present a SPENT token and trip the backend's reuse detection — which
  // revokes every session for that user. Adopting the newest stored session
  // keeps sibling tabs from destroying a healthy login.
  useEffect(() => {
    function onStorage(e: StorageEvent) {
      if (e.key !== null && e.key !== STORAGE_KEY) return;
      try {
        const raw = localStorage.getItem(STORAGE_KEY);
        if (!raw) {
          setUser(null);
          clearApiSession();
          return;
        }
        const parsed = JSON.parse(raw) as AuthUser;
        if (!isUsableStoredSession(parsed)) return;
        setUser(parsed);
        applyApiSession(parsed);
      } catch {
        /* ignore */
      }
    }
    window.addEventListener('storage', onStorage);
    return () => window.removeEventListener('storage', onStorage);
  }, []);

  const persist = useCallback((next: AuthUser | null) => {
    setUser(next);
    if (next) {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(next));
      applyApiSession(next);
    } else {
      localStorage.removeItem(STORAGE_KEY);
      clearApiSession();
    }
  }, []);
  persistRef.current = persist;

  const requestOtp = useCallback(async (identifier: string, type: 'phone' | 'email' = 'phone'): Promise<OtpRequest> => {
    const res = await apiFetch<{ sessionId: string; otp?: string }>('/auth/login', { method: 'POST', body: { identifier, type } });
    const pending: OtpRequest = { identifier, type, sessionId: res.sessionId, devOtp: res.otp };
    setPendingOtp(pending);
    return pending;
  }, []);

  const verifyOtp = useCallback(
    async (otp: string, scope?: string, schoolId?: string): Promise<AuthUser> => {
      if (!pendingOtp) throw new Error('No OTP request in progress');
      const body: Record<string, unknown> = { identifier: pendingOtp.identifier, type: pendingOtp.type, otp, sessionId: pendingOtp.sessionId };
      if (scope) body.scope = scope;
      if (schoolId) body.schoolId = schoolId;
      const res = await apiFetch<{
        accessToken?: string;
        token?: string;
        refreshToken?: string;
        expiresAt?: string;
        sessionId?: string;
      }>('/auth/verify-otp', { method: 'POST', body });
      const token = res.accessToken || res.token || '';
      const tokens: SessionTokens = {
        token,
        refreshToken: res.refreshToken,
        expiresAt: res.expiresAt,
        sessionId: res.sessionId,
      };
      // Seed the client session BEFORE /auth/me so that call is authenticated —
      // and carry the refresh token so even /auth/me can self-heal on a 401.
      setApiSession(tokens);
      const me = await apiFetch<Record<string, unknown>>('/auth/me');
      const u = mapMeToUser(me, tokens);
      setPendingOtp(null);
      persist(u);
      return u;
    },
    [pendingOtp, persist],
  );

  // Both preview paths funnel through buildPreviewUser, which throws in a live
  // build. The explicit assert here makes the refusal happen BEFORE anything is
  // persisted, so a live build can never even briefly hold a preview session.
  const loginAsRole = useCallback(
    (role: ErpRole) => {
      assertDemoAuth('loginAsRole');
      const u = buildPreviewUser(role);
      persist(u);
      return u;
    },
    [persist],
  );

  const switchRole = useCallback(
    (role: ErpRole) => {
      assertDemoAuth('switchRole');
      const u = buildPreviewUser(role);
      persist(u);
      return u;
    },
    [persist],
  );

  const logout = useCallback(() => {
    // Sign-out is now also a server-side concern: the browser holds a long-lived
    // refresh token, so dropping it locally would leave a usable session behind.
    // Best-effort and non-blocking — the local sign-out must never depend on the
    // network. `/auth/logout` revokes this session only (never other devices).
    if (user?.token) {
      void apiFetch('/auth/logout', { method: 'POST' }).catch(() => {
        /* already signed out locally; nothing actionable */
      });
    }
    persist(null);
  }, [persist, user]);

  const value = useMemo(
    () => ({ user, ready, loginAsRole, logout, switchRole, requestOtp, verifyOtp, pendingOtp }),
    [user, ready, loginAsRole, logout, switchRole, requestOtp, verifyOtp, pendingOtp],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthContextValue {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used within AuthProvider');
  return ctx;
}

/**
 * True only in a demo build. The role explorer, the persona switcher and every
 * other preview-identity surface are rendered ONLY behind this flag; in a live
 * build the same paths are additionally hard-blocked in this module (see
 * `assertDemoAuth`), so hiding the UI is defence-in-depth, not the defence.
 */
export const AUTH_IS_DEMO = IS_DEMO_AUTH;
