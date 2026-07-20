import { useEffect } from 'react';
import { AnimatePresence, motion } from 'framer-motion';
import { cn } from '@/lib/utils/cn';
import { Icon } from '@/components/Icon';
import { Text } from './Text';

export interface DialogProps {
  open: boolean;
  onClose: () => void;
  title?: string;
  subtitle?: string;
  icon?: string;
  children?: React.ReactNode;
  footer?: React.ReactNode;
  size?: 'sm' | 'md' | 'lg' | 'xl';
  /** Disable close-on-scrim / Esc (e.g. destructive confirmations). */
  dismissible?: boolean;
}

const SIZE = { sm: 'max-w-md', md: 'max-w-lg', lg: 'max-w-2xl', xl: 'max-w-4xl' } as const;

/** Ports AksharaDialog — 24px radius, level4 elevation, scrim + centered card. */
export function Dialog({
  open,
  onClose,
  title,
  subtitle,
  icon,
  children,
  footer,
  size = 'md',
  dismissible = true,
}: DialogProps) {
  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape' && dismissible) onClose();
    };
    window.addEventListener('keydown', onKey);
    document.body.style.overflow = 'hidden';
    return () => {
      window.removeEventListener('keydown', onKey);
      document.body.style.overflow = '';
    };
  }, [open, onClose, dismissible]);

  return (
    <AnimatePresence>
      {open && (
        <div className="fixed inset-0 z-50 grid place-items-center p-s4">
          <motion.div
            className="absolute inset-0 bg-[rgb(var(--ak-scrim)/0.45)]"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.18 }}
            onClick={() => dismissible && onClose()}
          />
          <motion.div
            role="dialog"
            aria-modal="true"
            aria-label={title}
            className={cn(
              'relative z-10 w-full overflow-hidden rounded-2xl border border-outline-variant/55 bg-surface shadow-ak-5',
              SIZE[size],
            )}
            initial={{ opacity: 0, scale: 0.98, y: 8 }}
            animate={{ opacity: 1, scale: 1, y: 0 }}
            exit={{ opacity: 0, scale: 0.98, y: 8 }}
            transition={{ duration: 0.18, ease: [0.215, 0.61, 0.355, 1] }}
          >
            {(title || icon) && (
              <div className="flex items-start justify-between gap-s3 px-s6 pt-s6">
                <div className="flex items-start gap-s3">
                  {icon && (
                    <span className="grid h-10 w-10 place-items-center rounded-lg bg-primary-container text-on-primary-container">
                      <Icon name={icon} size={22} />
                    </span>
                  )}
                  <div>
                    {title && (
                      <Text variant="title-lg" className="text-on-surface">
                        {title}
                      </Text>
                    )}
                    {subtitle && (
                      <Text variant="body-sm" className="mt-[2px] text-on-surface-variant">
                        {subtitle}
                      </Text>
                    )}
                  </div>
                </div>
                {dismissible && (
                  <button
                    onClick={onClose}
                    aria-label="Close"
                    className="grid h-9 w-9 place-items-center rounded-full text-on-surface-variant hover:bg-on-surface/5"
                  >
                    <Icon name="close" size={20} />
                  </button>
                )}
              </div>
            )}
            {children && <div className="max-h-[70vh] overflow-y-auto px-s6 py-s5">{children}</div>}
            {footer && <div className="flex justify-end gap-s3 border-t border-outline-variant/60 px-s6 py-s4">{footer}</div>}
          </motion.div>
        </div>
      )}
    </AnimatePresence>
  );
}
