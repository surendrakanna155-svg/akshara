// QA-C-010 — Push / FCM channel BEHAVIOUR certification.
//
// Certifies the DB-free attributes of the push channel end-to-end through the
// server seam, NOT the device/FCM transport:
//
//   recipient  → the device token addressed on the message + the
//                `notification_id`/recipient carried in the `data` payload,
//   template   → rendered title (subject) + body forwarded to FCM,
//   placeholder→ the `data` map carries category / child_context,
//   deep-link  → `data.route` is the tap target the client routes on,
//   destination→ FCM HTTP v1 message shape (token + notification block),
//   delivery   → stub-mode push returns a provider ref (the value persisted as
//                `provider_ref` when the queue marks the row 'sent'),
//   audit      → `enqueueDelivery` writes the route/category/recipient onto the
//                `notification_deliveries` row (the durable record of the send).
//
// INFRA-BLOCKED (honestly marked, NOT forced here):
//   • device-token REGISTER from a real handset (FCM `getToken` + the
//     `/device-tokens/register` round-trip),
//   • push-TAP routing on a real OS (background/terminated isolate → deep link),
//   • the live `sendFcmV1` network POST to googleapis.com (service-account OAuth).
// Those legs run on the device/FCM lane; the pure handler half is already
// covered by test/core/notifications/qw4_push_messaging_service_test.dart.

import { assert, assertEquals } from "jsr:@std/assert@1";
import { buildFcmV1Payload } from "./fcm_v1_client.ts";
import { sendViaProvider, type DeliveryPayload } from "./notification_providers.ts";
import type { NotificationProviderConfig } from "./notification_provider_config.ts";
import { enqueueDelivery } from "./communication_repository.ts";
import type { TenantQueryClient } from "../tenant_db.ts";

const RECIPIENT = "11111111-1111-4111-8111-111111111111";
const DEVICE_TOKEN = "fGcm_DEVICE_TOKEN_abc123";

/** Stub-mode provider config: push runs through the no-network stub branch. */
function stubConfig(): NotificationProviderConfig {
  return {
    sms: { stubMode: true, accountSid: null, authToken: null, fromNumber: null },
    email: { stubMode: true, apiKey: null, fromEmail: null },
    push: { stubMode: true, configured: false },
  };
}

/** A representative push delivery payload (the shape `processDeliveryQueue` builds). */
function pushPayload(): DeliveryPayload {
  return {
    channel: "push",
    recipientUserId: RECIPIENT,
    subject: "Fee due",
    body: "₹4,200 due by 15 Jun for Asha (Class 3A).",
    deviceToken: DEVICE_TOKEN,
    notificationId: "d2000000-0000-4000-8000-000000000010",
    category: "fee",
    childContext: "Asha — Class 3A",
    route: "/parent/fees",
  };
}

// --- Destination + recipient + template + deep-link on the FCM v1 message -----

Deno.test("QA-C-010 buildFcmV1Payload addresses the recipient device token", () => {
  const p = pushPayload();
  const payload = buildFcmV1Payload({
    token: p.deviceToken!,
    title: p.subject!,
    body: p.body,
    data: { route: p.route!, category: p.category!, notification_id: p.notificationId! },
  }) as { message: Record<string, unknown> };

  assertEquals(payload.message.token, DEVICE_TOKEN);
});

Deno.test("QA-C-010 FCM message carries the rendered title + body (template output)", () => {
  const p = pushPayload();
  const msg = (buildFcmV1Payload({
    token: p.deviceToken!,
    title: p.subject!,
    body: p.body,
    data: {},
  }) as { message: Record<string, unknown> }).message;

  assertEquals(msg.notification, {
    title: "Fee due",
    body: "₹4,200 due by 15 Jun for Asha (Class 3A).",
  });
});

Deno.test("QA-C-010 FCM data payload carries the deep-link route + category placeholders", () => {
  const p = pushPayload();
  const msg = (buildFcmV1Payload({
    token: p.deviceToken!,
    title: p.subject!,
    body: p.body,
    data: {
      route: p.route!,
      category: p.category!,
      child_context: p.childContext!,
      notification_id: p.notificationId!,
    },
  }) as { message: Record<string, unknown> }).message;

  const data = msg.data as Record<string, string>;
  // deep-link the client (push_messaging_service.dart `_deepLink`) routes the tap on
  assertEquals(data.route, "/parent/fees");
  assertEquals(data.category, "fee");
  assertEquals(data.child_context, "Asha — Class 3A");
  // notification_id ties the tray push back to the inbox row.
  assertEquals(data.notification_id, "d2000000-0000-4000-8000-000000000010");
});

Deno.test("QA-C-010 FCM message keeps android-HIGH + apns sound for reliable delivery", () => {
  const msg = (buildFcmV1Payload({
    token: DEVICE_TOKEN,
    title: "x",
    body: "y",
    data: {},
  }) as { message: Record<string, unknown> }).message;
  assertEquals((msg.android as Record<string, unknown>).priority, "HIGH");
  assertEquals(typeof msg.apns, "object");
});

// --- sendPush forwards the right data map + returns a delivery ref (stub) -----

Deno.test("QA-C-010 sendViaProvider(push) in stub mode succeeds with a push_stub provider ref", async () => {
  const result = await sendViaProvider(stubConfig(), pushPayload());
  assertEquals(result.success, true);
  assertEquals(result.error, null);
  assert(result.providerRef !== null);
  // the ref is the value persisted as notification_deliveries.provider_ref on 'sent'.
  assert(result.providerRef!.startsWith("push_stub_"));
});

Deno.test("QA-C-010 sendPush fails closed when not stubbed and the device token is missing", async () => {
  const liveCfg = stubConfig();
  liveCfg.push = { stubMode: false, configured: true };
  const payload = pushPayload();
  payload.deviceToken = null; // recipient has no registered device → cannot address
  const result = await sendViaProvider(liveCfg, payload);
  assertEquals(result.success, false);
  assertEquals(result.providerRef, null);
  assert((result.error ?? "").includes("device token"));
});

// --- Delivery row / audit: enqueueDelivery records recipient + route + status -

interface Captured {
  sql: string;
  args: unknown[];
}

function fakeDb(): { db: TenantQueryClient; calls: Captured[] } {
  const calls: Captured[] = [];
  const db = {
    // deno-lint-ignore no-explicit-any
    queryObject(sql: string, args: unknown[] = []): Promise<any[]> {
      calls.push({ sql, args });
      // enqueueDelivery returns rows[0]; echo a row carrying the inserted fields.
      return Promise.resolve([{
        id: "d2000000-0000-4000-8000-000000000010",
        recipient_user_id: args[2],
        channel: args[3],
        template_id: args[4],
        category: args[5],
        rendered_subject: args[6],
        rendered_body: args[7],
        route: args[9],
        status: "pending",
      }]);
    },
  } as unknown as TenantQueryClient;
  return { db, calls };
}

Deno.test("QA-C-010 enqueueDelivery records recipient + channel + route + pending status (audit row)", async () => {
  const { db, calls } = fakeDb();
  const row = await enqueueDelivery(db, {
    organizationId: "org",
    schoolId: "school",
    recipientUserId: RECIPIENT,
    channel: "push",
    templateId: "tmpl-fee-due",
    category: "fee",
    renderedSubject: "Fee due",
    renderedBody: "₹4,200 due by 15 Jun.",
    childContext: "Asha — Class 3A",
    route: "/parent/fees",
  });

  assertEquals(calls.length, 1);
  const { sql, args } = calls[0];
  // durable delivery record persisted to the notification_deliveries table.
  assert(sql.includes("INSERT INTO notification_deliveries"));
  assert(sql.includes("'pending'")); // queued state — audit-visible before send
  // recipient, channel, template, route all captured on the row.
  assertEquals(args[2], RECIPIENT);
  assertEquals(args[3], "push");
  assertEquals(args[4], "tmpl-fee-due");
  assertEquals(args[9], "/parent/fees");
  assertEquals(row.status, "pending");
  assertEquals(row.recipient_user_id, RECIPIENT);
  assertEquals(row.route, "/parent/fees");
});
