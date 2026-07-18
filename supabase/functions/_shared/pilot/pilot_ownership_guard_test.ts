// PRA-P0-11 (S3) — the pilot write lane's per-class OWNERSHIP guard.
//
// The honest coverage gap that let the hole ship: pilot_rbac_gate_test asserts
// only PERMISSION (markAttendance / manageHomework) + scope, never that the
// caller actually teaches the class. These tests pin the ownership contract:
//   • a plain teacher (no verifyExamResults) writing to a class they are NOT
//     bound to is rejected (ClassOwnershipError → 403 at the handler);
//   • a plain teacher bound to the class is allowed;
//   • an oversight role (holds verifyExamResults) bypasses the check entirely
//     (the DB is never even queried), matching the exam engine's
//     isSubjectTeacherScoped.

import { assert, assertEquals, assertRejects } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  assertTeacherOwnsClass,
  assertTeacherOwnsClassSubject,
  assertTeacherOwnsHomework,
  ClassOwnershipError,
} from "./pilot_operations_repository.ts";

const ORG = "org";
const SCHOOL = "school";
const TEACHER = "11111111-1111-4111-8111-111111111111";
const PLAIN: string[] = ["markAttendance", "manageHomework"];
const OVERSIGHT: string[] = ["markAttendance", "verifyExamResults"];

/** DB mock: the canonical-ownership `SELECT (...) AS owns` returns `owns`; counts calls. */
function mockOwns(owns: boolean, counter: { n: number }): TenantQueryClient {
  return {
    // deno-lint-ignore require-await
    queryObject: async <T>() => {
      counter.n++;
      return [{ owns } as unknown as T];
    },
  } as unknown as TenantQueryClient;
}

Deno.test("PRA-P0-11: plain teacher NOT bound to the class is rejected (attendance)", async () => {
  const counter = { n: 0 };
  await assertRejects(
    () => assertTeacherOwnsClass(mockOwns(false, counter), ORG, SCHOOL, TEACHER, PLAIN, "8-A"),
    ClassOwnershipError,
  );
  assertEquals(counter.n, 1, "ownership must be checked against the DB for a plain teacher");
});

Deno.test("PRA-P0-11: plain teacher bound to the class is allowed (attendance)", async () => {
  const counter = { n: 0 };
  await assertTeacherOwnsClass(mockOwns(true, counter), ORG, SCHOOL, TEACHER, PLAIN, "8-A");
  assertEquals(counter.n, 1);
});

Deno.test("PRA-P0-11: oversight role (verifyExamResults) bypasses the check (no DB query)", async () => {
  const counter = { n: 0 };
  // owns=false in the mock, but the guard must NOT even query for an oversight caller.
  await assertTeacherOwnsClass(mockOwns(false, counter), ORG, SCHOOL, TEACHER, OVERSIGHT, "8-A");
  assertEquals(counter.n, 0, "oversight must bypass the ownership DB query entirely");
});

Deno.test("PRA-P0-11: plain teacher NOT teaching the (class, subject) is rejected (homework)", async () => {
  const counter = { n: 0 };
  const err = await assertRejects(
    () =>
      assertTeacherOwnsClassSubject(
        mockOwns(false, counter),
        ORG,
        SCHOOL,
        TEACHER,
        PLAIN,
        "8-A",
        "Mathematics",
      ),
    ClassOwnershipError,
  );
  assert(err.message.includes("8-A"));
  assertEquals(counter.n, 1);
});

Deno.test("PRA-P0-11: plain teacher teaching the (class, subject) is allowed (homework)", async () => {
  const counter = { n: 0 };
  await assertTeacherOwnsClassSubject(
    mockOwns(true, counter),
    ORG,
    SCHOOL,
    TEACHER,
    PLAIN,
    "8-A",
    "Mathematics",
  );
  assertEquals(counter.n, 1);
});

Deno.test("PRA-P0-11: oversight bypasses homework ownership too (no DB query)", async () => {
  const counter = { n: 0 };
  await assertTeacherOwnsClassSubject(
    mockOwns(false, counter),
    ORG,
    SCHOOL,
    TEACHER,
    OVERSIGHT,
    "8-A",
    "Mathematics",
  );
  assertEquals(counter.n, 0);
});

// --- review/grade path (reviewHomework / bulkReviewHomework / notify) ---

Deno.test("PRA-P0-11: plain teacher grading a homework they DON'T own is rejected", async () => {
  const counter = { n: 0 };
  await assertRejects(
    () => assertTeacherOwnsHomework(mockOwns(false, counter), ORG, SCHOOL, TEACHER, PLAIN, "hw_x"),
    ClassOwnershipError,
  );
  assertEquals(counter.n, 1);
});

Deno.test("PRA-P0-11: plain teacher grading their OWN homework is allowed", async () => {
  const counter = { n: 0 };
  await assertTeacherOwnsHomework(mockOwns(true, counter), ORG, SCHOOL, TEACHER, PLAIN, "hw_x");
  assertEquals(counter.n, 1);
});

Deno.test("PRA-P0-11: oversight bypasses homework-grade ownership (no DB query)", async () => {
  const counter = { n: 0 };
  await assertTeacherOwnsHomework(mockOwns(false, counter), ORG, SCHOOL, TEACHER, OVERSIGHT, "hw_x");
  assertEquals(counter.n, 0);
});
