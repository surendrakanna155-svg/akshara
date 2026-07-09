# Gap-Sweep Certification — Final Gap-Discovery → Fix Wave

**Date:** 2026-07-09 · **Branch:** `feature/data-reliability-platform` · **Tip:** descendant of `ad28f603` (fix wave `bc8b0b58 → 6416a742`, closure `4715858f`, P2 pass this session) · **Governing law:** `docs/engineering/AKSHARA_ENGINEERING_CONSTITUTION.md` Part 7B (Certification Engine) + Part 8 (EOS).

This certifies the **final gap-discovery sweep CLOSED**: every P0 and P1 it found is fixed, built (no stubs), tested, and integrated onto the feature tip, and the full regression is green. It supersedes the interim "closed" note in `docs/execution/GAP_REMEDIATION_WAVE.md`.

---

## 1. What the sweep found and did

A verify-first gap-discovery pass over the ERP found **3 P0** (broken production flows), **7 P1** (shipped actions that always fail), and a **P2** cleanup list. Owner directive: **fix all P0+P1 now and BUILD the missing backends** (complete the feature, don't stub), then P2 cleanup. Each candidate was traced to a *reachable* broken behavior before any code was touched — the sweep **discarded 4 false positives** (below). All P0+P1 are now closed; the P2 pass ran this session.

## 2. P0 — broken production flows (ALL FIXED + BUILT)

| # | Defect (reachable) | Fix (built, not stubbed) | Evidence |
|---|---|---|---|
| P0-1 | Student app dashboard/attendance/exams/timetable/profile **404 for every real student** — `createStudentScopedReadHandlers` hard-404'd on `SnapshotNotFoundError` while parent/teacher had a default-snapshot fallback; student was missed. | Student scope now builds a default snapshot from `students`/`sis_student_enrollments` then overlays live data (parity with parent/teacher). | `622e6341` · `student_default_snapshot_fallback_test.ts` (+335) |
| P0-2 | **5 timetable-workforce endpoints missing** → SubstituteManager / TeacherReassignment / TimetableOptimization screens 404 (client models existed, no server). | Built all 5 handlers (`optimize/apply`, `substitute/coverage`, `substitute/assign`, `reassign/options`, `reassign`) + registered in `school_completion_router.ts` with RBAC (`manageAcademicTimetable`/`viewTimetableOptimization`) + audit. | `e02faa2f` · `timetable_workforce_service_test.ts` (+319), `timetable_optimization_service_test.ts`, route-contract |
| P0-3 | **Inventory-replacement RLS inconsistency** — parent-scope RLS blocked the `replacement_status` UPDATE on `inv_student_distributions` while a `payment_request` committed → split state; `updated[0]!` masked the empty result. | Corrected the write path + scope so the status change and the payment stay consistent under RLS; removed the masking non-null assert. | `bc8b0b58` · migration `20260864000000_inventory_replacement_parent_write_scope.sql` · `inventory_distribution_replacement_repository_test.ts`, route-contract |

## 3. P1 — shipped actions that always failed (ALL FIXED + BUILT)

| # | Defect (reachable) | Fix | Evidence |
|---|---|---|---|
| P1-4 | Admissions Fee-Handoff picker → `GET /admissions/fee-structures` **404** (blocks admission→finance). | Added the GET (reuses finance fee-structures data), registered in `admissions_router.ts`, `viewAdmissions`. | `4cef88e3` · `admissions_fee_structures_test.ts` (+75) |
| P1-5 | Alumni Reports **key mismatch** — backend emitted `eventAttendance`; client read `eventAttendanceTrend`+`engagementByBatch` (never emitted) → charts always empty. | Aligned keys + added `engagementByBatch` aggregation in `computeAlumniReports`. | `4cef88e3` · `alumni_read_repository_test.ts` (+57) |
| P1-6 | Operations Hub Dismiss/Complete → `/operations/hub/alerts/:id/dismiss` + `/operations/hub/actions/:id/complete` **404**. | Built both POST routes + handlers (RBAC `manageManagement`+`viewOperationsHub` + audit + persisted state that `buildOperationsHub` reads back). | `6416a742` · migration `20260865000000_operations_hub_item_actions.sql` · `operations_hub_service_test.ts`, `qw4_operations_route_contract_test.ts` (+102) |
| P1-7 | Parent→teacher message → `POST /parent/messages` **404** (only `/parent/messages/send` existed). | Added the route (aligned client↔server path). | `10e4b5f5` · `parent_router_test.ts`, `communication_route_parity_test.ts` |
| P1-8 | Parent communication **acknowledge/read 404** → consent never acknowledgeable. | Added `POST /parent/communication/:id/read` + `/acknowledge` (persist + audit). | `10e4b5f5` · `parent_communication_ack_test.ts` (+117) |
| P1-9 | WhatsApp stub **fabricated delivery success** (unconfigured schools saw 100% delivery). | `sendWhatsAppMessage` now returns `success:false`/"unconfigured" for the stub; never records "sent". | `10e4b5f5` · `whatsapp_providers_test.ts`, `whatsapp_repository_test.ts` |
| P1-10 | Onboarding invite marked 'sent' but never delivered + `OnboardingHubScreen` orphaned. | Invite only becomes 'sent' after a real WhatsApp launch confirms; wired a reachable invite action; retired the orphan into a reachable flow. | `6416a742` · `onboarding_hub_screen_test.dart` (+126), `qw3_unified_onboarding_flow_widget_test.dart` |

## 4. Verify-first — false positives discarded (the policy earning its keep)

**Gap-discovery pass (4):** Management "hidden module" (module IS built — a dead placeholder builder misled the audit), mgmt-resolve dead code, SIS academic-assignment deprecated route, admissions generate-number. Each traced to a *dead* or *already-correct* path, not a reachable defect — **not** touched.

**P2 pass this session (reclassified from the candidate "dead code" list):** `vault-rotate`, `school-calendar`, `social` router, `memories/analytics`, `setup-wizard` GET-by-id, and `widgets/data/refresh` were each verified **reachable + RBAC-gated + working, just no-UI-yet** (several are certified backend endpoints or covered by route-contract tests, e.g. setup-wizard GET by `QA-B-008`). Removing them would delete working capabilities and/or churn certified tests for no gain — **KEEP**. The "orphaned catalog widgets" candidate was a false positive (`_WidgetCatalogList` is reachable via a routed, menu-linked screen). Only **one** item was genuinely orphaned dead code (below).

## 5. P2 cleanup — outcome (this session)

| Item | Action | Evidence |
|---|---|---|
| **`student_profiles` / `student_guardians` student-scope read** (new; most important) | Added additive student-scope `FOR SELECT` RLS policies so a logged-in student reads their OWN profile/guardian rows (fields were silently empty — root cause self-documented at `pilot_operations_repository.ts:1297`). Mirrors the certified `20260703100000`/`20260706000000` house pattern; existing policies untouched. | migration `20260866000000_student_profile_guardian_student_read_rls.sql` |
| **Salon/Hospital vertical-pack picker** | Gated to the school pack only (Akshara is education-only) — UI filter (`_kSupportedVerticalPackTypes`) **and** backend `listPacks` `WHERE type='school'` (defense-in-depth); existing interview drafts stay reopenable. | `organization_builder_hub_screen.dart`, `organization_builder_repository.ts`, hub-screen test updated · org-builder deno 14/14 |
| **Report-card PDF hardcoded school name** (parent + student) | Backend `overlayExamsSnapshotFromResults` now emits real `schools.name`; mappers/models/providers thread it; both report-card screens use it (neutral `'School'` fallback, never a hardcoded specific name). | `pilot_operations_repository.ts` + 8 client files · deno parent/student/entity_read 62/0, pilot 127/0, flutter exams 16/0 |
| **Orphaned `DynamicDashboardScreen`** | Removed the screen + its 3 exclusive providers (no route, no caller, no test — superseded by `DynamicWidgetRuntimeScreen`). | file deleted + `evolution_providers.dart` |
| **DS-enforcement regression** (found during re-cert) | The P0/P1 wave's OnboardingHubScreen fix had added 4 raw `TextStyle(…)` in `lib/features`, tripping the P2-UX-3 ratchet (the ONE full-suite failure). Migrated to `context.aksharaText`/`context.colors` tokens. | `onboarding_hub_screen.dart` · DS test 3/3 |

## 6. Regression evidence (green)

| Suite | Result |
|---|---|
| deno `_shared` full | **2409 passed / 0 failed** (3 ignored) |
| `flutter analyze` (whole project) | **0 issues** |
| full `flutter test` | **3766 passed / 0 failed** (1 skipped) |
| Targeted (this session) | org-builder deno 14/0 · deno parent/student/entity_read 62/0 · deno pilot 127/0 · flutter exams 16/0 · onboarding 44/0 · DS enforcement 3/3 |

## 7. EOS gate verdict

**PASS.** All P0 + P1 fixed, built (no stubs), tested, integrated; full regression green; P2 cleanup done with verify-first reclassification. No open P0 and no Part-7B automatic-failure condition in scope.

**Tracked residuals (owner-gated / live-lane):** live deploy of this session's backend + migrations `20260863–20260866` to `akshara-edge`, the `finance_fee_reductions` live cert, COM-4 cron + off-site R2 activation — all **blocked on the owner opening the SSH ControlMaster socket** (recipe staged in `docs/engineering/eos/GAP_SWEEP_DEPLOY_AND_LIVECERT_CHECKLIST.md`). P3 Adaptive AI + P1-CODE-4/6/7/8 remain owner-gated. `student_profiles` still has no *parent* read branch (deliberate; student-only was the ask).
