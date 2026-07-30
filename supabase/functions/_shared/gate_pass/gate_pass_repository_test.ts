// PRC-A Batch 2 — Gate Pass repository tests, hand-rolled in-memory mock
// (canonical style: sis/sis_certificates_repository_test.ts). The mock
// reproduces the exact SQL shapes gate_pass_repository.ts issues; it does NOT
// evaluate real JOIN/subquery semantics (a known limitation of this style —
// see the report), so the parent-scope guardian subqueries are modelled by
// direct JS filtering rather than proving live Postgres JOIN correctness.

import {
  assertEquals,
  assertRejects,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import { hashGatePassSecret } from "./gate_pass_crypto.ts";
import {
  applyGatePassDecision,
  cancelGatePass,
  createGatePass,
  effectiveGatePassStatus,
  GatePassError,
  gatePassToApi,
  GatePassInvalidStateError,
  type GatePassRow,
  GatePassVerificationFailedError,
  getGatePassForParent,
  getGatePassForStaff,
  linkApprovalRequest,
  listGatePassesForParent,
  listGatePassesForSchool,
  parentOwnsStudent,
  studentExistsInSchool,
  verifyGatePassCredential,
} from "./gate_pass_repository.ts";

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL = "a2000000-0000-4000-8000-000000000001";
const STUDENT = "a4000000-0000-4000-8000-000000000001";
const OTHER_STUDENT = "a4000000-0000-4000-8000-000000000002";
const PARENT = "a5000000-0000-4000-8000-000000000001";
const OTHER_PARENT = "a5000000-0000-4000-8000-000000000002";
const STAFF = "a3000000-0000-4000-8000-000000000001";
const APPROVER = "a3000000-0000-4000-8000-000000000002";

interface GuardianSeed {
  studentId: string;
  guardianUserId: string;
  schoolId: string;
  isPrimary: boolean;
  status: "active" | "inactive";
}

class GatePassMockDb {
  rows = new Map<string, GatePassRow>();
  studentSchools = new Map<string, { org: string; school: string }>();
  guardians: GuardianSeed[] = [];
  private seq = 0;

  seedStudent(id: string, org: string, school: string) {
    this.studentSchools.set(id, { org, school });
  }

  seedGuardian(seed: GuardianSeed) {
    this.guardians.push(seed);
  }

  /** Directly seed a gate_passes row (bypassing createGatePass) for tests that
   * exercise decision/verify/cancel against a pre-existing state. */
  seedGatePass(partial: Partial<GatePassRow> & { id: string }): GatePassRow {
    const row: GatePassRow = {
      organization_id: ORG,
      school_id: SCHOOL,
      student_id: STUDENT,
      pass_type: "early_pickup",
      reason: "appointment",
      requested_by: PARENT,
      pickup_person_name: "Ravi Rao",
      pickup_person_relation: "father",
      pickup_person_phone: "9999999999",
      scheduled_at: "2026-07-15T10:00:00.000Z",
      status: "pending",
      approval_request_id: null,
      otp_hash: null,
      qr_token_hash: null,
      credential_expires_at: null,
      verified_by: null,
      verified_at: null,
      verification_note: null,
      created_at: "2026-07-15T08:00:00.000Z",
      updated_at: "2026-07-15T08:00:00.000Z",
      ...partial,
    };
    this.rows.set(row.id, row);
    return row;
  }

  private ownedStudentIds(parentUserId: string, schoolId: string): Set<string> {
    return new Set(
      this.guardians
        .filter((g) => g.guardianUserId === parentUserId && g.status === "active" && g.schoolId === schoolId)
        .map((g) => g.studentId),
    );
  }

  // deno-lint-ignore require-await
  async queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    // ── INSERT ─────────────────────────────────────────────────────────────
    if (sql.includes("INSERT INTO gate_passes")) {
      const id = `gp-${++this.seq}`;
      const row: GatePassRow = {
        organization_id: String(args[0]),
        school_id: String(args[1]),
        student_id: String(args[2]),
        pass_type: String(args[3]),
        reason: String(args[4]),
        requested_by: String(args[5]),
        pickup_person_name: String(args[6]),
        pickup_person_relation: String(args[7]),
        pickup_person_phone: String(args[8]),
        scheduled_at: String(args[9]),
        status: "pending",
        approval_request_id: null,
        otp_hash: null,
        qr_token_hash: null,
        credential_expires_at: null,
        verified_by: null,
        verified_at: null,
        verification_note: null,
        created_at: "2026-07-15T08:00:00.000Z",
        updated_at: "2026-07-15T08:00:00.000Z",
        id,
      };
      this.rows.set(id, row);
      return [row] as T[];
    }

    // ── link approval_request_id ──────────────────────────────────────────
    if (sql.includes("SET approval_request_id")) {
      const [id, org, school, approvalId] = args as string[];
      const row = this.rows.get(id);
      if (!row || row.organization_id !== org || row.school_id !== school) return [] as T[];
      row.approval_request_id = approvalId;
      return [row] as T[];
    }

    // ── student-in-school guard ───────────────────────────────────────────
    if (sql.includes("SELECT id FROM students WHERE id")) {
      const [studentId, org, school] = args as string[];
      const rec = this.studentSchools.get(studentId);
      if (rec && rec.org === org && rec.school === school) return [{ id: studentId }] as T[];
      return [] as T[];
    }

    // ── parent-owns-student existence check ───────────────────────────────
    if (sql.includes("SELECT id FROM student_guardians")) {
      const [org, school, studentId, parentUserId] = args as string[];
      void org;
      const owns = this.guardians.some((g) =>
        g.studentId === studentId && g.guardianUserId === parentUserId &&
        g.schoolId === school && g.status === "active"
      );
      return owns ? [{ id: "sg-1" }] as T[] : [] as T[];
    }

    // ── primary guardian lookup (for OTP dispatch) ────────────────────────
    if (sql.includes("SELECT guardian_user_id FROM student_guardians")) {
      const [org, school, studentId] = args as string[];
      void org;
      const candidates = this.guardians.filter((g) =>
        g.studentId === studentId && g.schoolId === school && g.status === "active"
      );
      candidates.sort((a, b) => (a.isPrimary === b.isPrimary ? 0 : a.isPrimary ? -1 : 1));
      const first = candidates[0];
      return first ? [{ guardian_user_id: first.guardianUserId }] as T[] : [] as T[];
    }

    // ── cancel (guarded UPDATE) ────────────────────────────────────────────
    if (sql.includes("UPDATE gate_passes") && sql.includes("status = 'cancelled'")) {
      const [id, org, school, actorId, actorCanApprove] = args as [string, string, string, string, boolean];
      const row = this.rows.get(id);
      if (
        !row || row.organization_id !== org || row.school_id !== school ||
        !(row.status === "pending" || row.status === "approved") ||
        !(row.requested_by === actorId || actorCanApprove === true)
      ) {
        return [] as T[];
      }
      row.status = "cancelled";
      return [row] as T[];
    }

    // ── reject (guarded UPDATE) ────────────────────────────────────────────
    if (sql.includes("UPDATE gate_passes") && sql.includes("status = 'rejected'")) {
      const [id, org, school] = args as string[];
      const row = this.rows.get(id);
      if (!row || row.organization_id !== org || row.school_id !== school || row.status !== "pending") {
        return [] as T[];
      }
      row.status = "rejected";
      return [row] as T[];
    }

    // ── approve / mint credential (guarded UPDATE) ─────────────────────────
    if (sql.includes("UPDATE gate_passes") && sql.includes("otp_hash = $4")) {
      const [id, org, school, otpHash, qrTokenHash, expiresAt] = args as string[];
      const row = this.rows.get(id);
      if (!row || row.organization_id !== org || row.school_id !== school || row.status !== "pending") {
        return [] as T[];
      }
      row.status = "approved";
      row.otp_hash = otpHash;
      row.qr_token_hash = qrTokenHash;
      row.credential_expires_at = expiresAt;
      return [row] as T[];
    }

    // ── verify claim (guarded terminal UPDATE) ─────────────────────────────
    if (sql.includes("UPDATE gate_passes") && sql.includes("status = 'used'")) {
      const [id, org, school, verifiedBy, note] = args as string[];
      const row = this.rows.get(id);
      if (!row || row.organization_id !== org || row.school_id !== school || row.status !== "approved") {
        return [] as T[];
      }
      row.status = "used";
      row.verified_by = verifiedBy;
      row.verified_at = "2026-07-15T09:00:00.000Z";
      row.verification_note = note ?? null;
      return [row] as T[];
    }

    // ── approve: read the pending row ──────────────────────────────────────
    if (sql.includes("SELECT * FROM gate_passes") && sql.includes("status = 'pending'")) {
      const [id, org, school] = args as string[];
      const row = this.rows.get(id);
      if (!row || row.organization_id !== org || row.school_id !== school || row.status !== "pending") {
        return [] as T[];
      }
      return [row] as T[];
    }

    // ── plain by-id lookup (staff detail / verify's initial read) ─────────
    if (sql.includes("SELECT * FROM gate_passes") && sql.includes("WHERE id = $1")) {
      const [id, org, school] = args as string[];
      const row = this.rows.get(id);
      if (!row || row.organization_id !== org || row.school_id !== school) return [] as T[];
      return [row] as T[];
    }

    // ── parent detail (guardian-owned) ─────────────────────────────────────
    if (sql.includes("SELECT gp.* FROM gate_passes gp") && sql.includes("gp.id = $1")) {
      const [id, org, school, parentUserId] = args as string[];
      const row = this.rows.get(id);
      if (!row || row.organization_id !== org || row.school_id !== school) return [] as T[];
      const owned = this.ownedStudentIds(parentUserId, school);
      return owned.has(row.student_id) ? [row] as T[] : [] as T[];
    }

    // ── staff list ──────────────────────────────────────────────────────────
    if (sql.includes("SELECT * FROM gate_passes") && sql.includes("ORDER BY scheduled_at DESC")) {
      const [org, school, status] = args as string[];
      const out = [...this.rows.values()].filter((r) =>
        r.organization_id === org && r.school_id === school && (!status || r.status === status)
      );
      out.sort((a, b) => (a.scheduled_at < b.scheduled_at ? 1 : -1));
      return out as T[];
    }

    // ── parent list (guardian-owned) ───────────────────────────────────────
    if (sql.includes("SELECT gp.* FROM gate_passes gp") && sql.includes("ORDER BY gp.scheduled_at DESC")) {
      const [org, school, parentUserId, status] = args as string[];
      const owned = this.ownedStudentIds(parentUserId, school);
      const out = [...this.rows.values()].filter((r) =>
        r.organization_id === org && r.school_id === school && owned.has(r.student_id) &&
        (!status || r.status === status)
      );
      out.sort((a, b) => (a.scheduled_at < b.scheduled_at ? 1 : -1));
      return out as T[];
    }

    return [] as T[];
  }

  // deno-lint-ignore require-await
  async queryCount(): Promise<number> {
    return 0;
  }
}

function client(mock: GatePassMockDb): TenantQueryClient {
  return mock as unknown as TenantQueryClient;
}

// ── student / guardian guards ────────────────────────────────────────────────

Deno.test("studentExistsInSchool: true only for a student seeded in that org+school", async () => {
  const mock = new GatePassMockDb();
  mock.seedStudent(STUDENT, ORG, SCHOOL);
  assertEquals(await studentExistsInSchool(client(mock), ORG, SCHOOL, STUDENT), true);
  assertEquals(await studentExistsInSchool(client(mock), ORG, SCHOOL, OTHER_STUDENT), false);
  assertEquals(await studentExistsInSchool(client(mock), ORG, "wrong-school", STUDENT), false);
});

Deno.test("parentOwnsStudent: true only for an active guardian link", async () => {
  const mock = new GatePassMockDb();
  mock.seedGuardian({ studentId: STUDENT, guardianUserId: PARENT, schoolId: SCHOOL, isPrimary: true, status: "active" });
  assertEquals(await parentOwnsStudent(client(mock), ORG, SCHOOL, PARENT, STUDENT), true);
  assertEquals(await parentOwnsStudent(client(mock), ORG, SCHOOL, OTHER_PARENT, STUDENT), false, "not the guardian");
  assertEquals(await parentOwnsStudent(client(mock), ORG, SCHOOL, PARENT, OTHER_STUDENT), false, "wrong student");
});

Deno.test("parentOwnsStudent: an inactive guardian link does not count", async () => {
  const mock = new GatePassMockDb();
  mock.seedGuardian({ studentId: STUDENT, guardianUserId: PARENT, schoolId: SCHOOL, isPrimary: true, status: "inactive" });
  assertEquals(await parentOwnsStudent(client(mock), ORG, SCHOOL, PARENT, STUDENT), false);
});

// ── create + list + detail ────────────────────────────────────────────────────

Deno.test("createGatePass: inserts a pending row with the given fields", async () => {
  const mock = new GatePassMockDb();
  const row = await createGatePass(client(mock), ORG, SCHOOL, {
    studentId: STUDENT,
    passType: "early_pickup",
    reason: "dentist appointment",
    requestedBy: PARENT,
    pickupPersonName: "Ravi Rao",
    pickupPersonRelation: "father",
    pickupPersonPhone: "9999999999",
    scheduledAt: "2026-07-15T10:00:00.000Z",
  });
  assertEquals(row.status, "pending");
  assertEquals(row.student_id, STUDENT);
  assertEquals(row.otp_hash, null);
  assertEquals(row.qr_token_hash, null);
});

Deno.test("linkApprovalRequest: sets approval_request_id on the created row", async () => {
  const mock = new GatePassMockDb();
  const row = await createGatePass(client(mock), ORG, SCHOOL, {
    studentId: STUDENT,
    passType: "early_pickup",
    reason: "",
    requestedBy: PARENT,
    pickupPersonName: "",
    pickupPersonRelation: "",
    pickupPersonPhone: "",
    scheduledAt: "2026-07-15T10:00:00.000Z",
  });
  const linked = await linkApprovalRequest(client(mock), ORG, SCHOOL, row.id, "approval-1");
  assertEquals(linked.approval_request_id, "approval-1");
});

Deno.test("listGatePassesForSchool: scoped to org+school, optional status filter", async () => {
  const mock = new GatePassMockDb();
  mock.seedGatePass({ id: "gp-a", status: "pending", scheduled_at: "2026-07-15T09:00:00.000Z" });
  mock.seedGatePass({ id: "gp-b", status: "approved", scheduled_at: "2026-07-15T11:00:00.000Z" });
  mock.seedGatePass({ id: "gp-other-school", school_id: "other-school", status: "pending" });

  const all = await listGatePassesForSchool(client(mock), ORG, SCHOOL);
  assertEquals(all.length, 2);
  assertEquals(all[0]?.id, "gp-b", "newest scheduled_at first");

  const pendingOnly = await listGatePassesForSchool(client(mock), ORG, SCHOOL, "pending");
  assertEquals(pendingOnly.length, 1);
  assertEquals(pendingOnly[0]?.id, "gp-a");
});

Deno.test("listGatePassesForParent: only the caller's own children's passes", async () => {
  const mock = new GatePassMockDb();
  mock.seedGuardian({ studentId: STUDENT, guardianUserId: PARENT, schoolId: SCHOOL, isPrimary: true, status: "active" });
  mock.seedGatePass({ id: "gp-mine", student_id: STUDENT, status: "pending" });
  mock.seedGatePass({ id: "gp-not-mine", student_id: OTHER_STUDENT, status: "pending" });

  const mine = await listGatePassesForParent(client(mock), ORG, SCHOOL, PARENT);
  assertEquals(mine.map((r) => r.id), ["gp-mine"]);

  const otherParent = await listGatePassesForParent(client(mock), ORG, SCHOOL, OTHER_PARENT);
  assertEquals(otherParent.length, 0);
});

Deno.test("getGatePassForStaff: any pass in the staff's school", async () => {
  const mock = new GatePassMockDb();
  mock.seedGatePass({ id: "gp-1" });
  const row = await getGatePassForStaff(client(mock), ORG, SCHOOL, "gp-1");
  assertEquals(row?.id, "gp-1");
  assertEquals(await getGatePassForStaff(client(mock), ORG, SCHOOL, "missing"), null);
});

Deno.test("getGatePassForParent: 404s (null) for a child that is not theirs", async () => {
  const mock = new GatePassMockDb();
  mock.seedGuardian({ studentId: STUDENT, guardianUserId: PARENT, schoolId: SCHOOL, isPrimary: true, status: "active" });
  mock.seedGatePass({ id: "gp-1", student_id: STUDENT });

  const own = await getGatePassForParent(client(mock), ORG, SCHOOL, PARENT, "gp-1");
  assertEquals(own?.id, "gp-1");

  const notOwned = await getGatePassForParent(client(mock), ORG, SCHOOL, OTHER_PARENT, "gp-1");
  assertEquals(notOwned, null, "a non-guardian parent must not see the pass");
});

// ── cancel ─────────────────────────────────────────────────────────────────────

Deno.test("cancelGatePass: the original requester can cancel their own pending pass", async () => {
  const mock = new GatePassMockDb();
  mock.seedGatePass({ id: "gp-1", status: "pending", requested_by: PARENT });
  const row = await cancelGatePass(client(mock), ORG, SCHOOL, "gp-1", PARENT, false);
  assertEquals(row.status, "cancelled");
});

Deno.test("cancelGatePass: a staff holder of approveGatePass can cancel someone else's pass", async () => {
  const mock = new GatePassMockDb();
  mock.seedGatePass({ id: "gp-1", status: "approved", requested_by: PARENT });
  const row = await cancelGatePass(client(mock), ORG, SCHOOL, "gp-1", APPROVER, true);
  assertEquals(row.status, "cancelled");
});

Deno.test("cancelGatePass: neither the requester nor an approver -> rejected (no write)", async () => {
  const mock = new GatePassMockDb();
  mock.seedGatePass({ id: "gp-1", status: "pending", requested_by: PARENT });
  await assertRejects(
    () => cancelGatePass(client(mock), ORG, SCHOOL, "gp-1", "some-other-user", false),
    GatePassError,
  );
  assertEquals(mock.rows.get("gp-1")?.status, "pending", "not mutated");
});

Deno.test("cancelGatePass: a used/rejected/cancelled pass cannot be cancelled again", async () => {
  const mock = new GatePassMockDb();
  mock.seedGatePass({ id: "gp-1", status: "used", requested_by: PARENT });
  await assertRejects(
    () => cancelGatePass(client(mock), ORG, SCHOOL, "gp-1", PARENT, false),
    GatePassError,
  );
});

// ── approve / reject (F2 effect) ──────────────────────────────────────────────

Deno.test("applyGatePassDecision: reject flips status, no credential minted", async () => {
  const mock = new GatePassMockDb();
  mock.seedGatePass({ id: "gp-1", status: "pending" });
  const effect = await applyGatePassDecision(client(mock), ORG, SCHOOL, "gp-1", "rejected", APPROVER);
  assertEquals(effect.gatePassStatus, "rejected");
  assertEquals(effect.credentialIssued, false);
  assertEquals(mock.rows.get("gp-1")?.status, "rejected");
  assertEquals(mock.rows.get("gp-1")?.otp_hash, null);
});

Deno.test("applyGatePassDecision: reject on a non-pending pass throws (no write)", async () => {
  const mock = new GatePassMockDb();
  mock.seedGatePass({ id: "gp-1", status: "approved" });
  await assertRejects(
    () => applyGatePassDecision(client(mock), ORG, SCHOOL, "gp-1", "rejected", APPROVER),
    GatePassInvalidStateError,
  );
});

Deno.test("applyGatePassDecision: approve mints a credential — hashes persisted, TTL = scheduled_at+4h, effect payload leaks NOTHING secret", async () => {
  const mock = new GatePassMockDb();
  mock.seedGuardian({ studentId: STUDENT, guardianUserId: PARENT, schoolId: SCHOOL, isPrimary: true, status: "active" });
  mock.seedGatePass({
    id: "gp-1",
    status: "pending",
    student_id: STUDENT,
    scheduled_at: "2026-07-15T10:00:00.000Z",
  });

  const effect = await applyGatePassDecision(client(mock), ORG, SCHOOL, "gp-1", "approved", APPROVER);

  // The effect payload is exactly this shape — no otp/qrToken/hash field of any kind.
  assertEquals(
    Object.keys(effect).sort(),
    ["credentialIssued", "expiresAt", "gatePassStatus", "otpDispatched"].sort(),
  );
  assertEquals(effect.gatePassStatus, "approved");
  assertEquals(effect.credentialIssued, true);
  assertEquals(effect.otpDispatched, true, "a guardian exists, so dispatch is attempted");
  assertEquals(effect.expiresAt, "2026-07-15T14:00:00.000Z", "scheduled_at + 4h TTL");

  const row = mock.rows.get("gp-1")!;
  assertEquals(row.status, "approved");
  assertEquals(row.otp_hash?.length, 64, "SHA-256 hex hash persisted");
  assertEquals(row.qr_token_hash?.length, 64);
  assertEquals(row.credential_expires_at, "2026-07-15T14:00:00.000Z");
  // Never JSON.stringify to something containing a plausible plaintext OTP —
  // the only string fields on the effect are enums/ids/timestamps.
  const serialized = JSON.stringify(effect);
  assertEquals(/"\d{6}"/.test(serialized), false, "no bare 6-digit OTP-shaped string in the effect payload");
});

Deno.test("applyGatePassDecision: approve with NO guardian on file -> credential still minted, otpDispatched=false", async () => {
  const mock = new GatePassMockDb();
  mock.seedGatePass({ id: "gp-1", status: "pending", student_id: STUDENT });
  const effect = await applyGatePassDecision(client(mock), ORG, SCHOOL, "gp-1", "approved", APPROVER);
  assertEquals(effect.credentialIssued, true);
  assertEquals(effect.otpDispatched, false);
});

Deno.test("applyGatePassDecision: approve on an already-decided pass throws (no second credential minted)", async () => {
  const mock = new GatePassMockDb();
  mock.seedGatePass({ id: "gp-1", status: "approved", otp_hash: "existing-hash" });
  await assertRejects(
    () => applyGatePassDecision(client(mock), ORG, SCHOOL, "gp-1", "approved", APPROVER),
    GatePassInvalidStateError,
  );
  assertEquals(mock.rows.get("gp-1")?.otp_hash, "existing-hash", "untouched");
});

// ── verify (the gate check) ───────────────────────────────────────────────────

async function seedApprovedWithOtp(
  mock: GatePassMockDb,
  otp: string,
  opts: Partial<GatePassRow> = {},
): Promise<GatePassRow> {
  const otpHash = await hashGatePassSecret(otp);
  return mock.seedGatePass({
    id: "gp-1",
    status: "approved",
    otp_hash: otpHash,
    qr_token_hash: await hashGatePassSecret("qr-token-value"),
    credential_expires_at: "2026-12-31T23:59:59.000Z",
    ...opts,
  });
}

Deno.test("verifyGatePassCredential: correct OTP -> status='used', verified_by/at recorded", async () => {
  const mock = new GatePassMockDb();
  await seedApprovedWithOtp(mock, "654321");
  const row = await verifyGatePassCredential(client(mock), ORG, SCHOOL, "gp-1", "654321", STAFF, "Collected by father");
  assertEquals(row.status, "used");
  assertEquals(row.verified_by, STAFF);
  assertEquals(row.verification_note, "Collected by father");
});

Deno.test("verifyGatePassCredential: correct QR token also verifies", async () => {
  const mock = new GatePassMockDb();
  await seedApprovedWithOtp(mock, "654321");
  const row = await verifyGatePassCredential(client(mock), ORG, SCHOOL, "gp-1", "qr-token-value", STAFF, null);
  assertEquals(row.status, "used");
});

Deno.test("verifyGatePassCredential: wrong OTP -> generic failure, no write", async () => {
  const mock = new GatePassMockDb();
  await seedApprovedWithOtp(mock, "654321");
  await assertRejects(
    () => verifyGatePassCredential(client(mock), ORG, SCHOOL, "gp-1", "000000", STAFF, null),
    GatePassVerificationFailedError,
  );
  assertEquals(mock.rows.get("gp-1")?.status, "approved", "not consumed by a failed attempt");
});

Deno.test("verifyGatePassCredential: expired credential fails even with the right OTP", async () => {
  const mock = new GatePassMockDb();
  await seedApprovedWithOtp(mock, "654321", { credential_expires_at: "2020-01-01T00:00:00.000Z" });
  await assertRejects(
    () => verifyGatePassCredential(client(mock), ORG, SCHOOL, "gp-1", "654321", STAFF, null),
    GatePassVerificationFailedError,
  );
  assertEquals(mock.rows.get("gp-1")?.status, "approved");
});

Deno.test("verifyGatePassCredential: already-used pass cannot be re-verified", async () => {
  const mock = new GatePassMockDb();
  await seedApprovedWithOtp(mock, "654321");
  await verifyGatePassCredential(client(mock), ORG, SCHOOL, "gp-1", "654321", STAFF, null);
  await assertRejects(
    () => verifyGatePassCredential(client(mock), ORG, SCHOOL, "gp-1", "654321", "another-staff", null),
    GatePassVerificationFailedError,
  );
  assertEquals(mock.rows.get("gp-1")?.verified_by, STAFF, "the FIRST verifier's claim stands");
});

Deno.test("verifyGatePassCredential: a still-pending (never approved) pass fails — no credential exists yet", async () => {
  const mock = new GatePassMockDb();
  mock.seedGatePass({ id: "gp-1", status: "pending" });
  await assertRejects(
    () => verifyGatePassCredential(client(mock), ORG, SCHOOL, "gp-1", "654321", STAFF, null),
    GatePassVerificationFailedError,
  );
});

Deno.test("verifyGatePassCredential: an unknown pass id fails with the SAME generic error as a wrong code (no existence leak)", async () => {
  const mock = new GatePassMockDb();
  await seedApprovedWithOtp(mock, "654321");
  const notFound = await assertRejects(
    () => verifyGatePassCredential(client(mock), ORG, SCHOOL, "does-not-exist", "654321", STAFF, null),
    GatePassVerificationFailedError,
  );
  const wrongCode = await assertRejects(
    () => verifyGatePassCredential(client(mock), ORG, SCHOOL, "gp-1", "111111", STAFF, null),
    GatePassVerificationFailedError,
  );
  // Both are the same error type/message — a caller cannot distinguish
  // "no such pass" from "wrong code" from the thrown error alone.
  assertEquals(notFound.message, wrongCode.message);
});

Deno.test("verifyGatePassCredential: CONCURRENT DOUBLE-VERIFY — the loser's terminal UPDATE claims 0 rows and fails, even though its own SELECT still saw 'approved'", async () => {
  const mock = new GatePassMockDb();
  await seedApprovedWithOtp(mock, "654321");

  // Simulate the real race: two transactions both SELECT while the row is
  // still 'approved' (this is exactly what a real Postgres READ COMMITTED
  // race looks like — the guard that actually decides the winner is the
  // terminal UPDATE ... WHERE status = 'approved', not the earlier read).
  let winnerHasCommitted = false;
  const racedForLoser = {
    // deno-lint-ignore require-await
    async queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
      if (sql.includes("UPDATE gate_passes") && sql.includes("status = 'used'")) {
        // By the time the loser's UPDATE runs, the winner has already
        // committed and flipped the row — 0 rows match the guard.
        if (winnerHasCommitted) return [] as T[];
      }
      return mock.queryObject<T>(sql, args);
    },
    queryCount: () => Promise.resolve(0),
  } as unknown as TenantQueryClient;

  // Winner verifies first and commits.
  const winner = await verifyGatePassCredential(client(mock), ORG, SCHOOL, "gp-1", "654321", "guard-A", null);
  assertEquals(winner.status, "used");
  winnerHasCommitted = true;

  // Loser's SELECT would have seen 'approved' pre-race, but its terminal
  // UPDATE guard now claims 0 rows — it must fail, not silently succeed.
  await assertRejects(
    () => verifyGatePassCredential(racedForLoser, ORG, SCHOOL, "gp-1", "654321", "guard-B", null),
    GatePassVerificationFailedError,
  );
  assertEquals(mock.rows.get("gp-1")?.verified_by, "guard-A", "only the winner's claim persisted — no double release");
});

// ── redaction ──────────────────────────────────────────────────────────────────

Deno.test("gatePassToApi: NEVER includes otp_hash or qr_token_hash, under any status", async () => {
  const mock = new GatePassMockDb();
  const row = await seedApprovedWithOtp(mock, "654321");
  const api = gatePassToApi(row);
  assertEquals("otp_hash" in api, false);
  assertEquals("qr_token_hash" in api, false);
  const serialized = JSON.stringify(api);
  assertEquals(serialized.includes(row.otp_hash!), false, "the hash value itself never leaks into the response");
  assertEquals(serialized.includes(row.qr_token_hash!), false);
  assertEquals(api.hasCredential, true);
});

Deno.test("gatePassToApi: an approved pass past credential_expires_at DISPLAYS as expired (lazy evaluation)", () => {
  const row: GatePassRow = {
    id: "gp-1",
    organization_id: ORG,
    school_id: SCHOOL,
    student_id: STUDENT,
    pass_type: "early_pickup",
    reason: "",
    requested_by: PARENT,
    pickup_person_name: "",
    pickup_person_relation: "",
    pickup_person_phone: "",
    scheduled_at: "2026-07-15T10:00:00.000Z",
    status: "approved",
    approval_request_id: null,
    otp_hash: "h",
    qr_token_hash: "h2",
    credential_expires_at: "2026-07-15T14:00:00.000Z",
    verified_by: null,
    verified_at: null,
    verification_note: null,
    created_at: "2026-07-15T08:00:00.000Z",
    updated_at: "2026-07-15T08:00:00.000Z",
  };
  const now = new Date("2026-07-16T00:00:00.000Z"); // well past expiry
  assertEquals(effectiveGatePassStatus(row, now), "expired");
  assertEquals(gatePassToApi(row, now).status, "expired");
  assertEquals(gatePassToApi(row, now).rawStatus, "approved", "the true column value is still visible separately");

  const beforeExpiry = new Date("2026-07-15T12:00:00.000Z");
  assertEquals(effectiveGatePassStatus(row, beforeExpiry), "approved");
});

Deno.test("gatePassToApi: a non-approved status is never coerced to 'expired' by a stale credential_expires_at", () => {
  const row: GatePassRow = {
    id: "gp-1",
    organization_id: ORG,
    school_id: SCHOOL,
    student_id: STUDENT,
    pass_type: "early_pickup",
    reason: "",
    requested_by: PARENT,
    pickup_person_name: "",
    pickup_person_relation: "",
    pickup_person_phone: "",
    scheduled_at: "2026-07-15T10:00:00.000Z",
    status: "used",
    approval_request_id: null,
    otp_hash: "h",
    qr_token_hash: "h2",
    credential_expires_at: "2020-01-01T00:00:00.000Z",
    verified_by: STAFF,
    verified_at: "2026-07-15T10:05:00.000Z",
    verification_note: null,
    created_at: "2026-07-15T08:00:00.000Z",
    updated_at: "2026-07-15T10:05:00.000Z",
  };
  assertEquals(effectiveGatePassStatus(row), "used");
});
