import { cn } from '@/lib/utils/cn';

/**
 * Material Symbols (Rounded) — the web equivalent of Flutter's Material `Icons.*`.
 * Usage: <Icon name="dashboard" /> · <Icon name="check_circle" fill /> · sizes in px.
 */
export interface IconProps {
  name: string;
  /** Filled variant (Flutter's filled icons). */
  fill?: boolean;
  size?: number;
  weight?: 300 | 400 | 500 | 600 | 700;
  className?: string;
  title?: string;
}

export function Icon({ name, fill, size = 24, weight = 400, className, title }: IconProps) {
  return (
    <span
      className={cn('material-symbols-rounded inline-flex shrink-0 leading-none', fill && 'fill', className)}
      style={{
        fontSize: size,
        width: size,
        height: size,
        fontVariationSettings: `'FILL' ${fill ? 1 : 0}, 'wght' ${weight}, 'GRAD' 0, 'opsz' ${size}`,
      }}
      aria-hidden={title ? undefined : true}
      role={title ? 'img' : undefined}
      aria-label={title}
    >
      {name}
    </span>
  );
}
