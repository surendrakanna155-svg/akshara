// P1-PROD-22 SLICE 1 — face_enrollment_repository.ts SQL-shape tests (DB-free).
// mockDb pattern follows the existing repository-test house style (e.g.
// ai_semantic_cache_repository_test.ts): a plain object cast to TenantQueryClient
// that records every call's SQL + args in order.

import { assert, assertEquals, assertThrows } from "jsr:@std/assert@1";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  type AttendanceAuthScope,
  enrollFace,
  FaceEnrollmentValidationError,
  getActiveEnrollment,
  revokeEnrollment,
  validateEmbedding,
} from "./face_enrollment_repository.ts";

function mockDb(
  responders: Array<{ match: string; rows: unknown[] }> = [],
): { db: TenantQueryClient; calls: Array<{ sql: string; args: unknown[] }> } {
  const calls: Array<{ sql: string; args: unknown[] }> = [];
  return {
    calls,
    db: {
      queryObject: <T>(sql: string, args: unknown[] = []): Promise<T[]> => {
        calls.push({ sql, args });
        const hit = responders.find((r) => sql.includes(r.match));
        return Promise.resolve((hit?.rows ?? []) as T[]);
      },
      // deno-lint-ignore no-explicit-any
    } as any as TenantQueryClient,
  };
}

const SCOPE: AttendanceAuthScope = { organizationId: "org-1", schoolId: "sch-1" };
const DIM64 = Array.from({ length: 64 }, (_, i) => i / 64);

// ─── validateEmbedding ────────────────────────────────────────────────────────

Deno.test("validateEmbedding: not an array → EMBEDDING_REQUIRED", () => {
  try {
    validateEmbedding("not-an-array");
    throw new Error("expected throw");
  } catch (e) {
    assert(e instanceof FaceEnrollmentValidationError);
    assertEquals(e.code, "EMBEDDING_REQUIRED");
  }
});

Deno.test("validateEmbedding: too short (<64) → EMBEDDING_DIMS_INVALID", () => {
  try {
    validateEmbedding(Array.from({ length: 63 }, () => 0.1));
    throw new Error("expected throw");
  } catch (e) {
    assert(e instanceof FaceEnrollmentValidationError);
    assertEquals(e.code, "EMBEDDING_DIMS_INVALID");
  }
});

Deno.test("validateEmbedding: too long (>1024) → EMBEDDING_DIMS_INVALID", () => {
  try {
    validateEmbedding(Array.from({ length: 1025 }, () => 0.1));
    throw new Error("expected throw");
  } catch (e) {
    assert(e instanceof FaceEnrollmentValidationError);
    assertEquals(e.code, "EMBEDDING_DIMS_INVALID");
  }
});

Deno.test("validateEmbedding: non-finite element → EMBEDDING_INVALID", () => {
  const bad = [...DIM64];
  bad[10] = NaN;
  try {
    validateEmbedding(bad);
    throw new Error("expected throw");
  } catch (e) {
    assert(e instanceof FaceEnrollmentValidationError);
    assertEquals(e.code, "EMBEDDING_INVALID");
  }
});

Deno.test("validateEmbedding: huge-magnitude values are rejected (would overflow float4 to Infinity → NaN cosine downstream)", () => {
  const bad = [...DIM64];
  bad[0] = 1e39;
  const e = assertThrows(() => validateEmbedding(bad), FaceEnrollmentValidationError);
  assertEquals((e as FaceEnrollmentValidationError).code, "EMBEDDING_INVALID");
  const bad2 = [...DIM64];
  bad2[10] = -1e7;
  assertThrows(() => validateEmbedding(bad2), FaceEnrollmentValidationError);
});

Deno.test("validateEmbedding: an all-zeros vector is rejected (can never match — would brick the user)", () => {
  const zeros = Array.from({ length: 64 }, () => 0);
  const e = assertThrows(() => validateEmbedding(zeros), FaceEnrollmentValidationError);
  assertEquals((e as FaceEnrollmentValidationError).code, "EMBEDDING_INVALID");
});

Deno.test("validateEmbedding: a near-zero vector whose L2 norm underflows to 0 is rejected the same way (R2 P3)", () => {
  const tiny = Array.from({ length: 64 }, () => 1e-200);
  const e = assertThrows(() => validateEmbedding(tiny), FaceEnrollmentValidationError);
  assertEquals((e as FaceEnrollmentValidationError).code, "EMBEDDING_INVALID");
});

Deno.test("validateEmbedding: boundary dims (64 and 1024) are accepted", () => {
  assertEquals(validateEmbedding(DIM64).length, 64);
  assertEquals(validateEmbedding(Array.from({ length: 1024 }, () => 0.5)).length, 1024);
});

Deno.test("validateEmbedding: coerces numeric-string elements to numbers", () => {
  const mixed = DIM64.map((v) => v.toString());
  const parsed = validateEmbedding(mixed);
  assertEquals(parsed[0], 0);
  assertEquals(typeof parsed[0], "number");
});

// ─── getActiveEnrollment ───────────────────────────────────────────────────────

Deno.test("getActiveEnrollment: no active row → null", async () => {
  const { db } = mockDb([]);
  const result = await getActiveEnrollment(db, SCOPE, "u1");
  assertEquals(result, null);
});

Deno.test("getActiveEnrollment: maps the row, scopes by org+school+user+status=active", async () => {
  const { db, calls } = mockDb([
    {
      match: "FROM staff_face_enrollments",
      rows: [{
        id: "face_enr_1",
        user_id: "u1",
        embedding: [0.1, 0.2],
        embedding_dims: 2,
        model_tag: "mobilefacenet-v1",
        enrolled_by: "u1",
        created_at: "2026-07-01T00:00:00Z",
        updated_at: "2026-07-01T00:00:00Z",
      }],
    },
  ]);
  const result = await getActiveEnrollment(db, SCOPE, "u1");
  assertEquals(result, {
    id: "face_enr_1",
    userId: "u1",
    embedding: [0.1, 0.2],
    embeddingDims: 2,
    modelTag: "mobilefacenet-v1",
    enrolledBy: "u1",
    createdAt: "2026-07-01T00:00:00Z",
    updatedAt: "2026-07-01T00:00:00Z",
  });
  assertEquals(calls.length, 1);
  assert(calls[0]!.sql.includes("status = 'active'"));
  assertEquals(calls[0]!.args, ["org-1", "sch-1", "u1"]);
});

// ─── enrollFace ────────────────────────────────────────────────────────────────

Deno.test("enrollFace: revoke-then-insert order — UPDATE (revoke) runs strictly BEFORE the INSERT", async () => {
  const { db, calls } = mockDb([
    {
      match: "INSERT INTO staff_face_enrollments",
      rows: [{
        id: "face_enr_new",
        user_id: "u1",
        embedding: DIM64,
        embedding_dims: 64,
        model_tag: "",
        enrolled_by: "u1",
        created_at: "2026-07-10T00:00:00Z",
        updated_at: "2026-07-10T00:00:00Z",
      }],
    },
  ]);
  await enrollFace(db, SCOPE, { userId: "u1", embedding: DIM64, enrolledBy: "u1" });

  assertEquals(calls.length, 2, "exactly one UPDATE then one INSERT");
  assert(calls[0]!.sql.includes("UPDATE staff_face_enrollments"), "call 0 must be the revoke UPDATE");
  assert(calls[0]!.sql.includes("status = 'revoked'"));
  assert(calls[0]!.sql.includes("status = 'active'"), "the WHERE must target only the currently-active row");
  assert(calls[1]!.sql.includes("INSERT INTO staff_face_enrollments"), "call 1 must be the INSERT");
  assert(calls[1]!.sql.includes("'active'"));
});

Deno.test("enrollFace: the revoke UPDATE and the INSERT are scoped to the same org+school+user", async () => {
  const { db, calls } = mockDb([
    {
      match: "INSERT INTO staff_face_enrollments",
      rows: [{
        id: "face_enr_new",
        user_id: "u1",
        embedding: DIM64,
        embedding_dims: 64,
        model_tag: "model-x",
        enrolled_by: "hr-1",
        created_at: "2026-07-10T00:00:00Z",
        updated_at: "2026-07-10T00:00:00Z",
      }],
    },
  ]);
  await enrollFace(db, SCOPE, {
    userId: "u1",
    embedding: DIM64,
    modelTag: "model-x",
    enrolledBy: "hr-1",
  });

  assertEquals(calls[0]!.args, ["org-1", "sch-1", "u1", "hr-1"]);
  const insertArgs = calls[1]!.args;
  assertEquals(insertArgs[1], "org-1");
  assertEquals(insertArgs[2], "sch-1");
  assertEquals(insertArgs[3], "u1");
  assertEquals(insertArgs[4], DIM64);
  assertEquals(insertArgs[5], 64);
  assertEquals(insertArgs[6], "model-x");
  assertEquals(insertArgs[7], "hr-1");
});

Deno.test("enrollFace: returns the mapped inserted row", async () => {
  const { db } = mockDb([
    {
      match: "INSERT INTO staff_face_enrollments",
      rows: [{
        id: "face_enr_new",
        user_id: "u1",
        embedding: DIM64,
        embedding_dims: 64,
        model_tag: "",
        enrolled_by: "u1",
        created_at: "2026-07-10T00:00:00Z",
        updated_at: "2026-07-10T00:00:00Z",
      }],
    },
  ]);
  const result = await enrollFace(db, SCOPE, { userId: "u1", embedding: DIM64, enrolledBy: "u1" });
  assertEquals(result.id, "face_enr_new");
  assertEquals(result.embeddingDims, 64);
});

Deno.test("enrollFace: an invalid embedding is rejected BEFORE any DB call", async () => {
  const { db, calls } = mockDb([]);
  try {
    await enrollFace(db, SCOPE, { userId: "u1", embedding: [1, 2, 3], enrolledBy: "u1" });
    throw new Error("expected throw");
  } catch (e) {
    assert(e instanceof FaceEnrollmentValidationError);
    assertEquals(e.code, "EMBEDDING_DIMS_INVALID");
  }
  assertEquals(calls.length, 0, "no revoke/insert should run for an invalid payload");
});

// ─── revokeEnrollment ───────────────────────────────────────────────────────────

Deno.test("revokeEnrollment: an active row is revoked (never deleted) and its id returned", async () => {
  const { db, calls } = mockDb([
    { match: "UPDATE staff_face_enrollments", rows: [{ id: "face_enr_1" }] },
  ]);
  const result = await revokeEnrollment(db, SCOPE, "u1", "hr-1");
  assertEquals(result, { id: "face_enr_1" });
  assertEquals(calls.length, 1);
  assert(calls[0]!.sql.includes("status = 'revoked'"));
  assert(!calls[0]!.sql.toUpperCase().includes("DELETE"), "revocation must never DELETE the row");
  assertEquals(calls[0]!.args, ["org-1", "sch-1", "u1", "hr-1"]);
});

Deno.test("revokeEnrollment: nothing active to revoke → null", async () => {
  const { db } = mockDb([{ match: "UPDATE staff_face_enrollments", rows: [] }]);
  const result = await revokeEnrollment(db, SCOPE, "u1", "hr-1");
  assertEquals(result, null);
});
