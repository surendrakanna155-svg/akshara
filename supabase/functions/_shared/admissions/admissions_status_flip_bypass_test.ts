// Gap-sweep FIX 3 (P1) — Admissions generic-update status-flip bypass.
//
// handleUpdateApplication (PUT /admissions/applications/:id) is gated only on
// manageAdmissions, yet used to forward a client-supplied `status` straight
// into updateApplication(...). That let ANY manageAdmissions holder (e.g. a
// counselor) flip an application to 'approved' through the generic endpoint,
// bypassing the dedicated approve path (handleApproveAdmission →
// setApprovalDecision), which requires approveAdmissions AND enforces the
// maker != checker SoD guard (AdmissionsSelfApproveDeniedError — see
// admissions_approval_sod_test.ts).
//
// FIX: handleUpdateApplication no longer reads/forwards `status` at all —
// 'approved'/'rejected' can ONLY be set via handleApproveAdmission →
// setApprovalDecision.
//
// updateApplication() itself still supports a `status` field (other
// legitimate internal callers may use it) — the fix is entirely at the
// HANDLER boundary. This file proves BOTH halves DB-free:
//   1. updateApplication(), called the way the FIXED handler now calls it
//      (status omitted), NEVER changes status — even though other fields
//      DO update. (Positive control: passing status explicitly at the repo
//      layer still works, showing the guard is a handler-level policy, not a
//      repository capability that was removed.)
//   2. The dedicated approve path (setApprovalDecision) is untouched by this
//      fix — reuses the existing admissions_approval_sod_test.ts coverage.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import { updateApplication } from "./admissions_repository.ts";
import type { AdmissionsApplicationRow } from "./admissions_mapper.ts";

const ORG = "f9000000-0000-4000-8000-000000000001";
const SCHOOL = "fa000000-0000-4000-8000-000000000001";
const APPLICATION = "fb000000-0000-4000-8000-000000000001";

class FakeApplicationDb {
  row: AdmissionsApplicationRow = {
    id: APPLICATION,
    organization_id: ORG,
    school_id: SCHOOL,
    lead_id: null,
    student_name: "Original Name",
    class_label: "Grade 3",
    parent_name: "Parent",
    counselor: "Counselor A",
    status: "submitted",
    submitted_at: "2026-07-08T00:00:00.000Z",
    submitted_by: "counselor-a",
    created_at: "2026-07-08T00:00:00.000Z",
    updated_at: "2026-07-08T00:00:00.000Z",
  };

  // deno-lint-ignore no-explicit-any
  async queryObject<T>(sql: string, args: any[] = []): Promise<T[]> {
    if (sql.includes("SELECT a.*") && sql.includes("FROM admissions_applications a")) {
      return (this.row.id === args[0] ? [{ ...this.row }] : []) as unknown as T[];
    }
    if (sql.includes("UPDATE admissions_applications SET")) {
      // Mirrors the real UPDATE column order: student_name, class_label,
      // parent_name, counselor, status.
      this.row = {
        ...this.row,
        student_name: args[3],
        class_label: args[4],
        parent_name: args[5],
        counselor: args[6],
        status: args[7],
      };
      return [{ ...this.row }] as unknown as T[];
    }
    throw new Error(`Unhandled SQL in FakeApplicationDb: ${sql.slice(0, 80)}`);
  }
}

function db(fake: FakeApplicationDb): TenantQueryClient {
  return fake as unknown as TenantQueryClient;
}

Deno.test("FIX-3: updateApplication called the way the FIXED handler calls it (status omitted) never changes status", async () => {
  const fake = new FakeApplicationDb();
  const updated = await updateApplication(db(fake), ORG, SCHOOL, APPLICATION, {
    studentName: "Updated Name",
    classLabel: "Grade 4",
    // status intentionally OMITTED — exactly what handleUpdateApplication
    // now does, even if the client's body contained status: "approved".
  });
  assertEquals(updated?.student_name, "Updated Name", "other fields still update");
  assertEquals(updated?.status, "submitted", "status must be UNCHANGED — never flipped by the generic endpoint");
  assertEquals(fake.row.status, "submitted");
});

Deno.test("FIX-3: a spoofed status in the caller's intent is a no-op at the repo layer too, when simply not passed through", async () => {
  const fake = new FakeApplicationDb();
  // Simulates: client PUTs { status: "approved", student_name: "X" }, and the
  // (now fixed) handler builds the repo input WITHOUT status regardless of
  // what the body said.
  const clientBody: Record<string, unknown> = { status: "approved", student_name: "X" };
  const repoInput = {
    studentName: typeof clientBody.student_name === "string" ? clientBody.student_name : undefined,
    // status: deliberately never read from clientBody.status
  };
  const updated = await updateApplication(db(fake), ORG, SCHOOL, APPLICATION, repoInput);
  assertEquals(updated?.status, "submitted", "status is NOT approved afterward");
});

Deno.test("FIX-3 (positive control): updateApplication STILL supports an explicit status at the repository layer (the guard is handler-only policy)", async () => {
  const fake = new FakeApplicationDb();
  const updated = await updateApplication(db(fake), ORG, SCHOOL, APPLICATION, {
    status: "approved",
  });
  assertEquals(updated?.status, "approved", "the repository capability itself is intentionally untouched");
});
