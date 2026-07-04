# Akshara ERP — NEXT ACTIVE WAVE

**This is the ONLY file Opus 4.8 reads before each autonomous wave** — together with its state companion [`../execution/EXECUTION_DASHBOARD.md`](../execution/EXECUTION_DASHBOARD.md). Keep it small — current work only.
**Updated by:** the executor at each wave boundary (on EOS PASS + commit → advance to the next wave; refresh the dashboard at the same moment).
**Authority:** [`FINAL_EXECUTION_MASTER_ROADMAP.md`](FINAL_EXECUTION_MASTER_ROADMAP.md) · run per [`AUTONOMOUS_EXECUTION_PLAN.md`](AUTONOMOUS_EXECUTION_PLAN.md) · journal to [`../execution/IMPLEMENTATION_PROGRESS.md`](../execution/IMPLEMENTATION_PROGRESS.md).

> **Previous wave:** **P0 · W1 — Documentation Truth ✅ COMPLETE (2026-07-04)** — EOS DOCS PASS, `flutter analyze` 0, `git status` coherent. DOC-1/2/4/5 closed in the ledger.

---

## ▶ CURRENT

- **Phase:** P0 — Truth · Documentation · Live Verification 🔴 (gates everything)
- **Wave:** **W2 — Safety Fixes** (SEC ∥ INFRA ∥ CODE)
- **Status:** ⚪ Pending
- **Why now:** W1 (docs) is done; the safety base (release fail-closed, PII-at-rest, money lost-update guard, off-site backup, alert delivery) must be true before Live Proof/CI (W3) and everything downstream.

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
