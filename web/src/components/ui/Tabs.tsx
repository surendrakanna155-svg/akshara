import { cn } from '@/lib/utils/cn';
import { Icon } from '@/components/Icon';

export interface TabItem {
  key: string;
  label: string;
  icon?: string;
  count?: number;
}

export interface TabsProps {
  items: TabItem[];
  value: string;
  onChange: (key: string) => void;
  className?: string;
}

/** Ports the M15 TabBarTheme — underline indicator, primary active label. */
export function Tabs({ items, value, onChange, className }: TabsProps) {
  return (
    <div role="tablist" className={cn('flex items-center gap-s1 overflow-x-auto border-b border-outline-variant/65', className)}>
      {items.map((t) => {
        const active = t.key === value;
        return (
          <button
            key={t.key}
            role="tab"
            aria-selected={active}
            onClick={() => onChange(t.key)}
            className={cn(
              'relative inline-flex items-center gap-s2 whitespace-nowrap px-s3 py-s3 ak-label-lg transition-colors duration-fast',
              active ? 'text-primary' : 'text-on-surface-variant hover:text-on-surface',
            )}
          >
            {t.icon && <Icon name={t.icon} size={18} />}
            {t.label}
            {t.count !== undefined && (
              <span
                className={cn(
                  'rounded-full px-s2 py-[1px] ak-label-sm',
                  active ? 'bg-primary-container text-on-primary-container' : 'bg-surface-highest text-on-surface-variant',
                )}
              >
                {t.count}
              </span>
            )}
            {active && <span className="absolute inset-x-s2 -bottom-px h-[3px] rounded-full bg-primary" />}
          </button>
        );
      })}
    </div>
  );
}
