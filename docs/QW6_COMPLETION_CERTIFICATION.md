# QW6 — Resilience & Non-functional · COMPLETION CERTIFICATION

**Date:** 2026-06-30 · **Branch:** `feature/data-reliability-platform`
**Gate:** Engineering Operating System (`/eos`) per [`engineering/ENGINEERING_GATE_POLICY.md`](engineering/ENGINEERING_GATE_POLICY.md).
**Companion:** [`FINAL_QA_MASTER_TRACKER.md`](FINAL_QA_MASTER_TRACKER.md) · [`FINAL_QA_ROADMAP.md`](FINAL_QA_ROADMAP.md) · [`PRODUCT_COMMERCIAL_BACKLOG.md`](PRODUCT_COMMERCIAL_BACKLOG.md).

---

## Verdict

> **EOS gate: PASS** for all locally-verifiable QW6 work. The wave is **CONDITIONAL at the program
> level** pending **1 Test-Written/infra-blocked** row (`QA-X-025` p95 latency cron — needs the live
> VPS) and **1 Blocked-MISSING-FEATURE** row (`QA-X-020` HR Excel import — owner-deferred; feature
> does not exist). **No locally-fixable P0/P1 remains** — everything provable on local hardware is
> proven, and the two that could not be are honestly marked, not forced.

**QW6 scope = 24 rows.** 3 (`QA-X-014/015/016` audit-trail) were already closed in QW4. The **21
open rows**: **17 Verified · 2 Verified-rescoped · 1 Test-Written/infra-blocked · 1 Blocked-MISSING-FEATURE.**

Authoritative sweep on local hardware:
- **Flutter** `flutter test` → **2974 passed / 0 failed** (1 skipped) — up +69 from QW5's 2905, no regression.
- **Deno** new QW6 tests → **37 passed / 0 failed**; `api/` regression (the `handleRequest` change's blast radius) → **16/0**.
- `flutter analyze` → **0 issues**; `deno check` → clean.
- **69 new Flutter tests · 37 new Deno tests · 20 golden baselines · 1 reusable platform build · 1 contained backend wire-up · 1 infra-blocked k6 probe.**

---

## Backlog cross-check FIRST (the wave's standing discipline)

Per the owner's standing instruction, **every row was compared against
[`PRODUCT_COMMERCIAL_BACKLOG.md`](PRODUCT_COMMERCIAL_BACKLOG.md), [`FINAL_QA_ROADMAP.md`](FINAL_QA_ROADMAP.md)
and `still_pending.md` BEFORE any code was written.** A 4-agent read-only discovery pass classified
each of the 21 rows **REAL-NOW / INFRA-BLOCKED / MISSING-FEATURE** against the actual codebase. Five
rows depended on a missing feature; rather than assume scope, **four owner decisions** were taken
(the fifth, `QA-X-017`'s backend leg, was folded into decision 2):

| Row | Finding | Owner decision (2026-06-30) |
|---|---|---|
| `QA-X-004` offline cached reads | No read cache exists — Phase 0 shipped offline *writes* (outbox/drafts) only | **BUILD** the read-cache platform now |
| `QA-X-017` backend denied-audit | Deno permission middleware returns 403 with no server-side audit | **Also wire it** (single choke point) |
| `QA-X-021` education/marks CSV import | Doesn't exist; the student-onboarding importer does | **Re-scope** to the certified student importer; defer the education-CSV variant |
| `QA-X-022` batch/file reconciliation | Doesn't exist; single-payment reconcile does | **Re-scope** to single-payment reconcile + idempotency; defer the batch variant |
| `QA-X-020` HR Excel import | Entirely absent (no UI, no endpoint) — corroborates QW3 `QA-F-048` | **Defer** to a future build; log to the backlog |

A documentation discrepancy was surfaced and corrected: the roadmap's Phase-0 section claimed
`QA-X-004 → Verified`, but the tracker had it `Open/QW6` and the code confirmed **no read cache** —
Phase 0 over-claimed offline-read coverage. QW6 closes the real gap.

---

## What landed, by batch

### Batch A — Offline read-cache platform + offline behaviour (`QA-X-004/005/009`)
The read-side counterpart of Phase 0's write outbox, built as a **reusable platform layer**, not
per-screen code:
- `lib/core/reliability/model/cache_record.dart` — the cached-read record.
- `ReliabilityStore.putCache/getCache/deleteCache/clearCache` (interface + both impls). The
  encrypted SQLCipher store gains a `reliability_read_cache` table via a safe **v1→v2 `onUpgrade`
  migration** (never drops the existing outbox/drafts), **LRU-bounded** (oldest evicted on insert),
  and wiped on logout alongside drafts/outbox.
- `lib/core/network/interceptors/offline_read_cache_interceptor.dart` — a **single Dio choke point**
  (placed after `RetryInterceptor`, before `ApiErrorInterceptor`) that caches successful `GET`
  bodies and, once retry has exhausted online attempts on a connectivity failure, serves the
  last-good copy tagged as a saved copy. **Tenant-scoped** keys; **excludes auth/legal/session/token**
  (a stale security answer is never served). Every read inherits offline caching with no per-screen
  code — the same philosophy as the write side.
- Wired via an optional `readCacheStore` dependency on `DioClientDependencies`, supplied from
  `dioProvider` (omitting it — tests/auth client — disables caching cleanly).
- `QA-X-005` connectivity-change banner + `QA-X-009` unsaved-changes guard proven against the
  existing Phase-0 `SyncBanner` / RT-30 `AksharaUnsavedChangesGuard`.
- Tests: `qw6_offline_read_cache_store_test.dart` (8), `qw6_offline_read_cache_interceptor_test.dart`
  (9), `qw6_connectivity_banner_test.dart` (1), `qw6_unsaved_guard_test.dart` (3).

### Batch B — Backend denied-access audit (`QA-X-017`)
- `supabase/functions/_shared/audit/access_denied_audit.ts` — emits a structured `access_denied`
  observability event (the same channel `logRequest` uses), best-effort actor resolution
  (re-verifies the bearer; a 403 means a *valid* token lacking the permission), reads the body via
  `clone()` so the client response is untouched, **never throws**.
- Wired at the **single `handleRequest` choke point** — **zero changes to the 29 `requirePermission`
  call sites** (the large cross-cutting change was deliberately avoided per the standing "pause on
  systemic fixes" rule).
- Client leg proven via real `ManagePermissionGuard`/`ApprovePermissionGuard` denies.
- Tests: `api/qw6_access_denied_audit_test.ts` (5), `test/security/rbac/qw6_denied_access_audit_test.dart` (3).
- **Honest scope note:** the persisted DB-audit-*row* leg is intentionally the live-DB extension
  (consistent with how `QA-X-014/015/016`'s persisted-row leg is live-DB); the contract is fully
  proven DB-free here.

### Batch C — State sweeps (`QA-X-018/019`)
- `test/shared/async/qw6_state_sweep_test.dart` (9) sweeps the **single canonical seam every ERP
  screen delegates to** — `ErpAsyncBody`/`resolveErpAsync`: loading/error/empty/data → the canonical
  `AksharaLoading/Error/EmptyState`/builder; and proves errors surface a **mapped** message (a raw
  `Exception(sentinel)` never leaks its text/stack), with a working retry affordance when retryable
  and none when forbidden. Robust across all screens vs brittle per-screen enumeration.

### Batch D — Import/export (`QA-X-021/022/023`)
- `qa_x_021_student_import_integrity_test.ts` (3) — student-importer round-trip (bad-row + duplicate
  surfaced; commit inserts only valid rows; rollback reverses).
- `qa_x_022_offline_reconcile_integrity_test.ts` (3) — single-payment reconcile match-once /
  no-double-credit / idempotent-twice / unknown-id error.
- `qa_x_023_board_pack_pdf_test.dart` (3) — fills the named gap: `buildDirectorBoardPackPdf`
  valid-`%PDF`/non-empty-bytes + model field-presence, plus `buildTabularReportPdf` non-empty.

### Batch E — Performance (`QA-X-024/026/025`)
- `qa_x_024_large_list_lazy_render_test.dart` (3) — 5000-item `ListView.separated` builds only
  ~viewport+buffer rows (<<5000), never the last item up front, recycles on deep scroll.
- `qa_x_026_parent_fanout_cap_test.ts` (5) — `loadChildProfiles` applies `.limit(50)` to both
  fan-out queries against an over-cap (500–1000 row) fake; empty child list → zero DB reads.
- `scripts/perf/qa_x_025_p95_latency_probe.js` + README — k6 probe **authored, INFRA-BLOCKED**
  (throws if `API_BASE_URL` unset; flips to Verified on the first scheduled live-VPS run, same lane
  as QW1's live-regression cron).

### Batch F — Golden / visual-regression (`QA-X-027/028/029/030`)
20 new baselines (390/428/834 + dark) pinning the surfaces not previously covered: finance
collections + collection-detail (`027`), admissions enrollment wizard (`028`), control-center
dashboard (`029`), HR dashboard (`030`). Finance/admissions/director/management/intelligence
dashboard goldens already existed and were not regenerated.

### Batch G — Security (`QA-X-031/032/033/034`)
- `qa_x_031_token_storage_encryption_test.dart` (6) — production selection yields the encrypted
  `FlutterSecureStorageBackend` (Keychain/Keystore), plaintext prefs only on web/forced — **passes**.
- `qa_x_032_legal_gate_bounded_failopen_test.dart` (4) — fail-open on source error, **bounded**: a
  reachable "blocked" verdict re-blocks on the next refresh/login (no permanent bypass).
- `qa_x_033_exam_results_antitamper_test.ts` (8) — publish-without-approval rejected before publish;
  post-publish mark edit fenced by `published=false` (0-row update → not-found).
- `qa_x_034_upload_presign_enforcement_test.ts` (13) — oversized / disallowed-type / cross-constraint
  presign → 422 before storage; non-holder → 403; allowed type+size passes.
- **No real security weakness found** — `QA-X-031` (encrypted-at-rest) and `QA-X-032` (bounded
  fail-open) are honest passes.

---

## Row ledger (21 worked rows)

| Status | Rows |
|---|---|
| **Verified** (17) | `QA-X-004` `QA-X-005` `QA-X-009` `QA-X-017` `QA-X-018` `QA-X-019` `QA-X-023` `QA-X-024` `QA-X-026` `QA-X-027` `QA-X-028` `QA-X-029` `QA-X-030` `QA-X-031` `QA-X-032` `QA-X-033` `QA-X-034` |
| **Verified — re-scoped** (2) | `QA-X-021` (→ student importer) · `QA-X-022` (→ single-payment reconcile) |
| **Test-Written — infra-blocked** (1) | `QA-X-025` (p95 k6 probe; needs live VPS cron) |
| **Blocked — MISSING-FEATURE** (1) | `QA-X-020` (HR Excel import does not exist; owner-deferred → backlog) |

Already closed in QW4 (in QW6's nominal 24-row scope): `QA-X-014/015/016`.

---

## Honest conditions carried forward

1. **`QA-X-020` HR Excel import** — feature absent; owner-deferred. Logged in
   `PRODUCT_COMMERCIAL_BACKLOG.md` (Queue 3). Certify `QA-X-020`/`QA-F-048` once built. Not GA-blocking.
2. **`QA-X-025` p95 latency** — probe authored; flips to Verified on the first scheduled live-VPS run.
3. **Live-DB legs** — the persisted denied-audit *row* (`QA-X-017`), the live exam-publish 403 +
   persisted reject (`QA-X-033`), and live latency (`QA-X-025`) belong to the live cert, per the
   established QW4 convention. The DB-free contracts are fully proven here.
4. **Product-review note (not a defect):** the finance collection-detail receipt tile is non-tappable
   but still renders an `open_in_new` affordance (captured in the `027` golden) — flagged for product.

---

## EOS verdict

**EOS gate: PASS** (locally-verifiable scope). 0 open P0/P1 that is locally fixable; analyze 0;
`flutter test` 2974/0; new Deno 37/0; `api/` regression 16/0; the read-cache build is encrypted,
tenant-scoped, LRU-bounded, security-rail-guarded, and migration-safe; the denied-audit wire-up is
contained and non-throwing. The two non-green rows are honestly marked (infra-blocked / owner-deferred),
not forced.
