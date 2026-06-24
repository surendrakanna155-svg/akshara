# B2 — Entitlement Layer · Status Ledger (single source of truth)

**Purpose:** one place to see what is DONE vs OPEN for B2, so no full re-audit is
needed — check this file. Updated at every step. Scope locked: entitlement layer
only (no billing/payments/renewals/invoices/MRR/addons/white-label).

Legend: ✅ done & certified · 🟡 partial · ⛔ open · 🚫 intentionally out of scope (owner)

| # | Spec item (B2_CAPABILITY_GATING_SPEC.md) | Status | Where |
|---|---|---|---|
| G1 | Plan catalog (`subscription_plans` + `plan_entitlements`, seeded) | ✅ | Step 1 (`f006cba`) |
| G2 | Org → plan assignment (default Trial + reassign) | ✅ | Step 1 (default) + Step 4.5 (`22eb76c`) |
| G3 | Entitlement resolution (`planAllows ∩ schoolConfigEnabled`) | ✅ | Step 2 (`5f9d6bb`) + Step 3 (`39b3c6d`) |
| G4 | Server-side enforcement (`requireEntitlement` → 402) | ✅ | Step 2 — transport/hostel/library/inventory/alumni/hr/director(multi_branch) |
| G4a | Control-Center gating | 🚫 | Owner: keep ungated (overlaps core `module.management`) |
| G5 | **Limit enforcement** (`limit.students`/`limit.schools` slab + grace on create paths) | ⛔ OPEN | data model + resolver expose limits; enrollment/school-create checks NOT wired |
| G6 | Locked/upgrade UX | 🟡 | badge + Plan & Entitlements screen ✅ (Step 4); items below open |
| G6a | Inline locked states on real module screens/KPIs | ⛔ OPEN | only the entitlements screen lists locked modules today |
| G6b | School Discovery wizard renders plan-locked modules as locked | ⛔ OPEN | wizard still edits raw local config; effective is bounded but UI doesn't show the ceiling |
| G6c | Copilot plan-locked topic message | ⛔ OPEN | `CopilotCapabilityFilter` not extended for plan-locked topics |
| G7 | Audit — plan assign/change | ✅ | Step 4.5 (`subscription.plan.assigned`) |
| G7a | Audit — enterprise per-deal override applied | ⛔ OPEN (minor) | overrides exist in data model; no route/UI/`subscriptionOverrideApplied` yet |

## API (spec §6)
| Route | Status | Where |
|---|---|---|
| `GET /plans` | ✅ | Step 2 |
| `GET /subscription` | ✅ | Step 2 |
| `PUT /platform/organizations/{id}/subscription` | ✅ | Step 4.5 |
| `GET /platform/subscriptions` (assign screen list) | ✅ | Step 4.5 |
| `GET /school-config` also returns resolved effective capabilities | ⚠️ DONE DIFFERENTLY | resolution done client-side in `schoolCapabilitiesProvider` (= local ∩ plan ceiling); server response unchanged. Functionally equivalent for gating; revisit only if a server-authoritative effective payload is required |
| Limit checks on count-growing create paths | ⛔ OPEN | = G5 |

## UI (spec §7)
| Item | Status |
|---|---|
| Plan badge | ✅ Step 4 |
| Plan & Entitlements screen + wa.me upgrade CTA | ✅ Step 4 |
| Locked module/KPI inline states | ⛔ OPEN (G6a) |
| School Discovery wizard ceiling | ⛔ OPEN (G6b) |
| Copilot plan-locked message | ⛔ OPEN (G6c) |
| SuperAdmin assign-plan screen | ✅ Step 4.5 |

## Step 5 (planned — tests + production)
| Item | Status |
|---|---|
| Contract / integration / E2E tests (assign → 402 → upgrade → 200) | ⛔ OPEN |
| `scripts/capability_gating_b2_smoke.sh` | ⛔ OPEN |
| VPS deploy (migrations `20260717*`×3 + `20260718`) + edge | ⛔ OPEN |
| Live production certification | ⛔ OPEN |
| ⚠️ Assign live pilot org a plan BEFORE enabling enforcement | ⛔ OPEN (else Trial 402s its modules) |

## Per-step certification docs
- Step 1: in commit `f006cba` (data model + seed; validated via `supabase db reset`)
- Step 2: `docs/B2_STEP2_CERTIFICATION.md`
- Step 3: `docs/B2_STEP3_CERTIFICATION.md`
- Step 4: `docs/B2_STEP4_CERTIFICATION.md`
- Step 4.5: `docs/B2_STEP4_5_CERTIFICATION.md`

## Definition of "B2 100% complete"
All ⛔ closed (G5, G6a/b/c, Step 5) or explicitly marked 🚫 by owner. Today: the
**core entitlement loop is built and certified locally**; the open items are
enforcement of slab limits, the remaining locked-state UX surfaces, and Step-5
production. None are forgotten — they are listed here and will be closed before
B2 is declared done.
