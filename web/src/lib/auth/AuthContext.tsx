import { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react';
import { apiFetch, clearApiSession, setApiSession } from '@/lib/api/client';
import { IS_DEMO } from '@/lib/api/config';
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

/** Maps a live `/auth/me` payload to a web AuthUser. */
function mapMeToUser(me: Record<string, unknown>, token: string): AuthUser {
  const roleStr = String(me.role ?? me.erpRole ?? 'schoolAdmin');
  const role: ErpRole = ErpRoleFromName(roleStr);
  return {
    id: String(me.id ?? me.userId ?? 'me'),
    name: String(me.name ?? me.fullName ?? me.displayName ?? 'Signed in'),
    role,
    email: me.email as string | undefined,
    phone: me.phone as string | undefined,
    schoolName: String(me.schoolName ?? me.organizationName ?? 'Akshara'),
    schoolId: String(me.schoolId ?? ''),
    tenantId: String(me.organizationId ?? me.tenantId ?? ''),
    token,
  };
}
function ErpRoleFromName(v: string): ErpRole {
  const known: ErpRole[] = ['superAdmin', 'schoolAdmin', 'principal', 'vicePrincipal', 'management', 'financeAdmin', 'admissionsCounselor', 'teacher', 'parent', 'student', 'transportManager', 'hostelManager', 'librarian', 'inventoryManager', 'storekeeper'];
  return (known.includes(v as ErpRole) ? v : 'schoolAdmin') as ErpRole;
}

const AuthContext = createContext<AuthContextValue | null>(null);
const STORAGE_KEY = 'akshara.session';

/**
 * A NEUTRAL preview identity for a role — NOT fabricated business data.
 * It carries only the role label (for the shell) + the Akshara brand name; it
 * invents no person, no institution, no records. Real identity is populated from
 * the live `/auth/me` endpoint once credential sign-in is wired.
 */
function buildPreviewUser(role: ErpRole): AuthUser {
  return {
    id: `role_${role}`,
    name: ROLE_META[role].label,
    role,
    schoolName: 'Akshara',
    schoolId: '',
    tenantId: '',
  };
}

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<AuthUser | null>(null);
  const [ready, setReady] = useState(false);
  const [pendingOtp, setPendingOtp] = useState<OtpRequest | null>(null);

  useEffect(() => {
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      if (raw) {
        const parsed = JSON.parse(raw) as AuthUser;
        setUser(parsed);
        setApiSession({ token: parsed.token, tenantId: parsed.tenantId, schoolId: parsed.schoolId, userId: parsed.id });
      }
    } catch {
      /* ignore */
    }
    setReady(true);
  }, []);

  const persist = useCallback((next: AuthUser | null) => {
    setUser(next);
    if (next) {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(next));
      setApiSession({ token: next.token, tenantId: next.tenantId, schoolId: next.schoolId, userId: next.id });
    } else {
      localStorage.removeItem(STORAGE_KEY);
      clearApiSession();
    }
  }, []);

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
      const res = await apiFetch<{ accessToken?: string; token?: string }>('/auth/verify-otp', { method: 'POST', body });
      const token = res.accessToken || res.token || '';
      setApiSession({ token });
      const me = await apiFetch<Record<string, unknown>>('/auth/me');
      const u = mapMeToUser(me, token);
      setPendingOtp(null);
      persist(u);
      return u;
    },
    [pendingOtp, persist],
  );

  const loginAsRole = useCallback(
    (role: ErpRole) => {
      const u = buildPreviewUser(role);
      persist(u);
      return u;
    },
    [persist],
  );

  const switchRole = useCallback(
    (role: ErpRole) => {
      const u = buildPreviewUser(role);
      persist(u);
      return u;
    },
    [persist],
  );

  const logout = useCallback(() => persist(null), [persist]);

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

/** Exposed so the login page can note demo vs live mode. */
export const AUTH_IS_DEMO = IS_DEMO;
