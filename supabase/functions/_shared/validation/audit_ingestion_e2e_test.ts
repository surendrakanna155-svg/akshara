import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  enqueueDomainEvent,
  ingestClientAuditBatch,
  recordMutationAudit,
} from "../audit/audit_repository.ts";

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL_A = "a2000000-0000-4000-8000-000000000001";

class E2eAuditDb {
  auditRows: Array<Record<string, unknown>> = [];
  domainRows: Array<Record<string, unknown>> = [];

  async queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    if (sql.includes("FROM audit_events") && sql.includes("client_event_id")) {
      const row = this.auditRows.find(
        (r) => r.organization_id === args[0] && r.client_event_id === args[1],
      );
      return row ? [{ id: row.id }] as T[] : [] as T[];
    }
    if (sql.includes("INSERT INTO audit_events")) {
      const row: Record<string, unknown> = {
        id: crypto.randomUUID(),
        client_event_id: args[0] ?? null,
        organization_id: args[1],
        event_type: sql.includes("'server'") ? args[6] : args[6],
        category: args[7],
        source: sql.includes("'server'") ? "server" : "client",
      };
      this.auditRows.push(row);
      if (sql.includes("RETURNING id::text")) {
        return [{ id: row.id }] as T[];
      }
      return [] as T[];
    }
    if (sql.includes("FROM domain_events") && sql.includes("idempotency_key")) {
      const row = this.domainRows.find(
        (r) => r.organization_id === args[0] && r.idempotency_key === args[1],
      );
      return row ? [{ id: row.id }] as T[] : [] as T[];
    }
    if (sql.includes("INSERT INTO domain_events")) {
      const row = {
        id: crypto.randomUUID(),
        organization_id: args[0],
        idempotency_key: args[6],
        event_type: args[2],
      };
      this.domainRows.push(row);
      return [{ id: row.id }] as T[];
    }
    return [] as T[];
  }
}

function schoolClaims(): AccessTokenClaims {
  return {
    sub: "a3000000-0000-4000-8000-000000000001",
    tenant_id: ORG,
    organization_id: ORG,
    school_id: SCHOOL_A,
    role: "schoolAdmin",
    role_slugs: ["schoolAdmin"],
    primary_role: "schoolAdmin",
    permissions: ["manageAdmissions"],
    permissions_version: 1,
    scope: "school",
    school_group_id: null,
    student_id: null,
    child_ids: [],
    session_id: "e2e",
  };
}

Deno.test("audit ingestion E2E: client batch then mutation audit + domain event", async () => {
  const mock = new E2eAuditDb();
  const db = mock as unknown as TenantQueryClient;

  const batch = await ingestClientAuditBatch(db, schoolClaims(), [{
    id: "e2e_client_audit_1",
    type: "leadCreated",
    timestamp: "2026-06-10T12:00:00Z",
    tenantId: ORG,
    schoolId: SCHOOL_A,
    category: "workflow",
    metadata: { leadId: "lead_e2e_1" },
  }]);
  assertEquals(batch.acceptedCount, 1);

  await recordMutationAudit(
    db,
    schoolClaims(),
    {
      eventType: "leadCreated",
      category: "workflow",
      entityType: "lead",
      entityId: "lead_e2e_1",
      correlationId: "corr_e2e_1",
    },
    {
      eventType: "admissions.lead.created",
      payload: { leadId: "lead_e2e_1" },
      sourceModule: "admissions",
      idempotencyKey: "admissions.lead.created:lead_e2e_1",
    },
  );

  assertEquals(mock.auditRows.length, 2);
  assertEquals(mock.domainRows.length, 1);

  const replay = await enqueueDomainEvent(db, schoolClaims(), {
    eventType: "admissions.lead.created",
    payload: { leadId: "lead_e2e_1" },
    sourceModule: "admissions",
    idempotencyKey: "admissions.lead.created:lead_e2e_1",
  });
  assertEquals(mock.domainRows.length, 1);
  assertEquals(typeof replay, "string");
});

Deno.test("audit ingestion E2E: replay client batch is idempotent", async () => {
  const mock = new E2eAuditDb();
  const db = mock as unknown as TenantQueryClient;
  const event = {
    id: "e2e_client_replay",
    type: "login",
    timestamp: "2026-06-10T12:00:00Z",
    tenantId: ORG,
  };
  await ingestClientAuditBatch(db, schoolClaims(), [event]);
  const second = await ingestClientAuditBatch(db, schoolClaims(), [event]);
  assertEquals(second.acceptedCount, 1);
  assertEquals(mock.auditRows.filter((r) => r.client_event_id === "e2e_client_replay").length, 1);
});
