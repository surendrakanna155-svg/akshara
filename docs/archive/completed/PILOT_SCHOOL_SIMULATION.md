# Akshara ERP — Pilot School Simulation

**Status:** ✅ PASSED — LIVE CERTIFIED (2026-06-27)
**Nature:** Real-world school simulation against the live VPS pilot — *not* a code audit.
**Live backend:** `https://akshara.veloraunisexsalon.com` (real auth · real DB · real RBAC)

> This exercise runs Akshara the way real customers do — principals, teachers,
> parents and students across multiple school types — instead of re-auditing
> code. It treats every prior certification (B1–B11, Engineering Waves 0–5,
> Journey Waves 0–5, Onboarding & Dynamic Configuration) as the source of truth
> and does **not** re-audit certified-and-unchanged areas, invent features, or
> change the roadmap.

---

## 1. What was simulated

| Area | Coverage |
|------|----------|
| **School types** | Small Private (State board), Large CBSE, ICSE, State Board |
| **Organization topology** | Single-school organization vs. multi-school Trust |
| **Dynamic module lifecycle** | Inventory · Hostel · Library · Transport · HR · Alumni (enable → use → disable → re-enable) + Marketing (plan upgrade path) |
| **Full school lifecycle (one month)** | Onboarding → teachers → admission → parent linking → attendance → homework → exams → fee collection → receipts → results-to-parent → import preview/commit/rollback |
| **Cross-cutting** | UX empty-states, RBAC, persistence, API contracts, AI fallback/available behaviour |

Each school/org is an **isolated throwaway** created in the pilot, exercised
end-to-end, then scrubbed and soft-deleted in a `finally` block. The live pilot
school is never touched.

---

## 2. Quality gates (all green)

| Gate | Result |
|------|--------|
| `flutter analyze --no-fatal-infos` | **0 issues** |
| `flutter test` (unit/widget/integration) | **2440 passed / 0 failed** (1 expected skip) |
| Backend `deno test supabase/functions/` | **857 passed / 0 failed** (2 ignored — need live DB) |
| Live VPS — Pilot Simulation | **41 / 41** (`scripts/qa/live_cert_pilot_simulation.py`) |
| Live VPS — Full school lifecycle | **25 / 25** (`scripts/qa/live_cert_full_journeys.py`) |
| Live VPS — Onboarding & Dynamic Config | **17 / 17** (`scripts/qa/live_cert_onboarding_dynamic_config.py`) |

**Live total: 83 / 83** against the real VPS pilot.

---

## 3. Multi-board onboarding (PART A — live 28/28 within the run)

A customer onboards a school by board; go-live provisions the right ERP for that
board. Verified live for four distinct school types — each from a fresh school:

| School type | Board | Modules requested | Go-live | Subjects provisioned | Capabilities match | Disabled module | Empty-state read |
|-------------|-------|-------------------|---------|----------------------|--------------------|-----------------|------------------|
| Small Private | State | sis · finance · attendance | ✅ | ✅ | optional modules all OFF | `/transport` → **403 MODULE_DISABLED** | `/sis/students` → **200** |
| Large CBSE | CBSE | + transport · library · hostel · inventory · hr | ✅ | ✅ | transport/library/hostel/inventory ON | `/alumni` → **403 MODULE_DISABLED** | **200** |
| ICSE | ICSE | + library · transport | ✅ | ✅ | library/transport ON, rest OFF | `/hostel` → **403 MODULE_DISABLED** | **200** |
| State Board | State | + transport | ✅ | ✅ | transport ON, rest OFF | `/library` → **403 MODULE_DISABLED** | **200** |

- **AI prefill honours the board** — `/onboarding/startup/ai-prefill` returns a
  structured proposal for every board (200, never 500), demonstrating the
  **AI-available** path with a deterministic fallback that can never error.
- **Empty-state contract** — a brand-new school's reads return a clean `200`
  empty list, never a `500`.
- Each school's `school_configuration.capabilities` in the live DB exactly
  matches the modules the founder chose — the founder's choice reaches the
  runtime gate.

---

## 4. Organization topology (PART B — live 5/5)

The chain flag is the live rule "more than one non-deleted school in the org":

| Topology | Schools | `isChainOrganization` (/auth/me) | JWT `is_chain_organization` | Director multi-branch |
|----------|---------|----------------------------------|-----------------------------|-----------------------|
| Single-school organization | 1 | **false** | **false** | entitlement-gated → **402 PLAN_UPGRADE_REQUIRED** on trial |
| Multi-school Trust | 2 | **true** | **true** | (chain unlocked) |

This is what gates the Organization Builder / Director portal correctly for a
single school vs. a trust that runs multiple branches.

---

## 5. Dynamic module lifecycle (PART C — live 7/7)

This is the core "schools grow into modules" scenario. For each of the six
school-capability modules, on a live CBSE school, the full lifecycle was proven:

```
DISABLE  → GET /<module>/dashboard → 403 MODULE_DISABLED   (UI hides the module)
ENABLE   → GET /<module>/dashboard → 200 empty-state        (menu appears, API activates)
USE      → create module data while enabled                 (row persists)
DISABLE  → GET /<module>/dashboard → 403 MODULE_DISABLED   (UI hides) — data NOT deleted ✓
RE-ENABLE→ GET /<module>/dashboard → 200                    (API reactivates) — data restored ✓
```

| Module | off→ | enable→ | data created | disable→ | **data kept** | re-enable→ | **data restored** |
|--------|------|---------|--------------|----------|---------------|------------|-------------------|
| Inventory | 403 | 200 | ✅ | 403 | ✅ | 200 | ✅ |
| Hostel | 403 | 200 | ✅ | 403 | ✅ | 200 | ✅ |
| Library | 403 | 200 | ✅ | 403 | ✅ | 200 | ✅ |
| Transport | 403 | 200 | ✅ | 403 | ✅ | 200 | ✅ |
| HR | 403 | 200 | ✅ | 403 | ✅ | 200 | ✅ |
| Alumni | 403 | 200 | ✅ | 403 | ✅ | 200 | ✅ |

- **Disabling never deletes data.** The module's data row survives the disable
  and is fully readable on re-enable. (Consistent with the live `erp_tenant`
  no-DELETE constraint — disable is a capability flag flip, not a data wipe.)
- **Marketing** is a *plan-entitlement* upgrade path (not a school-capability
  toggle): a trial-plan org hitting `/growth` gets **402 PLAN_UPGRADE_REQUIRED**,
  the correct "upgrade to unlock" signal.

---

## 6. Full school lifecycle — one month (PART D — live 25/25)

Re-certified the entire month-long journey across the admin, teacher and parent
personas (`live_cert_full_journeys.py`):

- Identity / RBAC (admin `/auth/me`, permission count, **teacher denied** on
  admin-only `/attendance/corrections` → 403)
- School config read + capability write round-trip
- SIS read · Finance dashboard · Attendance sessions
- Parent visibility (dashboard / exams / receipts)
- **Fee → parent receipt**: admin records a collection → parent sees the new
  receipt (then cancelled to restore)
- **Results → parent**: create exam → open marks → enter marks → process →
  **publish gate enforced without approval (403)** → publish approved →
  **parent sees the published result**
- **First-time student onboarding**: import preview → commit → rollback

---

## 7. Issue found and fixed (one genuine production bug)

The simulation surfaced **one** genuine, customer-impacting defect — see
`docs/PILOT_SIMULATION_ROADMAP.md` for the full write-up.

**Empty-state 404 on snapshot dashboards.** Transport, Inventory and Hostel
dashboards (and, by the same root cause, Management and Control-Center/Director
dashboards) returned **`404 NOT_FOUND`** for any school other than the seeded
demo pilot — because their derived "snapshot" row is only seeded by a migration
hardcoded to the pilot org/school, and go-live does not create one per school.
A freshly-onboarded customer enabling Transport/Inventory/Hostel saw an **error
screen**, not an empty dashboard. (Library/HR/Alumni were already correct — they
were modernized in Journey Wave 3 to compute their dashboards live.)

**Fix (server-side, no migration):** the snapshot read handlers now return a
clean empty `{}` payload at **200** when the snapshot row is absent. The
client mappers are null-tolerant, so this renders a proper zero-state dashboard
instead of an error. Applied uniformly to the five affected handlers, deployed
to the VPS, and re-verified live (all six module dashboards now return 200 on
enable). Backend suite 857/0 unchanged.

---

## 8. Cross-cutting verification summary

| Dimension | Evidence |
|-----------|----------|
| **UX / empty states** | Fresh-school reads return 200 empty (not 500/404); dashboards now render zero-state — **fixed** this run |
| **Performance** | Live reads respond within the cert's 45s ceiling; no N+1 observed in exercised paths (covered by Wave 5 p95 224ms cert) |
| **RBAC** | Teacher denied admin-only route (403); unauth → 401; disabled module → 403; plan-gated → 402 — all live |
| **Persistence** | Capabilities, subjects, module data, collections, exam results all persist and are re-read under RLS live |
| **API contracts** | Module gate (403 MODULE_DISABLED / 402 PLAN_UPGRADE_REQUIRED), empty-state 200, publish-gate 403 all match client expectations |
| **Multi-device** | Cross-persona (admin writes → parent reads) verified for fees + results |
| **AI fallback / available** | AI prefill returns a structured proposal for every board (200, never 500); deterministic fallback path is unit-tested (backend 857/0) |
| **Empty / disabled** | Disabled modules hidden + blocked; re-enable restores data — proven for all 6 modules |

---

## 9. Verdict

Akshara behaves correctly as a real ERP across small private, large CBSE, ICSE
and State-board schools, single-school organizations and multi-school trusts,
through the complete dynamic-module lifecycle and a full month of operations.
**One** genuine production gap (empty-state 404 on snapshot dashboards) was
found, fixed, deployed and re-verified live. No other genuine issues remain
within the simulated scope.

**Live total: 83 / 83** · analyze 0 · flutter 2440/0 · backend 857/0.

---

*Scripts:* `scripts/qa/live_cert_pilot_simulation.py` (new),
`scripts/qa/live_cert_full_journeys.py`,
`scripts/qa/live_cert_onboarding_dynamic_config.py`.
