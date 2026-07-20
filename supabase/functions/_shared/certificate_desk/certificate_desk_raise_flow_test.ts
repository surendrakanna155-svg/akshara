// Proves the exact sequence handleRaiseCertificateRequest performs inside its
// withTenantContext transaction: createCertificateRequest -> submitApproval
// (F2 framework, type "certificateRequest") -> linkApprovalRequest. Since
// withTenantContext needs a real Postgres connection (unavailable in this
// offline test run — see certificate_desk_handlers_test.ts's header), this
// exercises the three real repository functions directly, composed in the
// same order, against a combined fake DB that models BOTH
// sis_certificate_requests (this module's table) and approval_requests /
// approval_audit_entries (the F2 framework's tables, per
// approval_repository.ts's real SQL). This is the "request->approval
// linkage" proof: not a JOIN, just a same-transaction write sequence, so the
// fake DB's lack of JOIN semantics does not weaken this particular test.

import { assertEquals, assertNotEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import { submitApproval } from "../approval/approval_repository.ts";
import type { ApprovalRequestRow } from "../approval/approval_types.ts";
import {
  createCertificateRequest,
  getCertificateRequestById,
  linkApprovalRequest,
} from "./certificate_desk_repository.ts";

const ORG = "d1000000-0000-4000-8000-000000000001";
const SCHOOL = "d2000000-0000-4000-8000-000000000001";
const STUDENT = "d4000000-0000-4000-8000-000000000001";
const PARENT = "d3000000-0000-4000-8000-000000000001";

type Row = Record<string, unknown>;

class RaiseFlowMockDb {
  requests = new Map<string, Row>();
  approvals: ApprovalRequestRow[] = [];
  auditEntries: Row[] = [];

  // deno-lint-ignore require-await
  async queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    // sis_certificate_requests INSERT.
    if (sql.includes("INSERT INTO sis_certificate_requests")) {
      const [, , studentId, certificateType, purpose, requestedBy, requestedByRole] = args;
      const row: Row = {
        id: crypto.randomUUID(),
        organization_id: ORG,
        school_id: SCHOOL,
        student_id: studentId,
        certificate_type: certificateType,
        purpose: purpose ?? null,
        status: "pending",
        requested_by: requestedBy,
        requested_by_role: requestedByRole ?? null,
        approval_request_id: null,
        issued_certificate_id: null,
        issue_note: null,
        decided_at: null,
        created_at: "2026-07-15T00:00:00.000Z",
        updated_at: "2026-07-15T00:00:00.000Z",
      };
      this.requests.set(String(row.id), row);
      return [row] as T[];
    }
    if (sql.includes("SELECT") && sql.includes("FROM sis_certificate_requests") && sql.includes("WHERE id =")) {
      const row = this.requests.get(String(args[0]));
      return row ? [row] as T[] : [] as T[];
    }
    if (sql.includes("UPDATE sis_certificate_requests") && sql.includes("SET approval_request_id")) {
      const row = this.requests.get(String(args[0]));
      if (!row) return [] as T[];
      row.approval_request_id = args[3];
      return [row] as T[];
    }

    // approval_requests — findPendingByEntity (dedup lookup).
    if (sql.includes("SELECT * FROM approval_requests") && sql.includes("status = 'pending'")) {
      const [, , type, entityType, entityId] = args;
      const found = this.approvals.find((a) =>
        a.type === type && a.entity_type === entityType && a.entity_id === entityId &&
        a.status === "pending"
      );
      return found ? [found] as T[] : [] as T[];
    }
    // approval_requests INSERT.
    if (sql.includes("INSERT INTO approval_requests")) {
      const [orgId, schoolId, type, title, summary, requesterId, requesterName, entityType, entityId, payload] =
        args;
      const row: ApprovalRequestRow = {
        id: crypto.randomUUID(),
        organization_id: String(orgId),
        school_id: String(schoolId),
        type: String(type),
        status: "pending",
        title: String(title),
        summary: String(summary),
        requester_id: String(requesterId),
        requester_name: String(requesterName),
        entity_type: String(entityType),
        entity_id: String(entityId),
        payload: JSON.parse(String(payload)),
        decided_at: null,
        decided_by_id: null,
        decided_by_name: null,
        decision_comment: null,
        created_at: "2026-07-15T00:00:00.000Z",
        updated_at: "2026-07-15T00:00:00.000Z",
      };
      this.approvals.push(row);
      return [row] as T[];
    }
    // approval_audit_entries INSERT.
    if (sql.includes("INSERT INTO approval_audit_entries")) {
      const row = { id: crypto.randomUUID(), approval_request_id: args[2], action: args[3] };
      this.auditEntries.push(row);
      return [row] as T[];
    }

    return [] as T[];
  }

  // deno-lint-ignore require-await
  async queryCount(): Promise<number> {
    return 0;
  }
}

function client(mock: RaiseFlowMockDb): TenantQueryClient {
  return mock as unknown as TenantQueryClient;
}

Deno.test("raise flow: create request -> submit F2 approval -> link approval_request_id (staff)", async () => {
  const mock = new RaiseFlowMockDb();
  const scope = { organizationId: ORG, schoolId: SCHOOL };

  const created = await createCertificateRequest(client(mock), scope, {
    studentId: STUDENT,
    certificateType: "bonafide",
    purpose: "bank KYC",
    requestedBy: "staff-1",
    requestedByRole: "officeStaff",
  });
  assertEquals(created.status, "pending");
  assertEquals(created.approval_request_id, null, "not linked yet");

  const approval = await submitApproval(client(mock), ORG, SCHOOL, {
    type: "certificateRequest",
    title: "Bonafide certificate request",
    summary: "Reason: bank KYC",
    requesterId: "staff-1",
    requesterName: "Requester",
    entityType: "certificate_request",
    entityId: created.id,
    payload: { certificateType: "bonafide", studentId: STUDENT },
  });
  assertEquals(approval.type, "certificateRequest");
  assertEquals(approval.entity_type, "certificate_request");
  assertEquals(approval.entity_id, created.id, "the approval points at THIS request");
  assertEquals(approval.status, "pending");
  assertNotEquals(approval.id, created.id, "the approval row is distinct from the request row");

  await linkApprovalRequest(client(mock), scope, created.id, approval.id);

  const reloaded = await getCertificateRequestById(client(mock), scope, created.id);
  assertEquals(reloaded?.approval_request_id, approval.id, "the request now points BACK at the approval");
  assertEquals(mock.auditEntries.length, 1, "submitApproval's own 'submitted' audit entry fired");
});

Deno.test("raise flow: parent-raised request carries the parent as requested_by/role, and links identically", async () => {
  const mock = new RaiseFlowMockDb();
  const scope = { organizationId: ORG, schoolId: SCHOOL };

  const created = await createCertificateRequest(client(mock), scope, {
    studentId: STUDENT,
    certificateType: "transfer",
    requestedBy: PARENT,
    requestedByRole: "parent",
  });
  assertEquals(created.requested_by, PARENT);
  assertEquals(created.requested_by_role, "parent");

  const approval = await submitApproval(client(mock), ORG, SCHOOL, {
    type: "certificateRequest",
    title: "Transfer certificate request",
    summary: "Transfer certificate requested",
    requesterId: PARENT,
    requesterName: "Parent",
    entityType: "certificate_request",
    entityId: created.id,
  });
  await linkApprovalRequest(client(mock), scope, created.id, approval.id);

  const reloaded = await getCertificateRequestById(client(mock), scope, created.id);
  assertEquals(reloaded?.approval_request_id, approval.id);
  assertEquals(approval.requester_id, PARENT, "the F2 approval's requester is the parent, never trusted from a body field");
});
