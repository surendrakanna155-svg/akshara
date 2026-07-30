/**
 * Typed contract for the ASIP platform Support Console (`/support/platform/*`).
 *
 * The Akshara Support Team is a cross-tenant PLATFORM_ORG principal (see
 * docs/support-intelligence/ASIP_DESIGN.md §6.1). These endpoints read the
 * PII-minimized incident MIRROR, never a school tenant table.
 *
 * Wire contract: envelope `{data,error}` (unwrapped by `apiFetch`), incident /
 * cluster / evidence / note bodies are snake_case; the `investigate` and
 * `handoff` endpoints return camelCase composites. Normalizers below tolerate
 * either casing so the UI has one stable, camelCase shape.
 */

import type { SemanticStatus } from '@/components/ui';

export type SupportStatus = 'queue' | 'investigating' | 'awaiting_engineering' | 'resolved';

/** sev1 (most severe) … sev4 (least). Kept as a string — unknown values render neutrally. */
export type IncidentSeverity = 'sev1' | 'sev2' | 'sev3' | 'sev4';

/** Source (school-side) lifecycle status of the originating incident. */
export type IncidentSourceStatus =
  | 'new'
  | 'triaging'
  | 'in_progress'
  | 'awaiting_customer'
  | 'resolved'
  | 'closed';

export interface SupportIncident {
  id: string;
  sourceOrgId: string;
  sourceSchoolId: string;
  publicRef: string;
  title: string;
  description: string;
  category: string;
  severity: string;
  sourceStatus: string;
  moduleKey: string;
  screenRoute: string;
  appVersion: string;
  platform: string;
  supportStatus: SupportStatus;
  assignedTo: string | null;
  escalatedAt: string | null;
  clusterId: string | null;
  firstSeenAt: string;
  mirroredAt: string;
  updatedAt: string;
}

export interface SupportCluster {
  id: string;
  clusterKey: string;
  title: string;
  category: string;
  moduleKey: string;
  status: string;
  rootCause: string;
  resolution: string;
  incidentCount: number;
  updatedAt: string;
}

export type EvidenceKind = 'context' | 'audit_events' | 'api_calls' | 'workflow_state' | 'diagnostics';

export interface SupportEvidence {
  kind: string;
  payload: unknown;
  collectedAt: string;
}

export interface SupportNote {
  id: string;
  authorUserId: string;
  body: string;
  createdAt: string;
}

/** GET /support/platform/incidents/:id */
export interface SupportIncidentDetail {
  incident: SupportIncident;
  evidence: SupportEvidence[];
  notes: SupportNote[];
  cluster: SupportCluster | null;
}

/** POST /support/platform/incidents/:id/investigate — AI-assisted DRAFT (human decides). */
export interface SupportInvestigation {
  summary: string;
  likelyRootCause: string;
  recommendedFix: string;
  confidence: number;
  method: 'deterministic' | 'ai_enriched' | string;
  model: string;
  clusterSize: number;
}

/** GET /support/platform/incidents/:id/handoff — the engineering package. */
export interface SupportHandoff {
  incidentRef: string;
  category: string;
  severity: string;
  environment: {
    module?: string;
    screenRoute?: string;
    appVersion?: string;
    platform?: string;
  };
  reproduction: {
    failingCorrelationId?: string;
    topErrorStatus?: string | number;
    topErrorPath?: string;
    signals?: unknown;
  };
  cluster: { id: string; affectedIncidents: number } | null;
  evidence: Record<string, unknown>;
  supportNotes: unknown[];
}

export interface SupportListResult<T> {
  items: T[];
  total: number;
  page: number;
  pageSize: number;
  hasMore: boolean;
}

// ---- normalization (snake_case | camelCase → camelCase) -------------------

type Raw = Record<string, unknown>;

function asRecord(v: unknown): Raw {
  return v && typeof v === 'object' ? (v as Raw) : {};
}

function str(src: Raw, ...keys: string[]): string {
  for (const k of keys) {
    const v = src[k];
    if (typeof v === 'string') return v;
    if (typeof v === 'number' || typeof v === 'boolean') return String(v);
  }
  return '';
}

function strOrNull(src: Raw, ...keys: string[]): string | null {
  for (const k of keys) {
    const v = src[k];
    if (typeof v === 'string' && v !== '') return v;
    if (v === null) return null;
  }
  return null;
}

function num(src: Raw, ...keys: string[]): number {
  for (const k of keys) {
    const v = src[k];
    if (typeof v === 'number') return v;
    if (typeof v === 'string' && v.trim() !== '' && !Number.isNaN(Number(v))) return Number(v);
  }
  return 0;
}

export function normalizeIncident(raw: unknown): SupportIncident {
  const s = asRecord(raw);
  const supportStatus = str(s, 'support_status', 'supportStatus') || 'queue';
  return {
    id: str(s, 'id'),
    sourceOrgId: str(s, 'source_org_id', 'sourceOrgId'),
    sourceSchoolId: str(s, 'source_school_id', 'sourceSchoolId'),
    publicRef: str(s, 'public_ref', 'publicRef'),
    title: str(s, 'title'),
    description: str(s, 'description'),
    category: str(s, 'category'),
    severity: str(s, 'severity'),
    sourceStatus: str(s, 'source_status', 'sourceStatus'),
    moduleKey: str(s, 'module_key', 'moduleKey'),
    screenRoute: str(s, 'screen_route', 'screenRoute'),
    appVersion: str(s, 'app_version', 'appVersion'),
    platform: str(s, 'platform'),
    supportStatus: supportStatus as SupportStatus,
    assignedTo: strOrNull(s, 'assigned_to', 'assignedTo'),
    escalatedAt: strOrNull(s, 'escalated_at', 'escalatedAt'),
    clusterId: strOrNull(s, 'cluster_id', 'clusterId'),
    firstSeenAt: str(s, 'first_seen_at', 'firstSeenAt'),
    mirroredAt: str(s, 'mirrored_at', 'mirroredAt'),
    updatedAt: str(s, 'updated_at', 'updatedAt'),
  };
}

export function normalizeCluster(raw: unknown): SupportCluster {
  const s = asRecord(raw);
  return {
    id: str(s, 'id'),
    clusterKey: str(s, 'cluster_key', 'clusterKey'),
    title: str(s, 'title'),
    category: str(s, 'category'),
    moduleKey: str(s, 'module_key', 'moduleKey'),
    status: str(s, 'status'),
    rootCause: str(s, 'root_cause', 'rootCause'),
    resolution: str(s, 'resolution'),
    incidentCount: num(s, 'incident_count', 'incidentCount'),
    updatedAt: str(s, 'updated_at', 'updatedAt'),
  };
}

export function normalizeEvidence(raw: unknown): SupportEvidence {
  const s = asRecord(raw);
  return {
    kind: str(s, 'kind'),
    payload: s.payload ?? null,
    collectedAt: str(s, 'collected_at', 'collectedAt'),
  };
}

export function normalizeNote(raw: unknown): SupportNote {
  const s = asRecord(raw);
  return {
    id: str(s, 'id'),
    authorUserId: str(s, 'author_user_id', 'authorUserId'),
    body: str(s, 'body'),
    createdAt: str(s, 'created_at', 'createdAt'),
  };
}

export function normalizeIncidentDetail(raw: unknown): SupportIncidentDetail {
  const s = asRecord(raw);
  const clusterRaw = s.cluster;
  return {
    incident: normalizeIncident(s.incident ?? s),
    evidence: Array.isArray(s.evidence) ? s.evidence.map(normalizeEvidence) : [],
    notes: Array.isArray(s.notes) ? s.notes.map(normalizeNote) : [],
    cluster: clusterRaw ? normalizeCluster(clusterRaw) : null,
  };
}

export function normalizeInvestigation(raw: unknown): SupportInvestigation {
  const s = asRecord(raw);
  return {
    summary: str(s, 'summary'),
    likelyRootCause: str(s, 'likelyRootCause', 'likely_root_cause'),
    recommendedFix: str(s, 'recommendedFix', 'recommended_fix'),
    confidence: num(s, 'confidence'),
    method: (str(s, 'method') || 'deterministic') as SupportInvestigation['method'],
    model: str(s, 'model'),
    clusterSize: num(s, 'clusterSize', 'cluster_size'),
  };
}

/** Handoff is a nested camelCase composite; kept mostly as-is, defensively shaped. */
export function normalizeHandoff(raw: unknown): SupportHandoff {
  const s = asRecord(raw);
  const env = asRecord(s.environment);
  const repro = asRecord(s.reproduction);
  const clusterRaw = asRecord(s.cluster);
  const hasCluster = s.cluster != null && (clusterRaw.id !== undefined || clusterRaw.affectedIncidents !== undefined);
  return {
    incidentRef: str(s, 'incidentRef', 'incident_ref'),
    category: str(s, 'category'),
    severity: str(s, 'severity'),
    environment: {
      module: str(env, 'module') || undefined,
      screenRoute: str(env, 'screenRoute', 'screen_route') || undefined,
      appVersion: str(env, 'appVersion', 'app_version') || undefined,
      platform: str(env, 'platform') || undefined,
    },
    reproduction: {
      failingCorrelationId: str(repro, 'failingCorrelationId', 'failing_correlation_id') || undefined,
      topErrorStatus: (repro.topErrorStatus ?? repro.top_error_status) as string | number | undefined,
      topErrorPath: str(repro, 'topErrorPath', 'top_error_path') || undefined,
      signals: repro.signals ?? undefined,
    },
    cluster: hasCluster
      ? { id: str(clusterRaw, 'id'), affectedIncidents: num(clusterRaw, 'affectedIncidents', 'affected_incidents') }
      : null,
    evidence: asRecord(s.evidence),
    supportNotes: Array.isArray(s.supportNotes)
      ? s.supportNotes
      : Array.isArray(s.support_notes)
        ? (s.support_notes as unknown[])
        : [],
  };
}

// ---- display metadata ------------------------------------------------------

export const SUPPORT_STATUS_META: Record<SupportStatus, { label: string; status: SemanticStatus; icon: string }> = {
  queue: { label: 'Queue', status: 'neutral', icon: 'inbox' },
  investigating: { label: 'Investigating', status: 'info', icon: 'search' },
  awaiting_engineering: { label: 'Awaiting engineering', status: 'warning', icon: 'engineering' },
  resolved: { label: 'Resolved', status: 'success', icon: 'check_circle' },
};

export const SUPPORT_STATUS_ORDER: SupportStatus[] = ['queue', 'investigating', 'awaiting_engineering', 'resolved'];

export function supportStatusMeta(status: string): { label: string; status: SemanticStatus; icon: string } {
  return SUPPORT_STATUS_META[status as SupportStatus] ?? { label: status || 'Unknown', status: 'neutral', icon: 'help' };
}

/** sev1..sev4 → semantic tone + human label. */
export function severityMeta(severity: string): { label: string; status: SemanticStatus } {
  switch (severity) {
    case 'sev1':
      return { label: 'Sev 1 · Critical', status: 'error' };
    case 'sev2':
      return { label: 'Sev 2 · High', status: 'warning' };
    case 'sev3':
      return { label: 'Sev 3 · Medium', status: 'info' };
    case 'sev4':
      return { label: 'Sev 4 · Low', status: 'neutral' };
    default:
      return { label: severity || 'Unspecified', status: 'neutral' };
  }
}
