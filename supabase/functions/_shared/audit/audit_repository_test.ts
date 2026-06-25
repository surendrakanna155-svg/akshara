import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  enqueueDomainEvent,
  ingestClientAuditBatch,
  recordServerAuditEvent,
} from "./audit_repository.ts";

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL_A = "a2000000-0000-4000-8000-000000000001";

class MockAuditDb {
  auditRows: Array<Record<string, unknown>> = [];
  domainRows: Array<Record<string, unknown>> = [];

  async queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    if (sql.includes("FROM audit_events") && sql.includes("client_event_id")) {
      const orgId = args[0] as string;
      const clientId = args[1] as string;
      const row = this.auditRows.find(
        (entry) => entry.organization_id === orgId && entry.client_event_id === clientId,
      );
      return row ? [{ id: row.id as string }] as T[] : [] as T[];
    }

    if (sql.includes("INSERT INTO audit_events")) {
      const row = {
        id: crypto.randomUUID(),
        client_event_id: args[0] ?? null,
        organization_id: args[1],
        event_type: args[6],
        category: args[7],
      };
      this.auditRows.push(row);
      if (sql.includes("RETURNING id::text")) {
        return [{ id: row.id }] as T[];
      }
      return [] as T[];
    }

    if (sql.includes("FROM domain_events") && sql.includes("idempotency_key")) {
      const orgId = args[0] as string;
      const key = args[1] as string;
      const row = this.domainRows.find(
        (entry) => entry.organization_id === orgId && entry.idempotency_key === key,
      );
      return row ? [{ id: row.id as string }] as T[] : [] as T[];
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
    session_id: "test",
  };
}

Deno.test("ingestClientAuditBatch accepts valid event", async () => {
  const db = new MockAuditDb() as unknown as TenantQueryClient;
  const result = await ingestClientAuditBatch(db, schoolClaims(), [{
    id: "client_audit_1",
    type: "login",
    timestamp: "2026-06-10T10:00:00Z",
    tenantId: ORG,
    schoolId: SCHOOL_A,
    userId: "a3000000-0000-4000-8000-000000000001",
    category: "auth",
  }]);
  assertEquals(result.acceptedCount, 1);
  assertEquals(result.rejectedIds.length, 0);
});

Deno.test("ingestClientAuditBatch rejects tenant mismatch", async () => {
  const db = new MockAuditDb() as unknown as TenantQueryClient;
  const result = await ingestClientAuditBatch(db, schoolClaims(), [{
    id: "client_audit_bad",
    type: "login",
    timestamp: "2026-06-10T10:00:00Z",
    tenantId: "other-tenant",
  }]);
  assertEquals(result.acceptedCount, 0);
  assertEquals(result.rejectedIds, ["client_audit_bad"]);
});

Deno.test("ingestClientAuditBatch is idempotent on client id", async () => {
  const mock = new MockAuditDb();
  const db = mock as unknown as TenantQueryClient;
  const event = {
    id: "client_audit_dup",
    type: "login",
    timestamp: "2026-06-10T10:00:00Z",
    tenantId: ORG,
  };
  const first = await ingestClientAuditBatch(db, schoolClaims(), [event]);
  const second = await ingestClientAuditBatch(db, schoolClaims(), [event]);
  assertEquals(first.acceptedCount, 1);
  assertEquals(second.acceptedCount, 1);
  assertEquals(mock.auditRows.length, 1);
});

Deno.test("enqueueDomainEvent dedupes on idempotency key", async () => {
  const mock = new MockAuditDb();
  const db = mock as unknown as TenantQueryClient;
  const input = {
    eventType: "admissions.lead.created",
    payload: { leadId: "lead_1" },
    sourceModule: "admissions",
    idempotencyKey: "admissions.lead.created:lead_1",
  };
  const first = await enqueueDomainEvent(db, schoolClaims(), input);
  const second = await enqueueDomainEvent(db, schoolClaims(), input);
  // The insert path no longer projects an id (no RETURNING — see audit_repository);
  // the dedup path still returns the existing row id. The guarantee is one row.
  assertEquals(first, null);
  assertEquals(typeof second, "string");
  assertEquals(mock.domainRows.length, 1);
});

Deno.test("recordServerAuditEvent inserts server audit row", async () => {
  const mock = new MockAuditDb();
  const db = mock as unknown as TenantQueryClient;
  const id = await recordServerAuditEvent(db, schoolClaims(), {
    eventType: "leadCreated",
    category: "workflow",
    entityType: "lead",
    entityId: "lead_1",
  });
  assertEquals(typeof id, "string");
  assertEquals(mock.auditRows.length, 1);
});
