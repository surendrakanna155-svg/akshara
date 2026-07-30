import { cn } from '@/lib/utils/cn';

/**
 * The NIKSHA OS brand mark. Every surface renders through this component, so a
 * brand change is one edit here with zero page changes.
 *
 * The mark itself is the approved vector master from `brand/niksha-os/svg/`,
 * copied into `web/public/brand/` — never redrawn, recoloured or traced
 * (BRAND_GUIDELINES.md §2 rule 3, §6 "Don't").
 *
 * On a coloured background (`tone="onPrimary"`, e.g. the login hero) the lifted
 * `-on-dark` variant is used: the master's deep gradient stop is nearly the navy
 * canvas colour, so the flag detail disappears without it (§4).
 *
 * WORDMARK: the brand package contains no horizontal-lockup master, so the name
 * is typeset to the §5 specification — Inter 700 at +0.14em tracking, with the
 * "OS" sub-label in Inter 600 / brand primary. Replace the <span> pair below
 * with the lockup SVG once that master exists.
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
      <img
        src={onPrimary ? '/brand/niksha-os-symbol-on-dark.svg' : '/brand/niksha-os-symbol.svg'}
        alt=""
        width={size}
        height={size}
        style={{ width: size, height: size }}
        aria-hidden
      />
      {showWordmark && (
        <span className="flex items-baseline gap-[6px] leading-none">
          <span
            className={cn('ak-title-md font-bold', onPrimary ? 'text-white' : 'text-on-surface')}
            style={{ letterSpacing: '0.14em' }}
          >
            NIKSHA
          </span>
          <span
            className={cn('text-[13px] font-semibold', onPrimary ? 'text-white/90' : 'text-primary')}
            style={{ letterSpacing: '0.06em' }}
          >
            OS
          </span>
        </span>
      )}
    </span>
  );
}
