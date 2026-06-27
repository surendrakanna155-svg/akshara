# AKSHARA — Journey Wave 5 Completion Certification

**Status:** ✅ **PRODUCTION CERTIFIED (2026-06-27) — live 24/24**
**Wave:** MODULE_JOURNEY_ROADMAP **Wave 5** — "RBAC hardening, error-state UX sweep & test-gate parity — polish, consistency, and regression safety."
**Scope source of truth:** `docs/MODULE_JOURNEY_AUDIT.md` (issue IDs) + `docs/MODULE_JOURNEY_ROADMAP.md` (Wave 5). No new features, no roadmap expansion — this closes the audit's Wave-5 findings only.
**Live cert:** `scripts/qa/live_cert_journey_wave5.py` → **24/24** against the live VPS pilot (`https://akshara.veloraunisexsalon.com`) with real pilot OTP auth, edge-minted scoped JWTs (school + parent, with controlled permission sets), real DB rows, and real Postgres RLS.

---

## 1. Verdict

**PRODUCTION CERTIFIED.** All **10 Wave-5 findings** (2 High, 3 Medium, 5 Low / grouped) are closed at root cause. This is the final consolidation wave: it hardens intra-school RBAC, extends the error-state standard to mutation paths, and adds the client↔deployed-router path-parity contract tests that would have caught the wire-gaps.

Execution: the **8 disjoint, lower-risk items were built by parallel agents** over non-overlapping modules; the **higher-risk teacher/attendance RBAC (MJ-M10/M11)** — which required a new permission model + migration and must not break the certified teacher loop — was owned centrally.

**The live cert caught three real defects the offline gates could not — all fixed and re-certified to 24/24:**
1. **`GET /widgets/data` (and the whole operations hub) returned HTTP 500 live** — `PostgresError: column "recorded_on" does not exist`. The operations-hub "today's attendance" query referenced a column that does not exist on `attendance_records` (the date lives on the parent `attendance_sessions.session_date`). Pre-existing latent bug — the DW-2 audit claim was code-read, not live-probed. Fixed by joining `attendance_sessions` on `session_id` and filtering `session_date = CURRENT_DATE`. **This restores the dynamic-widgets data endpoint AND the operations hub for everyone.**
2. **Parent attendance-correction returned 403 even for the parent's OWN child.** The correction id is `att_corr_<count>`, but the new parent-scope SELECT RLS hides staff rows, so the count was always `0` → `att_corr_1` → primary-key collision with an existing staff row. Fixed by giving parent corrections a unique id (`att_corr_p_<uuid>`); the count path is retained for staff (accurate under school-scope RLS).
3. **The parent handler's error mapping masked the PK collision as a 403.** A generic `/violates/` match treated a duplicate-key error as an RLS denial. Narrowed to `/row-level security|permission denied/` so genuine RLS denials → 403 while unrelated db errors surface honestly.

**Deploy gotcha (recorded):** the first `rsync -R … supabase/functions/./_shared …` anchored to the wrong path and wrote a stray `/opt/akshara/functions/supabase/functions/_shared/…` tree (live code unchanged) — and the pipe to `tail` masked rsync's real exit code. Fixed by mirroring `_shared/` directly (`rsync -az _shared/ …:/opt/akshara/functions/_shared/`) and removing the stray tree. **Lesson: verify deployed file content/timestamp after every rsync; never read rsync's exit code through a pipe.**

Additionally, the MJ-M12 contract work **found and fixed a real wire-gap**: `PUT /communications/templates/:id` (template edit) had **no router route or handler** — the mock masked it, so editing a template would have 404'd live. The route + handler + service + repository + RBAC-inventory entry were added and are now live-verified.

---

## 2. Gate results

| Gate | Result | Baseline | Δ |
|------|--------|----------|---|
| `flutter analyze` | **0 issues** | 0 | — |
| `flutter test` | **2439 passed / 1 skipped / 0 failed** | 2416 | **+23 Wave-5 widget/contract/RBAC tests** |
| `deno test _shared/` | **848 passed / 0 failed / 2 ignored** | 825 | **+23 new Wave-5 backend tests** |
| Patrol (emulator) | smoke **2/2** · navigation **4/5** (1 pre-existing OTP-back failure, out of scope) | — | super-admin drawer + principal deep-link + teacher shell + parent nav all pass |
| Live cert (`live_cert_journey_wave5.py`) | ✅ **24/24** vs live VPS pilot | — | real OTP + scoped JWTs + RLS + DB |

The live cert is the authoritative gate — mock-DB unit tests cannot reproduce Postgres PK semantics, RLS, or the `recorded_on` schema bug (all three were green offline and caught only live).

---

## 3. Item-by-item closure

| ID | Module | Sev | What was wrong | Fix | Live evidence (24/24) |
|----|--------|-----|----------------|-----|-----------------------|
| **MJ-M10** | Teacher | 🟡 Med | Teacher pilot writes (mark attendance, create/grade homework, edit marks) authorized on **school scope only** — any school account (librarian, accountant, HR) could mark attendance / grade / edit marks. | New `markAttendance` + `manageHomework` permissions (reused existing `manageExamMarks`), granted to teaching roles only; all 5 pilot write handlers now `requirePermission`. `POST /teacher/homework` permission:null → `manageHomework` in the route inventory. | Each write: WITHOUT perm → **403**; WITH perm → 200/422/404 (gate passed). DB: teacher holds all 3; librarian holds none. |
| **MJ-M11** | Attendance | 🟡 Med | Parent correction submit was **403'd** (staff route requires manageSis a parent never has); marking had no permission gate. | New parent-scoped `POST /parent/attendance/corrections` + `attendance_corrections` parent INSERT/SELECT RLS (own children via `student_guardians`); the missing `submitAttendanceCorrection` permission defined + granted to parent so the client gate passes live. Marking gate covered by MJ-M10's `markAttendance`. | Non-parent → 403; parent + own child → **201**; parent + unlinked child → **403 (RLS)**; 2 parent policies present. |
| **MJ-L2** | Dynamic Widgets | 🟡 Med | Per-widget data permission bypassed for any school token; attendance-risk drill-down hit a non-existent `/sis/attendance`; runtime fetched data for RBAC-hidden widgets. | `hasWidgetAccess` now enforces the explicit per-widget permission for school scope; drill-down repointed to the real `/management/attendance-corrections`; live-data provider applies the render-time RBAC predicate before requesting ids. | `fee_collection` → `permissionDenied:true` WITHOUT viewFinance; real data WITH it. |
| **MJ-L4** | AI Features | 🟡 Med | Copilot send failure was silent; a Claude transport error 500'd and left a dangling user message. | Screen surfaces the error + restores typed text; `generateCopilotResponse` wraps the Claude call in try/catch → deterministic fallback (mirrors predictions/parent-insights). | Covered by deno + flutter unit tests (transport-error path can't be forced live). |
| **MJ-L5** | Super Admin | 🟡 Med | Client matrix granted superAdmin platform perms the server never seeds; mock-backed platform writes fabricated success in live builds. | Removed the 10 unseeded platform perms from the superAdmin grant; new `platform_backend_guard` makes mock-backed platform writes surface an honest "not connected" state in live builds instead of fake success. | Covered by flutter tests (165 platform/RBAC tests). |
| **MJ-L3** | Director | ⚪ Low | 8 of 9 Director sub-routes lacked the client entitlement gate; AI-summary + compliance-acknowledge had no error handling. | All 8 builders wrapped in `EntitlementModuleGate`; both writes now catch → error snackbar. | Covered by flutter director tests. |
| **MJ-L6** | Finance | ⚪ Low | No self-approval prevention on refunds. | `approveRefund` rejects when approver == `requested_by` (`RefundSelfApprovalError` → 403), before any state mutation. | Covered by deno finance tests (approver==requester → 403). |
| **MJ-L7** | Inventory | ⚪ Low | Intelligence GET endpoints INSERTed a snapshot row + audit on every read. | The 3 GET handlers now compute-and-return only; no INSERT, no audit (nothing reads the snapshot table). | Three intelligence GETs in a row: snapshot count **3 → 3** (no growth). |
| **MJ-L8** | Admin | ⚪ Low | Global search surfaced/navigated routes regardless of RBAC. | `GlobalSearchEntry.requiredPermission` added + populated; overlay filters results/recents/quick-actions by `rbac.hasPermission`. | Covered by flutter global-search tests. |
| **MJ-M12** | Communication | 🟠 High | Mock masked live 404s for template-write + broadcast-history; no path-parity test. | Added client↔router path-parity contract tests (dart + deno). **Found & fixed** the missing `PUT /communications/templates/:id` handler. | `GET broadcasts/history`, `POST templates`, `PUT templates/:id` all resolve live (no router miss; PUT → clean 404 on unknown id). |

---

## 4. What was built — migration, permissions, RLS

**Migration (1, forward-only, applied + ledgered on the live DB):**
`20260807000010_wave5_teacher_attendance_rbac.sql` —
- Defines `markAttendance` + `manageHomework` permissions (reuses existing `manageExamMarks`).
- Grants the three to teaching/supervisory roles (teacher, classTeacher, coordinator, pet/dance/musicTeacher, principal, vicePrincipal, schoolAdmin) — **excludes** non-teaching staff (librarian, officeStaff, finance/hr/inventory/transport/marketing managers).
- Defines `submitAttendanceCorrection` + grants it to the parent role (so the client correction gate passes in live mode).
- Adds `attendance_corrections_parent_insert` + `attendance_corrections_parent_read` RLS policies — parent-scoped, restricted to `student_guardians`-linked children, parent-authored pending rows only.

Idempotent (`ON CONFLICT DO NOTHING`); respects the `erp_tenant` no-DELETE constraint (INSERT/policy only).

**Permission-model alignment:** `manageExamMarks` was reused (it already existed server-side and on the client enum) rather than coining a duplicate, directly serving the wave's anti-drift theme. `manageHomework` was added to both the server and the client `Permission` enum + teacher matrix entry.

---

## 5. Out of scope (correctly deferred, not regressions)

- **Class-assignment binding (the second half of MJ-M10 / TEACH-4):** the granular permission gate (the security teeth — blocks non-teaching staff) is delivered. Binding a write to *the specific assigned teacher of the target class* depends on the `class_id`↔`class_label` identifier normalization (ATTEN-7, not a Wave-5 item); enforcing it on the current inconsistent identifier would risk false 403s on the certified teacher loop. Deferred to the ATTEN-7 fix.
- **MJ-L5 same-drift on other roles:** the audit's SA-1 finding (and this wave) is scoped to `superAdmin`. The identical unseeded-platform-perm drift also exists on `schoolAdmin`/`principal`/`vicePrincipal`/`management`; it was left untouched to honor scope (no roadmap change) and is recorded here as a known, audit-unflagged follow-up. In live mode the server snapshot already hides these (the perms are unseeded), so there is no live exposure.

---

## 6. Live cert evidence (24/24)

```
Journey Wave 5: 24/24 checks passed
  health · admin OTP auth
  MJ-M10 attendance/homework/marks: DENIED without perm, ALLOWED with perm (5 gates)
  MJ-M10 teacher granted 3 perms · librarian granted none
  MJ-M11 parent route rejects non-parent · own-child 201 · unlinked-child 403 (RLS)
  MJ-M11 parent submitAttendanceCorrection grant + 2 RLS policies
  MJ-L2 fee_collection permissionDenied WITHOUT viewFinance · data WITH it
  MJ-L7 three intelligence GETs do not grow the snapshot table
  MJ-M12 broadcasts/history + templates POST + templates PUT all resolve live
```

Run: `python3 scripts/qa/live_cert_journey_wave5.py` against `https://akshara.veloraunisexsalon.com`.
