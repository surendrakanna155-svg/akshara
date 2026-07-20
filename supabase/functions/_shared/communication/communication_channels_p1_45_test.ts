// PRA-P1-45 (S5): broadcasts were push-only with no SMS/email fallback. The fix
// makes delivery channels an ADDITIVE, opt-in set: `push` is always present (the
// free in-app baseline + the sole acknowledgement channel) and an admin can add
// `sms`/`email` explicitly, so no automatic cost is ever incurred. These pin the
// normalization that `sendBroadcastMessage` loops over to fan out one delivery
// batch per channel.

import { assertEquals } from "jsr:@std/assert@1";
import { normalizeBroadcastChannels } from "./communication_service.ts";

Deno.test("P1-45 default (omitted/empty) is push-only — zero behaviour change", () => {
  assertEquals(normalizeBroadcastChannels(undefined), ["push"]);
  assertEquals(normalizeBroadcastChannels(null), ["push"]);
  assertEquals(normalizeBroadcastChannels([]), ["push"]);
});

Deno.test("P1-45 opted-in sms/email are added on top of push (additive)", () => {
  assertEquals(normalizeBroadcastChannels(["sms"]), ["push", "sms"]);
  assertEquals(normalizeBroadcastChannels(["email"]), ["push", "email"]);
  assertEquals(normalizeBroadcastChannels(["sms", "email"]), ["push", "sms", "email"]);
});

Deno.test("P1-45 push is never dropped even when the caller omits it", () => {
  // Selecting only sms still keeps the in-app push copy (and the ack channel).
  assertEquals(normalizeBroadcastChannels(["SMS"]), ["push", "sms"]);
});

Deno.test("P1-45 unknown labels are dropped; result is de-duplicated and push-first ordered", () => {
  assertEquals(
    normalizeBroadcastChannels(["email", "whatsapp", "sms", "sms", "push", "carrier-pigeon"]),
    ["push", "sms", "email"],
  );
  assertEquals(normalizeBroadcastChannels(["telegram"]), ["push"]);
});

Deno.test("P1-45 labels are case/whitespace-insensitive", () => {
  assertEquals(normalizeBroadcastChannels([" Sms ", "EMAIL"]), ["push", "sms", "email"]);
});
