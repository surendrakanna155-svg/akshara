// SCE-1 — the handler's lifecycle coercion is the request-facing strictness
// gate. This pins the prototype-key defense that audit R-slice1 P1-1 flagged:
// a crafted ?lifecycle=<prototype key> must coerce to the strict exit default,
// never slip through to downgrade a blocking gate.

import { assertEquals } from "jsr:@std/assert@1";
import { resolveLifecycle } from "./clearance_handlers.ts";
import { LIFECYCLE_POLICIES } from "./clearance_engine.ts";

Deno.test("resolveLifecycle: every KNOWN lifecycle passes through unchanged", () => {
  for (const key of Object.keys(LIFECYCLE_POLICIES)) {
    assertEquals(resolveLifecycle(key), key);
  }
});

Deno.test("resolveLifecycle: null / empty / whitespace → strict exit default", () => {
  assertEquals(resolveLifecycle(null), "transfer_certificate");
  assertEquals(resolveLifecycle(""), "transfer_certificate");
  assertEquals(resolveLifecycle("   "), "transfer_certificate");
});

Deno.test("resolveLifecycle: a typo → strict exit default (not silently permissive)", () => {
  assertEquals(resolveLifecycle("transfercert"), "transfer_certificate");
  assertEquals(resolveLifecycle("promote"), "transfer_certificate");
});

Deno.test("resolveLifecycle: prototype keys never masquerade as a lifecycle (P1-1 fix)", () => {
  for (const evil of [
    "constructor",
    "valueOf",
    "toString",
    "hasOwnProperty",
    "__proto__",
    "isPrototypeOf",
  ]) {
    assertEquals(
      resolveLifecycle(evil),
      "transfer_certificate",
      `${evil} must coerce to the strict default`,
    );
  }
});

Deno.test("resolveLifecycle trims a valid key with surrounding space", () => {
  assertEquals(resolveLifecycle("  promotion  "), "promotion");
});
