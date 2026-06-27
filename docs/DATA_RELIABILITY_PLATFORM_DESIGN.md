# AKSHARA ERP — Data Reliability Platform — Architecture Design

**Status:** 🟢 **APPROVED WITH REFINEMENTS (2026-06-27) — implementing (Phase 0).**
**Date:** 2026-06-27 · HEAD `0f33c6a`
**Owner decision (2026-06-27):** Draft persistence + sync + retry are **core platform reliability requirements**, built as Phase 0 *before* the QA waves.

### Approved refinements (2026-06-27)
- **R1 (Receipts / Q1):** a fee collection **never** generates a *final* receipt until the **server confirms** the transaction. Until then it shows a clear **"Pending Sync"** state. *(See §6, §7, §14.)*
- **R2 (Conflict categories / Q2):** **no single global last-write-wins.** Conflicts are categorized: **low-risk** data (drafts, notes, temporary edits) → last-write-wins is acceptable; **high-risk** data (**fees, payroll, approvals, published marks, inventory, finance**) → **detect the conflict and require explicit user resolution.** *(See §6.)*
- **R3 (Sync Center / Q3):** ship a lightweight **Sync Center**: small sync-status indicator · offline banner only when needed · pending-item counter · manual-retry · detailed sync history. *(See §7.)*
- **R4 (Universal platform / Q4):** **not** a growing list of per-feature offline integrations. A **universal platform service** sits in the **shared repository/write pipeline** so **every write automatically passes through it**. Whether an operation supports draft/queue/retry/online-only is controlled by a **centralized Operation Policy Registry**, not per-screen code. **Future modules require only policy configuration — no new offline code.** *(See §7, §12.)*

**Relationship to QA program:** This platform unblocks tracker rows `QA-X-001, -002, -004, -005, -006, -007, -008, -009` (offline drafts, offline writes, cached reads, connectivity status, double-submit, auth replay, retry/backoff, unsaved-guard). See [`FINAL_QA_ROADMAP.md`](FINAL_QA_ROADMAP.md) Phase 0.

---

## 1. The problem, in one line

A user must **never lose work** to an interruption, an app close, a phone lock, or a flaky network — exactly like WhatsApp keeps a half-typed message. Today the app is **online-only**: every read and write hits the network live, there is no connectivity awareness, no local draft, and a write lost mid-flight is gone.

**Concrete failures this fixes:**
- Teacher enters 35 of 50 marks, gets interrupted, returns later → the 35 are still there.
- Teacher marks attendance and loses signal → the roster is queued and syncs later, never lost, never duplicated.
- Office staff records a fee collection and the network drops → the record is safe and reconciles exactly once.
- Any partially completed form survives app close / restart / lock / network loss.

---

## 2. Goals & non-goals

**Goals**
1. **Reusable platform layer**, not per-feature logic — built once in `lib/core/`, inherited by all 44 modules and every future one.
2. **Draft Persistence** — automatic local save during entry; recovery after close/restart/lock; resume exactly where left off.
3. **Sync Engine** — queue writes offline; auto-sync on reconnect; exponential backoff; **idempotent writes (no duplicates)**; conflict detection + safe resolution; user-visible sync status.
4. **Repository Integration** — every write passes through the common platform; no per-screen offline code.
5. **Zero data loss** and **exactly-once** semantics for queued writes.

**Non-goals (explicitly out of scope for Phase 0)**
- Full offline-first read replication of the whole database (we cache *already-loaded* reads, not the entire dataset).
- Real-time multi-user live collaboration / CRDT merge (we do detect & resolve conflicts, but not live co-editing).
- Changing any feature's UX beyond adding draft-resume + a sync indicator.
- Re-architecting the 267 existing write call sites in one big-bang (staged rollout — §12).

---

## 3. What we build on (grounded in the current codebase)

The investigation found the foundations already exist; the platform **extends proven patterns** rather than inventing new ones.

| Asset that already exists | Where | How the platform uses it |
|---|---|---|
| Single write funnel: `AsyncNotifier<T>` + per-feature `_runMutation()` wrapper (action + audit + invalidate + error-map) | `lib/features/*/*_mutations_provider.dart` (51 notifiers, ~154 methods) | Replace per-feature `_runMutation` with a **shared `ReliableMutation` base** so all writes inherit reliability |
| Uniform repository write shape: `Future<Entity> verbNoun({required RepositoryQuery query, required …Request request})` | `lib/core/repositories/api/<module>/…` | A single **`MutationGateway`** choke point sits under the repository write path |
| Dio **auth interceptor already replays only idempotent verbs OR requests carrying an `Idempotency-Key`** | `lib/core/network/dio_client.dart` | We make the client **always send an `Idempotency-Key`**, turning every queued write into a safe-to-replay write |
| Backend **`Idempotency-Key` store-and-replay** via `request_idempotency` table + `runWithIdempotency()` (today on 3 paths) | `supabase/functions/_shared/entity_write/module_write_handlers.ts`, migration `20260814000000` | Apply it **universally** so retries never duplicate |
| **Audit batch flush** — persisted, dedup-by-`client_event_id`, idempotent | client `lib/core/audit/audit_upload_queue.dart` + server `audit_handlers.ts` | The **exact template** for the outbox queue + its flush endpoint |
| Double-submit guard `mutationInProgressFailure()` (RT-24) | `lib/core/errors/mutation_in_progress.dart` | Folded into the `ReliableMutation` base (closes `QA-X-006`) |
| Unsaved-changes guard (RT-30) `PopScope` + web `beforeunload` | `lib/shared/forms/akshara_unsaved_guard.dart` | Auto-wired from draft "dirty" state (closes `QA-X-009`) |
| Lifted form-state: `StateProvider<XxxDraft>` immutable models (~16) | e.g. `leave_apply_form.dart` ↔ `leaveApplyDraftProvider` | Primary **draft snapshot** target (add `toJson`/`fromJson`) |
| `ProviderObserver` (`AksharaErrorObserver`) registered at boot | `lib/core/observers/error_observer.dart`, `main.dart` | Extend to **autosave draft providers** on change |

**What is genuinely missing (must be built):** connectivity detection (no package, 0 references), an app-lifecycle observer (0 `WidgetsBindingObserver`), a durable local store for drafts/outbox (only `shared_preferences` + `flutter_secure_storage` today), row-versioning/conflict response on the backend, and universal idempotency application.

---

## 4. Architecture overview

A four-layer design. The **only invasive change** is introducing one choke point (`MutationGateway`) and one shared notifier base (`ReliableMutation`); everything else is new, additive code in `lib/core/reliability/`.

```
 ┌──────────────────────────────────────────────────────────────────────────────┐
 │ UI  (ConsumerWidget / Form)                                                    │
 │   • edits a typed Draft model         • shows Resume-draft prompt on open      │
 │   • shows per-item sync chip          • global SyncBanner (connectivity)       │
 └───────────────┬───────────────────────────────────────────────┬──────────────┘
                 │ draft writes (debounced + on lifecycle)         │ submit
                 ▼                                                 ▼
 ┌───────────────────────────────┐               ┌────────────────────────────────┐
 │ PILLAR 1  Draft Persistence   │               │ Mutation Notifier (AsyncNotifier)│
 │  DraftController / DraftStore │               │   uses ReliableMutation base     │
 │  autosave observer + lifecycle│               └───────────────┬─────────────────┘
 └───────────────────────────────┘                               ▼
                                                 ┌────────────────────────────────┐
                                                 │ Repository (Api / Hybrid)       │
                                                 │   verbNoun({query, request})    │
                                                 └───────────────┬─────────────────┘
                                                                 ▼
                                   ┌──────────────────── PILLAR 3 ───────────────────┐
                                   │ MutationGateway.execute(MutationEnvelope)        │
                                   │   • assigns operationId = Idempotency-Key        │
                                   │   • consults SyncPolicy(type)                    │
                                   └───────┬───────────────────────────────┬─────────┘
                              online &     │                     offline / queueable │
                              online-only  ▼                                         ▼
                              ┌────────────────────┐              ┌─────────────────────────────┐
                              │ Dio (Idempotency-Key│              │ PILLAR 2  Sync Engine        │
                              │  + correlation id)  │              │  Outbox (durable) → enqueue  │
                              │  → server row       │              │  → optimistic ack to caller  │
                              └──────────┬──────────┘              └──────────────┬───────────────┘
                                         │ 2xx row                                │
                                         ▼                          ConnectivityService fires
                              reconcile into cache/state            ▼  (+ backoff timer)
                                                          SyncEngine.flush() → Dio (replay w/ key)
                                                          → confirmed / conflict / failed
```

**Decision rule at the gateway:** the write's `SyncPolicy` decides the path —
- `onlineOnly` (login, payment-gateway, AI generation): never queued; fail fast with a clear error.
- `queueable` (attendance, marks, leave, internal fee-collection record, most data entry): try online; on network/5xx failure, enqueue to the outbox and return an **optimistic** result tagged `pending-sync`.
- `draftOnly` (multi-step wizards before final submit): persisted as a draft, never auto-sent until the user submits.

---

## 5. Pillar 1 — Draft Persistence

**Goal:** every in-progress form is continuously saved locally and offered back on return.

**Components (`lib/core/reliability/drafts/`):**
- `DraftModel` — interface every draftable form implements: `String get draftKey` (stable per entity, e.g. `exam_marks:{examId}:{classId}:{teacherId}`), `Map<String,dynamic> toJson()`, `factory fromJson(...)`.
- `DraftStore` — durable CRUD over the local DB (§9): `save(key, json, meta)`, `read(key)`, `delete(key)`, `listFor(userId)`. Keyed by `(draftKey, userId, schoolId)`.
- `DraftController` (Riverpod) — orchestrates autosave + recovery for a screen; exposes `hasRecoverableDraft`, `resume()`, `discard()`.
- `DraftAutosaveObserver` — extends the existing `AksharaErrorObserver` `ProviderObserver`; when a registered `…DraftProvider` changes, schedules a **debounced** (e.g. 800 ms) `DraftStore.save`.
- `LifecycleDraftFlusher` — the app's **first** `WidgetsBindingObserver` (added in `lib/app/app.dart`); on `inactive/paused/detached` flushes all dirty drafts immediately (covers phone-lock / app-switch / kill).

**Autosave triggers:** (1) debounced on draft-provider change; (2) on app lifecycle background/detach; (3) explicit `saveDraft()`. **Recovery:** on screen open, `DraftController` checks for a draft by key; if present, shows a non-blocking **"Resume / Discard"** prompt (WhatsApp-draft UX). Drafts are **deleted on confirmed submit** (or on explicit discard).

**Form integration (two existing patterns, both supported):**
- **Lifted `StateProvider<XxxDraft>`** (~16 today): add `toJson/fromJson` to the Draft model → fully automatic save/restore. This is the recommended pattern; new forms should use it.
- **Ephemeral `TextEditingController`** forms: provide a `DraftScopeMixin` that snapshots/restores controller text via a small adapter. Migrating these is incremental (not required for Phase 0 except the pilot-critical screens).

**Privacy:** drafts can hold PII (marks, fees) → stored in the **encrypted** local DB (§9), scoped to the logged-in user, and purged on logout.

---

## 6. Pillar 2 — Sync Engine

**Goal:** queue writes while offline, sync automatically on reconnect, never duplicate, detect & resolve conflicts.

**Components (`lib/core/reliability/sync/`):**
- `MutationEnvelope` — the durable unit of work: `{ operationId (uuid), type, method, path, requestJson, queryScope, createdAt, attempts, status, lastError, entityRef }`. `operationId` doubles as the **`Idempotency-Key`**.
- `Outbox` — durable FIFO-per-entity queue (DB table, §9) with a DAO: `enqueue`, `nextBatch`, `markInFlight/Confirmed/Conflict/Failed`, `purgeConfirmed`. Modeled on `audit_upload_queue.dart`, upgraded to a transactional store.
- `ConnectivityService` — wraps `connectivity_plus` + an actual reachability ping (connectivity ≠ internet); exposes `Stream<bool> online`.
- `SyncEngine` — the worker: on `online → true` (and on a backoff timer, and on enqueue-while-online) it drains the outbox: for each op, send via Dio with its `Idempotency-Key`, then transition state by response (table below). Single-flight per `entityRef` to preserve order; bounded concurrency overall (reuse the RT-35 pool idea).
- `Backoff` — exponential with jitter (e.g. 1s, 2s, 4s … cap 5 min), per-op attempt counter; permanent-failure cutoff after N attempts → surfaced, not silently dropped.
- `SyncStatusProvider` — exposes `{pending, inFlight, conflicts, lastSyncedAt, online}` for the banner + per-item chips.

**Op state machine & response handling:**

| Response | Meaning | Action |
|---|---|---|
| `2xx` + row | accepted | mark **confirmed**, reconcile returned row into cache/provider, delete its draft |
| `409 IDEMPOTENCY_CONFLICT` (replay) | already applied (lost ack) | mark **confirmed** using the replayed response — **exactly-once guaranteed** |
| `409 CONFLICT` (business, carries server row) | someone else changed it | mark **conflict**, surface "your copy vs server copy" resolver (§ conflict policy) |
| `4xx VALIDATION/FORBIDDEN/NOT_FOUND` | request is wrong / not allowed | mark **failed-permanent**, surface to user, do **not** retry |
| `402 PLAN_UPGRADE` | entitlement lost | mark **failed-permanent**, surface upgrade |
| `5xx` / network / timeout | transient | **retry with backoff**; stays `pending` |

**Idempotency (the no-duplicate guarantee).** Every queued write carries a client-generated `operationId` as `Idempotency-Key`. The backend's `runWithIdempotency` stores the first response keyed by `(org, key)` and **replays it** on any retry — so even if the original `2xx` was lost on a dropped connection, the retry returns the same result and creates **no second row**. This is the single most important correctness property and it builds directly on the existing `request_idempotency` table.

**Conflict handling — CONFLICT CATEGORIES (refinement R2, no global LWW).** Every operation in the Operation Policy Registry declares a `ConflictCategory`. There is **no single global policy**:

| Category | Applies to | Behaviour on conflict |
|---|---|---|
| **`lowRisk`** | drafts, notes, temporary edits, single-owner non-financial data (e.g. a teacher's own attendance/homework draft) | **Last-write-wins** — client write applied; the overwrite is logged for traceability |
| **`highRisk`** | **fees, payroll, approvals, published marks, inventory, finance** (anything money / record-of-truth) | **Detect + require explicit user resolution** — never auto-overwrite. The `409 CONFLICT` carries the current server row; the user is shown **"your copy vs server copy"** and must explicitly choose; nothing is committed silently |

The category is enforced by the `ConflictResolver`: `lowRisk` resolves automatically (LWW), `highRisk` parks the op in a `conflict` state and surfaces it in the Sync Center (R3) until the user resolves it. **Field-merge** stays deferred (added per-entity only where additive merges are provably safe, e.g. two teachers entering marks for *different* students; same-cell always treated as `highRisk`).

---

## 7. Pillar 3 — Repository Integration

**Goal:** every write inherits reliability with no per-screen code; future modules get it for free.

**Two integration seams (both thin, both reusable):**

1. **`ReliableMutation` base** (`lib/core/reliability/reliable_mutation.dart`) — a mixin/base for the mutation `AsyncNotifier`s that replaces the per-feature `_runMutation`. It provides, once: the double-submit guard, error-text mapping, audit hook, read-invalidation, **and** routing the call through the `MutationGateway`. Migrating a feature = changing `with ReliableMutation` and deleting its local `_runMutation`. New notifiers use it by default → **automatic inheritance**.

2. **`MutationGateway`** (`lib/core/reliability/sync/mutation_gateway.dart`) — the single choke point. Every repository write is expressed as a `MutationEnvelope` and handed to `gateway.execute(envelope)`. The gateway assigns the `operationId`/`Idempotency-Key`, consults the `SyncPolicy`, and routes online-vs-queue. Repositories no longer call `_dio.post` directly for queueable writes; they describe the write and let the gateway run it.

**`OperationPolicyRegistry`** (`operation_policy_registry.dart`) — the heart of R4. A **single centralized registry** maps every operation `type` → `OperationPolicy { kind: onlineOnly|queueable|draftOnly, conflictCategory: lowRisk|highRisk, optimisticBuilder?, reconciler? }`. Because **every write passes through the gateway**, behaviour is entirely **policy-driven, not per-screen**: enabling draft/queue/retry for a new module is a **one-line registry entry**, never new offline code. The registry is the one reviewable place where the whole app's reliability behaviour is declared. Defaults: data-entry = `queueable`+`lowRisk`; money/payroll/approvals/marks/inventory/finance = `queueable`+`highRisk`; auth/payment-gateway/AI = `onlineOnly`.

**Optimistic results:** for `queueable` writes the gateway returns an optimistic entity (built by `optimisticBuilder`, tagged `syncStatus: pending`) so the UI updates instantly; the real server row replaces it on confirm.

**Receipts (refinement R1):** an offline-recorded fee collection is stored and shown as **"Pending Sync"**, and a **final receipt is never generated/printed/shared until the server confirms** the transaction. The optimistic state is explicitly non-final; the Sync Center shows it as pending until confirmation.

### Sync Center (refinement R3)

A lightweight, always-available **Sync Center** (`lib/features/...` + `lib/core/reliability/sync_center/`):
- **Sync-status indicator** — a small chip (synced / syncing / pending / conflict) in the app shell.
- **Offline banner** — shown **only when** offline or when items are waiting.
- **Pending-item counter** — how many writes are queued.
- **Manual retry** — a button to force-drain the outbox now (in addition to automatic backoff).
- **Detailed sync history** — a list of recent operations with status (confirmed / pending / conflict / failed), timestamp, and the entity affected; conflicts are actionable here ("resolve").

`SyncStatusProvider` exposes `{online, pending, inFlight, conflicts, lastSyncedAt, history}` to drive all of the above.

---

## 8. Backend changes required (Phase 0, server side)

The client cannot guarantee exactly-once or conflict-safety alone. Three additive backend changes (each behind tests, deployed via the standard recipe):

1. **Universal idempotency.** Wrap the `moduleRouters` dispatch so **every** mutating route runs through `runWithIdempotency` keyed by the `Idempotency-Key` header + `(org)` — today only 3 paths do. Reuses `request_idempotency` (migration `20260814000000`); no new table. Effect: any retried write is replayed, never duplicated.
2. **Row versioning + conflict response.** Add `row_version` (int, bumped on update) — or adopt `updated_at` as an `If-Unmodified-Since` precondition — on the tables that participate in queued writes (attendance, marks, leave, fee records, profile edits). On precondition mismatch, return **`409 CONFLICT` with the current server row in the body** so the client can show "yours vs theirs". One migration + handler change on the queueable entities (not all 446 routes).
3. **(Optional) batch flush endpoint** mirroring `audit/events/batch` for high-volume queues (attendance rosters): accept `{operations:[…]}`, dedup by `operationId`, return per-op results. Reduces round-trips on reconnect. Can be deferred to post-Phase-0 if per-op flush is fast enough.

These are tracked as Phase 0 backend tasks and verified by new Deno tests (which also help close the QA-B idempotency/conflict gaps later).

---

## 9. Local storage & security

**Decision: use an embedded SQLite database via `drift`, encrypted with SQLCipher.** (Engineering decision — see §11 trade-offs.)

- **Why SQLite/drift, not `shared_preferences`/Hive:** the outbox needs **transactional** dequeue (mark-in-flight + delete atomically) to guarantee exactly-once; it needs indexed queries (by status / entity / key); and draft payloads (e.g. a 50-student marks grid) are larger than `shared_preferences` is meant for. `shared_preferences` is a single JSON blob with no transactions — corruption-prone under concurrent writes. `audit_upload_queue` gets away with it only because audit events are tiny and append-only.
- **Tables:** `outbox_ops` (the `MutationEnvelope`s), `drafts` (form snapshots), `sync_meta` (cursors/last-sync). One drift database: `lib/core/reliability/db/reliability_db.dart`.
- **Encryption at rest:** the DB is opened with SQLCipher using a key held in `flutter_secure_storage` (drafts/outbox may contain PII — marks, fees, names). This also advances `QA-X-031` (secure storage).
- **Tokens stay** in `flutter_secure_storage` (unchanged). **Read cache** (Pillar for `QA-X-004`) is a lightweight, TTL'd table in the same DB for already-loaded reads — bounded, not a full mirror.
- **Retention & purge:** confirmed ops purged immediately; drafts purged on submit/discard; **everything wiped on logout / user switch** (multi-user device safety).

---

## 10. New components & dependencies

**New code (all additive, under `lib/core/reliability/` unless noted):**
```
lib/core/reliability/
  connectivity/connectivity_service.dart            (+ provider)
  drafts/draft_model.dart, draft_store.dart,
         draft_controller.dart, draft_autosave_observer.dart,
         draft_scope_mixin.dart
  sync/mutation_envelope.dart, mutation_gateway.dart, outbox.dart,
       sync_engine.dart, sync_policy.dart, backoff.dart, conflict.dart,
       sync_status_provider.dart
  reliable_mutation.dart                             (shared notifier base)
  db/reliability_db.dart                             (drift, encrypted)
lib/shared/widgets/sync_banner.dart                  (+ per-item sync chip)
lib/app/app.dart                                     (add WidgetsBindingObserver)
supabase/functions/_shared/…                         (universal idempotency wrapper)
supabase/migrations/<new>_row_version_conflict.sql   (versioning on queueable entities)
```
**New packages (pubspec):** `uuid` (op ids), `connectivity_plus` (reachability), `drift` + `sqlite3_flutter_libs` + `sqlcipher_flutter_libs` (encrypted local DB), `drift_dev` + `build_runner` (dev). All are mainstream, well-maintained, license-clean.

---

## 11. Key design decisions & trade-offs

| # | Decision | Why | Alternative considered |
|---|---|---|---|
| D1 | Hook at a **shared notifier base + `MutationGateway`**, not a raw Dio interceptor | The Dio layer can't reconcile a returned row into app state or know draft identity; the app already has one uniform write funnel to extend | Dio-interceptor queue — rejected (no domain/state awareness; would need ids anyway) |
| D2 | **Client always sends an `Idempotency-Key`; backend applies it universally** | Turns every retry into a safe replay → the no-duplicate guarantee; reuses existing `request_idempotency` + an already-key-aware auth interceptor | Server-minted ids only — rejected (a lost 2xx duplicates the row) |
| D3 | **SQLite + SQLCipher behind a `ReliabilityStore` interface** (sqflite impl for device; in-memory impl for tests) | Transactional exactly-once dequeue, indexed queries, PII encryption; the interface keeps engine logic storage-agnostic and unit-testable **without codegen** | Drift — great DX but adds `build_runner` codegen risk to a brand-new package; `shared_preferences`/Hive — rejected for the outbox (no atomic dequeue) |
| D4 | **Universal `OperationPolicyRegistry`** (onlineOnly / queueable / draftOnly + conflict category per type) — every write passes through (R4) | Not everything should be queued (login, gateway, AI); one declarative, reviewable place; new modules = policy config, no per-screen code | Per-feature offline integrations — **rejected by owner (R4)**; queue-everything — unsafe for gateway/AI |
| D5 | **Conflict categories (R2):** `lowRisk`=LWW, `highRisk`=detect+explicit resolution; field-merge deferred | No global LWW; money/approvals/marks/inventory/finance never silently overwritten; LWW only for single-owner low-risk data | Global LWW — **rejected by owner (R2)**; auto-merge everywhere — silent-corruption risk |
| D6 | **Staged rollout behind a flag**, pilot-critical writes first | Avoids rewriting 267 sites at once; matches the existing per-module `ENABLE_API_MODE` pattern | Big-bang migration — rejected (risk, untestable in one step) |

---

## 12. Rollout / sequencing (no big-bang)

- **Phase 0a — Foundation (no behavior change):** build `lib/core/reliability/*`, the DB, `ConnectivityService`, `MutationGateway` (default policy = `onlineOnly` pass-through), and the universal `Idempotency-Key` (client) + universal idempotency (backend). Result: **retries are now safe everywhere**, zero UX change. Add the lifecycle observer + sync banner (shows "online", does nothing else yet).
- **Phase 0b — Pilot-critical writes:** migrate **attendance, exam marks, leave, internal fee-collection record** to `queueable` + draft persistence + recovery UX. These are precisely the QA-X P0 rows; verify each with the airplane-mode integration tests.
- **Phase 0c — Inherit-by-default:** flip the shared `ReliableMutation` base on so all ~154 mutations route through the gateway (still `onlineOnly` unless their policy says otherwise) and new modules inherit automatically. Migrate remaining forms to draft persistence opportunistically.
- **Exit Phase 0 → start QW1.**

---

## 13. Test strategy (this is what closes the QA-X rows)

Because the whole program is QA-first, the platform ships **with** its tests, which become the closing evidence:
- **Unit:** outbox lifecycle, backoff schedule (fake clock), idempotency replay, conflict transitions, draft save/read/purge, connectivity stream. → `QA-X-007, -008`.
- **Widget:** draft autosave + Resume/Discard prompt; sync banner states; per-item pending/synced/conflict chips; unsaved-guard from dirty state. → `QA-X-005, -006, -009`.
- **Integration (airplane-mode harness):** enter attendance offline → kill app → relaunch → draft restored → reconnect → flushed exactly once (no duplicate); same for fee collection. → `QA-X-001, -002`. Cached read offline → `QA-X-004`.
- **Backend Deno:** universal idempotency replay; 409-with-server-row conflict. → also strengthens QA-B idempotency/RLS rows.

---

## 14. Risks & mitigations

| Risk | Mitigation |
|---|---|
| Money double-charge / double-receipt on retry | Idempotency-Key replay (D2) + money stays "Pending sync" until server-confirmed; receipt not finalized offline (Q2) |
| Local DB corruption | Transactional drift + WAL; outbox is the source of truth; corrupt-DB recovery wipes cache only (outbox ops are also re-derivable from server idempotency where applied) |
| Stale/conflicting offline edits | Row-version precondition → 409-with-server-row → reject-and-surface (D5) |
| Migration risk across 267 sites | Staged rollout behind a flag (D6); pilot-critical first |
| Battery/wakeups from sync polling | Event-driven on connectivity change + bounded backoff timer, not continuous polling |
| PII at rest on shared devices | SQLCipher encryption + wipe-on-logout (§9) |

---

## 15. Resolved decisions (2026-06-27)

The Q1–Q4 review is **closed**; decisions are baked into the design above:

- **Q1 → R1 (approved):** fee collections **never** produce a final receipt until the **server confirms**; "Pending Sync" until then. (§6, §7, §14.)
- **Q2 → R2 (refined):** **no global last-write-wins.** **Conflict categories** — `lowRisk` (drafts/notes/temp) = LWW; `highRisk` (fees, payroll, approvals, published marks, inventory, finance) = detect + explicit user resolution. (§6.)
- **Q3 → R3 (approved):** lightweight **Sync Center** — status indicator, offline banner only when needed, pending counter, manual retry, detailed sync history. (§7.)
- **Q4 → R4 (modified):** **universal platform service** in the shared write pipeline; **every write passes through**; behaviour driven by the centralized **Operation Policy Registry**; future modules = policy config only, no per-screen offline code. (§7, §12.)

---

## 16. Definition of done (Phase 0 exit → unblocks QW1)

- `lib/core/reliability/*` merged with unit + widget + integration tests green in CI.
- Universal `Idempotency-Key` (client) + universal idempotency (backend) live; conflict 409-with-row on queueable entities; migration deployed.
- Drafts auto-save + recover on the pilot-critical screens; sync banner + per-item status shipped.
- All writes route through `MutationGateway` (policy-gated); new modules inherit by default.
- Tracker rows `QA-X-001/002/004/005/006/007/008/009` move to `Verified`.
- A short `DATA_RELIABILITY_PLATFORM_CERTIFICATION.md` records the green evidence (consistent with project certification discipline).

---

**This is a design for review. No code will be written until you approve the architecture (and the Q1–Q4 choices). On approval, Phase 0 implements it; only after Phase 0 ships does QW1 begin.**
