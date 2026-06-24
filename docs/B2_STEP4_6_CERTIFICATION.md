# B2 — Entitlement Layer · Step 4.6 · Certification

**Date:** 2026-06-24 · **Branch:** `feature/scope-trim-school-build`
**Purpose:** close the functional gaps deferred by per-step scoping (G5 + G6a/b/c)
so Step 5 deploys a **whole** B2 — no gaps reach production. Builds on Step 4.5
(`22eb76c`). Scope locked: entitlement layer only. Not deployed.

## What was closed

### G5 — Slab-limit enforcement + deploy-dark master switch
- `entitlement_enforcement.ts` — `ENTITLEMENT_ENFORCEMENT` env (default **off**). Backend
  enforcement (module 402 guards **and** the new limit guards) is a no-op until flipped.
  Lets the edge deploy dark → assign plans → enable. Prevents 402-ing the Step-1 Trial
  back-fill on deploy. `withEntitlement` now short-circuits when the switch is off.
- `entitlement_limits.ts` — pure `withinSlab(current, limit, grace)` + `enforceStudentLimit`
  (SIS `handleCreateStudent`) and `enforceSchoolLimit` (control-center add-school). 402
  `PLAN_LIMIT_EXCEEDED` at slab + grace. Fail-open on any resolve error (never breaks creation).

### G6a — Inline locked module states (never hidden)
- `EntitlementModuleGate` + `modulePlanLockedProvider` — wraps gated module routes
  (transport/hostel/library/inventory/alumni/hr/director); a plan-locked module renders
  `PlanLockedModuleView` (lock + "Upgrade to unlock" + WhatsApp CTA + "View plans").
- Admin nav now **shows** plan-locked modules with a lock glyph instead of hiding them
  (`adminNavDestinationsProvider` marks `isLocked`; `AksharaNavRailTile` renders the lock).
  School-disabled-within-plan modules still hide (unchanged personalization).

### G6b — School Discovery wizard ceiling
- Wizard capability toggles for plan-disallowed modules render **disabled** with a lock +
  "Upgrade to unlock"; toggles operate only within the plan ceiling.

### G6c — Copilot plan-locked message
- `CopilotCapabilityFilter` differentiates **plan-locked** (→ "not included in your plan…
  open Plan & Entitlements to upgrade") from **school-disabled** (→ "enable in config").

## Backward compatibility
The enforcement switch defaults off and the plan ceiling is unrestricted when the
entitlement layer is disabled, so **with B2 off everything behaves exactly as pre-B2**:
no module hidden differently, no toggle locked, no copilot/limit change.

## Definition of Done — Step 4.6

| Gate | Result |
|---|---|
| G5 student + school limit enforcement | ✅ wired, gated by master switch |
| Enforcement master switch (deploy-dark) | ✅ default off; module 402 + limits both gated |
| G6a inline locked states (route + nav, never hidden) | ✅ |
| G6b wizard ceiling | ✅ |
| G6c copilot plan-locked message | ✅ |
| Backend tests | ✅ Deno **29/29** (incl. `withinSlab` slab+grace math, switch-off default) |
| Flutter tests | ✅ new locked-UX suite (gate view shows/ hides, `modulePlanLockedProvider`, copilot plan-vs-school message); entitlements + copilot-filter + admin-nav + school-config suites green (**55 in the run**) |
| `flutter analyze` | ✅ **0 errors** project-wide; no issues in any touched file |
| Deno type-check | ✅ index + touched handlers |
| Backward compatible (B2 off) | ✅ unrestricted ceiling + switch off → pre-B2 behaviour |
| Not deployed | ✅ local only |

## Test commands
```
cd supabase/functions && deno test _shared/entitlements/     # 29 passed
flutter test test/features/entitlements/ test/features/copilot/ test/core/school_config/ test/features/admin/
flutter analyze                                              # 0 errors
```

**Status: B2 Step 4.6 = certified locally. All functional spec items (G1–G7, minus
documented-deferred G7a + the §6 server-payload deviation) are now done. Only Step 5
(tests + VPS production cert) remains — on owner go.** See `docs/B2_STATUS_LEDGER.md`.
