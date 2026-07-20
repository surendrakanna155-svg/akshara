import { motion } from 'framer-motion';
import { cn } from '@/lib/utils/cn';
import { Icon } from '@/components/Icon';
import { Text } from './Text';
import { Button } from './Button';

/** Ports AksharaEmptyState — centered illustration glyph, title, hint, CTA. */
export function EmptyState({
  icon = 'inbox',
  title,
  message,
  actionLabel,
  onAction,
  className,
}: {
  icon?: string;
  title: string;
  message?: string;
  actionLabel?: string;
  onAction?: () => void;
  className?: string;
}) {
  return (
    <motion.div
      initial={{ opacity: 0, scale: 0.98 }}
      animate={{ opacity: 1, scale: 1 }}
      transition={{ duration: 0.24, ease: [0.215, 0.61, 0.355, 1] }}
      className={cn('grid place-items-center px-s6 py-s12 text-center', className)}
    >
      <span className="mb-s4 grid h-16 w-16 place-items-center rounded-2xl bg-surface-container text-on-surface-variant">
        <Icon name={icon} size={32} />
      </span>
      <Text variant="title-md" className="text-on-surface">
        {title}
      </Text>
      {message && (
        <Text variant="body-md" className="mt-s1 max-w-reading text-on-surface-variant">
          {message}
        </Text>
      )}
      {actionLabel && onAction && (
        <Button className="mt-s5" icon="add" onClick={onAction}>
          {actionLabel}
        </Button>
      )}
    </motion.div>
  );
}

/** Ports AksharaErrorState. */
export function ErrorState({
  title = 'Something went wrong',
  message,
  onRetry,
  className,
}: {
  title?: string;
  message?: string;
  onRetry?: () => void;
  className?: string;
}) {
  return (
    <div className={cn('grid place-items-center px-s6 py-s12 text-center', className)}>
      <span className="mb-s4 grid h-16 w-16 place-items-center rounded-2xl bg-error-container text-error">
        <Icon name="error" size={32} />
      </span>
      <Text variant="title-md" className="text-on-surface">
        {title}
      </Text>
      {message && (
        <Text variant="body-md" className="mt-s1 max-w-reading text-on-surface-variant">
          {message}
        </Text>
      )}
      {onRetry && (
        <Button className="mt-s5" variant="outlined" icon="refresh" onClick={onRetry}>
          Retry
        </Button>
      )}
    </div>
  );
}

/**
 * Shown where a screen is fully built but its backend endpoint is not yet
 * enabled. Honest placeholder — never fabricated data. Replaced by live content
 * the moment the API is wired.
 */
export function DataUnavailable({
  title = 'Awaiting live data',
  message = 'This screen is ready and will populate automatically once its backend endpoint is connected.',
  icon = 'cloud_sync',
  className,
}: {
  title?: string;
  message?: string;
  icon?: string;
  className?: string;
}) {
  return (
    <div className={cn('grid place-items-center rounded-lg border border-dashed border-outline-variant px-s6 py-s12 text-center', className)}>
      <span className="mb-s4 grid h-16 w-16 place-items-center rounded-2xl bg-primary-container text-on-primary-container">
        <Icon name={icon} size={32} />
      </span>
      <Text variant="title-md" className="text-on-surface">
        {title}
      </Text>
      <Text variant="body-md" className="mt-s1 max-w-reading text-on-surface-variant">
        {message}
      </Text>
    </div>
  );
}

/** Shimmer skeleton block. */
export function Skeleton({ className }: { className?: string }) {
  return <div className={cn('animate-pulse rounded-md bg-surface-highest/70', className)} />;
}

/** Full-card loading placeholder. */
export function LoadingState({ rows = 5, className }: { rows?: number; className?: string }) {
  return (
    <div className={cn('space-y-s3 p-s2', className)}>
      {Array.from({ length: rows }).map((_, i) => (
        <div key={i} className="flex items-center gap-s3">
          <Skeleton className="h-10 w-10 rounded-full" />
          <div className="flex-1 space-y-s2">
            <Skeleton className="h-3 w-1/3" />
            <Skeleton className="h-3 w-2/3" />
          </div>
        </div>
      ))}
    </div>
  );
}
