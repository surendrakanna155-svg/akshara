# Akshara ERP — Data Reliability & Offline Platform Audit

**Auditor:** Fable (independent) · **Date:** 2026-07-03 · **HEAD:** `68f15cb`
**Scope:** the Phase-0 "Data Reliability Platform" — draft persistence, sync engine, idempotency, offline read-cache, encryption.
**Confidence:** High (client-side code read directly).

> **Verdict up front:** the platform is **genuinely engineered, not a facade** — but it is advertised as
> *universal / exactly-once* and delivers those properties on only **~4% of mutations**, bypasses the
> platform on the primary marks-save path, lacks draft persistence on 2 of the 4 pilot-critical
> screens, and does not auto-recover the outbox on app restart. Against the platform's **own**
> definition of done, this scope is **BLOCKED**, and the "universal idempotency / exactly-once /
> never-silently-overwritten" claims should be re-scoped before pilot.

---

## 1. What is genuinely built (real, high quality)

`lib/core/reliability/` is **34 real Dart files**: mutation gateway, sync engine with exponential backoff + jitter, send-classification state machine, conflict resolver, policy registry, encrypted SQLCipher store, offline read-cache interceptor, Sync Center UI. The code quality is high and it is unit-tested (34 cases). Three pillars are genuinely strong:

- **Offline read-cache — the strongest pillar.** One Dio choke point (`dio_client.dart:79`), GET-only, 2xx-only, tenant/school/user-scoped keys, sensitive-path exclusion (auth/legal/session/token), serve-only-on-connectivity-failure, encrypted at rest, LRU-bounded, wiped on logout. Genuinely universal for reads.
- **Encryption at rest — correct.** SQLCipher via `sqflite_sqlcipher`; 256-bit key generated once into `flutter_secure_storage`; wiped on logout.
- **R1 offline receipt-gating — correct.** Offline fee collection sets `pendingSync`, suppresses the receipt number, shows "pending sync," and only mints the receipt on server-confirm (`finance_workflow_actions.dart:798-813`). This specific money-safety promise is real.

---

## 2. Findings (against the platform's own claims)

| ID | Sev | Finding | Evidence | Recommendation |
|---|---|---|---|---|
| REL-1 | **P0** | "Universal idempotency" is inert for ~148 of ~154 mutations — only `ReliableWriter` paths send an `Idempotency-Key` (~6 methods, 5 datasources). The auth interceptor *replays* keyed writes but never *mints* a key | `dio_mutation_executor.dart:28` (only key-attach site); `auth_interceptor.dart:112`; `grep ReliableWriter → 5 datasources` | Mint an `Idempotency-Key` in a Dio interceptor for **all** mutating verbs, or state honestly that only ~6 paths are idempotent. Any non-migrated write retried after a lost 2xx **duplicates the row** (double fee / double leave). |
| REL-2 | **P1** | Marks "Save all" (the real teacher flow) bypasses the platform — direct `_dio.post`, no key/queue/draft | `exam_marks_entry_screen.dart:339,195,225`; `exam_remote_datasource.dart:196` | Route `bulkUpdateMarks` through `ReliableWriter`; add draft autosave to the grid. The flagship "35 of 50 marks survive interruption" scenario currently fails for the batch path. |
| REL-3 | **P1** | No draft persistence on 2 of 4 pilot-critical screens (exam marks, fee); `DraftAutosaveMixin` wired into only 2 screens (parent leave, teacher attendance) | `grep DraftAutosaveMixin → 2 files`; none in exam_admin/finance | Wire the mixin into the marks grid + fee form, or scope the "resume where you left off" claim to attendance+leave. |
| REL-4 | **P1** | App-restart doesn't auto-drain the outbox when relaunched already-online (start = connectivity-transition listener only; no boot flush) | `sync_engine.dart:50-57`; `main.dart:72` (no boot flush) | Call `syncEngine.flush()` on boot and on app-resume when online. Add a "relaunch-while-online" test. Queued writes from a killed session can otherwise sit undrained indefinitely. |
| REL-5 | **P1** | First-write optimistic concurrency is not active — `expectedVersion` is set only on the retry path; a first offline edit that loses a race silently overwrites | `sync_engine.dart:169-180`; never set on first `runWrite` | Capture + send the base `row_version` on the first write of high-risk ops (the documented Phase-0c task). R2's "fees/marks never silently overwritten" is not enforced today. |
| REL-6 | **P2** | No transactional dequeue — exactly-once rests entirely on the server key (which REL-1 shows is mostly off) | `grep transaction lib/core/reliability/store → empty`; `sqflite_reliability_store.dart:115-131` | Wrap mark-in-flight/confirm/delete in `db.transaction`, or drop the "transactional exactly-once" claim. |
| REL-7 | **P2** | Read-cache has no TTL despite the design's "TTL'd table"; serves arbitrarily-stale bodies | `offline_read_cache_interceptor.dart`; `cache_record.dart` (no expiry field) | Add a max-age on serve (mitigated today by serve-only-on-connectivity-failure). |
| REL-8 | **P2** | Store-open failure silently degrades to in-memory (no durability, no encryption) with only a `debugPrint` | `reliability_store_opener.dart:19-24` | Surface a telemetry event; consider blocking offline writes if the durable store is unavailable. |
| REL-9 | **P3** | Connectivity = interface-only (no reachability ping) despite design §6; per-entity single-flight ordering described but unimplemented | `connectivity_service_impl.dart:50`; `entityRef` stored but never used to serialize | Correct the doc, or add a lightweight HEAD ping + per-entity lock. |

---

## 3. Idempotency coverage — the count

- Client mutation surface: **~154 methods** across 51 notifiers.
- Client paths that emit an `Idempotency-Key`: **~6** (attendance submit/mark, exam per-cell `updateMark`, teacher+parent leave, fee `createCollection`, staff check-in) — all via `ReliableWriter → MutationGateway → DioMutationExecutor`.
- Backend `dispatchWithIdempotency` is real and dispatch-wide **but self-admittedly inert without the header** → it guards those ~6 keyed paths, not ~154.
- `row_version`/409: enforced on the exam-mark update only, and only on the retry path.

**Verdict: end-to-end idempotency covers ~6 of ~154 mutations (~4%). "Universal idempotency" is not true as shipped.**

## 4. Reliability platform reality (summary)

| Pillar | Reality |
|---|---|
| Draft persistence | **PARTIAL** — reusable mixin, wired into 2 screens; missing on marks + fee |
| Sync engine | **REAL** with 2 gaps — no boot-flush recovery (REL-4), no transactional dequeue (REL-6) |
| Idempotency | **~4% coverage** — not universal (REL-1) |
| Offline read-cache | **REAL & well-placed** (strongest pillar); no TTL (REL-7) |
| Encryption at rest | **REAL & correct**; silent in-memory fallback (REL-8) |

## 5. Genuine strengths

- The read-cache interceptor is textbook (single choke point, safe filters, tenant-scoped, encrypted, logout-wiped).
- Encryption-at-rest is correctly done.
- R1 offline receipt-gating is a real, correct money-safety guarantee.
- The sync engine's classification + backoff + conflict state machine is coherent and well-unit-tested.
- Integration is additive/non-invasive (nullable `ReliableWriter` seam) → zero regression risk (the flip side of why coverage is low).

## 6. Unknowns

- Exact backend handler-count that would honour a key if the client sent one (the client ceiling of ~6 bounds real coverage regardless).
- Live-cert reproducibility of the "20/20 reliability" run (proves the *server replay mechanism* on 3 routes; cannot prove ~154-route coverage, and doesn't claim to).
- Real-world impact of the unimplemented per-entity ordering (depends on whether two queued writes ever target the same row).
