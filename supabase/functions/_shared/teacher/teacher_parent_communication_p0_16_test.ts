// PRA-P0-16 (S5): the teacher "Send to parent" write previously stamped a
// hardcoded status:"sent" and enqueued NOTHING — the captured `channels` array
// was ignored and the parent received nothing. The handler now resolves the
// student's ACTIVE guardians (shared guardianUserIdsForStudents), enqueues a real
// delivery per requested channel, and reports an HONEST status ("queued" vs
// "no_recipients") + recipientCount.
//
// The auth/tenant-wrapped handler body is exercised on the live lane (same
// boundary as the other write handlers). Here we pin the pure channel-mapping
// unit the handler feeds into the delivery queue: the teacher UI's channel
// labels must map onto the notification_deliveries CHECK channels (push/sms/email).

import { assertEquals } from "jsr:@std/assert@1";
import { deliveryChannels } from "./teacher_parent_communication_handlers.ts";

Deno.test("P0-16 empty channel selection defaults to push (the always-available in-app channel)", () => {
  assertEquals(deliveryChannels([]), ["push"]);
});

Deno.test("P0-16 app/in-app/notification labels all map to the push channel", () => {
  assertEquals(deliveryChannels(["app"]), ["push"]);
  assertEquals(deliveryChannels(["in_app"]), ["push"]);
  assertEquals(deliveryChannels(["notification"]), ["push"]);
  assertEquals(deliveryChannels(["push"]), ["push"]);
});

Deno.test("P0-16 sms and email pass through as their own delivery channels", () => {
  assertEquals(deliveryChannels(["sms"]), ["sms"]);
  assertEquals(deliveryChannels(["email"]), ["email"]);
});

Deno.test("P0-16 a mixed selection is mapped and de-duplicated", () => {
  // app+push collapse to a single push; sms/email are distinct.
  assertEquals(deliveryChannels(["app", "push", "sms", "email"]), ["push", "sms", "email"]);
  // Two app-ish labels never enqueue two push copies.
  assertEquals(deliveryChannels(["App", "notification"]), ["push"]);
});
