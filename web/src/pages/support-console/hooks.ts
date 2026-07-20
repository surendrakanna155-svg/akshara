/**
 * Data hooks for the ASIP platform Support Console.
 *
 * Reads go through `useModuleQuery` (so with no live backend the pages render the
 * honest "awaiting backend" state instead of fabricated data); writes go through
 * `useMutation` against the real edge API and invalidate the `support` cache tree.
 * All endpoints are under `/support/platform/*` and require a PLATFORM_ORG session
 * holding `platformSupport` (server enforces → 403; the route is also gated).
 */
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { apiFetch } from '@/lib/api/client';
import { useModuleQuery } from '@/lib/api/useModuleQuery';
import {
  normalizeCluster,
  normalizeIncident,
  normalizeIncidentDetail,
  normalizeInvestigation,
  normalizeHandoff,
  type SupportCluster,
  type SupportHandoff,
  type SupportIncident,
  type SupportIncidentDetail,
  type SupportInvestigation,
  type SupportListResult,
  type SupportStatus,
} from '@/lib/contracts/support';

export const supportKeys = {
  all: ['support', 'platform'] as string[],
  incidents: (filters: IncidentFilters): unknown[] => ['support', 'platform', 'incidents', filters],
  incident: (id: string): unknown[] => ['support', 'platform', 'incident', id],
  clusters: (filters: ClusterFilters): unknown[] => ['support', 'platform', 'clusters', filters],
  cluster: (id: string): unknown[] => ['support', 'platform', 'cluster', id],
  handoff: (id: string): unknown[] => ['support', 'platform', 'handoff', id],
};

export interface IncidentFilters {
  supportStatus?: SupportStatus | '';
  clusterId?: string;
  page?: number;
  pageSize?: number;
}

export interface ClusterFilters {
  status?: string;
  page?: number;
  pageSize?: number;
}

function toListResult<T>(raw: unknown, mapItem: (r: unknown) => T): SupportListResult<T> {
  const obj = (raw && typeof raw === 'object' ? raw : {}) as Record<string, unknown>;
  const rawItems = Array.isArray(obj.items) ? obj.items : Array.isArray(raw) ? (raw as unknown[]) : [];
  const items = rawItems.map(mapItem);
  const total = typeof obj.total === 'number' ? obj.total : items.length;
  const page = typeof obj.page === 'number' ? obj.page : 1;
  const pageSize = typeof obj.pageSize === 'number' ? obj.pageSize : items.length;
  const hasMore = typeof obj.hasMore === 'boolean' ? obj.hasMore : false;
  return { items, total, page, pageSize, hasMore };
}

// ---- reads -----------------------------------------------------------------

export function useIncidents(filters: IncidentFilters) {
  const { supportStatus, clusterId, page = 1, pageSize = 50 } = filters;
  return useModuleQuery<SupportListResult<SupportIncident>>(supportKeys.incidents(filters), () =>
    apiFetch<unknown>('/support/platform/incidents', {
      query: {
        support_status: supportStatus || undefined,
        cluster_id: clusterId || undefined,
        page,
        pageSize,
      },
    }).then((raw) => toListResult(raw, normalizeIncident)),
  );
}

export function useIncidentDetail(id: string) {
  return useModuleQuery<SupportIncidentDetail>(
    supportKeys.incident(id),
    () => apiFetch<unknown>(`/support/platform/incidents/${id}`).then(normalizeIncidentDetail),
    { enabled: !!id },
  );
}

export function useClusters(filters: ClusterFilters) {
  const { status, page = 1, pageSize = 50 } = filters;
  return useModuleQuery<SupportListResult<SupportCluster>>(supportKeys.clusters(filters), () =>
    apiFetch<unknown>('/support/platform/clusters', {
      query: { status: status || undefined, page, pageSize },
    }).then((raw) => toListResult(raw, normalizeCluster)),
  );
}

export interface ClusterDetail {
  cluster: SupportCluster;
  incidents: SupportIncident[];
}

export function useClusterDetail(id: string) {
  return useModuleQuery<ClusterDetail>(
    supportKeys.cluster(id),
    () =>
      apiFetch<unknown>(`/support/platform/clusters/${id}`).then((raw) => {
        const obj = (raw && typeof raw === 'object' ? raw : {}) as Record<string, unknown>;
        return {
          cluster: normalizeCluster(obj.cluster ?? obj),
          incidents: Array.isArray(obj.incidents) ? obj.incidents.map(normalizeIncident) : [],
        };
      }),
    { enabled: !!id },
  );
}

/** Fetched lazily — only when the engineering-handoff panel is opened. */
export function useHandoff(id: string, enabled: boolean) {
  return useModuleQuery<SupportHandoff>(
    supportKeys.handoff(id),
    () => apiFetch<unknown>(`/support/platform/incidents/${id}/handoff`).then(normalizeHandoff),
    { enabled: !!id && enabled, staleTime: 0 },
  );
}

// ---- writes ----------------------------------------------------------------

function useInvalidateSupport() {
  const qc = useQueryClient();
  return () => qc.invalidateQueries({ queryKey: ['support', 'platform'] });
}

/** `assignedTo` omitted → assign to self; explicit `null` → unassign. */
export function useAssignIncident(id: string) {
  const invalidate = useInvalidateSupport();
  return useMutation<SupportIncident, Error, { assignedTo?: string | null }>({
    mutationFn: (body) =>
      apiFetch<unknown>(`/support/platform/incidents/${id}/assign`, {
        method: 'POST',
        body,
      }).then(normalizeIncident),
    onSuccess: invalidate,
  });
}

export function useSetSupportStatus(id: string) {
  const invalidate = useInvalidateSupport();
  return useMutation<SupportIncident, Error, { status: SupportStatus }>({
    mutationFn: (body) =>
      apiFetch<unknown>(`/support/platform/incidents/${id}/support-status`, {
        method: 'POST',
        body,
      }).then(normalizeIncident),
    onSuccess: invalidate,
  });
}

export function useEscalateIncident(id: string) {
  const invalidate = useInvalidateSupport();
  return useMutation<SupportIncident, Error, void>({
    mutationFn: () =>
      apiFetch<unknown>(`/support/platform/incidents/${id}/escalate`, { method: 'POST' }).then(normalizeIncident),
    onSuccess: invalidate,
  });
}

export function useAddNote(id: string) {
  const invalidate = useInvalidateSupport();
  return useMutation<unknown, Error, { body: string }>({
    mutationFn: (body) => apiFetch<unknown>(`/support/platform/incidents/${id}/notes`, { method: 'POST', body }),
    onSuccess: invalidate,
  });
}

/** AI-assisted investigation — returns a DRAFT for the engineer to review. */
export function useInvestigateIncident(id: string) {
  const invalidate = useInvalidateSupport();
  return useMutation<SupportInvestigation, Error, void>({
    mutationFn: () =>
      apiFetch<unknown>(`/support/platform/incidents/${id}/investigate`, { method: 'POST' }).then(normalizeInvestigation),
    onSuccess: invalidate,
  });
}

export interface ResolveResult {
  resolved: boolean;
  count: number;
}

/** `resolveCluster` resolves EVERY incident in the cluster ("resolve many"). */
export function useResolveIncident(id: string) {
  const invalidate = useInvalidateSupport();
  return useMutation<ResolveResult, Error, { resolution: string; resolveCluster?: boolean }>({
    mutationFn: (body) =>
      apiFetch<unknown>(`/support/platform/incidents/${id}/resolve`, { method: 'POST', body }).then((raw) => {
        const o = (raw && typeof raw === 'object' ? raw : {}) as Record<string, unknown>;
        return { resolved: o.resolved === true, count: typeof o.count === 'number' ? o.count : 0 };
      }),
    onSuccess: invalidate,
  });
}
