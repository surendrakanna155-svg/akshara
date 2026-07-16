// PRC-A Batch 3 — AI credit wallet master switch (owner decision #3).
//
// The wallet is always WIRED but only ACTS when `AI_WALLET_ENFORCEMENT=true`.
// This is not optional caution — without it, deploying the edge would instantly
// enforce a balance against orgs that have never been granted a single credit.
// Balance would be 0, the admit clause would deny, and EVERY AI call for EVERY
// live tenant would fall back. The wallet must ship dark: deploy the code, grant
// real balances, THEN flip the env.
//
// Mirrors `entitlements/entitlement_enforcement.ts` deliberately — that switch
// exists for exactly the same reason (its comment: "deploying the edge would
// immediately enforce against the Step-1 Trial back-fill and could 402 a live
// school"). Same hazard, same shape, so there is one recognisable pattern for
// "shipped but not yet acting" rather than two.
//
// Read from the env each call so flipping it needs only an edge restart, not a
// redeploy. Default OFF → safe to deploy.
export function aiWalletEnforcementEnabled(): boolean {
  try {
    return (Deno.env.get("AI_WALLET_ENFORCEMENT") ?? "").toLowerCase() === "true";
  } catch {
    // Env not readable (e.g. a restricted context) → fail safe to OFF.
    // NOTE the asymmetry with the rest of this module, and that it is intentional:
    // everywhere else the wallet fails CLOSED (an unreadable balance denies). Here
    // it fails OPEN, because this flag answers "is the wallet live at all?", not
    // "does this org have credit?". Failing closed on an unreadable FLAG would take
    // every tenant's AI offline over an env glitch — a self-inflicted outage, not a
    // safety property.
    return false;
  }
}
