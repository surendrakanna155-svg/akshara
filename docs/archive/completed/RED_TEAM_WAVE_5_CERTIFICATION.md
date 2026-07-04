# AKSHARA — Red Team Wave 5 Certification

**Status:** ✅ **PRODUCTION CERTIFIED (2026-06-27) — live 15/15** · **Regression: W1 26/26 · W2 25/25 · W3 24/24 · W4 flutter 2450**
**Wave:** RED_TEAM **Wave 5** — "Input/Upload Hardening & Scale." **(Final Red Team wave — RT-01..35 now all Closed.)**
**Scope source of truth:** [`RED_TEAM_MASTER_TRACKER.md`](./RED_TEAM_MASTER_TRACKER.md) (RT-31..RT-35) + [`RED_TEAM_COMPLETION_ROADMAP.md`](./RED_TEAM_COMPLETION_ROADMAP.md) (Wave 5). No new features, no roadmap expansion, no new audit — this closes the tracker's Wave-5 findings only.
**Branch:** `feature/scope-trim-school-build`
**Migration:** none. Backend = 6 edge files; client = shared form field + SIS sheet. Bucket size/MIME limits were already migrated (`20260622700000`, `20260806000020`); Wave 5 adds the matching app-layer early-rejection.
**Live cert:** `scripts/qa/live_cert_red_team_wave5.py` → **15/15** against the live VPS pilot (edge-minted scoped JWTs referencing real `sessions` rows + the live `permissions_version`, per Wave-3 RT-16/17).

---

## 1. Verdict

**PRODUCTION CERTIFIED.** All **5 Wave-5 findings** (1 High, 3 Medium, 1 Low) are closed. This wave bounds untrusted input (uploads, text, numbers), caps an unbounded fan-out, and removes the per-request DB connect/teardown that was the scaling cliff.

With Wave 5 closed, **all five Red Team waves (RT-01..RT-35) are Closed** — the engagement's fix scope is complete.

## 2. Gate results

| Gate | Result |
|------|--------|
| `flutter analyze` | **No issues found** |
| `flutter test` | **2450 passed / 1 skipped / 0 failed** (+2 new `test/red_team/red_team_wave5_test.dart`) |
| `deno test` (`supabase/functions/_shared`) | **871 passed / 0 failed / 2 ignored** (+4 new `red_team_wave5_test.ts`) |
| Live cert (`live_cert_red_team_wave5.py`) | ✅ **15/15** vs live VPS pilot |
| **Regression — Wave 1** | ✅ **26/26** live (exercises the new pool) |
| **Regression — Wave 2** | ✅ **25/25** live |
| **Regression — Wave 3** | ✅ **24/24** live (exercises the new pool) |
| **Regression — Wave 4** | ✅ **flutter 2450** (client wave; no VPS cert) |

## 3. Methodology

Backend findings are proven over HTTPS against the deployed edge (with deno unit tests for the pure readers); the client bound is a widget test. The connection-pool fix (RT-35) is proven three ways: a static check that the deployed `tenant_db.ts` uses a pool (acquire/`release`, no per-request `await client.end()`), a **20-way concurrent** authenticated-read probe that all succeed (the pool absorbs concurrency without a connection-exhaustion cliff), and the W1/W2/W3 regression certs — which route every read/write through `withTenantContext` — passing end-to-end on the pooled path. Per-request transaction isolation is preserved on reused connections (the `/health/tenant-access` cross-scope probes — parent-sees-only-own-child, student-sees-self — still pass on pooled connections, because each request keeps its `BEGIN … set_request_context(is_local) … COMMIT` envelope).

## 4. Headline live evidence (15/15)

| RT | Finding | Live proof |
|---|---|---|
| **RT-35** (High) | No DB connection pooling (per-request connect → exhaustion cliff) | Deployed `tenant_db.ts` uses a process-level `Pool` (acquire + `release`, no `await client.end()`); a pooled authenticated read → **200**; **20 concurrent** reads → **20/20 200**. |
| **RT-31** (Med) | Presign sets no content-type / size | Memories presign of a `.exe` → **422**; oversized (60 MiB) → **422**; admissions presign of a `.exe` → **422** (bucket caps still enforce at upload as defence-in-depth). |
| **RT-32** (Med) | Unbounded text input | A 20 001-char title on `POST /library/digital-resources` → **422**; deployed reader carries `MAX_FIELD_LEN` (20 000); the shared `AksharaFormField` (116 usages) now caps entry. |
| **RT-33** (Med) | `intOr` accepts any finite int | Deployed reader carries `MAX_INT_MAGNITUDE` (1e12); behaviour unit-tested in deno (rejects `MAX+1`, accepts in-range incl. negatives). |
| **RT-34** (Low) | Parent children fan-out has no LIMIT | Deployed `auth_context.ts` carries `PARENT_FANOUT_LIMIT` (50) on all three fan-out queries; a real parent still resolves their linked child via `/auth/me`. |

## 5. What was fixed (per finding)

- **RT-35** — `_shared/tenant_db.ts`: a lazy, process-level `Pool` (size 10) of `erp_tenant` connections replaces `new Client() → connect() → end()` on every tenant query. `withTenantContext` now `pool.connect()` → `BEGIN`/`set_request_context`/operation/`COMMIT` → `client.release()`. Connection count is bounded by the pool size and connections are reused, eliminating the per-request connect/teardown that exhausted DB slots under spike. Chosen as an in-app pool (no PgBouncer container / infra change), self-contained in one file. Per-request RLS context is unchanged (still transaction-local, reset at `COMMIT`).
- **RT-31** — `_shared/storage/storage_service.ts` adds `validateUpload()` + `MEMORY_/ADMISSIONS_UPLOAD_CONSTRAINTS` mirroring the bucket policies; the two presign handlers (`school_memories_handlers`, `admissions_handlers`) reject a disallowed extension / declared content-type / oversized declared size with a clean **422** before issuing the signed URL. The bucket remains the hard enforcement at upload time.
- **RT-32** — `module_write_handlers.str()` now rejects a value over `MAX_FIELD_LEN` (20 000) instead of persisting it unbounded; the shared `AksharaFormField` (116 usages) gained a generous default `maxLength` (1 000 single-line / 10 000 multi-line, counter hidden) and the SIS profile sheet's raw fields were bounded.
- **RT-33** — `module_write_handlers.intOr()` now rejects an integer whose magnitude exceeds `MAX_INT_MAGNITUDE` (1e12). Sign-specific bounds (e.g. marks `0 ≤ x ≤ max`) stay enforced by DB CHECKs at the relevant tables (RT-08), so this is the systemic reader bound, not a per-field re-implementation.
- **RT-34** — `auth_context.ts` adds `.limit(PARENT_FANOUT_LIMIT)` (50) to the `student_guardians` query and the two `loadChildProfiles` fan-outs, bounding the worst-case parent-login query for an outlier/abusive account.

## 6. Disposition

RT-31, RT-32, RT-33, RT-34, RT-35 → **Closed** (fixed, deployed to the live VPS pilot, live-certified 15/15, regression W1 26/26 · W2 25/25 · W3 24/24 · W4 flutter 2450). The client portion (form `maxLength`) ships in the next app release (Play submission owner-gated).

**With Wave 5 closed, the Red Team engagement (RT-01..RT-35, Waves 1–5) is COMPLETE.** Out-of-scope tracks (Performance / UX / Security / Chaos / Legal / GA certifications) were never part of this roadmap and are not started.
