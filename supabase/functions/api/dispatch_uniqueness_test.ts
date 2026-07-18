// PRA-N-14 (S0/T1b) — dispatch-uniqueness / route-shadowing guard.
//
// The dispatch loop in app.ts returns on the FIRST matching module router, so if
// two routers claim the same (method, path) the earlier one silently wins. That
// is exactly how PRA-P0-12 shipped: `pilot_operations_router` shadowed the
// governed `PUT /teacher/exams/marks/:id` in `teacher_router` and reached an
// UNSCOPED exam-mark handler. This test locks in the S0/T1a fix and fails if
// either known shadow is re-introduced.
//
// A router returns a non-null Response when it CLAIMS a path (a 401 here, since
// the requests are unauthenticated and rejected before any DB access) and null
// when it does not. Scope note: a fully generic cross-router scan would require
// exporting the `moduleRouters` array from app.ts; this focused guard covers the
// two paths that were actually shadowed plus the specific regression we fixed.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AppConfig } from "../_shared/config.ts";
import { routePilotOperations } from "../_shared/pilot/pilot_operations_router.ts";
import { routeTeacher } from "../_shared/teacher/teacher_router.ts";
import { routeCommunication } from "../_shared/communication/communication_router.ts";

const config = { jwtSecret: "test-jwt-secret-minimum-32-characters-long" } as AppConfig;

function req(method: string, path: string): Request {
  return new Request(`https://x${path}`, {
    method,
    headers: { "content-type": "application/json" },
    body: method === "GET" ? undefined : JSON.stringify({ marks_obtained: 1 }),
  });
}

// `null` = router does not claim the path. Any non-null Response = claims it.
async function claims(
  router: (r: Request, c: AppConfig, m: string, p: string) => Promise<Response | null>,
  method: string,
  path: string,
): Promise<boolean> {
  const res = await router(req(method, path), config, method, path);
  return res !== null;
}

Deno.test("PRA-P0-12: PUT /teacher/exams/marks/:id is NOT claimed by the pilot router", async () => {
  const method = "PUT";
  const path = "/teacher/exams/marks/00000000-0000-4000-8000-000000000001";
  // The pilot router must no longer match this path (the shadow was removed)...
  assertEquals(await claims(routePilotOperations, method, path), false);
  // ...and the governed teacher router must still own it, so dispatch reaches the
  // certified, subject-teacher-scoped exam engine.
  assertEquals(await claims(routeTeacher, method, path), true);
});

Deno.test("PRA-N-13: GET /teacher/messages is owned by communication, not the teacher router's dead handler", async () => {
  const method = "GET";
  const path = "/teacher/messages";
  // routeCommunication is dispatched before routeTeacher in app.ts, so it owns
  // this path via the governed handleTeacherMessageThreads. The dead teacher_router
  // handler was removed in S0/T1a.
  assertEquals(await claims(routeCommunication, method, path), true);
});
