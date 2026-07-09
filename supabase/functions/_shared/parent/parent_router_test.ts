import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { matchParentRoute } from "./parent_router.ts";

// ─── MJ-H12 — parent leave ───────────────────────────────────────────────────

Deno.test("parent router does NOT claim POST /parent/leave (pilot-ops owns it)", () => {
  // POST /parent/leave is served by routePilotOperations (it writes the canonical
  // mobile_leave_requests row the school/HR side reads). routeParent must not
  // shadow it; the Wave-2 fix is on the READ side instead.
  const match = matchParentRoute("POST", "/parent/leave");
  assertEquals(match, null);
});

Deno.test("parent router GET /parent/leave overlays real leave rows", () => {
  const match = matchParentRoute("GET", "/parent/leave");
  // handleLeave now reads mobile_leave_requests via handleLeaveRequests so the
  // submitted leave is visible to the parent.
  assertEquals(match?.handler.name, "handleLeave");
});

// ─── MJ-C3 — parent communication inbox ──────────────────────────────────────

Deno.test("parent router matches GET /parent/communication/inbox", () => {
  const match = matchParentRoute("GET", "/parent/communication/inbox");
  assertEquals(match?.handler.name, "handleCommunicationInbox");
});

Deno.test("parent router matches GET /parent/communication/:id", () => {
  const match = matchParentRoute("GET", "/parent/communication/comm-123");
  // Dynamic handlers are wrapped in a closure; assert it resolves (not null).
  assertEquals(typeof match?.handler, "function");
});

Deno.test("inbox is not shadowed by the dynamic communication route", () => {
  // The literal /inbox path must bind the list handler, not the by-id closure.
  const match = matchParentRoute("GET", "/parent/communication/inbox");
  assertEquals(match?.handler.name, "handleCommunicationInbox");
});

// GAP-P1-8 — parent communication read/acknowledge (consent can never be
// acknowledged without these; the client posts here — see
// parent_communication_inbox_provider.dart's markParentCommunicationRead /
// acknowledgeParentCommunication — but no route matched before this fix).

Deno.test("GAP-P1-8: parent router matches POST /parent/communication/:id/read", () => {
  const match = matchParentRoute("POST", "/parent/communication/comm-123/read");
  assertEquals(typeof match?.handler, "function");
});

Deno.test("GAP-P1-8: parent router matches POST /parent/communication/:id/acknowledge", () => {
  const match = matchParentRoute("POST", "/parent/communication/comm-123/acknowledge");
  assertEquals(typeof match?.handler, "function");
});

Deno.test("GAP-P1-8: read/acknowledge do not shadow other communication paths", () => {
  // A bare id (no /read or /acknowledge suffix) is a GET-only resource, so a
  // POST to it must NOT match either handler.
  assertEquals(matchParentRoute("POST", "/parent/communication/comm-123"), null);
  // Distinct resource from the communication-delivery-receipt ack, which the
  // communication router owns at /communications/notifications/:id/acknowledge.
  assertEquals(
    matchParentRoute("POST", "/communications/notifications/comm-123/acknowledge"),
    null,
  );
});

// ─── MJ-C4 — parent meetings / PTM ───────────────────────────────────────────

Deno.test("parent router matches GET /parent/meetings", () => {
  const match = matchParentRoute("GET", "/parent/meetings");
  assertEquals(match?.handler.name, "handleListMeetings");
});

Deno.test("parent router matches POST /parent/meetings/:id/rsvp", () => {
  const match = matchParentRoute("POST", "/parent/meetings/pm_1/rsvp");
  assertEquals(typeof match?.handler, "function");
});

// ─── Negative / regression ───────────────────────────────────────────────────

Deno.test("parent router does not match unrelated paths", () => {
  assertEquals(matchParentRoute("GET", "/sis/students"), null);
  assertEquals(matchParentRoute("DELETE", "/parent/leave"), null);
  // /parent/messages is owned by the communication router, not here.
  assertEquals(matchParentRoute("GET", "/parent/messages"), null);
  // RSVP requires the trailing segment.
  assertEquals(matchParentRoute("POST", "/parent/meetings/pm_1"), null);
});
