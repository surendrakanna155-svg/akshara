import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { initialScanStatus, resolveScanDisposition, type ScanStatus } from "./upload_scan_service.ts";

// ─── initialScanStatus (the "never fabricate clean" honesty property) ────────

Deno.test("Batch 9: an unscanned upload is HONESTLY 'skipped', never a fabricated 'clean' (default)", () => {
  Deno.env.delete("MALWARE_SCAN_ENABLED");
  const r = initialScanStatus();
  assertEquals(r.status, "skipped");
  assertEquals(r.engine, "none");
});

Deno.test("Batch 9: scanning enabled but no engine → honest 'error' (misconfigured, not 'clean')", () => {
  try {
    Deno.env.set("MALWARE_SCAN_ENABLED", "true");
    Deno.env.delete("MALWARE_SCAN_ENGINE");
    assertEquals(initialScanStatus().status, "error");
  } finally {
    Deno.env.delete("MALWARE_SCAN_ENABLED");
  }
});

Deno.test("Batch 9: scanning enabled with an engine → 'pending' (queued for the AV, never auto-clean)", () => {
  try {
    Deno.env.set("MALWARE_SCAN_ENABLED", "true");
    Deno.env.set("MALWARE_SCAN_ENGINE", "clamav");
    const r = initialScanStatus();
    assertEquals(r.status, "pending");
    assertEquals(r.engine, "clamav");
  } finally {
    Deno.env.delete("MALWARE_SCAN_ENABLED");
    Deno.env.delete("MALWARE_SCAN_ENGINE");
  }
});

// ─── resolveScanDisposition (the serving gate) ───────────────────────────────

Deno.test("Batch 9: enforcement OFF always allows (backward compatible, no behaviour change)", () => {
  const statuses: (ScanStatus | null)[] = ["pending", "clean", "infected", "skipped", "error", null];
  for (const s of statuses) {
    assertEquals(resolveScanDisposition(s, false), "allow", `status ${s} with enforcement off`);
  }
});

Deno.test("Batch 9: enforcement ON blocks a known-infected object", () => {
  assertEquals(resolveScanDisposition("infected", true), "block");
});

Deno.test("Batch 9: enforcement ON serves a clean object", () => {
  assertEquals(resolveScanDisposition("clean", true), "allow");
});

Deno.test("Batch 9: enforcement ON serves an honestly-unscanned 'skipped' object (no AV, nothing to enforce)", () => {
  // This is the key property: turning enforcement on WITHOUT an AV cannot take
  // uploads offline — 'skipped' means nothing was scanned, so it passes.
  assertEquals(resolveScanDisposition("skipped", true), "allow");
});

Deno.test("Batch 9: enforcement ON holds a still-scanning ('pending') or errored scan", () => {
  assertEquals(resolveScanDisposition("pending", true), "hold");
  assertEquals(resolveScanDisposition("error", true), "hold");
});

Deno.test("Batch 9: enforcement ON never retroactively blocks a legacy object with no scan record", () => {
  assertEquals(resolveScanDisposition(null, true), "allow");
});
