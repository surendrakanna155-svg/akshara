# UXR — Principal Journey Log (Design System V2, Phase 4 module migration)

Presentation-only migration of the **Principal / school-leadership module screens**
to the DS V2 flagship look: the persona **premium canvas** (`AksharaPremiumBackground`,
**Admin/Principal = indigo `#6366F1`** accent) behind the standalone-Scaffold
screens, and the signature **`AksharaProgressRing`** wherever a screen has a
natural headline **score/percentage** rendered flat. This journey is **diagnostic,
not a blind wrap**: unlike Parent/Student, most management module screens already
route through the premium `AksharaDashboardCanvas` via `ManagementModuleScaffold`
and were already fully premium — those correctly needed **no change** (mirroring the
Phase-3 Principal Dashboard P3-4, where the only gap was a raw Material gauge).

The Principal **dashboard** (MG-01 `ManagementDashboardScreen`) was migrated in
Phase 3 (P3-4) and is out of scope here.

Branch: `worktree-agent-a546c2bd7ed925919` (repositioned onto the tip of
`feature/uxr-flutter-remediation` — see base-correction note).

Goldens: all new principal-module goldens live in the single new file
`test/golden/ds_v2_flagship_principal_modules_golden_test.dart` (Admin/Principal
persona theme, Light + Dark, leadership viewport `600x1400` — wider than a 390px
phone so these desktop-oriented screens read faithfully, still ≤ `mobileMax` 767 so
the clean card layouts render). Each of the 8 PNGs was visually confirmed premium,
cohesive-indigo and overflow-free before locking.

## Base-correction note
The isolation worktree was initially branched from the wrong lineage — the Jul-20
backend/ICA freeze commit `a806ee2c`, which lacks every DS V2 prerequisite
(`akshara_progress_ring.dart`, `premium/akshara_premium_background.dart`,
`persona_accents.dart`, the Phase-3 management dashboard + `ManagementModuleScaffold`).
Caught **before any work, tree clean**; repositioned this worktree branch onto the
correct uxr tip `19c47710` with `git reset --hard` (own throwaway branch only — no
switch/merge/rebase of any shared branch). All prerequisites verified present after
the reset. Every slice below sits on that correct lineage.

## Slices (screens that changed)

| # | Screen(s) | Path routing | Change | Ring? | Verification | Commit |
|---|-----------|--------------|--------|-------|--------------|--------|
| A | Office attendance (ATT-1/2/4/D1/D2) + Attendance corrections (P0-ATT-001) | standalone `Scaffold` | Persona **premium canvas** behind the body across all states (transparent Scaffold + `AksharaPremiumBackground`, `showMotif:false`) | No — attendance registers/corrections are honest tables + status chips, no headline % | analyze clean; `test/features/management/` **115/0**; goldens 4/4 (L+D) eyeballed | `bf655282` |
| B | School calendar (PRA-P1-17) | standalone `Scaffold` (view + permission-denied) | Persona **premium canvas** behind both Scaffolds (view-gated + main) | No — event list, no headline % | analyze clean; `test/features/management/` 115/0 (incl. calendar gating); goldens 2/2 (L+D) eyeballed | `2d255181` |
| C | Principal Command Center | standalone flat `Scaffold` | Persona **premium canvas** + **priority-engine score restructured into a signature `AksharaProgressRing`** (health-toned, mirrors the P3-4 dashboard health ring) replacing the flat "NN/100" list tile | **Yes** — priority-engine score /100 | analyze clean; route-guard + copilot-routing green; goldens 2/2 (L+D) eyeballed (ring reads 82, indigo) | `5e86812f` |

Total changed: **4 screens** (2 attendance + calendar + command), **1 new ring**,
**8 new goldens**.

## Screens that needed NO change (honest — already premium)
These route through `ManagementModuleScaffold` → `AdminContentScaffold` →
`AksharaDashboardCanvas(palette: management, watermark: chartTrend)`, i.e. the
premium canvas is **already present**, and they already use the premium management
vocabulary (`AksharaExecutiveKpiCard` KPI rows, `ManagementTrendChart`,
`ManagementSegmentPanel`, `AksharaSectionHeader`, floating cards, insight cards).
No raw Material headline gauge or flat 3-up strip exists to restructure — so, like
most of the P3-4 dashboard, the honest outcome is "no change needed". Double-wrapping
them in `AksharaPremiumBackground` would have created a double-canvas.

| Screen | Why no change |
|--------|---------------|
| Academics (MG-05) | Canvas present; premium KPI row + metric cards + subject table + at-risk list + insight cards |
| Analytics (MG-02) | Canvas present; premium KPI row + trend chart + segment panel + class-summary table |
| Finance (MG-04) | Canvas present; read-only banner + tinted revenue/expenses/net-profit **money** hero (money ceremony preserved) + premium **money** KPI row + P&L/cash-flow trend charts + drill links. **No collection-% metric on this screen** — that % lives on the dashboard (P3-4), so no ring candidate here |
| Performance (MG-06) | Canvas present; the Pass-Rate/Distinction %s are already **premium `AksharaExecutiveKpiCard` tiles** + class-performance table. Promoting a certified KPI tile to a ring would churn the premium KPI row |
| Admissions (MG-03) | Canvas present; premium KPI row + funnel (structural `LinearProgressIndicator` stage bars, already premium data-viz) + source-performance segment panel + conversions table |
| Tasks (MG-07) | Delegates to `PrincipalApprovalCenterScreen` (it *is* the approval center) |
| Settings (MG-08) | Canvas present; `AksharaSectionHeader`s + surface cards + list tiles; the only `CircularProgressIndicator` is a 16px inline save-button spinner |
| Principal Approval Center (M-D2) | Canvas present; already fully premium — KPI row, stale banner, digest card, unsubmitted-marks card, type filter, batch-action bar, queue table, detail panel, insight card. Has its own golden (`approval_center_golden_test.dart`) |

## Ring decisions (honest-state)
- **Principal Command — priority-engine score /100 → ring.** The score was a flat
  `"NN/100"` trailing text in a bare `ListTile`; restructured into an
  `AksharaProgressRing` in a premium surface card, **health-toned exactly like the
  P3-4 dashboard school-health ring** (primary ≥80 / tertiary ≥60 / error else). Same
  metric, same 0–100 scale, presentation only. The demo mock reads **82** → indigo
  primary arc.
- **Finance — no ring.** The finance module screen's hero shows **money**
  (revenue/expenses/net profit), not a %, and its KPIs are money values. The
  collection % (68%) is a **dashboard** metric (already premium on P3-4), absent from
  this screen — inventing a margin-% ring would fabricate a metric and touch the
  money ceremony. Left as-is.
- **Performance — no ring.** Pass Rate (89.4%) is already a premium
  `AksharaExecutiveKpiCard` tile in the KPI row (not a flat/Material gauge).
  Converting it would churn the certified premium KPI row — the P3-4 precedent
  explicitly left the executive KPI cards untouched.
- **Attendance / Calendar — no ring.** Registers, corrections, and event lists are
  honest tables / status chips with no single headline percentage; canvas-cohesion
  only, per the "don't force a ring" rule.

## Preserved (presentation-only)
Navigation architecture, workflows, providers, business logic, **RBAC gates**
(`viewSchoolCalendar` / `manageSchoolCalendar` add-event FAB + per-event delete;
approval-center approve/RBAC), **maker-checker / approval semantics** (attendance
corrections Pending/Approved chips; approval center batch-action, filters, stale
banner, unsubmitted-marks card, digest card), **export/PDF flows** (office-attendance
CSV/PDF on every tab), **honest-state** (teacher-submission card; "not submitted"
banners), **amber money ceremony** (untouched — every ₹ display on the finance screen
was left as-is), `QaTestKeys`, semantics/a11y, 48dp targets, AB/ML/DB semantics, and
every asserted widget type/text.

## Shared-file changes needed (deliberately NOT made)
None. Every change reused existing primitives (`AksharaPremiumBackground`,
`AksharaProgressRing`, `AksharaSurfaceCard`) via their existing barrels — no
`lib/shared/**`, theme, or cross-persona (`parent`/`student_app`/`teacher`) file was
touched.
