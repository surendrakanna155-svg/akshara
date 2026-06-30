// QW4 · QA-X-015 (P1) — Publishing exam results writes a server-side audit event
// carrying the actor + the result-set (exam_session) id.
//
// CONTRACT: POST /academics/exams/:id/publish → handlePublishExamResults must,
// on the publish success path, emit an `audit_events` row (+ an
// `exam.results.published` domain event) that binds the publishing user
// (claims.sub) to the published result set and records how many entries went
// live.
//
// FINDING / FIX (this row): on entry, handlePublishExamResults published results
// (publishExamResults) and notified parents but emitted NO audit/domain event —
// a critical, non-reversible mutation with no server-side trail. This wave added
//   • examAudit.resultsPublished(examId, count, approvalId) to the catalog, and
//   • an emitMutationAudit(...) call on the publish success path (inside the same
//     withTenantContext as publishExamResults).
//
// What is proven DB-free here:
//   1. The catalog builder shape — examAudit.resultsPublished yields
//      eventType "examResultsPublished", category "workflow",
//      entityType "exam_session", entityId = examId, and the
//      "exam.results.published" domain event keyed per session.
//   2. The audit/domain WRITE PATH — emitMutationAudit with that spec issues
//      exactly one audit INSERT (bound to claims.sub) and one outbox INSERT.
//   3. HANDLER WIRING (static-source) — handlePublishExamResults imports
//      examAudit + emitMutationAudit and calls it with
//      examAudit.resultsPublished AFTER publishExamResults on the success path
//      (not in the approval-required early-return branch).
//
// REMAINDER (infra-blocked, needs ERP_TENANT_DATABASE_URL / live RLS): the
// actually-PERSISTED audit_events row after a real publish, and its per-school
// RLS isolation, need a live Postgres — the emit runs inside withTenantContext
// (exam_administration_handlers.ts handlePublishExamResults) against the
// unconfigured tenant DB here.

import { assertEquals, assertStringIncludes } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AccessTokenClaims } from "../../jwt.ts";
import type { TenantQueryClient } from "../../tenant_db.ts";
import { emitMutationAudit, examAudit } from "../../audit/mutation_audit_catalog.ts";

const ACTOR = "e0000000-0000-4000-8000-000000000001";
const ORG = "e1000000-0000-4000-8000-000000000001";
const SCHOOL = "e2000000-0000-4000-8000-000000000001";

interface AuditCapture {
  args: unknown[];
}

class AuditSpyDb {
  audits: AuditCapture[] = [];
  domains: AuditCapture[] = [];

  queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    if (sql.includes("FROM domain_events") && sql.includes("idempotency_key")) {
      return Promise.resolve([] as T[]);
    }
    if (sql.includes("INSERT INTO audit_events")) {
      this.audits.push({ args });
      return Promise.resolve([{ id: crypto.randomUUID() }] as unknown as T[]);
    }
    if (sql.includes("INSERT INTO domain_events")) {
      this.domains.push({ args });
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
    role: "principal",
    role_slugs: ["principal"],
    primary_role: "principal",
    permissions: ["publishExamResults"],
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

Deno.test("QA-X-015: examAudit.resultsPublished binds the exam_session result set, count and approver", () => {
  const spec = examAudit.resultsPublished("exam-1", 30, "appr-1");
  assertEquals(spec.audit.eventType, "examResultsPublished");
  assertEquals(spec.audit.category, "workflow");
  assertEquals(spec.audit.entityType, "exam_session");
  assertEquals(spec.audit.entityId, "exam-1");
  assertEquals(spec.audit.metadata?.publishedCount, 30);
  assertEquals(spec.audit.metadata?.approvalId, "appr-1");
  assertEquals(spec.domain.eventType, "exam.results.published");
  assertEquals(spec.domain.sourceModule, "exam");
  assertEquals(spec.domain.idempotencyKey, "exam.results.published:exam-1");
});

Deno.test("QA-X-015: a publish with no approval gate still records the trail (approvalId null, not dropped)", () => {
  const spec = examAudit.resultsPublished("exam-2", 12, null);
  assertEquals(spec.audit.entityId, "exam-2");
  // null approvalId is allowed (publish without the approval gate) and the
  // domain payload normalises it so downstream consumers get a stable shape.
  assertEquals(spec.domain.payload.approvalId, null);
});

Deno.test("QA-X-015: emitMutationAudit on publish writes one audit_events row bound to the publishing actor + one exam.results.published domain event", async () => {
  const spy = new AuditSpyDb();
  await emitMutationAudit(db(spy), claims(), examAudit.resultsPublished("exam-9", 25, "appr-9"));
  assertEquals(spy.audits.length, 1);
  assertEquals(spy.domains.length, 1);
  const a = spy.audits[0].args;
  assertEquals(a[0], ORG);
  assertEquals(a[1], SCHOOL);
  assertEquals(a[2], ACTOR); // actor binding — WHO published the results
  assertEquals(a[5], "examResultsPublished");
  assertEquals(a[6], "workflow");
  assertEquals(spy.domains[0].args[2], "exam.results.published");
});

Deno.test("QA-X-015 (handler wiring): handlePublishExamResults emits the audit AFTER publishExamResults on the success path", async () => {
  const src = await Deno.readTextFile(
    new URL("./exam_administration_handlers.ts", import.meta.url),
  );
  assertStringIncludes(src, "examAudit.resultsPublished");
  assertStringIncludes(src, "emitMutationAudit(");
  // The emit must follow the publish (it audits the COMPLETED publish), and sit
  // after the approval-required early throw so a denied publish is not audited.
  const publish = src.indexOf("publishExamResults(db");
  const audit = src.indexOf("emitMutationAudit(", publish);
  if (publish < 0 || audit < 0 || audit < publish) {
    throw new Error("expected emitMutationAudit to follow publishExamResults on the publish success path");
  }
});
