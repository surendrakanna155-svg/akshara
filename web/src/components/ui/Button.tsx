import { forwardRef } from 'react';
import { cn } from '@/lib/utils/cn';
import { Icon } from '@/components/Icon';

export type ButtonVariant = 'filled' | 'tonal' | 'outlined' | 'text' | 'destructive';
export type ButtonSize = 'sm' | 'md' | 'lg';

export interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: ButtonVariant;
  size?: ButtonSize;
  /** Material Symbols icon name shown before the label. */
  icon?: string;
  /** Icon shown after the label. */
  trailingIcon?: string;
  loading?: boolean;
  fullWidth?: boolean;
}

// Ports lib/theme/app_theme.dart button styles (filled/tonal/outlined/text).
const VARIANT: Record<ButtonVariant, string> = {
  filled:
    'bg-primary text-on-primary hover:shadow-ak-1 active:shadow-ak-1 disabled:bg-on-surface/[.12] disabled:text-on-surface/[.38]',
  tonal:
    'bg-primary-container text-on-primary-container hover:shadow-ak-1 disabled:bg-on-surface/[.12] disabled:text-on-surface/[.38]',
  outlined:
    'bg-surface text-primary border border-outline-variant hover:bg-primary-container/40 hover:border-primary/60 disabled:text-on-surface/[.38] disabled:border-outline-variant/[.38]',
  text: 'bg-transparent text-primary hover:bg-primary/[.06] disabled:text-on-surface/[.38]',
  destructive: 'bg-error text-on-primary hover:shadow-ak-1 disabled:bg-on-surface/[.12] disabled:text-on-surface/[.38]',
};

const SIZE: Record<ButtonSize, string> = {
  sm: 'h-9 px-s3 text-[13px] gap-s1 rounded-md',
  md: 'h-11 px-s4 gap-s2 rounded-md ak-label-lg',
  lg: 'h-12 px-s5 gap-s2 rounded-md ak-label-lg',
};

export const Button = forwardRef<HTMLButtonElement, ButtonProps>(function Button(
  { variant = 'filled', size = 'md', icon, trailingIcon, loading, fullWidth, className, children, disabled, ...rest },
  ref,
) {
  const iconSize = size === 'sm' ? 18 : 20;
  return (
    <button
      ref={ref}
      disabled={disabled || loading}
      className={cn(
        'inline-flex select-none items-center justify-center whitespace-nowrap font-medium',
        'transition-all duration-fast ease-enter outline-none',
        'focus-visible:ring-2 focus-visible:ring-primary/50 focus-visible:ring-offset-1 focus-visible:ring-offset-surface',
        'disabled:cursor-not-allowed disabled:shadow-none',
        VARIANT[variant],
        SIZE[size],
        fullWidth && 'w-full',
        className,
      )}
      {...rest}
    >
      {loading ? (
        <Icon name="progress_activity" size={iconSize} className="animate-spin" />
      ) : (
        icon && <Icon name={icon} size={iconSize} />
      )}
      {children}
      {trailingIcon && !loading && <Icon name={trailingIcon} size={iconSize} />}
    </button>
  );
});

/** Circular icon-only button — matches Flutter IconButton theme. */
export const IconButton = forwardRef<HTMLButtonElement, ButtonProps & { label: string }>(function IconButton(
  { icon, label, size = 'md', className, disabled, loading, ...rest },
  ref,
) {
  const px = size === 'sm' ? 'h-9 w-9' : 'h-11 w-11';
  return (
    <button
      ref={ref}
      aria-label={label}
      title={label}
      disabled={disabled || loading}
      className={cn(
        'inline-flex items-center justify-center rounded-full text-on-surface-variant',
        'transition-all duration-fast hover:bg-primary/[.06] hover:text-primary',
        'focus-visible:ring-2 focus-visible:ring-primary/50 outline-none disabled:opacity-40',
        px,
        className,
      )}
      {...rest}
    >
      <Icon name={loading ? 'progress_activity' : icon ?? 'circle'} size={size === 'sm' ? 18 : 22} className={loading ? 'animate-spin' : ''} />
    </button>
  );
});
