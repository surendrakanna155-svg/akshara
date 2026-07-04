# Akshara ERP — NEXT ACTIVE WAVE

**This is the ONLY file Opus 4.8 reads before each autonomous wave** — together with its state companion [`../execution/EXECUTION_DASHBOARD.md`](../execution/EXECUTION_DASHBOARD.md). Keep it small — current work only.
**Updated by:** the executor at each wave boundary (on EOS PASS + commit → advance to the next wave; refresh the dashboard at the same moment).
**Authority:** [`FINAL_EXECUTION_MASTER_ROADMAP.md`](FINAL_EXECUTION_MASTER_ROADMAP.md) · run per [`AUTONOMOUS_EXECUTION_PLAN.md`](AUTONOMOUS_EXECUTION_PLAN.md) · journal to [`../execution/IMPLEMENTATION_PROGRESS.md`](../execution/IMPLEMENTATION_PROGRESS.md).

> **Previous wave:** **P0 · W1 — Documentation Truth ✅ COMPLETE (2026-07-04)** — EOS DOCS PASS, `flutter analyze` 0, `git status` coherent. DOC-1/2/4/5 closed in the ledger.

---

## ▶ CURRENT

- **Phase:** **P1 — Backend & Code Fixes** 🟠
- **Wave:** **P1-CODE-1 — Reliability finish** (REL-1..5)
- **Status:** 🔵 In progress
- **Sequencing (owner, 2026-07-04):** the **complete live lane is provisioned in ONE dedicated phase after all code implementation is done** — so `P0-INFRA-1/3` + `P0-TEST-1/2/3` (and CI-green) are **explicitly owner-deferred**, satisfying the Autonomous-Plan Phase-0 gate ("all P0 ✅ or explicitly owner-deferred"). Execution proceeds through the **code** waves of P1→P3 first; the live lane + all LIVE-graded verification runs as the dedicated pre-pilot phase. Do NOT request off-site creds / alert sink / CI setup until then.
- **P0 status:** code/security tasks **14/19 ✅ COMPLETE**; the 5 live-lane tasks are **queued** (owner-deferred, not blocked-and-forgotten — tracked for the live-lane phase).

### P1-CODE-1 tasks (this wave) — findings REL-1..5
| Sub | Sev | What |
|---|---|---|
| **REL-1** | P0 | Mint an `Idempotency-Key` in a Dio interceptor for **all** mutating verbs (today ~4% coverage — only ~6 ReliableWriter paths). A retried non-migrated write duplicates the row (double fee/leave). |
| **REL-2** | P1 | Route marks "Save all" (`bulkUpdateMarks`) through `ReliableWriter` (not raw `_dio.post`). |
| **REL-3** | P1 | Wire `DraftAutosaveMixin` into the marks grid + fee form (currently only leave + attendance). |
| **REL-4** | P1 | Boot/resume outbox flush — `syncEngine.flush()` on boot + on app-resume when online. |
| **REL-5** | P1 | First-write optimistic concurrency — capture + send base `row_version` on the first write of high-risk ops (today set only on retry). |

### EOS gate
- `/eos reliability` → PASS. Regression: `flutter analyze` 0 · full suite green (no new failures) · new idempotency/draft/boot-flush/first-write tests.

### Next
On P1-CODE-1 EOS PASS + commit → **P1-CODE-2** (reliability polish: REL-6..9) then P1-CODE-3 (backend hardening) ∥ P1-CODE-4 (identity, 👤 PLAT-0 partial) ∥ P1-CODE-5 (HR payroll); P1-PROD-0 (XCT). Owner-scope tasks (P1-CODE-6/7/8 Hostel/Alumni/Finance-posting) pause + surface when reached.

> **Deferred live-lane tail (run in the dedicated live phase):** `P0-INFRA-1` off-site backup · `P0-INFRA-3` alert delivery · `P0-TEST-1/2/3` CI + isolation-in-CI + live-regression cron (starts the 7-day P7 clock). Plus every LIVE-graded re-verification across P0→P3.

### Active tasks (this wave only)
| Task | Category | Description | Finding | Gate / blocker |
|---|---|---|---|---|
| **P0-SEC-1** | SEC/CODE | `kReleaseMode` build refuses to run/auth unless `APP_ENV==production`; no debug-signing fallback | SEC-1, SEC-2 | proceeds now |
| **P0-SEC-2** | SEC/CODE | Session PII snapshot (phone/name/child) → encrypted secure storage, not plaintext prefs | SEC-3 | proceeds now |
| **P0-SEC-3** | SEC/CODE | Mock/QA auth compiled out of release (flavor); `ENABLE_DEMO_AUTH` production-guarded | SEC-9, SEC-10 | proceeds now |
| **P0-CODE-1** | CODE | Finance `row_version` optimistic-lock guard made effective (money lost-update) | ENG-1 | proceeds now |
| **P0-INFRA-5** | INFRA/MIGRATION | Migration reads tenant DB password from vault/secret, not a literal | DB-1/OPS-6 | proceeds now (live already rotated) |
| **P0-INFRA-6** | INFRA/CODE | Deploy-time self-test asserts edge DSN role = `erp_tenant` (NOBYPASSRLS) | DB-2 | code proceeds; live assert needs deploy |
| **P0-INFRA-4** | INFRA | Fix backup script `$1` unbound-variable warning | LV-10 | script edit proceeds; verify on live |
| **P0-INFRA-1** | INFRA | Off-site backup (3-2-1): `RCLONE_REMOTE` + nightly encrypted push | LV-3 | ⏳ **live lane** |
| **P0-INFRA-3** | INFRA | Wire watchdog alert delivery to a human sink | LV-6 | ⏳ **live lane** |
| ~~P0-INFRA-2~~ | INFRA | WAL/PITR → **✅ RESOLVED: owner accepted ~24h nightly RPO (2026-07-04)**; WAL deferred post-pilot | LV-1 | ✅ done (RPO signed off) |
| **P0-CODE-2** | CODE | Hide backend-less/thin surfaces (~8, reachable-mock) | ENG-3/MOD-4 | 👤 **hide-list** |

### Dependencies
- **Upstream:** P0 · W1 ✅ done.
- **Live lane (owner-provisioned):** VPS SSH socket + tenant Postgres — gates `P0-INFRA-1/2/3` (and the live verification of INFRA-4/6). SEC + CODE legs do **not** need it.
- **Owner decisions (👤):** `P0-INFRA-2` RPO acceptance (WAL ≤15 min vs ~24h pilot) · `P0-CODE-2` hide-list · (`LV-5` `APP_ENV=staging` intent relevant to P0-SEC-1). Surface these in a batch; the task pauses, siblings proceed.

### Files expected to change (code + infra — first application-logic wave)
- SEC: release/env guard + signing config; secure-storage session snapshot; flavor exclusion of mock/QA auth (`lib/**` app-config/auth/bootstrap).
- CODE: finance write path `row_version` guard (`supabase/functions/_shared/**` + client conflict handling).
- INFRA: `supabase/migrations/**` (password-from-secret), deploy self-test, `deploy/akshara-vps/backup/*.sh` (`$1` fix, off-site), watchdog alert wiring.

### EOS gate
- Run the relevant scopes per leg: **SEC** (P0-SEC-1/2/3, INFRA-6), **RELIABILITY/CODE** (P0-CODE-1), **OPS** (P0-INFRA-1..4), **MIGRATION** (P0-INFRA-5) → each must return **PASS**. BLOCKED ⇒ fix, re-run; do not commit, do not advance.
- **Automatic-failure tripwires apply** (data loss · security breach · duplicate financial transaction · broken auth). Any → instant BLOCKED.

### Regression required
- `flutter analyze` = 0 · `flutter test` green (no count drop) · backend `deno test` green.
- New tests: release-fail-closed build test; no-PII-in-prefs test; money-concurrency (lost-update) test; demo/mock-auth-absent-in-release scan.

### Exit criteria (all true → wave complete)
- [ ] Insecure release build impossible; no debug-signing fallback; no demo/mock auth in a prod binary.
- [ ] Session PII encrypted at rest.
- [ ] Finance concurrent-write lost-update prevented (test proves it).
- [ ] No credential literal in git migrations; deploy asserts `erp_tenant`.
- [ ] Backup script warning gone; (live lane) off-site backup exists + alert reaches a human — or explicitly deferred to the live lane with the 👤/⏳ noted.
- [ ] `/eos` PASS for every executed leg; owner-gated legs (INFRA-2 RPO, CODE-2 hide-list) surfaced, not guessed.
- [ ] Journal rows appended; roadmap statuses flipped ✅; findings marked Fixed in the ledger.

### Next wave entry criteria
On W2's executable legs at EOS PASS + commit (with live-lane/👤 legs explicitly tracked), advance to **P0 · W3 — Live Proof / CI**: `P0-TEST-1` (CI green on branch) → `P0-TEST-2` (233-probe isolation suite in CI) / `P0-TEST-3` (live-regression cron — **starts the 7-day clock** for P7). Update this file's ▶ CURRENT block to W3 and refresh the task table + dashboard.

> **Rule:** never begin the next wave with an open P0 or an EOS BLOCKED. Owner-decision (👤) tasks pause and surface in a batch; live-lane (⏳) tasks defer until provisioned; non-blocked tasks in the wave proceed.
