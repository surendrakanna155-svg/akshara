import { useQuery, type UseQueryOptions } from '@tanstack/react-query';
import { IS_DEMO } from './config';

/**
 * Standard data hook for every page. When no live backend is configured
 * (IS_DEMO), the query does NOT run and the page renders an "awaiting backend"
 * state instead of fabricating data. When a live base URL + `VITE_DATA_MODE=live`
 * are set, it hits the real endpoint. There is never mock business data.
 *
 * A caller-supplied `enabled` is AND-ed with the demo gate (e.g. a detail query
 * that should only run once an id is selected).
 */
export function useModuleQuery<T>(
  key: unknown[],
  queryFn: () => Promise<T>,
  options?: Omit<UseQueryOptions<T, Error, T, unknown[]>, 'queryKey' | 'queryFn'>,
) {
  const { enabled = true, ...rest } = options ?? {};
  const q = useQuery<T, Error, T, unknown[]>({
    queryKey: key,
    queryFn,
    ...rest,
    enabled: !IS_DEMO && enabled,
  });
  return { ...q, unavailable: IS_DEMO };
}
