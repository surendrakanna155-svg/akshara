// Living Dashboard Phase 5 — Copilot's view of the dashboard. Pure parts only
// (intent gate + persona mapping); the DB-backed loader is covered by the
// copilot route contract tests.

import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import {
  personaForCopilot,
  wantsDashboardContext,
} from "./copilot_dashboard_context.ts";

function claims(over: Partial<AccessTokenClaims> = {}): AccessTokenClaims {
  return {
    sub: "u1",
    tenant_id: "org-1",
    organization_id: "org-1",
    school_id: "school-1",
    role: "principal",
    role_slugs: ["principal"],
    primary_role: "principal",
    permissions: [],
    permissions_version: 1,
    scope: "school",
    school_group_id: null,
    student_id: null,
    child_ids: [],
    session_id: "s1",
    ...over,
  };
}

Deno.test("the mission's own example opens the dashboard slot", () => {
  // "User dismisses Transport Delay, later asks: show transport details"
  assert(wantsDashboardContext("show me transport details"));
});

Deno.test("questions about put-away work open the slot", () => {
  for (
    const q of [
      "what did I dismiss earlier?",
      "show my dashboard",
      "what are my priorities today",
      "anything I snoozed?",
      "which approvals are pending",
      "is anything overdue",
      "remind me what I hid",
    ]
  ) {
    assert(wantsDashboardContext(q), `should match: ${q}`);
  }
});

Deno.test("unrelated questions do NOT pay for a feed computation", () => {
  // The feed costs an analytics bundle + risk + ops worklists. A question that
  // is plainly not about the dashboard must not trigger that on every turn.
  for (
    const q of [
      "how do I add a new student?",
      "what is the fee structure for class 8?",
      "draft a message to parents about the sports day",
    ]
  ) {
    assert(!wantsDashboardContext(q), `should NOT match: ${q}`);
  }
});

Deno.test("persona mapping follows session scope first", () => {
  assertEquals(personaForCopilot(claims({ scope: "parent" })), "parent");
  assertEquals(
    personaForCopilot(claims({ scope: "student", student_id: "s" })),
    "student",
  );
});

Deno.test("staff roles map onto their feed persona", () => {
  assertEquals(personaForCopilot(claims({ primary_role: "principal" })), "principal");
  assertEquals(personaForCopilot(claims({ primary_role: "vicePrincipal" })), "principal");
  assertEquals(personaForCopilot(claims({ primary_role: "financeAdmin" })), "finance");
  assertEquals(personaForCopilot(claims({ primary_role: "teacher" })), "teacher");
  assertEquals(personaForCopilot(claims({ primary_role: "director" })), "director");
});

Deno.test("an unknown staff role reads the school feed, never a per-user one", () => {
  // Falling back to `admin` keeps the caller on the school-scoped sources,
  // whose own RBAC gates then decide what they actually see. Falling back to a
  // per-user persona would silently pick someone else's classes/children.
  assertEquals(personaForCopilot(claims({ primary_role: "librarian" })), "admin");
});
