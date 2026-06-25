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
