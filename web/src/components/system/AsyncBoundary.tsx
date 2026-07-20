import type { ReactNode } from 'react';
import { DataUnavailable, EmptyState, ErrorState, LoadingState } from '@/components/ui';
import { ApiError } from '@/lib/api/client';

export interface AsyncState<T> {
  data: T | undefined;
  isLoading: boolean;
  isError: boolean;
  error: Error | null;
  unavailable: boolean;
  refetch: () => void;
}

interface AsyncBoundaryProps<T> {
  query: AsyncState<T>;
  children: (data: T) => ReactNode;
  isEmpty?: (data: T) => boolean;
  empty?: ReactNode;
  loading?: ReactNode;
  unavailableTitle?: string;
  unavailableMessage?: string;
}

/**
 * Renders live data or the correct honest state. Order: awaiting-backend →
 * loading → error → empty → data. Guarantees a page never shows fabricated data.
 */
export function AsyncBoundary<T>({
  query,
  children,
  isEmpty,
  empty,
  loading,
  unavailableTitle,
  unavailableMessage,
}: AsyncBoundaryProps<T>) {
  if (query.unavailable) return <DataUnavailable title={unavailableTitle} message={unavailableMessage} />;
  if (query.isLoading) return <>{loading ?? <LoadingState rows={6} />}</>;
  if (query.isError) {
    const err = query.error;
    // Entitlement gating (403 MODULE_DISABLED): not an error — this school's plan
    // doesn't include the module. Render an honest "not enabled" state.
    if (err instanceof ApiError && (err.code === 'MODULE_DISABLED' || (err.status === 403 && /disabled|entitl/i.test(err.message)))) {
      return (
        <DataUnavailable
          icon="lock"
          title="Module not enabled"
          message="This module isn't part of your school's current plan. Contact your administrator to enable it."
        />
      );
    }
    // 422: the endpoint needs filters (class / date / academic year) the page
    // hasn't supplied yet — guide the user rather than showing a raw error.
    if (err instanceof ApiError && (err.status === 422 || /validation/i.test(err.code))) {
      return (
        <DataUnavailable
          icon="tune"
          title="Choose filters to load"
          message="Select a class, date or academic year above to load this view."
        />
      );
    }
    return <ErrorState message={err?.message ?? 'Could not load this data.'} onRetry={query.refetch} />;
  }
  if (query.data === undefined || (isEmpty?.(query.data) ?? false))
    return <>{empty ?? <EmptyState icon="inbox" title="Nothing to show yet" />}</>;
  return <>{children(query.data)}</>;
}
