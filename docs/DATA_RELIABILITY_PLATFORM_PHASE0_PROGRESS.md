# Data Reliability Platform — Phase 0 Implementation Progress

**Date:** 2026-06-27 (Phase 0a) · 2026-06-28 (Phase 0b) · Branch: `feature/data-reliability-platform`
**Design:** [`DATA_RELIABILITY_PLATFORM_DESIGN.md`](DATA_RELIABILITY_PLATFORM_DESIGN.md) (approved with refinements R1–R4)
**Status:** 🟢 **Phase 0a (Foundation) COMPLETE & VERIFIED** · 🟢 **Phase 0b (Integration) COMPLETE & VERIFIED** · 🟡 Phase 0c (inherit-by-default) follows

> **Phase 0b cert:** see [`DATA_RELIABILITY_PLATFORM_CERTIFICATION.md`](DATA_RELIABILITY_PLATFORM_CERTIFICATION.md).
> The reliability platform is now wired into the live app: bootstrap opens the
> encrypted on-device store and starts the sync engine; the app's lifecycle
> observer flushes drafts on background/lock; a global Sync Center + banner ship
> in every shell; the four pilot-critical write paths (attendance, exam marks,
> leave, fee collection) route through `ReliableWriter`; leave + attendance grid
> are draft-persisted (resume-on-return); fee collection shows "Pending Sync"
> with no final receipt until confirmed (R1); the backend applies universal
> idempotency at the dispatch layer and returns `409 CONFLICT` with the current
> row on a version mismatch; the local store is encrypted at rest (SQLCipher).

> Verification: `flutter analyze` → **0 errors project-wide**; `flutter test test/core/reliability` → **34/34 passing**. All Phase 0a code is **additive** — it modifies no existing app file (only `pubspec.yaml`), so the running app is unaffected until integration is wired.

---

## What is built and tested (Phase 0a — the universal platform)

All under `lib/core/reliability/`:

| Area | Files | Verified behaviour |
|---|---|---|
| **Models** | `model/` — `reliability_enums`, `operation_policy`, `mutation_request`, `mutation_envelope`, `mutation_outcome`, `draft_record` | JSON round-trip; immutable copyWith |
| **Operation Policy Registry (R4)** | `policy/operation_policy_registry.dart` | Unknown op → safe `onlineOnly` fallback; pilot-critical seed (attendance/marks/leave = queueable+lowRisk, fee/marks-submit = queueable+highRisk, login/gateway/AI = onlineOnly); one-line opt-in |
| **Universal gateway (R4)** | `sync/mutation_gateway.dart` | Routes every write by policy: online-only fails-fast offline; queueable enqueues offline; online success/5xx/4xx/409 handled |
| **Sync engine** | `sync/sync_engine.dart`, `backoff.dart`, `send_classification.dart`, `conflict_resolver.dart` | **Exactly-once** via idempotency replay; exponential backoff w/ jitter; **conflict categories (R2)** — lowRisk LWW (re-apply w/ server version), highRisk park-for-resolution; retry exhaustion → failed |
| **Conflict resolution (R2)** | `conflict_resolver.dart` + engine `resolveConflict` | Keep-mine re-queues with precondition; use-server drops |
| **Store** | `store/` — interface, `InMemoryReliabilityStore`, `SqfliteReliabilityStore` | Durable outbox + drafts; pending ordering; logout wipe |
| **Adapters** | `sync/dio_mutation_executor.dart` (attaches `Idempotency-Key`), `connectivity/connectivity_service_impl.dart` | Map Dio envelope → ExecutorResponse; network-failure → queue signal |
| **Drafts** | `drafts/draft_model.dart`, `draft_controller.dart` | Save / recover / discard / per-user scoping ("resume where you left off") |
| **Sync Center (R3)** | `sync_center/` — `sync_summary`, `sync_center_controller`, `sync_banner`, `sync_center_screen` | Status indicator, offline-only banner, pending counter, manual retry, history, conflict actions |
| **Wiring + write seam** | `reliability_providers.dart`, `reliable_writer.dart`, `reliability_ids.dart` | Riverpod providers; `ReliableWriter.runWrite()` is the repo/notifier seam |

**Tests** (`test/core/reliability/`, 34 cases): `sync_engine_test` (idempotent exactly-once, transient-retry-backoff, high-risk park, low-risk LWW, fail-fast 4xx, retry exhaustion, conflict resolution), `mutation_gateway_test` (8 routing cases incl. R1 non-final pending + fallback), `backoff_test`, `operation_policy_registry_test`, `in_memory_store_test`, `draft_controller_test`, `sync_center_test` (summary + banner widget).

### Refinements landed
- **R1** — `MutationOutcome.isFinal` is false until `confirmed`; the registry marks fee collection high-risk so the UI shows "Pending Sync" and must not finalise a receipt until confirmed.
- **R2** — conflict *categories* (no global LWW): `ConflictCategory.lowRisk`/`highRisk`, enforced by `ConflictResolver` + the engine.
- **R3** — Sync Center (banner + screen + controller) shipped.
- **R4** — universal pipeline: every write goes through `MutationGateway`; behaviour is declared once in `OperationPolicyRegistry`; new modules = one registry line.

---

## Phase 0b — Integration — ✅ DONE (2026-06-28)

All landed and verified (see the certification for evidence/`file:line`):

1. ✅ **App bootstrap wiring** — `main.dart` opens the durable store via `openReliabilityStore()` (encrypted; in-memory fallback), overrides `reliabilityStoreProvider`, and starts `syncEngineProvider`. Logout wipes the store (`AuthNotifier.logout`).
2. ✅ **Lifecycle autosave** — `AksharaApp` is the app's first `WidgetsBindingObserver`; on `inactive/paused/detached/hidden` it flushes every active form via `DraftFlushRegistry.flushAll()`.
3. ✅ **Sync banner + Sync Center** — `SyncBanner` injected globally via the `MaterialApp.router` builder (all shells + future ones); top-level `/sync-center` route → `SyncCenterScreen`.
4. ✅ **Pilot-critical integration** — attendance (draft+submit), exam-marks (per-cell), teacher+parent leave, fee collection all route through `ReliableWriter` at the datasource seam (gated by a nullable writer → zero regression for legacy/mock tests). Leave form + attendance grid are draft-persisted (autosave + Resume/Discard). Fee shows "Pending Sync" with no final receipt until confirmed (R1).
6. ✅ **Backend — universal idempotency** — `dispatchWithIdempotency` wraps the whole `moduleRouters` dispatch (`api/index.ts`); inert without an `Idempotency-Key`, exactly-once replay with one. The `createModuleWriteHandlers` factory defers to it (no double-claim). Reuses `request_idempotency`. 6 Deno tests.
7. ✅ **Backend — row versioning + conflict** — migration `20260817000000` adds `row_version` + a `bump_row_version` trigger to the four queueable tables; the exam-mark update honours an `expectedVersion` precondition and returns `409 CONFLICT` carrying the current row. 4 Deno tests.
8. ✅ **Encryption-at-rest** — `SqfliteReliabilityStore.open()` uses `sqflite_sqlcipher` with a 256-bit key generated once into `flutter_secure_storage`.
9. ✅ **Integration tests (airplane-mode)** — attendance offline → "relaunch" → reconnect → flushed **exactly once**; lost-ack idempotency replay; fee R1 pending/no-receipt; draft resume across sessions + per-user isolation + logout wipe.

### Remaining → Phase 0c (after QW-gate, not blocking Phase 0b)

5. **Inherit-by-default (0c)** — migrate the shared mutation notifier base so all ~154 mutations pass through the gateway (online-only unless their policy opts in), and send a captured base `row_version` on first write so conflict detection is active for every high-risk update (today the conflict path is exercised on retry/resolution; first-attempt detection for marks is a 0c enhancement).

---

## Tracker impact

Phase 0 rows `QA-X-001/002/004/005/006/007/008/009`: the platform is now **integrated and verified end-to-end** (airplane-mode integration tests green) → these move to `Verified`. No row is `Won't-Build`.

**Definition of done** (design §16): platform merged + tested; universal idempotency + conflict response live (Deno-tested); drafts auto-save/recover on pilot-critical screens; Sync Center shipped; pilot writes route through the gateway; airplane-mode evidence captured; cert written. ✅ Met for Phase 0b. **QW1 may begin once the EOS gate passes.**
