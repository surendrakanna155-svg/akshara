# Data Reliability Platform — Phase 0b Certification

**Date:** 2026-06-28 · Branch: `feature/data-reliability-platform`
**Scope:** Phase 0b — integration of the reliability platform into the live app + the four pilot-critical write paths + backend universal idempotency & conflict handling.
**Design:** [`DATA_RELIABILITY_PLATFORM_DESIGN.md`](DATA_RELIABILITY_PLATFORM_DESIGN.md) (approved, refinements R1–R4)
**Phase 0a:** [`DATA_RELIABILITY_PLATFORM_PHASE0_PROGRESS.md`](DATA_RELIABILITY_PLATFORM_PHASE0_PROGRESS.md) (foundation, 34/34 unit/widget tests)

**Verdict:** 🟢 **PRODUCTION CERTIFIED (LIVE)** — `flutter analyze` clean; full Flutter suite green; reliability Deno suite green; **backend deployed to the live VPS pilot and live-certified 20/20**, with the existing idempotency suite **26/26** (no regression). EOS gate: **PASS**.

### Live deployment (2026-06-28, VPS pilot `akshara.veloraunisexsalon.com`)
- **Migration `20260817000000`** applied to `akshara_db` (4× `row_version` + `bump_row_version` trigger + function) and ledgered in `supabase_migrations.schema_migrations`.
- **Edge functions** deployed surgically (5 files) to `/opt/akshara/functions`, `deno check` clean, `akshara-edge` restarted → `/health` ok, `/health/ready database:true`. Only the Phase-0b idempotency delta was applied to `api/index.ts` (the VPS's pre-existing, separately-tracked legal-layer gap was left untouched).
- **Live cert `scripts/qa/live_cert_reliability_phase0b.py` → 20/20:**
  - migration deployed (row_version + trigger + function on all 4 tables)
  - **inert without an `Idempotency-Key`** — a keyless write creates no `request_idempotency` row (existing traffic unchanged)
  - **universal idempotency exactly-once** — a retried `PATCH /academics/exams/marks/{id}` with the same key (and a *different* value) replays the first response; the DB value is unchanged and `row_version` is not bumped twice — proven on a route that had **no** idempotency before this deploy
  - **optimistic concurrency** — a stale `expectedVersion` → `409 CONFLICT` carrying the current server row; the correct version applies and bumps `row_version`
- **Regression — `scripts/qa/live_cert_red_team_wave1.py` → 26/26:** finance double-submit yields exactly one collection; two concurrent payments → one wins / one clean 422 / never negative; the `createModuleWriteHandlers` factory route still replays via exactly one idempotency row (the factory correctly **defers** to the universal wrapper — no double-claim).

The four pilot write paths inherit the verified behaviour through the same route-agnostic universal dispatch (proven live across three distinct route families — academics/marks, finance/fee, library/generic). Client-side offline→reconnect→exactly-once is proven by the Flutter integration tests; the server-side exactly-once replay it depends on is now proven live.

---

## 1. What shipped (objective → evidence)

| Objective | Implementation | Evidence (`file:line`) |
|---|---|---|
| **1. Integrate the platform into the real app** | Bootstrap opens the durable store + starts the sync engine | [`lib/main.dart`](../lib/main.dart) (`openReliabilityStore`, `reliabilityStoreProvider.overrideWithValue`, `read(syncEngineProvider)`) |
| **2. Wire `ReliableWriter` into pilot modules** | Datasource seam routes each write via `ReliableWriter` (nullable → zero regression for mock/legacy) | attendance+leave [`teacher_remote_datasource.dart`](../lib/core/repositories/api/teacher/remote/teacher_remote_datasource.dart), parent leave [`parent_remote_datasource.dart`](../lib/core/repositories/api/parent/remote/parent_remote_datasource.dart), marks [`exam_remote_datasource.dart`](../lib/core/repositories/api/exam_administration/remote/exam_remote_datasource.dart), fee [`finance_remote_datasource.dart`](../lib/core/repositories/api/finance/remote/finance_remote_datasource.dart); wiring in [`api_repository_providers.dart`](../lib/core/repositories/api/api_repository_providers.dart) |
| **3. Draft persistence (WhatsApp resume)** | Reusable `DraftAutosaveMixin` (autosave + Resume/Discard banner + discard-on-submit); bound to leave form + attendance grid | [`drafts/draft_autosave.dart`](../lib/core/reliability/drafts/draft_autosave.dart), [`parent_leave_screen.dart`](../lib/features/parent/leave/parent_leave_screen.dart), [`teacher_attendance_screen.dart`](../lib/features/teacher/attendance/teacher_attendance_screen.dart) |
| **4. Autosave** | Debounced on form change + flushed on app background/lock | `DraftAutosaveMixin.scheduleDraftSave`; lifecycle flush in [`app.dart`](../lib/app/app.dart) (`didChangeAppLifecycleState` → `DraftFlushRegistry.flushAll`) |
| **5. Sync Banner + Sync Center in the shell** | Global `SyncBanner` injected via the `MaterialApp.router` builder (all shells); top-level `/sync-center` route | [`app.dart`](../lib/app/app.dart), [`app_router.dart`](../lib/router/app_router.dart) (`RouteNames.syncCenter`) |
| **6. Backend universal idempotency + conflict/version** | `dispatchWithIdempotency` wraps the whole module dispatch; `row_version` + `409 CONFLICT`-with-row — **deployed live + 20/20 cert** | [`idempotency_dispatch.ts`](../supabase/functions/_shared/idempotency_dispatch.ts), [`api/index.ts`](../supabase/functions/api/index.ts), migration [`20260817000000`](../supabase/migrations/20260817000000_reliability_row_version_conflict.sql), [`exam_administration_repository.ts`](../supabase/functions/_shared/academics/exam_administration/exam_administration_repository.ts) |
| **7. Encryption for local draft/outbox** | SQLCipher (`sqflite_sqlcipher`) with a 256-bit key generated once into `flutter_secure_storage` | [`sqflite_reliability_store.dart`](../lib/core/reliability/store/sqflite_reliability_store.dart) (`_obtainCipherKey`, `openDatabase(password:)`) |
| **8. Airplane-mode integration tests** | offline → "relaunch" → reconnect → flushed exactly once; lost-ack replay; fee R1; draft resume | [`test/integration/reliability/`](../test/integration/reliability/), [`test/core/reliability/draft_resume_test.dart`](../test/core/reliability/draft_resume_test.dart) |
| **9. No regression** | `flutter analyze` clean; full suite green | §3 |
| **10. Generic / inherit-by-default** | Behaviour declared once in `OperationPolicyRegistry`; new modules = one registry line; backend idempotency is dispatch-wide | [`operation_policy_registry.dart`](../lib/core/reliability/policy/operation_policy_registry.dart) |

### Refinements
- **R1 (no offline receipt):** an offline fee collection returns `pendingSync: true`, the UI shows "Pending Sync", and **no receipt number is minted** until the server confirms — [`finance_workflow_actions.dart`](../lib/features/finance/finance_workflow_actions.dart), [`finance_models.dart`](../lib/features/finance/finance_models.dart) (`FinanceCollectionResult.pendingSync`).
- **R2 (conflict categories):** attendance/marks-draft/leave = `lowRisk` (LWW); fee/marks-submit = `highRisk` (park for resolution) — registry.
- **R3 (Sync Center):** banner (offline/pending only) + status + pending counter + manual retry + history + conflict actions — `sync_center/`.
- **R4 (universal pipeline):** every queueable write goes through the gateway; backend idempotency at the dispatch layer.

---

## 2. The exactly-once guarantee (the critical property)

A queued write carries a client-generated `operationId` as its `Idempotency-Key`. On reconnect the platform replays it; the backend's `dispatchWithIdempotency` claims `(org, key)` once and **replays the stored 2xx envelope** on any retry — so a write whose `2xx` ack was lost on a dropped connection returns the same result and creates **no second row / receipt / charge**.

- Client side proven by [`airplane_mode_attendance_test.dart`](../test/integration/reliability/airplane_mode_attendance_test.dart): "queued write survives relaunch and flushes exactly once" + "lost-ack retry replays via idempotency → confirmed, never duplicated".
- Server side proven by [`idempotency_dispatch_test.ts`](../supabase/functions/_shared/idempotency_dispatch_test.ts): inert-without-key · exactly-once replay · in-flight 409 · release-on-failure · release-on-throw.

---

## 3. Test evidence

| Suite | Result |
|---|---|
| `flutter analyze` (project-wide) | **0 issues** |
| `flutter test` (full project) | **2504 passed, 0 failed, 1 skipped** — includes +7 new reliability integration/draft tests; 0 regressions |
| `flutter test test/core/reliability` | reliability unit/widget — **all pass** (Phase 0a 34 + draft-resume 2) |
| `flutter test test/integration/reliability` | airplane-mode + fee R1 — **5 pass** |
| `deno test _shared/idempotency_dispatch_test.ts` | **6 pass** (universal idempotency) |
| `deno test …/exam_mark_conflict_test.ts` | **4 pass** (row_version + 409 conflict) |
| `deno test _shared/transport _shared/entity_write red_team_wave1` | **no regression** from the dispatch wrapper / factory change |
| **LIVE** `live_cert_reliability_phase0b.py` (VPS) | **20/20** — idempotency exactly-once · inert-without-key · 409 conflict · row_version |
| **LIVE** `live_cert_red_team_wave1.py` (VPS) | **26/26** — finance/factory idempotency, no regression |

---

## 4. Design-fidelity & safety notes

- **Datasource seam, not a rewrite.** Pilot writes route through `ReliableWriter` only when a writer is injected (production providers do; legacy/mock unit tests pass `null` → unchanged direct-Dio path). No existing architecture was rewritten.
- **Backend wrapper is inert without a key.** `dispatchWithIdempotency` only activates for a mutating request that carries `Idempotency-Key`; all existing traffic is byte-for-byte unchanged. The `createModuleWriteHandlers` factory defers to it via a per-request marker, so there is never a double-claim.
- **Encryption + multi-user safety.** The local DB is SQLCipher-encrypted (key in the OS keystore) and **wiped on logout / user switch** ([`auth_provider.dart`](../lib/features/auth/auth_provider.dart) `logout()` → `reliabilityStore.clear()`).
- **Graceful degradation.** If the encrypted store can't open, the app falls back to in-memory ([`reliability_store_opener.dart`](../lib/core/reliability/store/reliability_store_opener.dart)); connectivity detection fails open ("online").

## 5. Carried to Phase 0c (not blocking 0b)

- Flip the shared `ReliableMutation` base so all ~154 mutations inherit the gateway by default.
- Track + send a captured base `row_version` on the first write of high-risk updates so optimistic-concurrency conflict detection is active on the first attempt (today the conflict path is exercised on retry/resolution and is fully unit-proven server-side).
- Migrate remaining forms to draft persistence opportunistically.

---

## 6. Tracker

Rows `QA-X-001/002/004/005/006/007/008/009` → **Verified** (platform integrated end-to-end, airplane-mode evidence captured). `QA-X-031` (secure storage) advanced by SQLCipher-at-rest.
