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
| G5 | **Limit enforcement** (`limit.students`/`limit.schools` slab + grace on create paths) | ✅ | Step 4.6 — `enforceStudentLimit` (SIS create) + `enforceSchoolLimit` (control-center add-school); gated by the enforcement master switch |
| G6 | Locked/upgrade UX | ✅ | badge + Plan & Entitlements screen (Step 4) + items below (Step 4.6) |
| G6a | Inline locked states on real module screens | ✅ | Step 4.6 — `EntitlementModuleGate` route guard + nav shows locked modules (visible, lock glyph, never hidden) |
| G6b | School Discovery wizard renders plan-locked modules as locked | ✅ | Step 4.6 — wizard toggles for plan-disallowed modules render disabled with "Upgrade to unlock" |
| G6c | Copilot plan-locked topic message | ✅ | Step 4.6 — `CopilotCapabilityFilter` differentiates plan-locked (upgrade) vs school-disabled (enable in config) |
| — | **Enforcement master switch** (`ENTITLEMENT_ENFORCEMENT`, default off) | ✅ | Step 4.6 — backend enforcement (module 402 + limits) is no-op until flipped → edge deploys dark safely |
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
| Limit checks on count-growing create paths | ✅ Step 4.6 | = G5 (gated by enforcement switch) |

## UI (spec §7)
| Item | Status |
|---|---|
| Plan badge | ✅ Step 4 |
| Plan & Entitlements screen + wa.me upgrade CTA | ✅ Step 4 |
| Locked module inline states | ✅ Step 4.6 |
| School Discovery wizard ceiling | ✅ Step 4.6 |
| Copilot plan-locked message | ✅ Step 4.6 |
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

## Per-step certification docs (cont.)
- Step 4.6: `docs/B2_STEP4_6_CERTIFICATION.md` (G5 limits + G6a/b/c locked UX + enforcement switch)

## Definition of "B2 100% complete"
All functional spec items (G1–G7 except the 🚫/deferred-minor G7a + the §6
GET /school-config server-payload deviation) are now ✅ **built and certified
locally**. The ONLY remaining work is **Step 5** (integration/E2E tests, smoke
script, VPS deploy + production cert) — ⛔ open by design (owner-gated). Deferred
minors (G7a override audit; server-resolved capabilities payload) remain tracked
above, non-blocking for the pilot.
