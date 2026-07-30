import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { motion } from 'framer-motion';
import { useAuth } from '@/lib/auth/AuthContext';
import { DEMO_ROLES, ROLE_META, type ErpRole } from '@/lib/auth/roles';
import { AUTH_IS_DEMO } from '@/lib/auth/AuthContext';
import { Button, Input, Logo, Text } from '@/components/ui';
import { Icon } from '@/components/Icon';
import { useTheme } from '@/theme/ThemeProvider';
import { cn } from '@/lib/utils/cn';

/** Login — ports login_screen.dart + the demo role picker (qa_login_screen.dart). */
export function LoginPage() {
  const { loginAsRole, requestOtp } = useAuth();
  const navigate = useNavigate();
  const { resolved, toggle } = useTheme();
  const [tab, setTab] = useState<'demo' | 'credentials'>(AUTH_IS_DEMO ? 'demo' : 'credentials');
  const [selected, setSelected] = useState<ErpRole>('schoolAdmin');
  const [identifier, setIdentifier] = useState('');
  const [sending, setSending] = useState(false);
  const [error, setError] = useState('');

  function enter(role: ErpRole) {
    const u = loginAsRole(role);
    navigate(ROLE_META[u.role].landing);
  }

  async function sendCode(e: React.FormEvent) {
    e.preventDefault();
    if (AUTH_IS_DEMO) return enter(selected);
    setSending(true);
    setError('');
    try {
      const type = identifier.includes('@') ? 'email' : 'phone';
      await requestOtp(identifier.trim(), type);
      navigate('/otp');
    } catch (err) {
      setError((err as Error).message || 'Could not send code. Check the identifier and try again.');
    } finally {
      setSending(false);
    }
  }

  return (
    <div className="relative flex min-h-screen">
      <button
        onClick={toggle}
        aria-label="Toggle theme"
        className="absolute right-s4 top-s4 z-10 grid h-10 w-10 place-items-center rounded-full bg-surface/80 text-on-surface-variant backdrop-blur hover:bg-surface"
      >
        <Icon name={resolved === 'dark' ? 'light_mode' : 'dark_mode'} size={20} />
      </button>

      {/* Brand panel */}
      <div className="relative hidden w-1/2 flex-col justify-between overflow-hidden bg-primary p-s12 lg:flex">
        <div className="absolute -right-24 -top-24 h-96 w-96 rounded-full bg-white/10 blur-3xl" />
        <div className="absolute -bottom-32 -left-16 h-96 w-96 rounded-full bg-white/10 blur-3xl" />
        <Logo tone="onPrimary" size={44} />
        <div className="relative z-10 max-w-md">
          <Text variant="display-md" as="h1" className="text-white">
            The easiest school ERP, now on the web.
          </Text>
          <Text variant="body-lg" className="mt-s4 text-white/80">
            Admissions to alumni, fees to timetables — one unified platform for every role in your school.
          </Text>
          <div className="mt-s8 flex flex-wrap gap-s2">
            {['Admissions', 'Finance', 'Attendance', 'Exams', 'Transport', 'HR'].map((m) => (
              <span key={m} className="rounded-full bg-white/12 px-s3 py-s1 ak-label-md text-white ring-1 ring-white/20">
                {m}
              </span>
            ))}
          </div>
        </div>
        <Text variant="body-sm" className="relative z-10 text-white">
          © {new Date().getFullYear()} NIKSHA Technologies Pvt. Ltd. Multi-tenant school platform.
        </Text>
      </div>

      {/* Form panel */}
      <div className="flex w-full items-center justify-center px-s5 py-s10 lg:w-1/2">
        <motion.div
          initial={{ opacity: 0, y: 12 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.24, ease: [0.215, 0.61, 0.355, 1] }}
          className="w-full max-w-md"
        >
          <div className="mb-s6 lg:hidden">
            <Logo size={40} />
          </div>
          <Text variant="headline-sm" as="h2" className="text-on-surface">
            Welcome back
          </Text>
          <Text variant="body-md" className="mt-s1 text-on-surface-variant">
            Sign in to your NIKSHA OS workspace.
          </Text>

          <div className="mt-s6 inline-flex w-full rounded-lg border border-outline-variant bg-surface-low p-[3px]">
            {(['demo', 'credentials'] as const).map((t) => (
              <button
                key={t}
                onClick={() => setTab(t)}
                className={cn(
                  'flex-1 rounded-md px-s3 py-s2 ak-label-lg transition-colors',
                  tab === t ? 'bg-surface text-primary shadow-ak-1' : 'text-on-surface-variant',
                )}
              >
                {t === 'demo' ? 'Explore by role' : 'Sign in'}
              </button>
            ))}
          </div>

          {tab === 'demo' ? (
            <div className="mt-s5">
              {AUTH_IS_DEMO && (
                <div className="mb-s4 flex items-center gap-s2 rounded-md bg-primary-container/60 px-s3 py-s2 ak-body-sm text-on-primary-container">
                  <Icon name="info" size={16} />
                  Preview mode — pick a role to explore its workspace and layout.
                </div>
              )}
              <div className="grid max-h-[46vh] grid-cols-1 gap-s2 overflow-y-auto pr-s1 sm:grid-cols-2">
                {DEMO_ROLES.map((r) => {
                  const rm = ROLE_META[r];
                  const active = r === selected;
                  return (
                    <button
                      key={r}
                      onClick={() => setSelected(r)}
                      onDoubleClick={() => enter(r)}
                      className={cn(
                        'flex items-center gap-s3 rounded-lg border p-s3 text-left transition-all',
                        active
                          ? 'border-primary bg-primary-container/50 ring-1 ring-primary'
                          : 'border-outline-variant bg-surface hover:bg-surface-low',
                      )}
                    >
                      <span
                        className={cn(
                          'grid h-9 w-9 shrink-0 place-items-center rounded-lg',
                          active ? 'bg-primary text-on-primary' : 'bg-surface-container text-on-surface-variant',
                        )}
                      >
                        <Icon name={rm.icon} size={20} />
                      </span>
                      <span className="min-w-0">
                        <span className="block ak-label-lg text-on-surface">{rm.label}</span>
                        <span className="block truncate text-[11px] text-secondary">{rm.workspace} workspace</span>
                      </span>
                    </button>
                  );
                })}
              </div>
              <Button className="mt-s5" fullWidth size="lg" trailingIcon="arrow_forward" onClick={() => enter(selected)}>
                Continue as {ROLE_META[selected].label}
              </Button>
            </div>
          ) : (
            <form className="mt-s5 space-y-s4" onSubmit={sendCode}>
              <Input
                label="Mobile number or email"
                leadingIcon="person"
                placeholder="9876543210"
                value={identifier}
                onChange={(e) => setIdentifier(e.target.value)}
                autoComplete="username"
                error={error || undefined}
              />
              <Button type="submit" fullWidth size="lg" loading={sending} disabled={!AUTH_IS_DEMO && !identifier.trim()} trailingIcon="arrow_forward">
                {AUTH_IS_DEMO ? 'Continue' : 'Send verification code'}
              </Button>
              <Text variant="body-sm" className="text-center text-on-surface-variant">
                {AUTH_IS_DEMO
                  ? 'Demo mode is on — use “Explore by role”, or connect a live backend to sign in with OTP.'
                  : 'We’ll send a one-time code to verify your identity.'}
              </Text>
            </form>
          )}
        </motion.div>
      </div>
    </div>
  );
}
