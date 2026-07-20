import { cn } from '@/lib/utils/cn';
import { Icon } from '@/components/Icon';
import { Text } from './Text';

export interface CardProps extends React.HTMLAttributes<HTMLDivElement> {
  /** Adds hover lift + pointer affordance (matches AksharaInteractiveSurface). */
  interactive?: boolean;
  padded?: boolean;
}

/** Ports AksharaSurfaceCard — 16px radius, hairline outline, transparent tint. */
export function Card({ interactive, padded = true, className, children, ...rest }: CardProps) {
  return (
    <div
      className={cn(
        'rounded-lg border border-outline-variant/60 bg-surface',
        padded && 'p-s5',
        interactive &&
          'cursor-pointer transition-all duration-standard ease-enter hover:-translate-y-[1px] hover:shadow-ak-2',
        className,
      )}
      {...rest}
    >
      {children}
    </div>
  );
}

export interface CardHeaderProps {
  title: string;
  subtitle?: string;
  icon?: string;
  action?: React.ReactNode;
  className?: string;
}

/** Ports AksharaSectionHeader used at the top of dashboard cards. */
export function CardHeader({ title, subtitle, icon, action, className }: CardHeaderProps) {
  return (
    <div className={cn('mb-s4 flex items-start justify-between gap-s3', className)}>
      <div className="flex min-w-0 items-start gap-s3">
        {icon && (
          <span className="mt-[2px] grid h-9 w-9 shrink-0 place-items-center rounded-md bg-primary-container text-on-primary-container">
            <Icon name={icon} size={20} />
          </span>
        )}
        <div className="min-w-0">
          <Text variant="title-md" className="truncate text-on-surface">
            {title}
          </Text>
          {subtitle && (
            <Text variant="body-sm" className="text-on-surface-variant">
              {subtitle}
            </Text>
          )}
        </div>
      </div>
      {action && <div className="shrink-0">{action}</div>}
    </div>
  );
}
