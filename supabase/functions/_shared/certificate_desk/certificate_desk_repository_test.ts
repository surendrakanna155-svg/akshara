import {
  assertEquals,
  assertRejects,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  assertCertificateRequestType,
  cancelCertificateRequest,
  type CertificateRequestRow,
  type CertificateRequestScope,
  CertificateRequestStateError,
  createCertificateRequest,
  DuplicateCertificateRequestError,
  getCertificateRequestById,
  InvalidCertificateRequestTypeError,
  linkApprovalRequest,
  listCertificateRequests,
  markRequestBlockedDues,
  markRequestIssued,
  markRequestRejected,
} from "./certificate_desk_repository.ts";

const ORG = "b1000000-0000-4000-8000-000000000001";
const SCHOOL = "b2000000-0000-4000-8000-000000000001";
const STUDENT = "b4000000-0000-4000-8000-000000000001";
const STUDENT_B = "b4000000-0000-4000-8000-000000000002";
const STAFF = "b3000000-0000-4000-8000-000000000001";
const SCOPE: CertificateRequestScope = { organizationId: ORG, schoolId: SCHOOL };

type Row = Record<string, unknown>;

/**
 * Faithful in-memory model of the exact SQL certificate_desk_repository.ts
 * issues against sis_certificate_requests, including the DB partial-unique
 * open-request guard (uq_sis_certificate_requests_open) and every guarded
 * terminal UPDATE's `AND status = '<pre>'` semantics.
 */
class RequestMockDb {
  rows = new Map<string, Row>();

  private nextRow(over: Partial<Row>): Row {
    const id = crypto.randomUUID();
    const now = "2026-07-15T00:00:00.000Z";
    return {
      id,
      organization_id: ORG,
      school_id: SCHOOL,
      purpose: null,
      requested_by_role: null,
      approval_request_id: null,
      issued_certificate_id: null,
      issue_note: null,
      decided_at: null,
      created_at: now,
      updated_at: now,
      ...over,
    };
  }

  private hasOpenDuplicate(studentId: string, certificateType: string, excludeId?: string): boolean {
    for (const row of this.rows.values()) {
      if (row.id === excludeId) continue;
      if (
        row.student_id === studentId &&
        row.certificate_type === certificateType &&
        (row.status === "pending" || row.status === "approved")
      ) {
        return true;
      }
    }
    return false;
  }

  // deno-lint-ignore require-await
  async queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    // INSERT — raise a request.
    if (sql.includes("INSERT INTO sis_certificate_requests")) {
      const [, , studentId, certificateType, purpose, requestedBy, requestedByRole] = args;
      if (this.hasOpenDuplicate(String(studentId), String(certificateType))) {
        throw new Error(
          `duplicate key value violates unique constraint "uq_sis_certificate_requests_open"`,
        );
      }
      const row = this.nextRow({
        student_id: studentId,
        certificate_type: certificateType,
        purpose: purpose ?? null,
        status: "pending",
        requested_by: requestedBy,
        requested_by_role: requestedByRole ?? null,
      });
      this.rows.set(String(row.id), row);
      return [row] as T[];
    }

    // SELECT by id.
    if (sql.includes("SELECT") && sql.includes("FROM sis_certificate_requests") && sql.includes("WHERE id =")) {
      const row = this.rows.get(String(args[0]));
      if (!row || row.organization_id !== args[1] || row.school_id !== args[2]) return [] as T[];
      return [row] as T[];
    }

    // SELECT list.
    if (sql.includes("SELECT") && sql.includes("FROM sis_certificate_requests") && sql.includes("ORDER BY created_at DESC")) {
      let out = [...this.rows.values()].filter(
        (r) => r.organization_id === args[0] && r.school_id === args[1],
      );
      // Positional filters: status then studentIds, OR studentIds then status —
      // detect by arg shape (array = studentIds, else status string).
      for (let i = 2; i < args.length; i++) {
        const a = args[i];
        if (Array.isArray(a)) {
          out = out.filter((r) => a.includes(r.student_id));
        } else {
          out = out.filter((r) => r.status === a);
        }
      }
      out.sort((a, b) => String(b.created_at).localeCompare(String(a.created_at)));
      return out as T[];
    }

    // UPDATE approval_request_id link (unguarded).
    if (sql.includes("UPDATE sis_certificate_requests") && sql.includes("SET approval_request_id")) {
      const row = this.rows.get(String(args[0]));
      if (row && row.organization_id === args[1] && row.school_id === args[2]) {
        row.approval_request_id = args[3];
        return [row] as T[];
      }
      return [] as T[];
    }

    // Guarded terminal UPDATEs (cancel / reject / issued / blocked_dues) — all
    // share `AND status = 'pending'` and RETURNING the full row.
    if (sql.includes("UPDATE sis_certificate_requests") && sql.includes("AND status = 'pending'")) {
      const row = this.rows.get(String(args[0]));
      if (!row || row.organization_id !== args[1] || row.school_id !== args[2] || row.status !== "pending") {
        return [] as T[]; // guard lost — 0 rows, exactly like a real guarded UPDATE.
      }
      if (sql.includes("status = 'cancelled'")) {
        row.status = "cancelled";
        row.decided_at = "2026-07-15T01:00:00.000Z";
      } else if (sql.includes("status = 'rejected'")) {
        row.status = "rejected";
        row.issue_note = args[3] ?? null;
        row.decided_at = "2026-07-15T01:00:00.000Z";
      } else if (sql.includes("status = 'issued'")) {
        row.status = "issued";
        row.issued_certificate_id = args[3];
        row.decided_at = "2026-07-15T01:00:00.000Z";
      } else if (sql.includes("status = 'blocked_dues'")) {
        row.status = "blocked_dues";
        row.issue_note = args[3];
        row.decided_at = "2026-07-15T01:00:00.000Z";
      }
      return [row] as T[];
    }

    return [] as T[];
  }

  // deno-lint-ignore require-await
  async queryCount(): Promise<number> {
    return 0;
  }
}

function client(mock: RequestMockDb): TenantQueryClient {
  return mock as unknown as TenantQueryClient;
}

// ─── assertCertificateRequestType ────────────────────────────────────────

Deno.test("assertCertificateRequestType accepts all five types including 'fee'", () => {
  for (const t of ["bonafide", "study", "conduct", "transfer", "fee"]) {
    assertEquals(assertCertificateRequestType(t), t);
  }
});

Deno.test("assertCertificateRequestType rejects an unknown type", () => {
  let threw = false;
  try {
    assertCertificateRequestType("character");
  } catch (e) {
    threw = true;
    assertEquals(e instanceof InvalidCertificateRequestTypeError, true);
  }
  assertEquals(threw, true);
});

// ─── createCertificateRequest ────────────────────────────────────────────

Deno.test("createCertificateRequest: inserts a pending row", async () => {
  const mock = new RequestMockDb();
  const row = await createCertificateRequest(client(mock), SCOPE, {
    studentId: STUDENT,
    certificateType: "bonafide",
    purpose: "bank KYC",
    requestedBy: STAFF,
    requestedByRole: "officeStaff",
  });
  assertEquals(row.status, "pending");
  assertEquals(row.certificate_type, "bonafide");
  assertEquals(row.purpose, "bank KYC");
  assertEquals(row.requested_by, STAFF);
  assertEquals(row.requested_by_role, "officeStaff");
});

Deno.test("createCertificateRequest: an invalid type never reaches the DB", async () => {
  const mock = new RequestMockDb();
  await assertRejects(
    () =>
      createCertificateRequest(client(mock), SCOPE, {
        studentId: STUDENT,
        certificateType: "diploma",
        requestedBy: STAFF,
      }),
    InvalidCertificateRequestTypeError,
  );
  assertEquals(mock.rows.size, 0);
});

Deno.test("createCertificateRequest: a duplicate OPEN request (pending) for the same student+type is rejected", async () => {
  const mock = new RequestMockDb();
  await createCertificateRequest(client(mock), SCOPE, {
    studentId: STUDENT,
    certificateType: "transfer",
    requestedBy: STAFF,
  });
  const error = await assertRejects(
    () =>
      createCertificateRequest(client(mock), SCOPE, {
        studentId: STUDENT,
        certificateType: "transfer",
        requestedBy: STAFF,
      }),
    DuplicateCertificateRequestError,
  );
  assertStringIncludes(error.message, "transfer");
  assertEquals(mock.rows.size, 1, "the duplicate insert never landed a second row");
});

Deno.test("createCertificateRequest: a DIFFERENT certificate type for the same student is allowed", async () => {
  const mock = new RequestMockDb();
  await createCertificateRequest(client(mock), SCOPE, {
    studentId: STUDENT,
    certificateType: "bonafide",
    requestedBy: STAFF,
  });
  const second = await createCertificateRequest(client(mock), SCOPE, {
    studentId: STUDENT,
    certificateType: "study",
    requestedBy: STAFF,
  });
  assertEquals(second.status, "pending");
  assertEquals(mock.rows.size, 2);
});

Deno.test("createCertificateRequest: the SAME type for a DIFFERENT student is allowed", async () => {
  const mock = new RequestMockDb();
  await createCertificateRequest(client(mock), SCOPE, {
    studentId: STUDENT,
    certificateType: "bonafide",
    requestedBy: STAFF,
  });
  const second = await createCertificateRequest(client(mock), SCOPE, {
    studentId: STUDENT_B,
    certificateType: "bonafide",
    requestedBy: STAFF,
  });
  assertEquals(second.status, "pending");
  assertEquals(mock.rows.size, 2);
});

Deno.test("createCertificateRequest: a request may be raised again once the prior one is no longer open (rejected)", async () => {
  const mock = new RequestMockDb();
  const first = await createCertificateRequest(client(mock), SCOPE, {
    studentId: STUDENT,
    certificateType: "bonafide",
    requestedBy: STAFF,
  });
  await markRequestRejected(client(mock), SCOPE, first.id, "not eligible");
  const second = await createCertificateRequest(client(mock), SCOPE, {
    studentId: STUDENT,
    certificateType: "bonafide",
    requestedBy: STAFF,
  });
  assertEquals(second.status, "pending");
});

// ─── list / get / link ────────────────────────────────────────────────────

Deno.test("listCertificateRequests: filters by status and by studentIds (parent scope)", async () => {
  const mock = new RequestMockDb();
  const a = await createCertificateRequest(client(mock), SCOPE, {
    studentId: STUDENT,
    certificateType: "bonafide",
    requestedBy: STAFF,
  });
  const b = await createCertificateRequest(client(mock), SCOPE, {
    studentId: STUDENT_B,
    certificateType: "study",
    requestedBy: STAFF,
  });
  await markRequestRejected(client(mock), SCOPE, b.id, "no");

  const pending = await listCertificateRequests(client(mock), SCOPE, { status: "pending" });
  assertEquals(pending.map((r) => r.id), [a.id]);

  const forStudentB = await listCertificateRequests(client(mock), SCOPE, {
    studentIds: [STUDENT_B],
  });
  assertEquals(forStudentB.map((r) => r.id), [b.id]);

  const forNoLinkedChildren = await listCertificateRequests(client(mock), SCOPE, {
    studentIds: [],
  });
  assertEquals(forNoLinkedChildren.length, 0, "empty studentIds short-circuits to no query at all");
});

Deno.test("getCertificateRequestById: null for a missing / cross-tenant id", async () => {
  const mock = new RequestMockDb();
  const created = await createCertificateRequest(client(mock), SCOPE, {
    studentId: STUDENT,
    certificateType: "bonafide",
    requestedBy: STAFF,
  });
  assertEquals(await getCertificateRequestById(client(mock), SCOPE, "missing-id"), null);
  const other: CertificateRequestScope = { organizationId: "other-org", schoolId: SCHOOL };
  assertEquals(await getCertificateRequestById(client(mock), other, created.id), null);
});

Deno.test("linkApprovalRequest: stamps approval_request_id", async () => {
  const mock = new RequestMockDb();
  const created = await createCertificateRequest(client(mock), SCOPE, {
    studentId: STUDENT,
    certificateType: "bonafide",
    requestedBy: STAFF,
  });
  await linkApprovalRequest(client(mock), SCOPE, created.id, "appr-1");
  const reloaded = await getCertificateRequestById(client(mock), SCOPE, created.id);
  assertEquals(reloaded?.approval_request_id, "appr-1");
});

// ─── guarded terminal writes ──────────────────────────────────────────────

Deno.test("cancelCertificateRequest: pending -> cancelled", async () => {
  const mock = new RequestMockDb();
  const created = await createCertificateRequest(client(mock), SCOPE, {
    studentId: STUDENT,
    certificateType: "bonafide",
    requestedBy: STAFF,
  });
  const cancelled = await cancelCertificateRequest(client(mock), SCOPE, created.id);
  assertEquals(cancelled.status, "cancelled");
  assertEquals(cancelled.decided_at !== null, true);
});

Deno.test("cancelCertificateRequest: already-decided -> CertificateRequestStateError, no write", async () => {
  const mock = new RequestMockDb();
  const created = await createCertificateRequest(client(mock), SCOPE, {
    studentId: STUDENT,
    certificateType: "bonafide",
    requestedBy: STAFF,
  });
  await markRequestRejected(client(mock), SCOPE, created.id, "declined");
  await assertRejects(
    () => cancelCertificateRequest(client(mock), SCOPE, created.id),
    CertificateRequestStateError,
  );
  const reloaded = await getCertificateRequestById(client(mock), SCOPE, created.id);
  assertEquals(reloaded?.status, "rejected", "the original decision is untouched");
});

Deno.test("CONCURRENT double-cancel: only the first wins, the second loses cleanly (no double-write)", async () => {
  const mock = new RequestMockDb();
  const created = await createCertificateRequest(client(mock), SCOPE, {
    studentId: STUDENT,
    certificateType: "bonafide",
    requestedBy: STAFF,
  });
  const first = await cancelCertificateRequest(client(mock), SCOPE, created.id);
  assertEquals(first.status, "cancelled");
  await assertRejects(
    () => cancelCertificateRequest(client(mock), SCOPE, created.id),
    CertificateRequestStateError,
    "not pending",
  );
});

Deno.test("markRequestIssued: pending -> issued, stamps issued_certificate_id", async () => {
  const mock = new RequestMockDb();
  const created = await createCertificateRequest(client(mock), SCOPE, {
    studentId: STUDENT,
    certificateType: "fee",
    requestedBy: STAFF,
  });
  const issued = await markRequestIssued(client(mock), SCOPE, created.id, "issue-123");
  assertEquals(issued.status, "issued");
  assertEquals(issued.issued_certificate_id, "issue-123");
});

Deno.test("markRequestBlockedDues: pending -> blocked_dues, records the note", async () => {
  const mock = new RequestMockDb();
  const created = await createCertificateRequest(client(mock), SCOPE, {
    studentId: STUDENT,
    certificateType: "transfer",
    requestedBy: STAFF,
  });
  const blocked = await markRequestBlockedDues(client(mock), SCOPE, created.id, "outstanding 500");
  assertEquals(blocked.status, "blocked_dues");
  assertEquals(blocked.issue_note, "outstanding 500");
});

Deno.test("markRequestRejected / markRequestIssued / markRequestBlockedDues all guard on status='pending'", async () => {
  const mock = new RequestMockDb();
  const created = await createCertificateRequest(client(mock), SCOPE, {
    studentId: STUDENT,
    certificateType: "bonafide",
    requestedBy: STAFF,
  });
  await markRequestIssued(client(mock), SCOPE, created.id, "issue-1");
  await assertRejects(
    () => markRequestRejected(client(mock), SCOPE, created.id, "x"),
    CertificateRequestStateError,
  );
  await assertRejects(
    () => markRequestIssued(client(mock), SCOPE, created.id, "issue-2"),
    CertificateRequestStateError,
  );
  await assertRejects(
    () => markRequestBlockedDues(client(mock), SCOPE, created.id, "x"),
    CertificateRequestStateError,
  );
  const reloaded = await getCertificateRequestById(client(mock), SCOPE, created.id);
  assertEquals(reloaded?.issued_certificate_id, "issue-1", "the second write never landed");
});

// ─── migration content ────────────────────────────────────────────────────

Deno.test("certificate_requests migration: table, partial-unique open guard, RLS, grants + RBAC present", async () => {
  const migration = await Deno.readTextFile(
    new URL(
      "../../../migrations/20260884000000_certificate_requests.sql",
      import.meta.url,
    ),
  );

  assertStringIncludes(migration, "CREATE TABLE sis_certificate_requests");
  assertStringIncludes(
    migration,
    "certificate_type IN ('bonafide', 'study', 'conduct', 'transfer', 'fee')",
  );
  assertStringIncludes(
    migration,
    "status IN ('pending', 'approved', 'rejected', 'issued', 'blocked_dues', 'cancelled')",
  );
  assertStringIncludes(migration, "uq_sis_certificate_requests_open");
  assertStringIncludes(migration, "WHERE status IN ('pending', 'approved')");

  assertStringIncludes(migration, "ALTER TABLE sis_certificate_requests FORCE ROW LEVEL SECURITY");
  assertStringIncludes(migration, "sis_certificate_requests_school_read");
  assertStringIncludes(migration, "sis_certificate_requests_school_insert");
  assertStringIncludes(migration, "sis_certificate_requests_school_update");
  assertStringIncludes(migration, "sis_certificate_requests_parent_read");
  assertStringIncludes(migration, "sis_certificate_requests_parent_insert");
  // Parent gets SELECT + INSERT only — no parent UPDATE policy at all.
  assertEquals(migration.includes("sis_certificate_requests_parent_update"), false);
  assertStringIncludes(migration, "app_current_parent_user_id()");
  assertStringIncludes(migration, "student_guardians sg");

  assertStringIncludes(migration, "GRANT SELECT, INSERT, UPDATE ON sis_certificate_requests TO erp_tenant");
  assertEquals(migration.includes("DELETE ON sis_certificate_requests"), false);

  assertStringIncludes(migration, "requestStudentCertificate");
  assertStringIncludes(migration, "approveCertificateRequest");
  assertStringIncludes(migration, "sis_certificate_requests_updated_at");
});
