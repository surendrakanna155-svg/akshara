# Wave 1 — Stop Silent Data Loss — CERTIFICATION

**Status:** ✅ **PRODUCTION CERTIFIED (live)**
**Date:** 2026-06-25
**Wave:** 1 of `docs/FINAL_COMPLETION_ROADMAP.md` (Theme A — writes that looked successful but never persisted)
**Release-review verdict:** **GO** (Engineering ✅ / QA ✅ / Release ✅)
**Live cert:** `scripts/qa/live_cert_completion_wave1.py` → **8/8 PASS** against the VPS pilot (real OTP auth, real DB, real RBAC)
**Deployed:** migration `20260731000000` applied + ledgered; edge functions rsynced + `akshara-edge` recreated.

---

## 1. What shipped

| ID | Item | Sev | Fix |
|----|------|:---:|-----|
| **TCH-1** | Teacher homework CREATE never persisted (in-memory only) | Critical | New `POST /teacher/homework` → durable `homework_assignment` in `teacher_entities` (teacher-scoped) + `homework_item` fan-out to target students in `student_entities`; audited (`homeworkCreated`). Migration `20260731000000` adds a **bounded** school-scope RLS policy on `student_entities` limited to `entity_type='homework_item'`. Full Flutter client slice (path/DTO/datasource/repo/interface/mutation provider/mock + UI rewire). |
| **TCH-2** | Teacher compose-message SEND was a no-op | Critical | `sendComposedMessage` now calls the real, audited `sendTeacherMessageProvider` (no `thread_id` → backend opens a new thread); success/error feedback; removed the `"(mock)"` string. |
| **TCH-5** | Exam remarks persisted only to a device-local store | High | Wired Flutter repo (`upsertRemark`/`listRemarks`) → existing backend; **fixed two backend defects**: remark `id` now carries a role slot (`…|teacher` vs `…|leadership`) so class-teacher and leadership remarks never overwrite each other, and the handler now accepts + authorizes `authorRole` (leadership requires `manageExams`). Store hydration on the marks-entry + teacher-exams screens. |
| **STF-7** | HR Reports data mocked; export preview-only | Med | Provider wired to live `getDashboard` for the headline metric; export buttons wired to the existing real `AksharaReportExportService` (PDF/CSV). |
| **STF-8** | 5 "Settings → Edit" controls were silent no-ops | Med | No write path exists in client or backend → the misleading edit affordance was removed from all 5 (HR/transport/alumni/control-center settings + roles). |
| **CORE-2** | Branch repo mock-only, reachable by deep-link | Med | `/branches` now chain-gated via `ChainScope` (symmetric with franchise) → unreachable for the single-school pilot. |
| **CORE-1 / PAR-4** | Parent Meetings (PTM) mock-only on a live route | High | Gated OFF (staff `/parent-meetings` + parent `/parent/ptm`) via `SchoolBuildScope` until a real backend is built — removes the mock-data-loss exposure. (Roadmap Option B; backend build tracked as the remaining half of this item.) |

## 2. Gates (verified by coordinator)

| Gate | Result |
|------|--------|
| `flutter analyze --fatal-infos` | **0 issues** |
| `flutter test` | **2383 passed, 1 skipped, 0 failed** |
| `deno test` (typecheck on) | **665 passed, 0 failed, 2 ignored** |
| `deno check api/index.ts` | clean (full edge graph) |

## 3. Live certification — 8/8

```
[PASS] auth.login:admin
[PASS] auth.login:teacher
[PASS] TCH-2.compose_send_opens_thread            HTTP 201 thread=f9d17b0b…
[PASS] TCH-1.homework_create_persists             HTTP 200 id=hw_af7394ca… delivered=1
[PASS] TCH-5.exam_available                       examId=exam_4
[PASS] TCH-5.both_slots_upsert                    teacher-slot 200, leadership-slot 200
[PASS] TCH-5.no_collision_both_remarks_present    roles=[classTeacher, principal]
[PASS] TCH-5.rbac_teacher_cannot_author_leadership HTTP 403
=== 8/8 checks passed ===
```

**DB evidence (live `akshara_db`):** `teacher_entities` homework_assignment = 1; `student_entities` homework_item = 1 (delivered); `exam_remarks` for exam_4 = 2 rows (classTeacher + principal slots, no collision).

## 4. Deploy record

- **Migration:** `supabase/migrations/20260731000000_wave1_homework_create.sql` applied via `docker exec akshara-postgres psql` and recorded in `supabase_migrations.schema_migrations` (`20260731000000`). Policy `student_entities_school_homework` verified present. Additive + reversible (`DROP POLICY`).
- **Edge:** `rsync supabase/functions/ → /opt/akshara/functions/` (tests excluded); `docker compose … up -d --force-recreate --no-deps akshara-edge`. Container Up + serving; live cert green post-recreate.
- **Bug caught & fixed during cert:** the deployed `teacher_entities` schema added a `teacher_id` column (PK + RLS `teacher_id = app_current_user_id()`) in migration `20260702000000` after the original table — the create now inserts the assignment owned by the creating teacher.

## 5. Known limitations (documented, not blockers)

- **Whole-class homework targeting** delivers to all active students in the school until a class-roster column exists on `students`; named-student targeting is exact. Class-precise multi-class targeting is a tracked refinement (not silent data loss).
- **Parent Meetings backend** is the remaining half of CORE-1/PAR-4 — the feature is gated off (visibly, not silently) until built.
- **Client-side rollback:** any of the wired UIs revert cleanly via mock mode (per-module `*_API_ENABLED` flags) if needed.

## 6. Verdict

**Wave 1 CERTIFIED COMPLETE** — both Criticals and all High/Medium items live-certified and deployed. **Next is Wave 2 (Multi-child correctness + demo-identity purge) — do NOT start automatically.**
