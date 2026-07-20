import { cn } from '@/lib/utils/cn';
import { Icon } from '@/components/Icon';

export function Divider({ className }: { className?: string }) {
  return <hr className={cn('border-0 border-t border-outline-variant/60', className)} />;
}

export function Badge({ children, tone = 'neutral', className }: { children: React.ReactNode; tone?: 'neutral' | 'primary' | 'success' | 'warning' | 'error'; className?: string }) {
  const map = {
    neutral: 'bg-surface-highest text-on-surface-variant',
    primary: 'bg-primary-container text-on-primary-container',
    success: 'bg-success-container text-success',
    warning: 'bg-warning-container text-warning',
    error: 'bg-error-container text-error',
  } as const;
  return <span className={cn('inline-flex items-center rounded-full px-s2 py-[1px] ak-label-sm', map[tone], className)}>{children}</span>;
}

/** Lightweight CSS tooltip. */
export function Tooltip({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <span className="group/tt relative inline-flex">
      {children}
      <span className="pointer-events-none absolute -top-1 left-1/2 z-30 -translate-x-1/2 -translate-y-full whitespace-nowrap rounded-sm bg-inverse-surface px-s2 py-s1 ak-body-sm text-on-inverse-surface opacity-0 shadow-ak-3 transition-opacity duration-fast group-hover/tt:opacity-100">
        {label}
      </span>
    </span>
  );
}

export interface FilterBarProps {
  children: React.ReactNode;
  className?: string;
}

/** Sticky filter/search row above tables. */
export function FilterBar({ children, className }: FilterBarProps) {
  return <div className={cn('flex flex-wrap items-center gap-s2', className)}>{children}</div>;
}

/** Segmented control (period pills, view toggles). */
export function Segmented<T extends string>({
  options,
  value,
  onChange,
  className,
}: {
  options: { value: T; label: string; icon?: string }[];
  value: T;
  onChange: (v: T) => void;
  className?: string;
}) {
  return (
    <div className={cn('inline-flex rounded-md border border-outline-variant bg-surface-low p-[3px]', className)}>
      {options.map((o) => (
        <button
          key={o.value}
          onClick={() => onChange(o.value)}
          className={cn(
            'inline-flex items-center gap-s1 rounded-[9px] px-s3 py-s1 ak-label-md transition-colors duration-fast',
            value === o.value ? 'bg-surface text-primary shadow-ak-1' : 'text-on-surface-variant hover:text-on-surface',
          )}
        >
          {o.icon && <Icon name={o.icon} size={16} />}
          {o.label}
        </button>
      ))}
    </div>
  );
}
