# AKSHARA — Journey Wave 3 Completion Certification

**Status:** ✅ **PRODUCTION CERTIFIED (2026-06-26) — live 34/34**
**Wave:** MODULE_JOURNEY_ROADMAP **Wave 3** — "Static-snapshot read modernization — apply the live-overlay/recompute framework to the remaining personas/admin dashboards."
**Scope source of truth:** `docs/MODULE_JOURNEY_AUDIT.md` (issue IDs) + `docs/MODULE_JOURNEY_ROADMAP.md` (Wave 3). No new features, no roadmap expansion — this only closes the audit's Wave-3 findings.
**Live cert:** `scripts/qa/live_cert_journey_wave3.py` → **34/34** against the live VPS pilot (`https://akshara.veloraunisexsalon.com`) with real pilot OTP auth (admin/teacher JWTs), real RBAC, real DB rows, and real write→read aggregation cycles.

---

## 1. Verdict

**PRODUCTION CERTIFIED.** All **6 Wave-3 findings** (2 Critical, 2 High, 2 Medium) are closed at the true root cause. Every modernized read — the teacher's roster/marks/leave/dashboard, the principal's six executive dashboards, the HR dashboard, the alumni dashboard + profile, and the library dashboard/fines/reports/members — **no longer serves a frozen migration seed**. Each one now **computes from the real live tables inside the caller's tenant RLS context**, so it reflects actual data and the module's own writes, with honest zeros/empties for a fresh school instead of seed fiction.

This wave was the single largest systemic *trust* gap in the audit: real users were shown identical hardcoded numbers (every school saw ₹2.4Cr revenue, 87% collection, 148 employees, 2,400 alumni, ₹12.4L donations, a fabricated "Tech Corp" employment record, and a canned "Teacher attrition risk… Priya Sharma" AI insight). After Wave 3 those surfaces tell the truth.

The work was executed by **five parallel agents over disjoint backend modules** (teacher, management, HR, alumni, library), then integrated, gated, deployed, and live-certified centrally. Three offline gates are green with **zero regression**, and the live cert is **34/34** against the deployed VPS pilot.

**Live cert caught a real defect the offline gates could not:**
- **`GET /teacher/attendance/classes` returned HTTP 500 on the live DB** — the new `listTeacherAttendanceClasses` aggregate used a correlated sub-select referencing `ts.organization_id`/`ts.school_id`, which are **not in the `GROUP BY`** (`subquery uses ungrouped column "ts.organization_id"`). The module's mock-DB unit tests passed because a fake DB does not enforce Postgres `GROUP BY` semantics (this is exactly the audit's **TEACH-6** finding — mock tests mask live-only failures). Fixed by binding the subquery to the query parameters `$1`/`$2` (which equal those columns) instead of the ungrouped columns. Re-deployed and re-certified to **34/34**. **The live write→read cycle is what proved it.**

**Deploy:** 18 edge `_shared` files synced to the VPS host bind-mount (`/opt/akshara/functions/_shared`), edge container restarted, `/health` ok. **No migrations** — every recompute reads tables that already exist and already grant `erp_tenant` SELECT; no schema or seed change was required.

**Headline trust win:** a teacher's dashboard/roster/marks/leave now reflect their real classes and their own writes; a principal's executive dashboards show the school's actual revenue/collection/funnel/pass-rate (computed from the same live finance/admissions sources as the certified finance & admissions dashboards) instead of a universal seed; HR reports the real headcount (3, not 148) with a real Claude-or-deterministic insight; alumni counts and donation totals aggregate live (adding one alumnus moves the dashboard count by one); the alumni profile shows real/honest-empty employment & events instead of a fabricated "Tech Corp"; and library KPIs/fines/active-loans recompute from live entity rows.

---

## 2. Gate results

| Gate | Result | Baseline | Δ |
|------|--------|----------|---|
| `flutter analyze` | **0 issues** | 0 | — |
| `flutter test` | **2389 passed / 1 skipped / 0 failed** | 2389 | no regression (no Dart changes) |
| `deno test _shared/` | **790 passed / 0 failed / 2 ignored** | 742 | **+48 new Wave-3 tests** |
| Live cert (`live_cert_journey_wave3.py`) | ✅ **34/34** vs live VPS pilot | — | real auth + RBAC + write→read aggregation |

The +48 deno tests are recompute/overlay unit tests (teacher, management, HR, alumni, library), each asserting empty-data ⇒ honest zeros/empty and with-data ⇒ real aggregates. **Note:** mock-DB unit tests cannot reproduce Postgres `GROUP BY`/grouping-error semantics — the **live cert is the authoritative gate** for the SQL aggregates (it caught the `/teacher/attendance/classes` 500 the unit tests passed over).

---

## 3. Item-by-item closure

| ID | Module | Sev | What was wrong (seed fiction) | Fix (now computes from) | Live evidence (34/34) |
|----|--------|-----|----------|-----|----------|
| **MJ-C7** | Teacher | 🔴 Critical | Roster/classes, upcoming exams, exam marks, leave history and dashboard were static `teacher_entities` seed (only timetable was overlaid); roster came back empty seed, dashboard tasks/insight canned. | New read-overlays in `pilot_operations_repository.ts` + new handler seams in `mobile_read_handlers.ts`, scoped to the teacher's `sub`: classes/roster ← `timetable_slots` ⋈ `sis_student_enrollments` ⋈ `attendance_sessions`; upcoming exams ← `exam_sessions`; marks ← `exam_mark_entries`; leave ← `mobile_leave_requests`; dashboard pendingTasks/insight ← today's unmarked classes + pending homework reviews. | All 6 reads 200 + well-formed; dashboard has real `pendingTasks` list + computed `aiInsight`; roster is a real `studentsByClass` map (live enrollment overlay). |
| **MJ-C8** | Principal | 🔴 Critical | The 6 management exec dashboards served the never-refreshed `management_entities` seed — identical ₹2.4Cr/₹45L/87%/120-45-38/98%-94% for every school. | New `management_aggregate_repository.ts` + `management_payload_builders.ts`; the 6 handlers recompute under `withTenantContext`, **reusing the already-live finance & admissions dashboard repos** plus a new academic aggregate (attendance + exam marks). Honest 0/empty where no source table exists yet (expense ledger, history trends). | All 6 reachable + computed (200); **no seed sentinels** in dashboard/funnel/financial-health/academic-health; financial-health derives from the same live finance source as `/finance/dashboard`. |
| **MJ-H17** | HR | 🟠 High | Dashboard KPIs (e.g. "148 Total Employees" vs real 3) and the AI insight ("Teacher attrition risk… Priya Sharma") were hardcoded seed; no real Claude in HR. | `hr_read_repository.ts` recomputes KPIs from live HR rows; new `hr_dashboard_ai.ts` generates the insight via the shared `callClaude` client (deterministic-first, Claude refines, safe fallback — mirrors `director_ai.ts`). | Dashboard **free of seed fiction** (no 148 / no canned attrition); `total_employees` == live `/hr/employees` count (3); **add employee ⇒ dashboard total +1** (3→4→5 across runs). |
| **MJ-H18** | Alumni | 🟠 High | Dashboard "Registered" (2,400), donation summary (₹12.4L/₹2.1L/₹45K), recent graduates & upcoming events were a single seeded snapshot row. | `alumni_read_repository.ts` + handlers aggregate over live `alumni`/`event`/`campaign`/`donation` entity rows (paged across all rows for exact counts); reports trend/attendance computed too. | Dashboard **free of seed fiction** (no 2,400 / no ₹12.4L); **add alumnus ⇒ "Registered" +1** (2→3→4 across runs). |
| **MJ-M3** | Alumni | 🟡 Medium | Profile detail fabricated `employmentHistory` ("Tech Corp"), `eventsAttended` ("Annual Reunion <year>"), and derived `mentorshipRole` from a constant. | `alumniDetailToApi` now surfaces real sub-records when persisted, else **honest empty arrays**; donation history computed from real `donation` rows for that alumnus. | Profile detail **clean** — no "Tech Corp"/"Annual Reunion" constants; `employmentHistory`/`eventsAttended` are honest lists. |
| **MJ-M4** | Library | 🟡 Medium | `snapshot_dashboard`/`fines`/`reports` were static seeds never updated after issue/return; `member.activeLoans` never incremented. | New `library_aggregations.ts` recomputes dashboard (issued-today/overdue/totals), fines (overdue open loans × rule), and reports from live `library_entities`; `activeLoans` derived **on read** as the count of open loans per member (rises on issue, drops on return, zero drift). | dashboard/fines/reports/members all 200 + computed; `member.activeLoans` is a derived integer. |

---

## 4. Out of scope (correctly deferred, not regressions)

Per the roadmap, Wave 3 is **read-recompute only**. The following adjacent items were explicitly **not** touched and remain on their own waves:
- Teacher **TEACH-2/TEACH-3** (exam marks-entry/process/publish + parent-communication routes) — closed separately in Wave 2 / wire-gap scope.
- Alumni **ALUMN-3** (no donation *write* path) — Wave 4 (missing write surfaces). Wave 3 only aggregates over existing donation rows.
- Library settings/loan-rules (**LIBRA-5**), payroll-export (**HR-6**), etc. — later waves.

Honest-empty fields with no backing table yet (each returns 0/`[]`, never seed): management expense/P&L/cash-flow/enrollment-history trends, approval queues, per-student at-risk lists, teacher counts; teacher leave decision-timestamps; alumni employment/events when not persisted; library `issueTrend` sparkline. Each is listed so a future write-surface wave can light it up.

---

## 5. Deploy & reproduction

- **Files:** 18 `_shared` edge files (teacher/pilot/entity_read + management/hr/alumni/library) rsynced to `/opt/akshara/functions/_shared`; line-count parity verified vs local; `akshara-edge` restarted; `/health` → ok. No migrations.
- **Re-run the cert:** `python3 scripts/qa/live_cert_journey_wave3.py` (needs the VPS reachable + pilot OTP not in cooldown; admin `+919876543210`, teacher `+919876543213`). Writes are additive pilot records (one employee, one alumnus per run) — no deletes, no corruption.
- **Offline gates:** `flutter analyze`; `flutter test`; `cd supabase/functions && deno test --allow-all _shared/`.

**Verdict: GO.** Engineering (root-cause fixes, zero-regression gates), QA (34/34 live with real auth/RBAC/write→read), and Release (deployed, health-ok, no migration risk) all green.
