import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  type ChannelPolicy,
  computeEscalationTarget,
  validateEscalationChain,
} from "./communication_escalation.ts";

const chain = (c: string[], isActive = true): ChannelPolicy => ({
  escalationChain: c,
  isActive,
});

// ─── computeEscalationTarget ─────────────────────────────────────────────────

Deno.test("Batch 6: escalates to the next channel after the failed one", () => {
  const p = chain(["whatsapp", "sms", "push"]);
  assertEquals(computeEscalationTarget(p, "whatsapp", 0), "sms");
  assertEquals(computeEscalationTarget(p, "sms", 1), "push");
});

Deno.test("Batch 6: no policy → no escalation (backward compatible)", () => {
  assertEquals(computeEscalationTarget(null, "whatsapp", 0), null);
});

Deno.test("Batch 6: an inactive policy never escalates", () => {
  const p = chain(["whatsapp", "sms"], false);
  assertEquals(computeEscalationTarget(p, "whatsapp", 0), null);
});

Deno.test("Batch 6: the last link in the chain does not escalate", () => {
  const p = chain(["whatsapp", "sms", "push"]);
  assertEquals(computeEscalationTarget(p, "push", 2), null);
});

Deno.test("Batch 6: a channel not in the chain does not escalate", () => {
  const p = chain(["whatsapp", "sms"]);
  assertEquals(computeEscalationTarget(p, "email", 0), null);
});

Deno.test("Batch 6: escalation follows chain POSITION, not depth (no backwards)", () => {
  // A push enqueued directly (chain position 2) while the chain is
  // [whatsapp, sms, push] must never escalate 'backwards' to sms.
  const p = chain(["whatsapp", "sms", "push"]);
  assertEquals(computeEscalationTarget(p, "push", 0), null);
});

Deno.test("Batch 6: the depth guard bounds the fallback sequence (terminates)", () => {
  const p = chain(["whatsapp", "sms", "push"]);
  // depth already at chain.length-1 → stop, even mid-chain.
  assertEquals(computeEscalationTarget(p, "whatsapp", 2), null);
});

Deno.test("Batch 6: a single-element chain never escalates", () => {
  const p = chain(["whatsapp"]);
  assertEquals(computeEscalationTarget(p, "whatsapp", 0), null);
});

// ─── validateEscalationChain ─────────────────────────────────────────────────

Deno.test("Batch 6: a valid chain passes validation", () => {
  assertEquals(validateEscalationChain(["whatsapp", "sms", "push"]), null);
});

Deno.test("Batch 6: an empty / non-array chain is rejected", () => {
  assertEquals(
    validateEscalationChain([]),
    "escalationChain must be a non-empty array of channels",
  );
  assertEquals(
    validateEscalationChain("whatsapp"),
    "escalationChain must be a non-empty array of channels",
  );
});

Deno.test("Batch 6: an unknown channel is rejected", () => {
  assertEquals(
    validateEscalationChain(["whatsapp", "telegram"]),
    "escalationChain contains an unknown channel: telegram",
  );
});

Deno.test("Batch 6: a duplicate channel is rejected (ambiguous position)", () => {
  assertEquals(
    validateEscalationChain(["whatsapp", "sms", "whatsapp"]),
    "escalationChain contains a duplicate channel: whatsapp",
  );
});
