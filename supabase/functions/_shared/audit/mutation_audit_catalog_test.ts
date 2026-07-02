import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  admissionsAudit,
  academicAudit,
  emitMutationAudit,
  examAudit,
  financeAudit,
  sisAudit,
} from "./mutation_audit_catalog.ts";

class AuditSpyDb {
  auditInserts = 0;
  domainInserts = 0;
  lastAuditType = "";
  lastDomainType = "";

  async queryObject<T>(sql: string, _args: unknown[] = []): Promise<T[]> {
    if (sql.includes("FROM domain_events") && sql.includes("idempotency_key")) {
      return [] as T[];
    }
    if (sql.includes("INSERT INTO audit_events")) {
      this.auditInserts += 1;
      this.lastAuditType = String(_args[5] ?? _args[6] ?? "");
      return [{ id: crypto.randomUUID() }] as T[];
    }
    if (sql.includes("INSERT INTO domain_events")) {
      this.domainInserts += 1;
      this.lastDomainType = String(_args[2] ?? "");
      return [{ id: crypto.randomUUID() }] as T[];
    }
    return [] as T[];
  }
}

function claims(): AccessTokenClaims {
  return {
    sub: "a3000000-0000-4000-8000-000000000001",
    tenant_id: "a1000000-0000-4000-8000-000000000001",
    organization_id: "a1000000-0000-4000-8000-000000000001",
    school_id: "a2000000-0000-4000-8000-000000000001",
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

Deno.test("emitMutationAudit writes audit and domain event for admissions leadUpdated", async () => {
  const spy = new AuditSpyDb();
  const db = spy as unknown as TenantQueryClient;
  await emitMutationAudit(db, claims(), admissionsAudit.leadUpdated("lead-1"));
  assertEquals(spy.auditInserts, 1);
  assertEquals(spy.domainInserts, 1);
  assertEquals(spy.lastAuditType, "leadUpdated");
  assertEquals(spy.lastDomainType, "admissions.lead.updated");
});

Deno.test("finance invoiceIssued catalog includes domain idempotency key", async () => {
  const spec = financeAudit.invoiceIssued("inv-1");
  assertEquals(spec.domain.idempotencyKey, "finance.invoice.issued:inv-1");
});

Deno.test("sis admissionsConverted catalog references student and enrollment", () => {
  const spec = sisAudit.admissionsConverted("stu-1", "enr-1");
  assertEquals(spec.audit.eventType, "admissionsConversionCompleted");
  assertEquals(spec.domain.payload.enrollmentId, "enr-1");
});

Deno.test("sis documentVerified catalog binds document + student + status", () => {
  const spec = sisAudit.documentVerified("doc-1", "stu-1", "verified", "ok");
  assertEquals(spec.audit.eventType, "sisDocumentVerified");
  assertEquals(spec.audit.category, "workflow");
  assertEquals(spec.audit.entityType, "student_document");
  assertEquals(spec.audit.entityId, "doc-1");
  assertEquals(spec.audit.metadata?.studentId, "stu-1");
  assertEquals(spec.audit.metadata?.status, "verified");
  assertEquals(spec.audit.metadata?.note, "ok");
  assertEquals(spec.domain.eventType, "sis.document.verified");
  assertEquals(spec.domain.sourceModule, "sis");
  assertEquals(spec.domain.idempotencyKey, "sis.document.verified:doc-1:verified");
});

Deno.test("academic yearCreated catalog uses academic module", () => {
  const spec = academicAudit.yearCreated("yr-1");
  assertEquals(spec.domain.sourceModule, "academic");
});

Deno.test("exam resultsPublished catalog binds the result set + approver count", () => {
  const spec = examAudit.resultsPublished("exam-1", 42, "appr-1");
  assertEquals(spec.audit.eventType, "examResultsPublished");
  assertEquals(spec.audit.category, "workflow");
  assertEquals(spec.audit.entityType, "exam_session");
  assertEquals(spec.audit.entityId, "exam-1");
  assertEquals(spec.audit.metadata?.publishedCount, 42);
  assertEquals(spec.audit.metadata?.approvalId, "appr-1");
  assertEquals(spec.domain.eventType, "exam.results.published");
  assertEquals(spec.domain.idempotencyKey, "exam.results.published:exam-1");
});
