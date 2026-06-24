// B2 — Step 4.6 · backend enforcement master switch.
//
// Backend entitlement enforcement (module 402 guards + slab-limit guards) is
// always wired, but only ACTS when `ENTITLEMENT_ENFORCEMENT=true`. This lets the
// edge deploy "dark": ship the code, assign every live org its real plan via the
// Step-4.5 admin screen, THEN flip this env on. Without it, deploying the edge
// would immediately enforce against the Step-1 Trial back-fill and could 402 a
// live school that legitimately uses paid modules or exceeds the Trial slab.
//
// Default OFF → safe to deploy. Read from the env each call so flipping it needs
// only an edge restart, not a redeploy.
export function entitlementEnforcementEnabled(): boolean {
  try {
    return (Deno.env.get("ENTITLEMENT_ENFORCEMENT") ?? "").toLowerCase() === "true";
  } catch {
    // Env not readable (e.g. restricted context) → fail safe to OFF.
    return false;
  }
}
