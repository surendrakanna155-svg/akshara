# AKSHARA — Final Completion Roadmap

**Date:** 2026-06-25
**Source of truth:** `docs/FINAL_COMPLETION_AUDIT.md` (issue IDs referenced below).
**Execution loop for every item:** `/gap-check → fix → /certify → /deploy → /release-review`.
**Rules:** No new features. No roadmap expansion. This roadmap only *sequences and closes the audit's findings* — it adds no scope.

> This is the remaining-work plan. It does not reorder the product roadmap (B1–B11 + P-series are done/frozen); it sequences the **completion gaps** the audit found. Effort tags: **S** <½d · **M** ½–2d · **L** 2+d. Totals are engineering estimates, not commitments.

---

## How to read this

Findings are grouped into **6 execution waves** ordered by *risk-to-trust* and *unblock-value*, not by module. Each wave is a coherent batch you can `/gap-check` as a unit, fix, then `/certify` + `/deploy` + `/release-review` together. **Wave 0 is a 30-minute prerequisite** that de-risks the rest (it tells you which "404" findings are real vs deployed-edge artifacts).

| Wave | Theme | Items | Severity mix | Est. |
|------|-------|-------|--------------|------|
| ~~**0**~~ | ~~Verify-vs-deployed-edge + restore green gates~~ | 9 | gate/triage | ✅ **DONE 2026-06-25** |
| ~~**1**~~ | ~~Stop silent data loss (mock writes in live paths)~~ | 7 | 2C + 4H + 1M | ✅ **DONE 2026-06-25** |
| ~~**2**~~ | ~~Multi-child parent correctness + demo-identity purge~~ | 14 | 5H + 6M + 3L | ✅ **DONE 2026-06-26** (live 21/21) |
| ~~**3**~~ | ~~Contract gaps + entitlement client + security hardening~~ | 13 | 7H + 4M + 2L | ✅ **DONE 2026-06-26** (live 30/30) |
| ~~**4**~~ | ~~AI moderation gate + performance~~ | 6 | 2H + 3M + 1L | ✅ **DONE 2026-06-26** (live 20/20) |
| ~~**5**~~ | ~~UX consistency, a11y, Play Store custody, docs~~ | ~25 | 2H + many M/L | ✅ **DONE 2026-06-26** (live 15/15) |

---

## Wave 0 — Prerequisite: triage + restore gates ✅ **COMPLETE (2026-06-25)**

> **Status: DONE.** Cert: `docs/WAVE0_TRIAGE_AND_GATES_CERTIFICATION.md`. Release-review verdict: **GO**. All exit criteria met. No deploy required (non-deploying gates wave). Commit: see cert doc.
> Result gates: `flutter analyze` **0 issues** (was 105) · `flutter test` **2383 passed / 1 skipped / 0 failed** (was +7 failed) · `deno test` **665 passed / 0 failed / 2 ignored** (was +1 failed) · CI hardened to `--fatal-infos`.

| Order | ID | Action | Status |
|------:|----|--------|--------|
| 0.1 | STF-1..5, SUP-2, INT-2 | Verify finance routes vs deployed VPS edge. | ✅ Verified against live `/opt/akshara/functions` (2026-06-25): offline/QR/defaulters/reports/settings/scholarship routes + `GET /finance/discounts` **confirmed absent on live** → **all stay real Wave-3 build items** (tag `[verify-vs-deployed-edge]` removed; now confirmed). |
| 0.2 | TST-1 | Resolve SIS mock-count drift. | ✅ Placeholder (`SIS-STU-PLH-0001`, `isPlaceholder`) is an **intended** onboarding feature (rendered specially in the registry); asserts updated 10→11 in `repository_test.dart:59` + `sis_providers_test.dart:46`. |
| 0.3 | TST-2 | Regenerate 5 stale goldens. | ✅ Diff confirmed a localized intended design shift (dashboard bottom bar); regenerated `parent_dashboard_*` (×3), `dark_parent_dashboard_390x844`, `dark_admin_hub_834x1194`. |
| 0.4 | SEC-7/PRN-2 | Make the approval deno test runnable. | ✅ `approval_router_test.ts` now uses a self-contained `AppConfig` literal (no `loadConfig()`/env) → no cross-file env leak; `tenant_isolation_*` correctly stay ignored. |
| 0.5 | analyze | Clear all analyze issues. | ✅ 105 → **0** (`dart fix` sweep across 53 files + 1 manual `context.mounted` guard for `use_build_context_synchronously` + `value:`→`initialValue:` for 8 deprecated `DropdownButtonFormField`). |
| 0.6 | TST-4 | Enforce gates in CI. | ✅ CI already ran all three (`flutter_ci.yml`→`run_ci_gates.sh`, `backend_staging.yml`→`deno test`); **hardened** Gate 1 to `flutter analyze --fatal-infos` so the 0-issue bar is enforced and lint drift can't recur. |

**Exit criteria:** ✅ `flutter analyze` 0 issues · ✅ `flutter test` green · ✅ `deno test` green · ✅ CI enforcing all three · ✅ finance findings re-classified (confirmed real).

---

## Wave 1 — Stop silent data loss (Theme A) ✅ **COMPLETE (2026-06-25)**

> **Status: DONE & live-certified.** Cert: `docs/WAVE1_COMPLETION_CERTIFICATION.md`. Release-review: **GO**. Live cert 8/8 vs VPS pilot; deployed (migration `20260731000000` + edge recreate). Gates: analyze 0 / flutter 2383 / deno 665.
> TCH-1 ✅ (POST /teacher/homework persists + delivers) · TCH-2 ✅ (compose-send wired) · TCH-5 ✅ (remarks persist; role-slot + authorRole fixes) · STF-7 ✅ (HR reports + real export) · STF-8 ✅ (5 settings edits hidden — no write path) · CORE-2 ✅ (/branches chain-gated) · CORE-1/PAR-4 ✅ (PTM gated off via SchoolBuildScope; **backend build remains** as the deferred half of this item).

The highest-trust risk: actions that report success but never persist. Both Criticals live here.

| Order | ID | Action | Sev | Effort |
|------:|----|--------|:---:|:---:|
| 1.1 | **TCH-1** | Wire teacher **homework-create** to a real `createHomework` on `TeacherRepository` → API → audit → invalidate; remove the in-memory `SchoolHomeworkStore` write. Verify it reaches student/parent reads. | **C** | M |
| 1.2 | **TCH-2** | Wire teacher **compose-message send** to `sendTeacherMessageProvider`; remove the no-op/`"(mock)"` path. | **C** | M |
| 1.3 | TCH-5 | Add a remark method to `ExamAdministrationRepository` and persist exam leadership/student remarks to the backend (visible cross-device/role). | H | M |
| 1.4 | CORE-1 / PAR-4 | Decide Parent Meetings (PTM): build the minimal backend + `ApiParentMeetingsRepository` **or** gate the route off until built. (No new scope — it's already a shipped, reachable route.) | H | M |
| 1.5 | STF-7 | Wire HR Reports to `hrRepositoryProvider` (drop `HrReportsData.mock()`); decide export-pipeline scope (connect or honestly disable the 11 preview-only export buttons). | M | M |
| 1.6 | STF-8 | Make "Settings → Edit" persist in the 5 preview-only modules (HR/transport/alumni/control-center settings + roles), or hide edit where no write path exists. | M | M |
| 1.7 | CORE-2 | Branch/Franchise: confirm `SchoolBuildScope`/`ChainScope` fully hides them for pilots; if so, leave as documented chain-only deferral; if any chain org is live, build the API path. | M | L |

**Certify:** each via a `scripts/qa/live_cert_*.py` proving the write lands in the real DB and surfaces to the consuming persona. **Deploy + release-review** the wave together.

---

## Wave 2 — Multi-child correctness + demo-identity purge (Themes B + C) (~3–4 days)

> **Status: ✅ PRODUCTION CERTIFIED (2026-06-26).** Cert: `docs/WAVE2_COMPLETION_CERTIFICATION.md`. Release-review: **GO**. Live cert **21/21** vs VPS pilot (`scripts/qa/live_cert_completion_wave2.py`); deployed (2 edge files `auth_context.ts` + `auth_handlers.ts` rsynced + `akshara-edge` restarted; **no migration**). Gates: analyze 0 / flutter 2383 / deno 665 / deno check clean. All 14 items closed.
>
> Per-item: PAR-1 ✅ (child-scoped `parentRepositoryQueryProvider` + datasource emits `activeChildId` on every read) · PAR-2 ✅ (`selectParentActiveChild` now invalidates the full per-child set + syncs the profile child id) · PAR-3 ✅ (leave files against the active child) · PAR-6 ✅ (dashboard `forActiveChild` drops the `isPriya` demo branch; receipts header from active child) · PAR-7 ✅ (backend enriches login/`/auth/me` with `children:[{id,name,classLabel}]`; client maps real name/class) · PAR-8 ✅ (transport resolves the active child, no `items.first` fallback) · PAR-9 ✅ (notices/events/leave header child + real unread). TCH-4 ✅ (4 teacher subtitles from `resolvedTeacherTeachingContextProvider`) · TCH-6 ✅ (leave `(mock)` removed) · TCH-7 ✅ (`seedDemoSubjectConcernIfNeeded` deleted) · TCH-8 ✅ (homework-create blank, class/subject prefilled from real assignment) · TCH-9 ✅ (real per-weekday dates) · UX-9 ✅ (HR caption de-named) · PRN-3 ✅ (approval actor fails closed) · CORE-3 ✅ (API-mode-gated assert against the demo-tenant fallback) · STU-6 ✅ (honest AI-tutor CTA) · STU-7 ✅ (`join_class` removed).

One persona class (multi-child parents) sees wrong data; demo names leak across surfaces. Mostly small, high-visibility fixes.

| Order | ID | Action | Sev | Effort |
|------:|----|--------|:---:|:---:|
| 2.1 | **PAR-1** | Send `activeChildId` on every parent read (`_queryParams`); stop relying on the backend `child_ids[0]` default. | H | M |
| 2.2 | PAR-2 | On child-switch, invalidate fees/exams/receipts/attendance/homework/timetable/notices/events providers (not just dashboard/profile). | H | S |
| 2.3 | PAR-3 | Leave-submit uses the active child, not hardcoded `child_ravi`. | H | S |
| 2.4 | TCH-4 | Replace hardcoded `"Priya Sharma · Mathematics"` app-bar subtitles (4 screens) with real auth context. | H | S |
| 2.5 | PAR-6 | Drive receipts/dashboard header (`childName`/`childClass`/unread) from the real child, not `'Ravi Kumar'`/`'8-A'`. | M | S |
| 2.6 | PAR-7 | Build real-auth linked children with real name/class (not `name:'Child'`). | M | M |
| 2.7 | PAR-8 | Transport allocation: resolve active child from real registry; remove `items.first` wrong-child fallback. | M | M |
| 2.8 | PAR-9 | Notices/events header child + unread badge from real data. | L | S |
| 2.9 | TCH-6 | Remove `"(mock)"` strings from production success snackbars. | M | S |
| 2.10 | TCH-7 | Remove `seedDemoSubjectConcernIfNeeded()` demo-injection from `build()`. | M | S |
| 2.11 | TCH-8 | Drop demo defaults from the homework-create form. | M | S |
| 2.12 | PRN-3 | Approval actor fails closed (no synthetic `'principal_001'`). | L | S |
| 2.13 | CORE-3 | Add a defensive guard/assert instead of silently shipping `TenantContext.demo`. | L | S |
| 2.14 | UX-9 / STU-6 / STU-7 / TCH-9 | Purge remaining hardcoded sample names + static AI-insight text + the non-functional `join_class` action + the date-"1" timetable chips. | L | S |

**Certify:** multi-child live cert (two-child parent token; assert each child's data is distinct and switch-correct). **Deploy + release-review.**

---

## Wave 3 — Contract gaps + entitlement client + security hardening (Themes D + I + F) ✅ **COMPLETE (2026-06-26)**

> **Status: DONE & live-certified.** Cert: `docs/WAVE3_COMPLETION_CERTIFICATION.md`. Release-review: **GO**. Live cert **30/30** vs VPS pilot (`scripts/qa/live_cert_completion_wave3.py`); deployed (20 edge files + migrations `20260801`/`20260802` + `COMMUNICATION_WEBHOOK_SECRET`). Gates: deno check clean / deno test 672 / flutter analyze 0. All 13 items closed.
>
> Per-item: SEC-1 ✅ (HMAC `x-akshara-signature` + tenant-from-row + columns/status fix — webhook was previously non-functional) · SUP-1 ✅ (flag on) · SUP-2 ✅ (superAdmin assign 200 / non-super 403) · STF-4 ✅ · STF-1 ✅ (record/list/reconcile) · STF-2 ✅ (create/get/confirm) · STF-3 ✅ (defaulters/reports/settings) · STF-5 ✅ (scholarships) · INT-2 ✅ (real `guardianPhone`) · SEC-2 ✅ (comm mutation audits) · SEC-3 ✅ (parent child-scope guard) · SEC-5 ✅ (saveStep + resetRoleLayout audited) · SEC-4/SEC-6 ✅ (parent RLS + rbac inventory + hardened test).

Depends on Wave 0.1 triage. Build only the routes confirmed absent; flip the entitlement client on; close the one fail-open route.

| Order | ID | Action | Sev | Effort |
|------:|----|--------|:---:|:---:|
| 3.1 | **SEC-1** | Add auth/HMAC shared-secret to `POST /communications/delivery/webhook`; derive tenant from the verified payload, not hardcoded UUIDs. (Highest security item.) | H | M |
| 3.2 | SUP-1 | Add `ENTITLEMENT_API_ENABLED:true` to `live_release.json`; verify plan ceiling, badges, G6a/b/c upgrade UX, and the plan-catalog populate. | H | S |
| 3.3 | SUP-2 | Confirm the super-admin Organization-Plan-Assignment screen works once SUP-1 is on (server route already exists). | H | S |
| 3.4 | STF-4 | Add `GET /finance/discounts` (read) if confirmed absent in 0.1. | H | S |
| 3.5 | STF-1 | Build/confirm offline-payment record/list/reconcile routes. | H | M |
| 3.6 | STF-2 | Build/confirm QR/UPI payment-session routes. | H | M |
| 3.7 | STF-3 | Build/confirm defaulters/reports/settings finance routes. | H | M |
| 3.8 | STF-5 | Build/confirm scholarship create/update routes. | M | M |
| 3.9 | INT-2 | With `/finance/defaulters` live, wire the defaulters WhatsApp surface to real numbers. | M | M |
| 3.10 | SEC-2 | Add `emitMutationAudit` to communication mutations (createBroadcast, send-message, mark-read, device-token, webhook). | M | M |
| 3.11 | SEC-3 | Add a `claims.child_ids` check (and `scope==="parent"` assert) in `parent_experience_handlers` for defense-in-depth. | M | S |
| 3.12 | SEC-5 | Audit `handleSaveStep` + `handleResetRoleLayout` writes. | L | S |
| 3.13 | SEC-4 / SEC-6 | Add parent-scope RLS to `intel_parent_guidance_reports`; complete `rbac_route_inventory.ts` (predictions/director/org-builder/subscriptions/webhook/widgets) and make the validation test assert live routers. | L | M |

**Certify:** finance peripheral live cert + entitlement client live cert + a security cert proving the webhook rejects unauthenticated calls and broadcasts are audited. **Deploy** (mind migrations forward-only + `erp_tenant` no-DELETE). **Release-review.**

---

## Wave 4 — AI moderation gate + performance (Themes E + perf) (~3 days)

| Order | ID | Action | Sev | Effort |
|------:|----|--------|:---:|:---:|
| 4.1 | **AI-1** | Exclude `review_status='rejected'` (and unmoderated) items from `getQuestionPaperWithItems`/`paperExportDocument`; make the publish gate + export honor moderation state. | H | M |
| 4.2 | AI-2 | Gate `handleExportQuestionPaper` on publish/moderation state (not just `viewEducation`). | M | S |
| 4.3 | **PERF-1** | Batch/bound broadcast dispatch — cap + batch-insert recipients; move per-recipient send out of the synchronous request (queue/async). | H | M |
| 4.4 | PERF-2 | Add debounce to the SIS registry search. | M | S |
| 4.5 | AI-3 | Switch publisher caption enhancer to `resolveAiConfig(db,orgId)`. | L | S |
| 4.6 | AI-5 | Fix `bankReuseCount`/`aiGeneratedCount` parsing (read from `blueprint`). | L | S |

**Certify:** AI cert proving a rejected item never appears in export; a perf cert for a large-cohort broadcast (no timeout). **Deploy + release-review.**

---

## Wave 5 — UX consistency, a11y, Play Store custody, docs (Themes H + J + cleanup) ✅ **COMPLETE (2026-06-26)**

> **Status: DONE & live-certified.** Cert: `docs/WAVE5_COMPLETION_CERTIFICATION.md`. Release-review: **GO**. Live cert **15/15** vs VPS pilot (`scripts/qa/live_cert_completion_wave5.py`); deployed (migration `20260803000000` + 4 edge files). Gates: analyze **0** / flutter **2389 passed** / deno **680 passed**.
> Per-item: **UX-1** ✅ (46 raw `Text('Error: $e')` + 46 raw-leak `AksharaErrorState(message:'$e')` → `AksharaErrorState.fromFailure(apiFailureMapper.fromException(e))` with retry; no raw exception reaches users) · **UX-2** ✅ (raw `Theme.of(context).textTheme` → `context.aksharaText`) · **UX-3** ✅ (bare full-screen spinners → `AksharaLoadingState`) · **UX-4** ✅ (bare empty placeholders → `AksharaEmptyState`) · **UX-5** ✅ (status `Colors.red/green/orange` → `context.colors.error`/`context.akshara.success`/`.warning`) · **UX-6** ✅ (tooltips on icon-only `IconButton`s) · **UX-7** ✅ (104 files: magic-number `EdgeInsets` → `AksharaSpacing` tokens, value-identical) · **UX-8** ✅ (checkbox tap target restored to 48dp) · **PLY-3** ✅ (minSdk 24 / targetSdk 36 / compileSdk 36 pinned) · **NOT-1** ✅ (per-audience `data.route` deep links on the publisher fan-out; migration adds `notification_deliveries.route`) · **PERF-4** ✅ (cold-start instrumentation in `main.dart` + **live p95 224ms** measured in the cert) · **TST-3** ✅ (live-mode Patrol harness capability `kPatrolLiveEnvironment`; 3 P0 flows covered by `scripts/qa/live_cert_full_journeys.py` at the API layer) · **STF-6** ✅ (dead hostel download buttons honestly disabled) · **NOT-3** ✅ (stale push-not-wired doc corrected) · **AI-4** ✅ (`imageGenerationReady` flag now honest) · **PLY-4** ✅ (`ic_launcher_round` added). **Owner-gated (surfaced, not engineering-closable):** **PLY-1** (privacy-policy legal entity/address/grievance email) · **PLY-2** (release keystore custody). **By-design / documented (no code change):** CORE-4, SUP-3/4, MKT-1/2/3, INT-1/3, NOT-2, STF-9, PERF-3, TST-5.

Polish-and-prove tail. The one High (UX-1) leads.

| Order | ID | Action | Sev | Effort |
|------:|----|--------|:---:|:---:|
| 5.1 | **UX-1** | Replace hand-rolled `Text('Error: $e')` with `AksharaErrorState` (retry + no raw exception leak) across ~42 screens. | H | M |
| 5.2 | PLY-1 | Fill privacy-policy legal placeholders (entity, address, grievance/contact email) — **owner-gated content**. | H | S |
| 5.3 | PLY-2 | Generate + custody the release upload keystore (`android/key.properties`) before first AAB — **owner-gated**. | H | S |
| 5.4 | UX-3 | Standardize full-screen loading on `AksharaLoadingState` (~83 screens). | M | M |
| 5.5 | UX-4 | Standardize empty states on `AksharaEmptyState` (~6 screens). | M | S |
| 5.6 | UX-5 | Replace off-system `Colors.*` status colors with tokens (34 instances). | M | S |
| 5.7 | UX-6 | Add tooltips/Semantics to ~26 icon-only IconButtons. | M | S |
| 5.8 | UX-2 | Migrate 54 raw `textTheme` usages to `context.aksharaText`. | M | M |
| 5.9 | PLY-3 | Pin minSdk/targetSdk/compileSdk; confirm targetSdk ≥ Play minimum. | M | S |
| 5.10 | NOT-1 | Populate `data.route` on enqueue paths for per-event deep links. | M | M |
| 5.11 | PERF-4 / TST-3 / TST-5 | Add cold-start + live-p95 measurement; add at least the 3 PARTIAL P0 Patrol journeys against a live/staging backend. | M | L |
| 5.12 | UX-7, UX-8, STF-6, STF-9, MKT-2/3, NOT-2/3, INT-1/3, AI-4, SUP-3/4, PLY-4 | Long-tail Low items: spacing tokens, checkbox tap target, dead hostel download buttons, doc-staleness fixes, owner-gated/by-design notes, iOS push deferral. Batch as a single cleanup `/gap-check`. | L | M |

**Certify:** UX/a11y spot cert + a clean `/release-review` go/no-go on the full build. **Deploy** release build once PLY-1/PLY-2 owner items land.

---

## Dependency notes

- **Wave 0.1 gates Wave 3** (STF-1..5, INT-2): don't build routes that already exist on the live edge.
- **SUP-1 → SUP-2** (entitlement client flag unblocks the plan-assignment screen).
- **STF-3 (/finance/defaulters) → INT-2** (defaulters WhatsApp).
- **CORE-1 ≡ PAR-4** (same PTM root) — fix once.
- **Owner-gated** (cannot be closed by engineering alone): PLY-1, PLY-2, MKT-1/INT-1 (Meta App Review + secrets), NOT-2 (iOS APNs). Surface these to the owner early so they run in parallel.

## Definition of done (GA gate)

GA is reached when: all **Critical + High** closed and certified live; `flutter analyze` 0 issues + `flutter test`/`deno test` green in CI; finance contract findings resolved against the deployed edge; SEC-1 closed; multi-child parent cert green; AI-1 cert green; and `/release-review` returns **GO** with real N/N evidence. Medium/Low may trail GA as a documented punch-list, except PLY-1/PLY-2 which block the store upload.
