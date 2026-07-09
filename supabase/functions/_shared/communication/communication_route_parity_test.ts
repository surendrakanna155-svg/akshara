import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { matchCommunicationRoute } from "./communication_router.ts";
import {
  handleBroadcastHistory,
  handleCreateTemplate,
  handleListTemplates,
  handleParentMessageThreads,
  handleParentSendMessage,
  handleUpdateTemplate,
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

Deno.test("MJ-M12: PUT /communications/templates/:id routes to handleUpdateTemplate", () => {
  const match = matchCommunicationRoute(
    "PUT",
    "/communications/templates/3f1a2b3c-4d5e-6f70-8190-a1b2c3d4e5f6",
  );
  assert(match !== null, "PUT /communications/templates/:id must resolve");
  assertEquals(match!.handler, handleUpdateTemplate);
});

Deno.test("MJ-M12: PUT on the templates collection (no id) does NOT match", () => {
  // The collection path only accepts GET/POST; only an item path accepts PUT.
  assertEquals(matchCommunicationRoute("PUT", "/communications/templates"), null);
  // A nested path under an item is not an editable template item.
  assertEquals(
    matchCommunicationRoute("PUT", "/communications/templates/x/y"),
    null,
  );
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

// GAP-P1-7: the client posts a reply to /parent/messages (ParentApiPaths.messages
// in parent_remote_datasource.dart's sendMessage); only /parent/messages/send
// was registered, so a real parent->teacher reply 404'd silently (the client
// swallows the error). Both paths must resolve to the send handler.
Deno.test("GAP-P1-7: POST /parent/messages aliases to handleParentSendMessage", () => {
  const bare = matchCommunicationRoute("POST", "/parent/messages");
  assert(bare !== null, "POST /parent/messages must resolve (no trailing /send)");
  assertEquals(bare!.handler, handleParentSendMessage);

  const withSend = matchCommunicationRoute("POST", "/parent/messages/send");
  assert(withSend !== null);
  assertEquals(withSend!.handler, handleParentSendMessage);
});

Deno.test("unknown communication routes still return null (no false match)", () => {
  assertEquals(matchCommunicationRoute("DELETE", "/communications/templates"), null);
  assertEquals(matchCommunicationRoute("POST", "/communications/broadcasts/history"), null);
  assertEquals(matchCommunicationRoute("GET", "/communications/unknown"), null);
});

// MJ-C3: mirror the prefix guard in routeCommunication so the no-trailing-slash
// /parent/messages path is actually reached by the matcher (the guard strips a
// trailing slash from each prefix before the equality check).
// MJ-M12: client↔deployed-router path parity. Mirror of every Flutter
// CommunicationApiPaths constant (lib/core/repositories/api/communication/
// remote/communication_api_paths.dart) plus the HTTP method the remote
// datasource uses for it. This asserts the REAL router registration against the
// REAL client path surface — independent of MockCommunicationRepository, which
// previously masked the missing templates-write / broadcast-history routes
// (COMMU-3). The matching Flutter test pins the constants to these literals.
// Any client path the router does not expose fails here instead of 404ing live.
const CLIENT_ROUTE_CONTRACT: { method: string; path: string }[] = [
  // CommunicationApiPaths.templates (GET fetchTemplates / POST createTemplate)
  { method: "GET", path: "/communications/templates" },
  { method: "POST", path: "/communications/templates" },
  // CommunicationApiPaths.template(id) (PUT updateTemplate) — sample uuid
  {
    method: "PUT",
    path: "/communications/templates/3f1a2b3c-4d5e-6f70-8190-a1b2c3d4e5f6",
  },
  // CommunicationApiPaths.broadcasts (POST sendBroadcast)
  { method: "POST", path: "/communications/broadcasts" },
  // CommunicationApiPaths.broadcastHistory (GET listBroadcastHistory)
  { method: "GET", path: "/communications/broadcasts/history" },
  // CommunicationApiPaths.processQueue (POST)
  { method: "POST", path: "/communications/notifications/process-queue" },
  // CommunicationApiPaths.parentNotifications (GET) + mark/device (POST)
  { method: "GET", path: "/parent/notifications" },
  { method: "POST", path: "/parent/notifications/mark-read" },
  { method: "POST", path: "/parent/notifications/mark-all-read" },
  { method: "POST", path: "/parent/device-tokens/register" },
  { method: "POST", path: "/parent/device-tokens/unregister" },
  // CommunicationApiPaths.studentNotifications (GET)
  { method: "GET", path: "/student/notifications" },
];

Deno.test("MJ-M12: every communication client API path resolves in the router", () => {
  for (const route of CLIENT_ROUTE_CONTRACT) {
    const match = matchCommunicationRoute(route.method, route.path);
    assert(
      match !== null,
      `client path ${route.method} ${route.path} has no router registration ` +
        `(client↔router drift — would 404 live behind the mock)`,
    );
  }
});

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
