import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { matchCommunicationRoute } from "./communication_router.ts";
import {
  handleBroadcastHistory,
  handleCreateTemplate,
  handleListTemplates,
  handleParentMessageThreads,
} from "./communication_handlers.ts";

// MJ-C6a / MJ-C6b / MJ-C3: the wire-gap 404s these routes used to return are
// closed by registering them in the communication router. This asserts the
// pure method+path -> handler resolution (no auth/DB) so a future refactor that
// drops a registration fails here instead of regressing to a 404.

Deno.test("MJ-C6a: POST /communications/templates routes to handleCreateTemplate", () => {
  const match = matchCommunicationRoute("POST", "/communications/templates");
  assert(match !== null, "POST /communications/templates must resolve");
  assertEquals(match!.handler, handleCreateTemplate);
});

Deno.test("MJ-C6a: GET /communications/templates still routes to the list handler", () => {
  const match = matchCommunicationRoute("GET", "/communications/templates");
  assert(match !== null);
  assertEquals(match!.handler, handleListTemplates);
});

Deno.test("MJ-C6b: GET /communications/broadcasts/history routes to handleBroadcastHistory", () => {
  const match = matchCommunicationRoute(
    "GET",
    "/communications/broadcasts/history",
  );
  assert(match !== null, "GET /communications/broadcasts/history must resolve");
  assertEquals(match!.handler, handleBroadcastHistory);
});

Deno.test("MJ-C3: GET /parent/messages aliases to handleParentMessageThreads", () => {
  const noSlash = matchCommunicationRoute("GET", "/parent/messages");
  assert(noSlash !== null, "GET /parent/messages must resolve (no trailing slash)");
  assertEquals(noSlash!.handler, handleParentMessageThreads);

  const withThreads = matchCommunicationRoute("GET", "/parent/messages/threads");
  assert(withThreads !== null);
  assertEquals(withThreads!.handler, handleParentMessageThreads);
});

Deno.test("unknown communication routes still return null (no false match)", () => {
  assertEquals(matchCommunicationRoute("DELETE", "/communications/templates"), null);
  assertEquals(matchCommunicationRoute("POST", "/communications/broadcasts/history"), null);
  assertEquals(matchCommunicationRoute("GET", "/communications/unknown"), null);
});

// MJ-C3: mirror the prefix guard in routeCommunication so the no-trailing-slash
// /parent/messages path is actually reached by the matcher (the guard strips a
// trailing slash from each prefix before the equality check).
Deno.test("MJ-C3: prefix guard catches /parent/messages without a trailing slash", () => {
  const commPaths = [
    "/communications/",
    "/parent/notifications",
    "/parent/device-tokens/",
    "/parent/messages/",
    "/student/notifications",
    "/student/device-tokens/",
    "/teacher/messages",
  ];
  const caught = (path: string) =>
    commPaths.some((prefix) =>
      path.startsWith(prefix) || path === prefix.replace(/\/$/, "")
    );
  assert(caught("/parent/messages"), "/parent/messages must pass the prefix guard");
  assert(caught("/parent/messages/threads"));
  assert(caught("/communications/broadcasts/history"));
});
