// PRC-A Batch 9 — Upload malware-scan service (owner-future-idea 29).
//
// Pure decision logic + env flags, no IO — so the honesty-critical parts (what
// status an un-scanned upload gets, and when serving is gated) are exhaustively
// unit-testable. Ships DARK: without a configured AV every upload is honestly
// 'skipped', and with enforcement OFF (default) every object is served — no
// behaviour change on deploy.

export type ScanStatus = "pending" | "clean" | "infected" | "skipped" | "error";
export type ScanDisposition = "allow" | "block" | "hold";

/** Whether uploaded objects are actually scanned. Off by default → 'skipped'. */
export function malwareScanEnabled(): boolean {
  try {
    return (Deno.env.get("MALWARE_SCAN_ENABLED") ?? "").toLowerCase() === "true";
  } catch {
    return false;
  }
}

/** Whether serving is GATED on the scan verdict. Off by default → allow all
 * (backward compatible), so flipping scanning on never blocks serving until this
 * is also deliberately enabled. */
export function malwareScanEnforcementEnabled(): boolean {
  try {
    return (Deno.env.get("MALWARE_SCAN_ENFORCEMENT") ?? "").toLowerCase() === "true";
  } catch {
    return false;
  }
}

/** The configured AV engine name, or 'none'. */
export function malwareScanEngine(): string {
  try {
    return Deno.env.get("MALWARE_SCAN_ENGINE") || "none";
  } catch {
    return "none";
  }
}

/**
 * The HONEST status a freshly-confirmed upload is recorded with — never a
 * fabricated 'clean'. No scanning configured → 'skipped' (we did not scan this).
 * Scanning on but no engine → 'error' (misconfigured). Scanning on with an engine
 * → 'pending' (queued for the AV; the actual AV call is the external follow-up).
 */
export function initialScanStatus(): { status: ScanStatus; engine: string } {
  if (!malwareScanEnabled()) return { status: "skipped", engine: "none" };
  const engine = malwareScanEngine();
  if (engine === "none") return { status: "error", engine: "none" };
  return { status: "pending", engine };
}

/**
 * Whether an object may be served, given its recorded scan status and whether
 * enforcement is on. Enforcement OFF → always allow. Enforcement ON: a clean or
 * (honestly) un-scanned 'skipped' object is served; a known-'infected' object is
 * blocked; a 'pending'/'error' scan is held; a MISSING record (legacy object
 * uploaded before this feature) is allowed — enforcement never retroactively
 * blocks pre-existing content.
 */
export function resolveScanDisposition(
  status: ScanStatus | null,
  enforcementOn: boolean,
): ScanDisposition {
  if (!enforcementOn) return "allow";
  switch (status) {
    case "clean":
    case "skipped":
    case null:
      return "allow";
    case "infected":
      return "block";
    case "pending":
    case "error":
      return "hold";
    default:
      return "hold";
  }
}
