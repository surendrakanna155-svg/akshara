# AKSHARA — Red Team Wave 1 Certification

**Status:** ✅ **PRODUCTION CERTIFIED (2026-06-27) — live 26/26**
**Wave:** RED_TEAM **Wave 1** — "Transactional Integrity — duplicates & lost updates."
**Scope source of truth:** [`RED_TEAM_MASTER_TRACKER.md`](./RED_TEAM_MASTER_TRACKER.md) (RT-01..RT-08) + [`RED_TEAM_COMPLETION_ROADMAP.md`](./RED_TEAM_COMPLETION_ROADMAP.md) (Wave 1). No new features, no roadmap expansion, no new audit — this closes the tracker's Wave-1 findings only.
**Commit:** `6b1e5c1` · **Branch:** `feature/scope-trim-school-build`
**Migration:** `20260814000000_red_team_wave1_transactional_integrity.sql` (applied + ledgered on the live DB)
**Live cert:** `scripts/qa/live_cert_red_team_wave1.py` → **26/26** against the live VPS pilot (`https://akshara.veloraunisexsalon.com`) with edge-minted scoped JWTs (HS256 / live `JWT_SECRET`), real DB rows, real Postgres constraints + row locks + RLS.

---

## 1. Verdict

**PRODUCTION CERTIFIED.** All **8 Wave-1 findings** (2 Critical, 4 High, 2 Medium) are closed at root cause and verified on the live database. These are the only red-team findings that produce *silent data corruption* in money and student identity, so they were fixed first.

The fixes are layered defence: the application path is made safe (row locks, idempotency replay, savepoint retry, bound checks) **and** the database is given the matching last-line constraints (unique indexes, a CHECK, an idempotency store), so a race that ever slips past the app still cannot corrupt money, identity, or grades.

**The live cert caught four real defects the offline gates could not — all fixed and re-certified to 26/26:**

1. **`request_idempotency` was unreachable by the live edge role.** The new table had RLS + a policy but no `GRANT` to the non-bypass `erp_tenant` role, so every generic write with an `Idempotency-Key` 500'd (`permission denied for table request_idempotency`). Fixed by granting `SELECT/INSERT/UPDATE/DELETE` to `erp_tenant` (mirrors the `*_entities` tables) — added to the migration and applied live.
2. **RT-08 was edited in the wrong handler.** The audit cited `academics/exam_administration` `handleUpdateExamMark`, but the **live** `PUT /teacher/exams/marks/:id` route is served by `pilot/pilot_operations_handlers.ts` (a separate handler with its own `updateExamMark`). Over-max / negative marks were reaching the new DB CHECK and surfacing as a generic 500. Fixed by adding the bound to the pilot handler too: a fast 422 for negative/non-integer, and mapping the `exam_mark_entries_marks_bounds` CHECK violation to a 422 instead of a 500. (The academics handler fix is retained — that route is still reachable.)
3. **`relrowsecurity` probe bug.** `::text` on a boolean yields `'true'`, not psql's `'t'` — a cert-script-only false negative; fixed the probe.
4. **Cert fixture omitted NOT-NULL columns.** The isolated finance fixture's `finance_fee_assignments`/`finance_student_accounts` rows needed `academic_year` (NOT NULL) and a non-colliding `(student, fee_structure, year)` — without it the invoice JOIN found no account and the collection 422'd as "Invoice not found." Cert-script-only; fixed.

Items 1–2 were genuine production bugs; the live cert is the gate that surfaced them (mock-DB unit tests cannot reproduce Postgres grants, RLS, row locks, or which deployed handler actually serves a route).

## 2. Gate results

| Gate | Result |
|------|--------|
| `flutter analyze` | **0 issues** (no Dart changed; gate re-run for safety) |
| `flutter test` | **2440 passed / 1 skipped / 0 failed** |
| `deno test _shared/` | **860 passed / 0 failed / 2 ignored** (+3 new Wave-1 tests) |
| Live cert (`live_cert_red_team_wave1.py`) | ✅ **26/26** vs live VPS pilot |

The live cert is the authoritative gate.

## 3. Headline live evidence

- **RT-01 concurrency (FOR UPDATE):** two simultaneous full payments of one invoice → statuses `[201, 422]`, outstanding settled at **`0.00`** (never negative), **exactly one** completed collection row. Without the lock both would have committed → `-100` outstanding + double payment.
- **RT-01 idempotency:** a double-submit with the same `Idempotency-Key` returned the **same** collection id, persisted **one** row, and decremented the invoice **once** (200 → 150).
- **RT-02:** a duplicate `(school, admission_number)` create → **409** (DB-enforced).
- **RT-07 (+RT-06):** a double-submitted `POST /library/digital-resources` (same key) returned the **same** resource id, recorded **one** `request_idempotency` row, and appended to the snapshot once (via the new `FOR UPDATE` `mutateSnapshot`).
- **RT-08:** negative → **422**, marks > max_marks → **422**, valid → **200**.

## 4. Item-by-item closure

| RT | Sev | Root cause | Fix | Live evidence (26/26) |
|----|-----|-----------|-----|-----------------------|
| **RT-01** | 🔴 Crit | TOCTOU on invoice outstanding; no DB unique/lock/idempotency | `SELECT … FOR UPDATE OF fi` on the invoice; honour `Idempotency-Key` (replay before decrement); new `finance_collections.idempotency_key` + partial-unique index `finance_collections_idempotency_key_uq`; unique-violation → replay | concurrent `[201,422]`, outstanding 0.00, 1 row; double-submit → same id, 1 row, 200→150 |
| **RT-02** | 🔴 Crit | App-level SELECT-then-INSERT, no DB unique on admission number | `UNIQUE(school_id, admission_number)`; insert-time violation → `DuplicateAdmissionNumberError` (409); redundant index dropped | dup admission → 409; constraint present; old index gone |
| **RT-03** | 🟠 High | `MAX+1` student code with no lock → PK conflict 500s | Savepoint retry-on-conflict around the `students` insert (re-derives the code without aborting the tx) | `UNIQUE(school_id, student_code)` present; normal create still 201 |
| **RT-04** | 🟠 High | `att_corr_<count+1>` id raced to PK collisions | id → `att_corr_<uuid>`; `input.id` override retained | unit-tested (distinct UUID ids, input.id honoured); deployed |
| **RT-05** | 🟡 Med | `exam_<count+1>` id raced to PK collisions | id → `exam_<uuid>` | unit-tested (distinct UUID ids); deployed |
| **RT-06** | 🟠 High | `mutateSnapshot` read-modify-write, no lock (5 call sites) | `SELECT … FOR UPDATE` the snapshot row before read; first-writer conflict recovery | snapshot append via the locked path persists once live |
| **RT-07** | 🟡 Med | `runWrite` ignored the CORS-advertised `Idempotency-Key` | New `request_idempotency` store-and-replay table (school-scoped RLS + `erp_tenant` grant); `runWrite` claims/replays per key | replay → same id, 1 idempotency row |
| **RT-08** | 🟠 High | No server/DB bound on `marks_obtained` | Server `0 <= marks <= max_marks` on **both** academics + live pilot teacher routes; DB CHECK `exam_mark_entries_marks_bounds` | negative/over-max → 422, valid → 200; CHECK present |

## 5. What was built — migration + code

**Migration (1, forward-only, applied + ledgered as `20260814000000`):**
- `finance_collections.idempotency_key` column + partial-unique index `(organization_id, idempotency_key)`.
- `student_profiles` `UNIQUE(school_id, admission_number)`; dropped redundant `idx_student_profiles_school_admission`.
- `request_idempotency` table (school-scoped RLS policy + `erp_tenant` grant).
- `exam_mark_entries` CHECK `exam_mark_entries_marks_bounds (marks_obtained >= 0 AND marks_obtained <= max_marks)` (NOT VALID → enforced for all new writes).

**Edge functions (9 `_shared` files):** finance collections repo/handler, entity-write store + module-write handler, SIS students repo, attendance-correction repo, exam-administration repo + handler, **pilot operations handler** (live teacher marks route).

**Tests:** `red_team_wave1_test.ts` (RT-04/05 id invariants) + the live cert script.

## 6. Deploy

- Migration applied to the live DB via `psql` and ledgered in `supabase_migrations.schema_migrations`; the `erp_tenant` grant applied live.
- `_shared` mirrored to `/opt/akshara/functions/_shared/` (rsync) and `akshara-edge` restarted; `/health` → 200.
- All cert fixtures use dedicated `cef…`/`rtw1-` identifiers and are cleaned up; `mark_1` is reset. Verified zero residue post-run.

## 7. Status

Wave 1 (RT-01..RT-08) → **Closed**. Per the engagement rules, **STOP** — do not begin Wave 2 (Tenant & Privacy / RLS) without owner approval.
