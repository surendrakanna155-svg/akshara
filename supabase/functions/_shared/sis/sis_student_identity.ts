// Akshara Identity Platform — the single SIS-owned writer of the STUDENT
// identity table (`students`) and its identity profile (`student_profiles`).
//
// ICA-F2 (Architecture): before this module the `students` identity table had
// THREE independent writers (SIS enrolment, admissions enrolment, onboarding
// import/placeholder), each with its own inline `INSERT INTO students`, its own
// column set, and inconsistent identity rules — admissions in particular minted
// a base row with NO Public Student ID. This module centralises the identity
// writes so the frozen Student Identity Architecture (Public Student ID
// `<SCHOOL_CODE>-<NNNN>`, UUID = only PK, admission_number separate + set-once)
// is enforced in ONE place. Callers still own their flow-specific student_code
// scheme (a frozen id, per-flow), guardian/enrolment wiring, and idempotency
// orchestration — but the identity-table rows themselves are written here.
//
// This module does NOT change any identity FORMAT; it only removes the
// duplication and closes the no-PSID base-row gap.

import type { TenantQueryClient } from "../tenant_db.ts";
import { allocatePublicStudentId } from "./sis_public_student_id.ts";

/** Fields for the canonical `students` identity-table row. */
export interface StudentIdentityRowInput {
  /** Per-flow student_code (frozen id: SIS MAX+1, admissions/import/placeholder schemes). */
  studentCode: string;
  displayName: string;
  /** DB status; defaults to 'active' (matches the `students.status` column default). */
  status?: string | null;
  createdBy?: string | null;
  userId?: string | null;
  isPlaceholder?: boolean;
  /** Masked Aadhaar (`XXXXXXXX1234`) — never the raw value. */
  aadhaarMasked?: string | null;
  /** sha256 hex of the Aadhaar (dedupe only). */
  aadhaarHash?: string | null;
  /**
   * When true, emit `ON CONFLICT (school_id, student_code) DO NOTHING` so a
   * duplicate deterministic code (placeholder idempotency) returns null instead
   * of raising. When false (default), a real duplicate propagates to the caller
   * (e.g. the SIS retry-on-conflict loop).
   */
  reuseOnStudentCodeConflict?: boolean;
}

/**
 * THE sole writer of the `students` identity table. Emits the canonical column
 * set with the same effective values every caller relied on (omitted columns
 * fall back to their previous DB defaults: user_id/created_by/aadhaar* NULL,
 * is_placeholder false, status 'active').
 *
 * Returns the new `{ id }`, or `null` ONLY when `reuseOnStudentCodeConflict` is
 * set and an existing row won the `ON CONFLICT` (the caller then fetches the
 * winner). Runs inside the caller's transaction/tenant scope (RLS enforced by
 * the school-scoped connection, unchanged).
 */
export async function insertStudentIdentityRow(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  input: StudentIdentityRowInput,
): Promise<{ id: string } | null> {
  const onConflict = input.reuseOnStudentCodeConflict
    ? "ON CONFLICT (school_id, student_code) DO NOTHING"
    : "";
  const rows = await db.queryObject<{ id: string }>(
    `INSERT INTO students (
      organization_id, school_id, student_code, display_name, status,
      created_by, user_id, is_placeholder, aadhaar, aadhaar_hash
    ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
    ${onConflict}
    RETURNING id`,
    [
      organizationId,
      schoolId,
      input.studentCode,
      input.displayName,
      input.status ?? "active",
      input.createdBy ?? null,
      input.userId ?? null,
      input.isPlaceholder ?? false,
      input.aadhaarMasked ?? null,
      input.aadhaarHash ?? null,
    ],
  );
  return rows[0] ?? null;
}

/** Fields for the canonical `student_profiles` identity row (PSID + admission#). */
export interface StudentProfileIdentityInput {
  admissionNumber: string;
  dateOfBirth?: string | null;
  gender?: string | null;
  bloodGroup?: string | null;
  address?: string | null;
  city?: string | null;
  state?: string | null;
  postalCode?: string | null;
  country?: string | null;
  motherName?: string | null;
  createdBy?: string | null;
  /**
   * When true, emit `ON CONFLICT (student_id) DO NOTHING` (placeholder / retry
   * idempotency: a profile already exists for the student). `inserted` reports
   * whether a row was actually written.
   */
  reuseOnStudentConflict?: boolean;
}

/**
 * THE sole allocator of the canonical Public Student ID and writer of the
 * `student_profiles` identity row. Allocates the never-reused, never-gapped,
 * per-school `<SCHOOL_CODE>-<NNNN>` PSID (set-once) via {@link allocatePublicStudentId}
 * and inserts the profile with the canonical column set. Fails loudly (school
 * has no code) exactly as before, because the PSID requires it.
 *
 * Returns the allocated `publicStudentId` and whether a profile row was written
 * (`inserted` = false only on an `ON CONFLICT` no-op). Any DB error (e.g. a
 * duplicate admission_number unique violation) propagates unchanged so the
 * caller can map it to its domain error.
 */
export async function allocateAndInsertStudentProfile(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  studentId: string,
  input: StudentProfileIdentityInput,
): Promise<{ publicStudentId: string; inserted: boolean }> {
  const publicStudentId = await allocatePublicStudentId(db, organizationId, schoolId);
  const onConflict = input.reuseOnStudentConflict
    ? "ON CONFLICT (student_id) DO NOTHING"
    : "";
  const rows = await db.queryObject<{ id: string }>(
    `INSERT INTO student_profiles (
      organization_id, school_id, student_id, admission_number, public_student_id,
      date_of_birth, gender, blood_group, address, city, state, postal_code, country,
      mother_name, created_by
    ) VALUES (
      $1, $2, $3, $4, $5,
      $6::date, $7, $8, $9, $10, $11, $12, $13,
      $14, $15
    )
    ${onConflict}
    RETURNING id`,
    [
      organizationId,
      schoolId,
      studentId,
      input.admissionNumber,
      publicStudentId,
      input.dateOfBirth ?? null,
      input.gender ?? null,
      input.bloodGroup ?? null,
      input.address ?? null,
      input.city ?? null,
      input.state ?? null,
      input.postalCode ?? null,
      input.country ?? null,
      input.motherName ?? null,
      input.createdBy ?? null,
    ],
  );
  return { publicStudentId, inserted: rows.length > 0 };
}
