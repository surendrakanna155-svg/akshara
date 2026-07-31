import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { act, cleanup, render, screen } from '@testing-library/react';
import type { ReactElement, ReactNode } from 'react';

/**
 * Production auth isolation.
 *
 * These tests load the auth modules FRESH under a live-build environment,
 * because the demo flag is resolved once at module load from `import.meta.env`.
 * They assert the production build has exactly one way in — phone → OTP — and
 * that no code path can mint a token-less preview identity.
 */

const STORAGE_KEY = 'akshara.session';

type AuthModule = typeof import('./AuthContext');

async function loadWith(env: Record<string, string>) {
  for (const [k, v] of Object.entries(env)) vi.stubEnv(k, v);
  vi.resetModules();
  const auth = (await import('./AuthContext')) as AuthModule;
  const { LoginPage } = await import('@/pages/auth/LoginPage');
  const { OtpVerificationPage } = await import('@/pages/auth/OtpVerificationPage');
  const { RoleSwitcher } = await import('@/components/shell/RoleSwitcher');
  const { ToastProvider } = await import('@/components/ui');
  const { ThemeProvider } = await import('@/theme/ThemeProvider');
  const { MemoryRouter } = await import('react-router-dom');
  const { QueryClient, QueryClientProvider } = await import('@tanstack/react-query');

  function Providers({ children }: { children: ReactNode }) {
    const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
    return (
      <ThemeProvider>
        <QueryClientProvider client={client}>
          <auth.AuthProvider>
            <ToastProvider>
              <MemoryRouter>{children}</MemoryRouter>
            </ToastProvider>
          </auth.AuthProvider>
        </QueryClientProvider>
      </ThemeProvider>
    );
  }

  return {
    auth,
    LoginPage,
    OtpVerificationPage,
    RoleSwitcher,
    renderIn: (ui: ReactElement) => render(ui, { wrapper: Providers }),
  };
}

const LIVE = { VITE_DATA_MODE: 'live', VITE_API_BASE_URL: 'https://api.example.test/v1' };
const DEMO = { VITE_DATA_MODE: 'demo' };

/** Captures the auth context so a test can drive it directly. */
function makeProbe(useAuth: () => unknown) {
  const seen: { current: Record<string, unknown> | null } = { current: null };
  function Probe() {
    seen.current = useAuth() as Record<string, unknown>;
    const u = seen.current.user as { id?: string } | null;
    return <div data-testid="probe">{u ? `signed-in:${u.id}` : 'anonymous'}</div>;
  }
  return { seen, Probe };
}

beforeEach(() => {
  localStorage.clear();
});

afterEach(() => {
  cleanup();
  vi.unstubAllEnvs();
  vi.resetModules();
  localStorage.clear();
});

describe('production build (live auth)', () => {
  it('resolves to live auth', async () => {
    const { auth } = await loadWith(LIVE);
    expect(auth.AUTH_IS_DEMO).toBe(false);
  });

  it('login page shows ONLY the mobile-number + send-code path', async () => {
    const { LoginPage, renderIn } = await loadWith(LIVE);
    renderIn(<LoginPage />);

    expect(screen.queryByText('Explore by role')).not.toBeInTheDocument();
    expect(screen.queryByText(/Preview mode/i)).not.toBeInTheDocument();
    expect(screen.queryByText(/Continue as/i)).not.toBeInTheDocument();
    expect(screen.queryByText(/Demo mode is on/i)).not.toBeInTheDocument();

    expect(screen.getByText('Mobile number')).toBeInTheDocument();
    expect(screen.getByText('Send verification code')).toBeInTheDocument();
    expect(screen.getByText(/one-time code to verify your identity/i)).toBeInTheDocument();
  });

  it('login page renders no demo role cards at all', async () => {
    const { LoginPage, renderIn } = await loadWith(LIVE);
    renderIn(<LoginPage />);
    // Every persona label from the demo grid must be absent.
    for (const label of ['School Admin', 'Principal', 'Teacher', 'Parent', 'Student', 'Librarian']) {
      expect(screen.queryByText(label)).not.toBeInTheDocument();
    }
  });

  it('loginAsRole is hard-disabled — it throws instead of creating a session', async () => {
    const { auth, renderIn } = await loadWith(LIVE);
    const { seen, Probe } = makeProbe(auth.useAuth);
    renderIn(<Probe />);

    expect(() => (seen.current!.loginAsRole as (r: string) => unknown)('schoolAdmin')).toThrow(/disabled in this build/i);
    expect(localStorage.getItem(STORAGE_KEY)).toBeNull();
    expect(screen.getByTestId('probe')).toHaveTextContent('anonymous');
  });

  it('switchRole is hard-disabled', async () => {
    const { auth, renderIn } = await loadWith(LIVE);
    const { seen, Probe } = makeProbe(auth.useAuth);
    renderIn(<Probe />);

    expect(() => (seen.current!.switchRole as (r: string) => unknown)('principal')).toThrow(/disabled in this build/i);
    expect(localStorage.getItem(STORAGE_KEY)).toBeNull();
  });

  it('rejects a token-less demo session left in storage by a demo build', async () => {
    localStorage.setItem(
      STORAGE_KEY,
      JSON.stringify({ id: 'role_schoolAdmin', name: 'School Admin', role: 'schoolAdmin', schoolName: 'NIKSHA OS', schoolId: '', tenantId: '' }),
    );
    const { auth, renderIn } = await loadWith(LIVE);
    const { Probe } = makeProbe(auth.useAuth);
    renderIn(<Probe />);

    expect(screen.getByTestId('probe')).toHaveTextContent('anonymous');
    expect(localStorage.getItem(STORAGE_KEY)).toBeNull();
  });

  it('keeps a REAL token-bearing session across a reload', async () => {
    localStorage.setItem(
      STORAGE_KEY,
      JSON.stringify({ id: 'u-1', name: 'Real User', role: 'schoolAdmin', schoolName: 'St Test', schoolId: 's1', tenantId: 't1', token: 'jwt-abc', refreshToken: 'r-1' }),
    );
    const { auth, renderIn } = await loadWith(LIVE);
    const { Probe } = makeProbe(auth.useAuth);
    renderIn(<Probe />);

    expect(screen.getByTestId('probe')).toHaveTextContent('signed-in:u-1');
    expect(localStorage.getItem(STORAGE_KEY)).not.toBeNull();
  });

  it('identity menu offers no persona switching', async () => {
    localStorage.setItem(
      STORAGE_KEY,
      JSON.stringify({ id: 'u-1', name: 'Real User', role: 'schoolAdmin', schoolName: 'St Test', schoolId: 's1', tenantId: 't1', token: 'jwt-abc' }),
    );
    const { RoleSwitcher, renderIn } = await loadWith(LIVE);
    renderIn(<RoleSwitcher />);

    const trigger = screen.queryByText('Real User');
    expect(trigger).toBeInTheDocument();
    act(() => trigger!.click());
    expect(screen.queryByText(/Switch persona/i)).not.toBeInTheDocument();
  });

  it('the OTP page cannot mint a session without a real OTP request', async () => {
    const { OtpVerificationPage, renderIn } = await loadWith(LIVE);
    renderIn(<OtpVerificationPage />);

    // Fill all six boxes, then submit with NO pending OTP request — the old
    // fallback signed the visitor in as School Admin with no backend call.
    const boxes = document.querySelectorAll('input');
    expect(boxes.length).toBe(6);
    act(() => {
      boxes.forEach((b) => {
        const setter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value')!.set!;
        setter.call(b, '1');
        b.dispatchEvent(new Event('input', { bubbles: true }));
      });
    });
    act(() => screen.getByText('Verify & continue').closest('button')!.click());

    expect(localStorage.getItem(STORAGE_KEY)).toBeNull();
    expect(screen.getByText(/sign-in session expired/i)).toBeInTheDocument();
  });

  it('an existing pre-refresh-token session keeps working (no forced logout)', async () => {
    // Sessions issued by the previously certified build have a token but no
    // refreshToken — they must survive, not be treated as invalid.
    localStorage.setItem(
      STORAGE_KEY,
      JSON.stringify({ id: 'u-legacy', name: 'Legacy User', role: 'principal', schoolName: 'St Test', schoolId: 's1', tenantId: 't1', token: 'jwt-legacy' }),
    );
    const { auth, renderIn } = await loadWith(LIVE);
    const { seen, Probe } = makeProbe(auth.useAuth);
    renderIn(<Probe />);

    expect(screen.getByTestId('probe')).toHaveTextContent('signed-in:u-legacy');
    expect((seen.current!.user as { role: string }).role).toBe('principal');
  });

  it('does not register the /qa-login demo route', async () => {
    vi.stubEnv('VITE_DATA_MODE', 'live');
    vi.resetModules();
    const { router } = await import('@/routes/router');
    const paths = router.routes.map((r) => r.path);
    expect(paths).not.toContain('/qa-login');
    expect(paths).toContain('/login');
    expect(paths).toContain('/otp');
  });
});

describe('demo build (unchanged)', () => {
  it('resolves to demo auth', async () => {
    const { auth } = await loadWith(DEMO);
    expect(auth.AUTH_IS_DEMO).toBe(true);
  });

  it('still offers the role explorer and both tabs', async () => {
    const { LoginPage, renderIn } = await loadWith(DEMO);
    renderIn(<LoginPage />);

    expect(screen.getByText('Explore by role')).toBeInTheDocument();
    expect(screen.getByText('Sign in')).toBeInTheDocument();
    expect(screen.getByText(/Preview mode/i)).toBeInTheDocument();
    expect(screen.getAllByText(/School Admin/i).length).toBeGreaterThan(0);
  });

  it('still creates a preview session via loginAsRole', async () => {
    const { auth, renderIn } = await loadWith(DEMO);
    const { seen, Probe } = makeProbe(auth.useAuth);
    renderIn(<Probe />);

    let u!: { role: string };
    act(() => {
      u = (seen.current!.loginAsRole as (r: string) => { role: string })('teacher');
    });
    expect(u.role).toBe('teacher');
    expect(localStorage.getItem(STORAGE_KEY)).toContain('teacher');
  });

  it('still allows persona switching from the identity menu', async () => {
    const { auth, renderIn } = await loadWith(DEMO);
    const { seen, Probe } = makeProbe(auth.useAuth);
    renderIn(<Probe />);
    let u!: { role: string };
    act(() => {
      u = (seen.current!.switchRole as (r: string) => { role: string })('librarian');
    });
    expect(u.role).toBe('librarian');
  });

  it('registers the /qa-login demo route', async () => {
    vi.stubEnv('VITE_DATA_MODE', 'demo');
    vi.resetModules();
    const { router } = await import('@/routes/router');
    expect(router.routes.map((r) => r.path)).toContain('/qa-login');
  });
});

describe('auth mode resolution (fail-closed)', () => {
  it('a live data build with no VITE_AUTH_MODE is live auth', async () => {
    const { auth } = await loadWith({ VITE_DATA_MODE: 'live' });
    expect(auth.AUTH_IS_DEMO).toBe(false);
  });

  it('an unknown VITE_AUTH_MODE resolves to live auth, never demo', async () => {
    const { auth } = await loadWith({ VITE_DATA_MODE: 'demo', VITE_AUTH_MODE: 'preview' });
    expect(auth.AUTH_IS_DEMO).toBe(false);
  });

  it('an empty VITE_AUTH_MODE falls back to the data mode', async () => {
    const { auth } = await loadWith({ VITE_DATA_MODE: 'live', VITE_AUTH_MODE: '' });
    expect(auth.AUTH_IS_DEMO).toBe(false);
  });

  it('supports the future dedicated demo deployment: live data + demo auth', async () => {
    const { auth } = await loadWith({ VITE_DATA_MODE: 'live', VITE_AUTH_MODE: 'demo' });
    expect(auth.AUTH_IS_DEMO).toBe(true);
  });
});
