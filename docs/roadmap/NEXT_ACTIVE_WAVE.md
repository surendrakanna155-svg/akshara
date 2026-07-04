# Akshara ERP — NEXT ACTIVE WAVE

**This is the ONLY file Opus 4.8 reads before each autonomous wave** — together with its state companion [`../execution/EXECUTION_DASHBOARD.md`](../execution/EXECUTION_DASHBOARD.md). Keep it small — current work only.
**Updated by:** the executor at each wave boundary (on EOS PASS + commit → advance to the next wave; refresh the dashboard at the same moment).
**Authority:** [`FINAL_EXECUTION_MASTER_ROADMAP.md`](FINAL_EXECUTION_MASTER_ROADMAP.md) · run per [`AUTONOMOUS_EXECUTION_PLAN.md`](AUTONOMOUS_EXECUTION_PLAN.md) · journal to [`../execution/IMPLEMENTATION_PROGRESS.md`](../execution/IMPLEMENTATION_PROGRESS.md).

> **Previous wave:** **P1-CODE-1 — Reliability finish (REL-1..5) ✅ COMPLETE (2026-07-04)** — EOS RELIABILITY PASS. REL-1/4 `5908509`, REL-2 `66f9f35`, REL-3/5 `afd1106`. Universal idempotency-key + boot/resume flush + bulk-marks via ReliableWriter + drafts on marks & fee (money-safe) + first-write `row_version` on the per-cell mark save. `flutter analyze` 0; full suite 3584 pass (only the 2 known UX-7 `TeacherDashboard` overflow fails, → P2-UX). Roadmap P1-CODE-1 ✅; ledger REL-1..5 closed.

---

## ▶ CURRENT

- **Phase:** **P1 — Backend & Code Fixes** 🟠
- **Wave:** **P1-CODE-2 — Reliability polish** (REL-6..9)
- **Status:** 🔵 Ready to start
- **Sequencing (owner, 2026-07-04):** the **complete live lane is provisioned in ONE dedicated phase after all code implementation is done** — so `P0-INFRA-1/3` + `P0-TEST-1/2/3` (and CI-green) are **explicitly owner-deferred**. Execution proceeds through the **code** waves of P1→P3 first; do NOT request off-site creds / alert sink / CI setup until the dedicated live phase. (VPS access exists — `ssh akshara` — but hold all live work.)
- **P0 status:** code/security tasks **14/19 ✅ COMPLETE**; the 5 live-lane tasks are **queued** (owner-deferred, tracked for the live-lane phase).

### P1-CODE-2 tasks (this wave) — findings REL-6..9
| Sub | Sev | What |
|---|---|---|
| **REL-6** | P1 | Transactional dequeue — the outbox drain must claim + delete/complete an operation atomically so a crash mid-drain never double-sends or drops a queued write. |
| **REL-7** | P1 | Read-cache TTL — the offline read-cache must not serve stale-past-TTL rows; expire/refresh on read when online. |
| **REL-8** | P2 | Store-fallback telemetry — surface when the reliability store falls back (e.g. SQLCipher open failure → in-memory) so a silent durability downgrade is observable. |
| **REL-9** | P2 | Connectivity ping + per-entity ordering — a real reachability check (not just the OS flag) gates the drain; queued writes for one entity replay in submission order. |

### EOS gate
- `/eos reliability` → PASS. Regression: `flutter analyze` 0 · full suite green (no NEW failures; the 2 UX-7 `TeacherDashboard` overflow fails are the known pre-existing baseline) · new transactional-dequeue / TTL / ordering tests · `deno test` for any backend touch.

### Next
On P1-CODE-2 EOS PASS + commit → **P1-CODE-3** (backend hardening: error-leak/bulk-caps/error-codes/retention — SECURITY+ARCH) ∥ **P1-CODE-4** (identity finish, 👤 PLAT-0 partial) ∥ **P1-CODE-5** (HR payroll); then **P1-PROD-0** (XCT). Owner-scope tasks (P1-CODE-6/7/8 Hostel/Alumni/Finance-posting) pause + surface when reached.

> **Deferred live-lane tail (run in the dedicated live phase):** `P0-INFRA-1` off-site backup · `P0-INFRA-3` alert delivery · `P0-TEST-1/2/3` CI + isolation-in-CI + live-regression cron (starts the 7-day P7 clock). Plus every LIVE-graded re-verification across P0→P3.

### Regression required
- `flutter analyze` = 0 · `flutter test` green (no NEW failures beyond the 2 known UX-7) · backend `deno test` green for any `supabase/**` change.

### Exit criteria (all true → wave complete)
- [ ] Outbox dequeue is crash-safe (no double-send, no dropped write) — test proves it.
- [ ] Read-cache never serves a row past its TTL when online — test proves it.
- [ ] Store-fallback (durability downgrade) is observable in telemetry/UI.
- [ ] Reachability ping gates the drain; per-entity writes replay in order.
- [ ] `/eos reliability` PASS; journal row + roadmap P1-CODE-2 ✅ + ledger REL-6..9; advance this file to **P1-CODE-3** + refresh the dashboard.

> **Rule:** never begin the next wave with an open P0 or an EOS BLOCKED. Owner-decision (👤) tasks pause and surface in a batch; live-lane (⏳) tasks defer until provisioned; non-blocked tasks in the wave proceed.
