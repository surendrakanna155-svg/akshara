import { useEffect, useRef, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { motion } from 'framer-motion';
import { useAuth } from '@/lib/auth/AuthContext';
import { ROLE_META } from '@/lib/auth/roles';
import { Button, Logo, Text } from '@/components/ui';
import { Icon } from '@/components/Icon';
import { cn } from '@/lib/utils/cn';

/** OTP verification — ports otp_verification_screen.dart / staff_otp_screen.dart. */
export function OtpVerificationPage() {
  const navigate = useNavigate();
  const { loginAsRole, verifyOtp, pendingOtp } = useAuth();
  const [digits, setDigits] = useState<string[]>(['', '', '', '', '', '']);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const refs = useRef<(HTMLInputElement | null)[]>([]);

  // Pilot/dev backends return the OTP in the login response — prefill it.
  useEffect(() => {
    if (pendingOtp?.devOtp && pendingOtp.devOtp.length === 6) setDigits(pendingOtp.devOtp.split(''));
  }, [pendingOtp]);

  async function submit() {
    const code = digits.join('');
    if (!pendingOtp) {
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

  function set(i: number, v: string) {
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
                onChange={(e) => set(i, e.target.value)}
                onKeyDown={(e) => { if (e.key === 'Backspace' && !digits[i] && i > 0) refs.current[i - 1]?.focus(); }}
                className={cn('h-14 w-12 rounded-lg border bg-surface-low text-center ak-headline-sm text-on-surface outline-none transition-colors',
                  d ? 'border-primary' : 'border-outline-variant', 'focus:border-primary focus:ring-2 focus:ring-primary/25')} />
            ))}
          </div>
          {error && <Text variant="body-sm" className="mt-s3 text-center text-error">{error}</Text>}
          <Button className="mt-s6" fullWidth size="lg" loading={busy} disabled={!complete} onClick={submit}>
            Verify & continue
          </Button>
          <div className="mt-s4 text-center">
            <button className="ak-label-md text-primary hover:underline">Resend code</button>
          </div>
        </div>
        <div className="mt-s4 text-center">
          <button onClick={() => navigate('/login')} className="ak-label-md text-on-surface-variant hover:text-on-surface">← Back to sign in</button>
        </div>
      </motion.div>
    </div>
  );
}
