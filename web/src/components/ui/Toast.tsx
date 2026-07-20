import { createContext, useCallback, useContext, useMemo, useRef, useState } from 'react';
import { AnimatePresence, motion } from 'framer-motion';
import { cn } from '@/lib/utils/cn';
import { Icon } from '@/components/Icon';

type ToastTone = 'success' | 'error' | 'info' | 'warning';
interface Toast {
  id: number;
  message: string;
  tone: ToastTone;
}
interface ToastApi {
  show: (message: string, tone?: ToastTone) => void;
  success: (message: string) => void;
  error: (message: string) => void;
  info: (message: string) => void;
}

const ToastContext = createContext<ToastApi | null>(null);

const TONE: Record<ToastTone, { icon: string; cls: string }> = {
  success: { icon: 'check_circle', cls: 'text-success' },
  error: { icon: 'error', cls: 'text-error' },
  warning: { icon: 'warning', cls: 'text-warning' },
  info: { icon: 'info', cls: 'text-primary' },
};

/** Global snackbar host — ports the M15 SnackBar (inverse surface, floating). */
export function ToastProvider({ children }: { children: React.ReactNode }) {
  const [toasts, setToasts] = useState<Toast[]>([]);
  const seq = useRef(0);

  const show = useCallback((message: string, tone: ToastTone = 'info') => {
    const id = ++seq.current;
    setToasts((t) => [...t, { id, message, tone }]);
    setTimeout(() => setToasts((t) => t.filter((x) => x.id !== id)), 3500);
  }, []);

  const api = useMemo<ToastApi>(
    () => ({ show, success: (m) => show(m, 'success'), error: (m) => show(m, 'error'), info: (m) => show(m, 'info') }),
    [show],
  );

  return (
    <ToastContext.Provider value={api}>
      {children}
      <div className="pointer-events-none fixed inset-x-0 bottom-s6 z-[80] flex flex-col items-center gap-s2 px-s4">
        <AnimatePresence>
          {toasts.map((t) => (
            <motion.div
              key={t.id}
              initial={{ opacity: 0, y: 16, scale: 0.98 }}
              animate={{ opacity: 1, y: 0, scale: 1 }}
              exit={{ opacity: 0, y: 8, scale: 0.98 }}
              transition={{ duration: 0.18, ease: [0.215, 0.61, 0.355, 1] }}
              role="status"
              className="pointer-events-auto flex max-w-md items-center gap-s2 rounded-lg bg-inverse-surface px-s4 py-s3 text-on-inverse-surface shadow-ak-4"
            >
              <Icon name={TONE[t.tone].icon} size={20} className={cn(TONE[t.tone].cls)} />
              <span className="ak-body-md">{t.message}</span>
            </motion.div>
          ))}
        </AnimatePresence>
      </div>
    </ToastContext.Provider>
  );
}

export function useToast(): ToastApi {
  const ctx = useContext(ToastContext);
  if (!ctx) throw new Error('useToast must be used within ToastProvider');
  return ctx;
}
