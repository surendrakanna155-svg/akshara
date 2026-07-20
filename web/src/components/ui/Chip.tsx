import { cn } from '@/lib/utils/cn';
import { Icon } from '@/components/Icon';

export type SemanticStatus = 'neutral' | 'info' | 'success' | 'warning' | 'error' | 'pending';

// Mirrors lib/shared/semantic_status.dart → container/on-container token pairs.
const STATUS: Record<SemanticStatus, string> = {
  neutral: 'bg-surface-highest text-on-surface-variant',
  info: 'bg-primary-container text-on-primary-container',
  success: 'bg-success-container text-success',
  warning: 'bg-warning-container text-warning',
  error: 'bg-error-container text-error',
  pending: 'bg-indigo-container text-indigo',
};

const STATUS_ICON: Record<SemanticStatus, string> = {
  neutral: 'circle',
  info: 'info',
  success: 'check_circle',
  warning: 'warning',
  error: 'error',
  pending: 'schedule',
};

export interface StatusChipProps {
  status: SemanticStatus;
  label: string;
  icon?: string | false;
  className?: string;
}

/** Ports AksharaStatusChip — pill with a semantic color pair. */
export function StatusChip({ status, label, icon, className }: StatusChipProps) {
  return (
    <span
      className={cn(
        'inline-flex items-center gap-s1 rounded-full px-s2 py-[3px] ak-label-sm font-medium',
        STATUS[status],
        className,
      )}
    >
      {icon !== false && <Icon name={icon || STATUS_ICON[status]} size={14} />}
      {label}
    </span>
  );
}

export interface ChipProps {
  label: string;
  icon?: string;
  selected?: boolean;
  onClick?: () => void;
  onRemove?: () => void;
  className?: string;
}

/** Filter / context chip — matches the M15 ChipTheme. */
export function Chip({ label, icon, selected, onClick, onRemove, className }: ChipProps) {
  const Comp = onClick ? 'button' : 'span';
  return (
    <Comp
      onClick={onClick}
      className={cn(
        'inline-flex items-center gap-s1 rounded-sm border px-s2 py-s1 ak-label-md transition-colors duration-fast',
        selected
          ? 'border-primary/40 bg-primary-container text-on-primary-container'
          : 'border-outline-variant bg-surface-low text-on-surface-variant hover:bg-surface-container',
        onClick && 'cursor-pointer',
        className,
      )}
    >
      {icon && <Icon name={icon} size={16} />}
      {label}
      {onRemove && (
        <button
          type="button"
          aria-label={`Remove ${label}`}
          onClick={(e) => {
            e.stopPropagation();
            onRemove();
          }}
          className="ml-[2px] grid h-4 w-4 place-items-center rounded-full hover:bg-on-surface/10"
        >
          <Icon name="close" size={12} />
        </button>
      )}
    </Comp>
  );
}
