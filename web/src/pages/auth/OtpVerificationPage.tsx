import { useEffect, useRef, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { motion } from 'framer-motion';
import { AUTH_IS_DEMO, useAuth } from '@/lib/auth/AuthContext';
import { ROLE_META } from '@/lib/auth/roles';
import { Button, Logo, Text } from '@/components/ui';
import { Icon } from '@/components/Icon';
import { cn } from '@/lib/utils/cn';

/**
 * Mirrors the backend's OTP_RESEND_COOLDOWN_SECONDS default. Purely a UI hint —
 * the server remains the authority and still rejects an early resend.
 */
const RESEND_COOLDOWN_SECONDS = 60;

/** OTP verification — ports otp_verification_screen.dart / staff_otp_screen.dart. */
export function OtpVerificationPage() {
  const navigate = useNavigate();
  const { loginAsRole, verifyOtp, requestOtp, pendingOtp } = useAuth();
  const [digits, setDigits] = useState<string[]>(['', '', '', '', '', '']);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');
  const [resending, setResending] = useState(false);
  // Seeded on arrival: the user has just been sent a code, so the server is
  // already inside its cooldown window. Starting at 0 would offer a button that
  // is guaranteed to 429.
  const [resendIn, setResendIn] = useState(RESEND_COOLDOWN_SECONDS);
  const refs = useRef<(HTMLInputElement | null)[]>([]);

  // Pilot/dev backends return the OTP in the login response — prefill it.
  useEffect(() => {
    if (pendingOtp?.devOtp && pendingOtp.devOtp.length === 6) setDigits(pendingOtp.devOtp.split(''));
  }, [pendingOtp]);

  useEffect(() => {
    if (resendIn <= 0) return;
    const t = setTimeout(() => setResendIn((s) => s - 1), 1000);
    return () => clearTimeout(t);
  }, [resendIn]);

  async function resend() {
    if (!pendingOtp || resendIn > 0 || resending) return;
    setResending(true);
    setError('');
    setNotice('');
    try {
      await requestOtp(pendingOtp.identifier, pendingOtp.type);
      setDigits(['', '', '', '', '', '']);
      refs.current[0]?.focus();
      setResendIn(RESEND_COOLDOWN_SECONDS);
      setNotice(`A new code has been sent to ${pendingOtp.identifier}.`);
    } catch (e) {
      // Covers OTP_COOLDOWN / OTP_RATE_LIMITED — the server's message is the
      // accurate one (it knows the real window), so surface it as-is and hold
      // the button closed rather than inviting another rejected attempt.
      setError((e as Error).message || 'Could not resend the code. Please try again shortly.');
      setResendIn(RESEND_COOLDOWN_SECONDS);
    } finally {
      setResending(false);
    }
  }

  async function submit() {
    const code = digits.join('');
    if (!pendingOtp) {
      // No OTP request in flight — reachable by opening /otp directly or by
      // reloading (the pending request lives in memory only). In a DEMO build
      // this is the preview shortcut. In a LIVE build it must NOT mint a
      // session: that was an unauthenticated route straight into the admin
      // workspace. Send the user back to start a real sign-in instead.
      if (!AUTH_IS_DEMO) {
        setError('Your sign-in session expired. Please request a new code.');
        return;
      }
      const u = loginAsRole('schoolAdmin');
      navigate(ROLE_META[u.role].landing);
      return;
    }
    setBusy(true);
    setError('');
    try {
      const u = await verifyOtp(code);
      navigate(ROLE_META[u.role].landing);
    } catch (e) {
      setError((e as Error).message || 'Invalid or expired code.');
    } finally {
      setBusy(false);
    }
  }

  /**
   * Write one or more digits starting at `from`, then park the caret on the
   * last box touched. This is the single path used by typing, pasting an SMS
   * code, and platform one-time-code autofill — all three can deliver more than
   * one character at once (`maxLength` does not constrain autofilled values),
   * and previously anything longer than a single digit was silently dropped.
   */
  function fill(from: number, raw: string) {
    const chars = raw.replace(/\D/g, '').slice(0, 6 - from).split('');
    if (chars.length === 0) return;
    setDigits((prev) => {
      const next = [...prev];
      chars.forEach((c, k) => (next[from + k] = c));
      return next;
    });
    refs.current[Math.min(from + chars.length, 5)]?.focus();
  }

  function set(i: number, v: string) {
    if (v.length > 1) return fill(i, v); // autofill / paste-into-box
    if (!/^\d?$/.test(v)) return;
    const next = [...digits];
    next[i] = v;
    setDigits(next);
    if (v && i < 5) refs.current[i + 1]?.focus();
  }
  const complete = digits.every((d) => d !== '');

  return (
    <div className="grid min-h-screen place-items-center bg-surface-low px-s5">
      <motion.div initial={{ opacity: 0, y: 12 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.24 }} className="w-full max-w-md">
        <div className="mb-s6 flex justify-center"><Logo size={44} /></div>
        <div className="rounded-2xl border border-outline-variant/60 bg-surface p-s8 shadow-ak-2">
          <div className="mb-s4 grid place-items-center">
            <span className="grid h-12 w-12 place-items-center rounded-full bg-primary-container text-on-primary-container"><Icon name="sms" size={26} /></span>
          </div>
          <Text variant="headline-sm" as="h1" className="text-center text-on-surface">Verify OTP</Text>
          <Text variant="body-md" className="mt-s1 text-center text-on-surface-variant">
            {pendingOtp ? `Enter the 6-digit code sent to ${pendingOtp.identifier}.` : 'Enter the 6-digit code sent to your registered mobile number.'}
          </Text>
          <div className="mt-s6 flex justify-center gap-s2">
            {digits.map((d, i) => (
              <input key={i} ref={(el) => (refs.current[i] = el)} value={d} inputMode="numeric" maxLength={1}
                // `one-time-code` on the FIRST box is what iOS/Android match to
                // hand over the SMS code; repeating it on all six makes the
                // platform offer autofill six times. `fill()` then spreads the
                // delivered code across the boxes.
                autoComplete={i === 0 ? 'one-time-code' : 'off'}
                aria-label={`Digit ${i + 1} of 6`}
                onChange={(e) => set(i, e.target.value)}
                onPaste={(e) => { e.preventDefault(); fill(i, e.clipboardData.getData('text')); }}
                onKeyDown={(e) => { if (e.key === 'Backspace' && !digits[i] && i > 0) refs.current[i - 1]?.focus(); }}
                className={cn('h-14 w-12 rounded-lg border bg-surface-low text-center ak-headline-sm text-on-surface outline-none transition-colors',
                  d ? 'border-primary' : 'border-outline-variant', 'focus:border-primary focus:ring-2 focus:ring-primary/25')} />
            ))}
          </div>
          {error && <Text variant="body-sm" className="mt-s3 text-center text-error">{error}</Text>}
          {notice && !error && <Text variant="body-sm" className="mt-s3 text-center text-primary">{notice}</Text>}
          <Button className="mt-s6" fullWidth size="lg" loading={busy} disabled={!complete} onClick={submit}>
            Verify & continue
          </Button>
          <div className="mt-s4 text-center">
            <button
              type="button"
              onClick={resend}
              disabled={!pendingOtp || resendIn > 0 || resending}
              className="ak-label-md text-primary transition-colors hover:underline disabled:cursor-not-allowed disabled:text-on-surface-variant disabled:no-underline"
            >
              {resending ? 'Sending…' : resendIn > 0 ? `Resend code in ${resendIn}s` : 'Resend code'}
            </button>
          </div>
        </div>
        <div className="mt-s4 text-center">
          <button onClick={() => navigate('/login')} className="ak-label-md text-on-surface-variant hover:text-on-surface">← Back to sign in</button>
        </div>
      </motion.div>
    </div>
  );
}
