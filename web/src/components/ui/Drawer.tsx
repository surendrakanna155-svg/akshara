import { useEffect } from 'react';
import { AnimatePresence, motion } from 'framer-motion';
import { cn } from '@/lib/utils/cn';
import { Icon } from '@/components/Icon';
import { Text } from './Text';

export interface DrawerProps {
  open: boolean;
  onClose: () => void;
  title?: string;
  subtitle?: string;
  children?: React.ReactNode;
  footer?: React.ReactNode;
  /** Right-side sheet (default) is the desktop equivalent of a bottom sheet. */
  side?: 'right' | 'left';
  width?: number;
}

/** Desktop side sheet — the web adaptation of Flutter's modal bottom sheet. */
export function Drawer({ open, onClose, title, subtitle, children, footer, side = 'right', width = 460 }: DrawerProps) {
  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && onClose();
    window.addEventListener('keydown', onKey);
    document.body.style.overflow = 'hidden';
    return () => {
      window.removeEventListener('keydown', onKey);
      document.body.style.overflow = '';
    };
  }, [open, onClose]);

  return (
    <AnimatePresence>
      {open && (
        <div className="fixed inset-0 z-50">
          <motion.div
            className="absolute inset-0 bg-[rgb(var(--ak-scrim)/0.45)]"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.18 }}
            onClick={onClose}
          />
          <motion.aside
            role="dialog"
            aria-modal="true"
            aria-label={title}
            className={cn(
              'absolute top-0 flex h-full flex-col border-outline-variant/55 bg-surface shadow-ak-5',
              side === 'right' ? 'right-0 border-l' : 'left-0 border-r',
            )}
            style={{ width: `min(${width}px, 92vw)` }}
            initial={{ x: side === 'right' ? width : -width }}
            animate={{ x: 0 }}
            exit={{ x: side === 'right' ? width : -width }}
            transition={{ duration: 0.24, ease: [0.215, 0.61, 0.355, 1] }}
          >
            {title && (
              <div className="flex items-start justify-between gap-s3 border-b border-outline-variant/60 px-s5 py-s4">
                <div>
                  <Text variant="title-md" className="text-on-surface">
                    {title}
                  </Text>
                  {subtitle && (
                    <Text variant="body-sm" className="text-on-surface-variant">
                      {subtitle}
                    </Text>
                  )}
                </div>
                <button
                  onClick={onClose}
                  aria-label="Close"
                  className="grid h-9 w-9 place-items-center rounded-full text-on-surface-variant hover:bg-on-surface/5"
                >
                  <Icon name="close" size={20} />
                </button>
              </div>
            )}
            <div className="flex-1 overflow-y-auto px-s5 py-s4">{children}</div>
            {footer && <div className="flex justify-end gap-s3 border-t border-outline-variant/60 px-s5 py-s4">{footer}</div>}
          </motion.aside>
        </div>
      )}
    </AnimatePresence>
  );
}
