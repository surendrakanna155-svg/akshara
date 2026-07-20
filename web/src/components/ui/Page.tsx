import { cn } from '@/lib/utils/cn';
import { Icon } from '@/components/Icon';
import { Text } from './Text';

export interface PageHeaderProps {
  title: string;
  subtitle?: string;
  icon?: string;
  breadcrumbs?: { label: string; onClick?: () => void }[];
  actions?: React.ReactNode;
  tabs?: React.ReactNode;
  className?: string;
}

/** Standard page header used at the top of every ERP page. */
export function PageHeader({ title, subtitle, icon, breadcrumbs, actions, tabs, className }: PageHeaderProps) {
  return (
    <div className={cn('flex flex-col gap-s4', className)}>
      {breadcrumbs && breadcrumbs.length > 0 && (
        <nav className="flex flex-wrap items-center gap-s1 ak-label-md text-on-surface-variant">
          {breadcrumbs.map((b, i) => (
            <span key={i} className="inline-flex items-center gap-s1">
              {i > 0 && <Icon name="chevron_right" size={16} className="opacity-60" />}
              <button
                onClick={b.onClick}
                className={cn(b.onClick ? 'hover:text-primary' : 'cursor-default', i === breadcrumbs.length - 1 && 'text-on-surface')}
              >
                {b.label}
              </button>
            </span>
          ))}
        </nav>
      )}
      <div className="flex flex-wrap items-start justify-between gap-s4">
        <div className="flex items-start gap-s3">
          {icon && (
            <span className="grid h-11 w-11 place-items-center rounded-xl bg-primary-container text-on-primary-container">
              <Icon name={icon} size={24} />
            </span>
          )}
          <div>
            <Text variant="headline-sm" as="h1" className="text-on-surface">
              {title}
            </Text>
            {subtitle && (
              <Text variant="body-md" className="mt-[2px] text-on-surface-variant">
                {subtitle}
              </Text>
            )}
          </div>
        </div>
        {actions && <div className="flex flex-wrap items-center gap-s2">{actions}</div>}
      </div>
      {tabs}
    </div>
  );
}

export interface SectionHeaderProps {
  title: string;
  subtitle?: string;
  action?: React.ReactNode;
  className?: string;
}

export function SectionHeader({ title, subtitle, action, className }: SectionHeaderProps) {
  return (
    <div className={cn('mb-s3 flex items-end justify-between gap-s3', className)}>
      <div>
        <Text variant="title-sm" className="uppercase tracking-wide text-on-surface-variant">
          {title}
        </Text>
        {subtitle && (
          <Text variant="body-sm" className="text-on-surface-variant/80">
            {subtitle}
          </Text>
        )}
      </div>
      {action}
    </div>
  );
}

/** A responsive grid of KPI cards / summary tiles. */
export function StatGrid({ children, className }: { children: React.ReactNode; className?: string }) {
  return <div className={cn('grid grid-cols-1 gap-s4 sm:grid-cols-2 xl:grid-cols-4', className)}>{children}</div>;
}
