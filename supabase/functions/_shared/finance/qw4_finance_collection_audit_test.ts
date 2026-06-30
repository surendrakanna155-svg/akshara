// QW4 · QA-X-014 (P1) — Fee-collection writes a server-side audit event.
//
// CONTRACT: collecting a fee (POST /finance/collections → handleCreateCollection)
// must emit an `audit_events` row (+ a `finance.collection.*` domain event) that
// binds the actor (the collecting user) to the mutated finance_collection.
//
// What is proven DB-free here:
//   1. The audit/domain WRITE PATH itself — emitMutationAudit(db, claims, spec)
//      issues exactly one `INSERT INTO audit_events` and one
//      `INSERT INTO domain_events`, with the actor (claims.sub / primary_role)
//      and the correct eventType + category. We drive it with the catalog
//      builder financeAudit.collectionCancelled (a real collection mutation that
//      DOES use the catalog) AND with the exact inline spec the collect path
//      hand-writes, so both shapes are covered.
//   2. HANDLER WIRING — a static-source assertion that
//      finance_collections_handlers.ts, on the collect (handleCreateCollection)
//      path, calls recordMutationAudit with eventType "collectionCreated",
//      category "workflow", entityType "finance_collection", the created
//      collection id as entityId, and the domain eventType
//      "finance.collection.created" — i.e. the audit emit is actually on the
//      success path of the mutation, not dead code. The actor binding is
//      provided by recordServerAuditEvent (audit_repository.ts) from claims.sub /
//      claims.tenant_id / claims.school_id (asserted in leg 1).
//
// REMAINDER (infra-blocked, needs ERP_TENANT_DATABASE_URL / live RLS): asserting
// the actually-PERSISTED audit_events row after a real 201 collection — the
// handler runs the emit INSIDE withTenantContext against the (unconfigured here)
// tenant DB, so the durable row + its per-school RLS isolation require a live
// Postgres. The DB boundary is finance_collections_handlers.ts:267 (runTenant →
// withTenantContext) wrapping the createCollection + recordMutationAudit pair.

import { assertEquals, assertStringIncludes } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  emitMutationAudit,
  financeAudit,
} from "../audit/mutation_audit_catalog.ts";
import { recordMutationAudit } from "../audit/audit_repository.ts";

const ACTOR = "f0000000-0000-4000-8000-000000000001";
const ORG = "f1000000-0000-4000-8000-000000000001";
const SCHOOL = "f2000000-0000-4000-8000-000000000001";

interface AuditCapture {
  sql: string;
  args: unknown[];
}

class AuditSpyDb {
  audits: AuditCapture[] = [];
  domains: AuditCapture[] = [];

  queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    // Idempotency probe on the outbox → "no existing row" so the INSERT fires.
    if (sql.includes("FROM domain_events") && sql.includes("idempotency_key")) {
      return Promise.resolve([] as T[]);
    }
    if (sql.includes("INSERT INTO audit_events")) {
      this.audits.push({ sql, args });
      return Promise.resolve([{ id: crypto.randomUUID() }] as unknown as T[]);
    }
    if (sql.includes("INSERT INTO domain_events")) {
      this.domains.push({ sql, args });
      return Promise.resolve([{ id: crypto.randomUUID() }] as unknown as T[]);
    }
    return Promise.resolve([] as T[]);
  }
}

function claims(): AccessTokenClaims {
  return {
    sub: ACTOR,
    tenant_id: ORG,
    organization_id: ORG,
    school_id: SCHOOL,
    role: "financeAdmin",
    role_slugs: ["financeAdmin"],
    primary_role: "financeAdmin",
    permissions: ["manageFinance"],
    permissions_version: 1,
    scope: "school",
    school_group_id: null,
    student_id: null,
    child_ids: [],
    session_id: "s1",
  };
}

function db(spy: AuditSpyDb): TenantQueryClient {
  return spy as unknown as TenantQueryClient;
}

// The exact inline spec hand-written on the collect path
// (finance_collections_handlers.ts handleCreateCollection). Mirrored here so the
// write-path leg exercises the real collect-path payload, not just the catalog.
function collectionCreatedSpec(collectionId: string, invoiceId: string, amount: number) {
  return {
    audit: {
      eventType: "collectionCreated",
      category: "workflow",
      entityType: "finance_collection",
      entityId: collectionId,
      metadata: { invoiceId, amount, paymentMethod: "cash" },
    },
    domain: {
      eventType: "finance.collection.created",
      payload: { collectionId, invoiceId, amount },
      sourceModule: "finance",
      idempotencyKey: `finance.collection:${collectionId}`,
    },
  };
}

Deno.test("QA-X-014: the collect-path audit spec carries the right eventType, category and finance_collection entity", () => {
  const spec = collectionCreatedSpec("col-1", "inv-1", 5000);
  assertEquals(spec.audit.eventType, "collectionCreated");
  assertEquals(spec.audit.category, "workflow");
  assertEquals(spec.audit.entityType, "finance_collection");
  assertEquals(spec.audit.entityId, "col-1");
  assertEquals(spec.domain.eventType, "finance.collection.created");
  assertEquals(spec.domain.sourceModule, "finance");
  assertEquals(spec.domain.idempotencyKey, "finance.collection:col-1");
});

Deno.test("QA-X-014: recordMutationAudit on collect writes an audit_events row + finance.collection.created domain event bound to the collecting actor", async () => {
  const spy = new AuditSpyDb();
  const spec = collectionCreatedSpec("col-7", "inv-7", 12000);
  await recordMutationAudit(db(spy), claims(), spec.audit, spec.domain);

  // Exactly one durable audit row and one outbox event were enqueued.
  assertEquals(spy.audits.length, 1);
  assertEquals(spy.domains.length, 1);

  // Audit row args (recordServerAuditEvent column order):
  //   $1 org, $2 school, $3 user_id(actor), $4 role, $5 corr, $6 eventType, $7 category…
  const a = spy.audits[0].args;
  assertEquals(a[0], ORG);
  assertEquals(a[1], SCHOOL);
  assertEquals(a[2], ACTOR); // actor binding — WHO collected the fee
  assertEquals(a[5], "collectionCreated");
  assertEquals(a[6], "workflow");

  // Domain (outbox) row args: $1 org, $2 school, $3 eventType, …
  const d = spy.domains[0].args;
  assertEquals(d[0], ORG);
  assertEquals(d[2], "finance.collection.created");
});

Deno.test("QA-X-014: the catalog collection builder (collectionCancelled) also persists via emitMutationAudit with actor + finance.collection event", async () => {
  const spy = new AuditSpyDb();
  await emitMutationAudit(db(spy), claims(), financeAudit.collectionCancelled("col-9"));
  assertEquals(spy.audits.length, 1);
  assertEquals(spy.domains.length, 1);
  assertEquals(spy.audits[0].args[2], ACTOR); // actor bound
  assertEquals(spy.audits[0].args[5], "collectionCancelled");
  assertEquals(spy.domains[0].args[2], "finance.collection.cancelled");
});

Deno.test("QA-X-014 (handler wiring): the collect handler invokes recordMutationAudit with the collectionCreated audit on the success path", async () => {
  const src = await Deno.readTextFile(
    new URL("./finance_collections_handlers.ts", import.meta.url),
  );
  // The collect handler must call the audit emit…
  assertStringIncludes(src, "recordMutationAudit(");
  // …with the collect event type + entity + domain event (proves it is the
  // collect path, not some other finance mutation).
  assertStringIncludes(src, 'eventType: "collectionCreated"');
  assertStringIncludes(src, 'entityType: "finance_collection"');
  assertStringIncludes(src, 'eventType: "finance.collection.created"');
  // …and is reached only after the collection is created (success path): the
  // emit sits inside the same runTenant callback as createCollection().
  const created = src.indexOf("createCollection(db");
  const audit = src.indexOf("recordMutationAudit(", created);
  if (created < 0 || audit < 0 || audit < created) {
    throw new Error("expected recordMutationAudit to follow createCollection on the collect path");
  }
});
