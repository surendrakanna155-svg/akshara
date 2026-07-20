import { cn } from '@/lib/utils/cn';

/**
 * Reusable Akshara logo placeholder. The final brand mark is not yet finalized,
 * so every surface renders through this component — swap the internals here once
 * the real logo lands, with zero page changes.
 */
export interface LogoProps {
  /** Show the wordmark next to the mark. */
  showWordmark?: boolean;
  size?: number;
  /** `onPrimary` inverts for use on a colored (login/hero) background. */
  tone?: 'default' | 'onPrimary';
  className?: string;
}

export function Logo({ showWordmark = true, size = 36, tone = 'default', className }: LogoProps) {
  const onPrimary = tone === 'onPrimary';
  return (
    <span className={cn('inline-flex items-center gap-s3', className)}>
      <span
        className={cn(
          'grid place-items-center rounded-[10px] font-bold',
          onPrimary ? 'bg-white/15 text-white ring-1 ring-white/30' : 'bg-primary text-on-primary shadow-ak-2',
        )}
        style={{ width: size, height: size, fontSize: size * 0.5 }}
        aria-hidden
      >
        A
      </span>
      {showWordmark && (
        <span className="flex flex-col leading-none">
          <span className={cn('ak-title-md font-bold tracking-tight', onPrimary ? 'text-white' : 'text-on-surface')}>
            Akshara
          </span>
          <span className={cn('text-[10px] font-medium uppercase tracking-[0.18em]', onPrimary ? 'text-white/90' : 'text-secondary')}>
            School ERP
          </span>
        </span>
      )}
    </span>
  );
}
