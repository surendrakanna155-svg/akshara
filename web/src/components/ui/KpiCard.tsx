import { cn } from '@/lib/utils/cn';
import { Icon } from '@/components/Icon';
import { Text } from './Text';

export interface KpiCardProps {
  label: string;
  value: string | number;
  icon?: string;
  /** Positive/negative delta vs previous period, e.g. +12.4. */
  delta?: number;
  deltaSuffix?: string;
  /** Muted supporting line under the value. */
  hint?: string;
  accent?: 'primary' | 'tertiary' | 'indigo' | 'success' | 'warning' | 'error';
  onClick?: () => void;
  className?: string;
}

const ACCENT: Record<NonNullable<KpiCardProps['accent']>, string> = {
  primary: 'bg-primary-container text-on-primary-container',
  tertiary: 'bg-tertiary-container text-on-tertiary-container',
  indigo: 'bg-indigo-container text-indigo',
  success: 'bg-success-container text-success',
  warning: 'bg-warning-container text-warning',
  error: 'bg-error-container text-error',
};

/** Ports AksharaKpiCard / AksharaExecutiveKpiCard — 20px radius KPI tile. */
export function KpiCard({
  label,
  value,
  icon,
  delta,
  deltaSuffix = '%',
  hint,
  accent = 'primary',
  onClick,
  className,
}: KpiCardProps) {
  const up = (delta ?? 0) >= 0;
  return (
    <div
      onClick={onClick}
      className={cn(
        'flex flex-col gap-s3 rounded-xl border border-outline-variant/60 bg-surface p-s5',
        onClick && 'cursor-pointer transition-all duration-standard ease-enter hover:-translate-y-[1px] hover:shadow-ak-2',
        className,
      )}
    >
      <div className="flex items-center justify-between">
        <Text variant="kpi-label" className="text-on-surface-variant">
          {label}
        </Text>
        {icon && (
          <span className={cn('grid h-9 w-9 place-items-center rounded-lg', ACCENT[accent])}>
            <Icon name={icon} size={20} />
          </span>
        )}
      </div>
      <Text variant="kpi-value" as="div" className="text-on-surface">
        {value}
      </Text>
      <div className="flex items-center gap-s2">
        {delta !== undefined && (
          <span
            className={cn(
              'inline-flex items-center gap-[2px] ak-label-md font-semibold',
              up ? 'text-success' : 'text-error',
            )}
          >
            <Icon name={up ? 'trending_up' : 'trending_down'} size={16} />
            {up ? '+' : ''}
            {delta}
            {deltaSuffix}
          </span>
        )}
        {hint && (
          <Text variant="body-sm" className="text-on-surface-variant">
            {hint}
          </Text>
        )}
      </div>
    </div>
  );
}
