import type { AccessTokenClaims } from "../jwt.ts";
import type { TenantQueryClient } from "../tenant_db.ts";

export const AUDIT_PROBE_SCHOOL_A = "c0000000-0000-4000-8000-000000000001";
export const AUDIT_PROBE_SCHOOL_B = "c0000000-0000-4000-8000-000000000002";
export const DOMAIN_EVENT_PROBE_SCHOOL_A = "c1000000-0000-4000-8000-000000000001";
export const DOMAIN_EVENT_PROBE_SCHOOL_B = "c1000000-0000-4000-8000-000000000002";

export const AUDIT_PROBE_DETAIL_SQL = `
  SELECT count(*)::text AS count
  FROM audit_events
  WHERE id = $1::uuid
`;

export const DOMAIN_EVENT_PROBE_DETAIL_SQL = `
  SELECT count(*)::text AS count
  FROM domain_events
  WHERE id = $1::uuid
`;

export interface ClientAuditEventInput {
  id: string;
  type: string;
  timestamp: string;
  userId?: string;
  tenantId?: string;
  schoolId?: string;
  correlationId?: string;
  category?: string;
  metadata?: Record<string, string>;
}

export interface IngestBatchResult {
  acceptedCount: number;
  rejectedIds: string[];
}

export interface ServerAuditInput {
  eventType: string;
  category: string;
  entityType?: string;
  entityId?: string;
  metadata?: Record<string, unknown>;
  correlationId?: string;
  userRole?: string;
}

export interface DomainEventInput {
  eventType: string;
  payload: Record<string, unknown>;
  sourceModule: string;
  correlationId?: string;
  idempotencyKey?: string;
  schoolId?: string | null;
}

function requestMeta(req?: Request): { ipAddress: string | null; userAgent: string | null } {
  if (!req) {
    return { ipAddress: null, userAgent: null };
  }
  return {
    ipAddress: req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ??
      req.headers.get("cf-connecting-ip"),
    userAgent: req.headers.get("user-agent"),
  };
}

function validateClientEvent(
  claims: AccessTokenClaims,
  event: ClientAuditEventInput,
): string | null {
  if (!event.id || !event.type || !event.timestamp) {
    return "missing required fields";
  }
  if (event.tenantId && event.tenantId !== claims.tenant_id) {
    return "tenant mismatch";
  }
  if (event.schoolId && claims.school_id && event.schoolId !== claims.school_id) {
    return "school mismatch";
  }
  if (event.userId && event.userId !== claims.sub) {
    return "user mismatch";
  }
  return null;
}

export async function ingestClientAuditBatch(
  db: TenantQueryClient,
  claims: AccessTokenClaims,
  events: ClientAuditEventInput[],
  req?: Request,
): Promise<IngestBatchResult> {
  const rejectedIds: string[] = [];
  let acceptedCount = 0;
  const { ipAddress, userAgent } = requestMeta(req);
  const orgId = claims.tenant_id;
  const schoolId = claims.school_id;

  for (const event of events) {
    const validationError = validateClientEvent(claims, event);
    if (validationError) {
      rejectedIds.push(event.id);
      continue;
    }

    const existing = await db.queryObject<{ id: string }>(
      `SELECT id::text
       FROM audit_events
       WHERE organization_id = $1
         AND client_event_id = $2`,
      [orgId, event.id],
    );
    if (existing.length > 0) {
      acceptedCount += 1;
      continue;
    }

    const metadata = event.metadata ?? {};
    const entityType = metadata.entityType ?? metadata.entity_type ?? null;
    const entityId = metadata.entityId ?? metadata.entity_id ?? metadata.leadId ??
      metadata.approvalId ?? null;

    await db.queryObject(
      `INSERT INTO audit_events (
         client_event_id,
         organization_id,
         school_id,
         user_id,
         user_role,
         correlation_id,
         event_type,
         category,
         entity_type,
         entity_id,
         metadata,
         source,
         ip_address,
         user_agent,
         client_timestamp
       ) VALUES (
         $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11::jsonb, 'client', $12, $13, $14::timestamptz
       )`,
      [
        event.id,
        orgId,
        event.schoolId ?? schoolId,
        event.userId ?? claims.sub,
        claims.primary_role,
        event.correlationId ?? null,
        event.type,
        event.category ?? "system",
        entityType,
        entityId,
        JSON.stringify(metadata),
        ipAddress,
        userAgent,
        event.timestamp,
      ],
    );
    acceptedCount += 1;
  }

  return { acceptedCount, rejectedIds };
}

// PRA-P1-53 (S2): read side of the forensic trail. `audit_events` was
// write-only (batch ingest + server-side mutation audit) with NO list/search
// path, so a school's "who changed this mark / deleted this payment" question
// was unanswerable. This adds a filtered, paginated, newest-first read that runs
// UNDER the tenant client — RLS (`audit_events_tenant_read`) is the authoritative
// org+school/organization scope guard; the `organization_id` predicate here is
// defense-in-depth, never a substitute for RLS.
export interface AuditEventFilters {
  /** actor user id → user_id */
  actor?: string;
  entityType?: string;
  entityId?: string;
  /** action / eventType → event_type */
  eventType?: string;
  /** inclusive lower bound on created_at (ISO 8601) */
  fromDate?: string;
  /** inclusive upper bound on created_at (ISO 8601) */
  toDate?: string;
}

export interface AuditEventRow {
  id: string;
  organization_id: string;
  school_id: string | null;
  user_id: string | null;
  user_role: string | null;
  correlation_id: string | null;
  event_type: string;
  category: string;
  entity_type: string | null;
  entity_id: string | null;
  metadata: Record<string, unknown>;
  source: string;
  ip_address: string | null;
  user_agent: string | null;
  client_timestamp: string | null;
  ingested_at: string;
  created_at: string;
}

export interface AuditEventPage {
  items: AuditEventRow[];
  total: number;
  page: number;
  pageSize: number;
  hasMore: boolean;
}

/** PRA-P1-53 (S2): list the tenant's audit events newest-first with optional
 * actor / entity / event-type / date-range filters. Runs on the `erp_tenant`
 * client so the tenant read RLS scopes rows automatically — no bypass. */
export async function listAuditEvents(
  db: TenantQueryClient,
  claims: AccessTokenClaims,
  filters: AuditEventFilters,
  pagination: { page: number; pageSize: number },
): Promise<AuditEventPage> {
  const limit = Math.min(Math.max(pagination.pageSize, 1), 100);
  const offset = (Math.max(pagination.page, 1) - 1) * limit;

  const where: string[] = ["organization_id = $1"];
  const args: unknown[] = [claims.tenant_id];

  if (filters.actor) {
    args.push(filters.actor);
    where.push(`user_id = $${args.length}::uuid`);
  }
  if (filters.entityType) {
    args.push(filters.entityType);
    where.push(`entity_type = $${args.length}`);
  }
  if (filters.entityId) {
    args.push(filters.entityId);
    where.push(`entity_id = $${args.length}`);
  }
  if (filters.eventType) {
    args.push(filters.eventType);
    where.push(`event_type = $${args.length}`);
  }
  if (filters.fromDate) {
    args.push(filters.fromDate);
    where.push(`created_at >= $${args.length}::timestamptz`);
  }
  if (filters.toDate) {
    args.push(filters.toDate);
    where.push(`created_at <= $${args.length}::timestamptz`);
  }

  const whereSql = where.join("\n       AND ");

  const total = await db.queryCount(
    `SELECT count(*)::text AS count
       FROM audit_events
      WHERE ${whereSql}`,
    args,
  );

  const items = await db.queryObject<AuditEventRow>(
    `SELECT id, organization_id, school_id, user_id, user_role, correlation_id,
            event_type, category, entity_type, entity_id, metadata, source,
            ip_address, user_agent, client_timestamp, ingested_at, created_at
       FROM audit_events
      WHERE ${whereSql}
      ORDER BY created_at DESC, id DESC
      LIMIT $${args.length + 1} OFFSET $${args.length + 2}`,
    [...args, limit, offset],
  );

  return {
    items,
    total,
    page: Math.max(pagination.page, 1),
    pageSize: limit,
    hasMore: offset + items.length < total,
  };
}

export async function recordServerAuditEvent(
  db: TenantQueryClient,
  claims: AccessTokenClaims,
  input: ServerAuditInput,
  req?: Request,
): Promise<string> {
  const { ipAddress, userAgent } = requestMeta(req);
  // No RETURNING: a server-side audit write must not depend on the actor's
  // SELECT RLS. INSERT ... RETURNING re-checks the table's read policy against
  // the new row, which (correctly) excludes persona scopes like parent/student
  // and would spuriously fail the audited mutation. The returned id is unused.
  await db.queryObject(
    `INSERT INTO audit_events (
       organization_id,
       school_id,
       user_id,
       user_role,
       correlation_id,
       event_type,
       category,
       entity_type,
       entity_id,
       metadata,
       source,
       ip_address,
       user_agent
     ) VALUES (
       $1, $2, $3, $4, $5, $6, $7, $8, $9, $10::jsonb, 'server', $11, $12
     )`,
    [
      claims.tenant_id,
      claims.school_id,
      claims.sub,
      input.userRole ?? claims.primary_role,
      input.correlationId ?? null,
      input.eventType,
      input.category,
      input.entityType ?? null,
      input.entityId ?? null,
      JSON.stringify(input.metadata ?? {}),
      ipAddress,
      userAgent,
    ],
  );
  return "";
}

export async function enqueueDomainEvent(
  db: TenantQueryClient,
  claims: AccessTokenClaims,
  input: DomainEventInput,
): Promise<string | null> {
  const schoolId = input.schoolId === undefined ? claims.school_id : input.schoolId;

  if (input.idempotencyKey) {
    const existing = await db.queryObject<{ id: string }>(
      `SELECT id::text
       FROM domain_events
       WHERE organization_id = $1
         AND idempotency_key = $2`,
      [claims.tenant_id, input.idempotencyKey],
    );
    if (existing.length > 0) {
      return existing[0].id;
    }
  }

  // No RETURNING: like the audit insert, the outbox write must not be gated by
  // the actor's SELECT RLS (RETURNING re-checks the read policy, which excludes
  // persona scopes). The id is unused by callers.
  await db.queryObject(
    `INSERT INTO domain_events (
       organization_id,
       school_id,
       event_type,
       payload,
       correlation_id,
       source_module,
       idempotency_key,
       status,
       published_at
     ) VALUES (
       $1, $2, $3, $4::jsonb, $5, $6, $7, 'published', timezone('utc', now())
     )`,
    [
      claims.tenant_id,
      schoolId,
      input.eventType,
      JSON.stringify(input.payload),
      input.correlationId ?? null,
      input.sourceModule,
      input.idempotencyKey ?? null,
    ],
  );
  return null;
}

export async function recordMutationAudit(
  db: TenantQueryClient,
  claims: AccessTokenClaims,
  audit: ServerAuditInput,
  domainEvent: DomainEventInput | null,
  req?: Request,
): Promise<void> {
  await recordServerAuditEvent(db, claims, audit, req);
  if (domainEvent) {
    await enqueueDomainEvent(db, claims, {
      ...domainEvent,
      correlationId: domainEvent.correlationId ?? audit.correlationId,
    });
  }
}

export function correlationIdFromRequest(req: Request): string | undefined {
  return req.headers.get("x-correlation-id") ??
    req.headers.get("X-Correlation-Id") ??
    undefined;
}

// ── DB-6 — audit retention code seam ────────────────────────────────────────
//
// `audit_events` is APPEND-ONLY (an immutable governance record), so retention
// is enforced by an ops-lane purge / partition-drop under a privileged role —
// never a client-reachable delete path. This is the code seam that the retention
// policy (AuditArchitecture.md, DOC-5) plugs into:
//   • `auditRetentionCutoff` — pure: the instant before which events are beyond
//     the configured horizon (unit-testable, no DB).
//   • `countAuditEventsBeyondRetention` — read-only: how many of the actor's
//     tenant's events are past the horizon, so ops can size a purge.
// The destructive DELETE / DROP PARTITION + the table-partitioning migration
// land in the live/ops lane, keeping this seam non-destructive.

/** The instant before which audit events are beyond the retention window. */
export function auditRetentionCutoff(nowMs: number, retentionDays: number): Date {
  if (!Number.isFinite(retentionDays) || retentionDays <= 0) {
    throw new Error("retentionDays must be a positive number");
  }
  return new Date(nowMs - retentionDays * 24 * 60 * 60 * 1000);
}

/** Read-only: count the actor tenant's audit events older than the retention
 * window. Drives an ops "purge N rows" decision; performs no deletion. */
export async function countAuditEventsBeyondRetention(
  db: TenantQueryClient,
  claims: AccessTokenClaims,
  retentionDays: number,
  nowMs: number = Date.now(),
): Promise<number> {
  const cutoff = auditRetentionCutoff(nowMs, retentionDays);
  const rows = await db.queryObject<{ count: string }>(
    `SELECT count(*)::text AS count
       FROM audit_events
      WHERE organization_id = $1
        AND created_at < $2`,
    [claims.tenant_id, cutoff.toISOString()],
  );
  return Number(rows[0]?.count ?? "0");
}
