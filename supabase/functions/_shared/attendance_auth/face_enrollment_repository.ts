// P1-PROD-22 SLICE 1 — Staff Face ID enrollment repository.
//
// docs/ATTENDANCE_AUTH_DESIGN_DECISION.md §7: a reference face is an EMBEDDING
// (a float vector, never a raw image) stored per (org, school, user),
// replaceable, ONE active enrollment at a time. Migration 20260877 evolves
// staff_face_enrollments (created in 20260820) to this governed shape — see its
// header for why this is an ALTER of a pre-existing table, not a fresh CREATE.

import type { TenantQueryClient } from "../tenant_db.ts";

/** Every query here is explicitly school-scoped (never relies solely on the
 * app_current_*() RLS GUCs) so an HR-managed write for ANOTHER user in the same
 * school binds the correct school without depending on session state. */
export interface AttendanceAuthScope {
  organizationId: string;
  schoolId: string;
}

const MIN_EMBEDDING_DIMS = 64;
const MAX_EMBEDDING_DIMS = 1024;

/** Per-value magnitude cap. Real face embeddings are unit-scale (|v| ≲ 1);
 * anything huge is garbage — and values ≥ ~3.4e38 would overflow the float4
 * column to Infinity, making every later cosine read NaN. Rejecting here keeps
 * non-finite values out of the database entirely. */
const MAX_EMBEDDING_VALUE = 1e6;

export class FaceEnrollmentValidationError extends Error {
  readonly code: string;
  constructor(code: string, message: string) {
    super(message);
    this.name = "FaceEnrollmentValidationError";
    this.code = code;
  }
}

/** Validates shape (array, in-bounds length, every element a finite number) —
 * mirrors the embedding_dims CHECK (64..1024) so a bad payload 422s before any
 * DB round-trip. Returns the embedding coerced to `number[]`. */
export function validateEmbedding(embedding: unknown): number[] {
  if (!Array.isArray(embedding)) {
    throw new FaceEnrollmentValidationError(
      "EMBEDDING_REQUIRED",
      "embedding (a live-capture face vector) is required",
    );
  }
  if (embedding.length < MIN_EMBEDDING_DIMS || embedding.length > MAX_EMBEDDING_DIMS) {
    throw new FaceEnrollmentValidationError(
      "EMBEDDING_DIMS_INVALID",
      `embedding must have between ${MIN_EMBEDDING_DIMS} and ${MAX_EMBEDDING_DIMS} dimensions`,
    );
  }
  const values = embedding.map((v) => {
    const n = Number(v);
    if (!Number.isFinite(n) || Math.abs(n) > MAX_EMBEDDING_VALUE) {
      throw new FaceEnrollmentValidationError(
        "EMBEDDING_INVALID",
        "embedding values must all be finite numbers of sane magnitude",
      );
    }
    return n;
  });
  // A zero-magnitude reference can never match anything (cosine fails closed
  // to 0) — accepting it would permanently brick the user's check-in until a
  // re-enrol. Test the squared L2 norm rather than the raw values so a
  // near-zero vector whose norm UNDERFLOWS to 0 (e.g. all ~1e-200) is rejected
  // the same way as literal zeros — cosine computes this exact sum.
  if (values.reduce((sum, v) => sum + v * v, 0) === 0) {
    throw new FaceEnrollmentValidationError(
      "EMBEDDING_INVALID",
      "embedding must not be a zero-magnitude vector",
    );
  }
  return values;
}

export interface FaceEnrollmentRow {
  id: string;
  userId: string;
  embedding: number[];
  embeddingDims: number;
  modelTag: string;
  enrolledBy: string | null;
  createdAt: string;
  updatedAt: string;
}

interface EnrollmentSqlRow {
  id: string;
  user_id: string;
  embedding: number[];
  embedding_dims: number;
  model_tag: string;
  enrolled_by: string | null;
  created_at: string;
  updated_at: string;
}

function fromSqlRow(r: EnrollmentSqlRow): FaceEnrollmentRow {
  return {
    id: r.id,
    userId: r.user_id,
    // embedding is stored as REAL[]; the driver returns it as a parsed number array.
    embedding: Array.isArray(r.embedding) ? r.embedding.map(Number) : [],
    embeddingDims: Number(r.embedding_dims),
    modelTag: r.model_tag,
    enrolledBy: r.enrolled_by,
    createdAt: r.created_at,
    updatedAt: r.updated_at,
  };
}

const ENROLLMENT_COLUMNS =
  `id, user_id, embedding, embedding_dims, model_tag, enrolled_by, created_at, updated_at`;

/** The caller's own (or, for an HR-managed lookup, a named target's) currently
 * ACTIVE enrollment — null when none exists. Never surfaces a revoked row. */
export async function getActiveEnrollment(
  db: TenantQueryClient,
  scope: AttendanceAuthScope,
  userId: string,
): Promise<FaceEnrollmentRow | null> {
  const rows = await db.queryObject<EnrollmentSqlRow>(
    `SELECT ${ENROLLMENT_COLUMNS}
       FROM staff_face_enrollments
      WHERE organization_id = $1 AND school_id = $2 AND user_id = $3 AND status = 'active'
      LIMIT 1`,
    [scope.organizationId, scope.schoolId, userId],
  );
  const r = rows[0];
  return r ? fromSqlRow(r) : null;
}

export interface EnrollFaceInput {
  userId: string;
  embedding: unknown;
  modelTag?: string;
  enrolledBy: string;
}

/**
 * Enrol (or REPLACE) `userId`'s reference face. Replace semantics, in order:
 *   1. UPDATE any prior active enrollment for this (org, school, user) to
 *      'revoked' first,
 *   2. THEN INSERT the new 'active' row.
 * That order matters: it is what keeps the partial unique index
 * (one active row per org+school+user) satisfied even mid-transaction, and it
 * is asserted explicitly by face_enrollment_repository_test.ts.
 */
export async function enrollFace(
  db: TenantQueryClient,
  scope: AttendanceAuthScope,
  input: EnrollFaceInput,
): Promise<FaceEnrollmentRow> {
  const embedding = validateEmbedding(input.embedding);
  const modelTag = input.modelTag ?? "";

  await db.queryObject(
    `UPDATE staff_face_enrollments
        SET status = 'revoked', revoked_at = timezone('utc', now()), revoked_by = $4,
            updated_at = timezone('utc', now())
      WHERE organization_id = $1 AND school_id = $2 AND user_id = $3 AND status = 'active'`,
    [scope.organizationId, scope.schoolId, input.userId, input.enrolledBy],
  );

  const id = `face_enr_${crypto.randomUUID()}`;
  try {
    const rows = await db.queryObject<EnrollmentSqlRow>(
      `INSERT INTO staff_face_enrollments (
         id, organization_id, school_id, user_id, embedding, embedding_dims,
         model_tag, enrolled_by, status
       ) VALUES ($1,$2,$3,$4,$5::real[],$6,$7,$8,'active')
       RETURNING ${ENROLLMENT_COLUMNS}`,
      [
        id,
        scope.organizationId,
        scope.schoolId,
        input.userId,
        embedding,
        embedding.length,
        modelTag,
        input.enrolledBy,
      ],
    );
    return fromSqlRow(rows[0]!);
  } catch (err) {
    // Two overlapping enrolls for the same user both pass the revoke step,
    // then the second INSERT trips the one-active-per-user partial unique
    // index — surface it as a typed conflict, not a raw 500.
    const msg = err instanceof Error ? err.message : String(err);
    if (msg.includes("idx_staff_face_active") || msg.includes("duplicate key")) {
      throw new FaceEnrollmentValidationError(
        "ENROLLMENT_CONFLICT",
        "Another enrolment for this user just completed — retry to replace it",
      );
    }
    throw err;
  }
}

/**
 * Revokes `userId`'s active enrollment (status -> 'revoked'; the row is kept as
 * an audit record, never deleted). Returns the revoked enrollment's id, or null
 * when there was nothing active to revoke.
 */
export async function revokeEnrollment(
  db: TenantQueryClient,
  scope: AttendanceAuthScope,
  userId: string,
  revokedBy: string,
): Promise<{ id: string } | null> {
  const rows = await db.queryObject<{ id: string }>(
    `UPDATE staff_face_enrollments
        SET status = 'revoked', revoked_at = timezone('utc', now()), revoked_by = $4,
            updated_at = timezone('utc', now())
      WHERE organization_id = $1 AND school_id = $2 AND user_id = $3 AND status = 'active'
      RETURNING id`,
    [scope.organizationId, scope.schoolId, userId, revokedBy],
  );
  const r = rows[0];
  return r ? { id: r.id } : null;
}
