# Akshara ERP — NEXT ACTIVE WAVE

**This is the ONLY file Opus 4.8 reads before each autonomous wave** — together with its state companion [`../execution/EXECUTION_DASHBOARD.md`](../execution/EXECUTION_DASHBOARD.md). Keep it small — current work only.
**Updated by:** the executor at each wave boundary (on EOS PASS + commit → advance to the next wave; refresh the dashboard at the same moment).
**Authority:** [`FINAL_EXECUTION_MASTER_ROADMAP.md`](FINAL_EXECUTION_MASTER_ROADMAP.md) · run per [`AUTONOMOUS_EXECUTION_PLAN.md`](AUTONOMOUS_EXECUTION_PLAN.md) · journal to [`../execution/IMPLEMENTATION_PROGRESS.md`](../execution/IMPLEMENTATION_PROGRESS.md).

> **Previous waves:** **P1-CODE-1 — Reliability finish (REL-1..5) ✅** (`5908509`/`66f9f35`/`afd1106`) · **P1-CODE-2 — Reliability polish (REL-6..9) ✅ COMPLETE (2026-07-04)** — EOS RELIABILITY PASS `c0f450f`: crash-safe dequeue reclaim (fixes a latent dropped-write), 24h read-cache TTL, degraded-store Sync banner, per-entity ordering + real DNS reachability probe. `flutter analyze` 0; suite 3599 pass (only the 2 known UX-7 overflow fails → P2-UX); +15 tests. The full reliability platform (REL-1..9) is now closed.

---

## ▶ CURRENT

- **Phase:** **P1 — Backend & Code Fixes** 🟠
- **Wave:** **P1-CODE-3 — Backend hardening** (ENG-4/5/7/8/9/10, DB-6 code)
- **Status:** 🔵 Ready to start
- **Sequencing (owner, 2026-07-04):** the **complete live lane is provisioned in ONE dedicated phase after all code implementation is done** — so `P0-INFRA-1/3` + `P0-TEST-1/2/3` (and CI-green) are **explicitly owner-deferred**. Execution proceeds through the **code** waves of P1→P3 first; do NOT request off-site creds / alert sink / CI setup until the dedicated live phase. (VPS access exists — `ssh akshara` — but hold all live work.)
- **P0 status:** code/security tasks **14/19 ✅ COMPLETE**; the 5 live-lane tasks are **queued** (owner-deferred).

### P1-CODE-3 scope (this wave) — backend hardening (SECURITY + ARCH)
This is a **backend** wave (`supabase/functions/**`), so `deno test` + `deno check` are the primary gates (client largely untouched → `flutter analyze` still 0).

| Sub | Sev | What |
|---|---|---|
| **ENG-7 (=SEC-6)** | P1 | Stop raw `error.message` leaking to clients (~154 sites) — return a safe code/message; log the detail server-side only. |
| **ENG-8 (=SEC-11)** | P1 | Cap the 4 unbounded bulk-array inputs (reject oversized payloads before work) — DoS / memory guard. |
| **ENG-9** | P1 | Standardize error codes across handlers (one taxonomy; stable machine-readable `code`). |
| **ENG-10** | P2 | Map validation failures `400 → 422` consistently (semantic HTTP status). |
| **ENG-4** | P2 | Route-registry lint — every mounted route is declared/authorized (no orphan/unguarded route). |
| **ENG-5** | P2 | Forced-auth choke point — every handler passes through the single auth/RBAC gate (no bypass path). |
| **DB-6 (code)** | P2 | Audit retention / partitioning **code** seam (the doc target from DOC-5); schema/migration only where non-destructive. |

### EOS gate
- Relevant scopes: **SECURITY** (ENG-7/8/5) + **ARCH** (ENG-9/10/4, DB-6). Each → PASS. Automatic-failure tripwires apply (security breach / broken auth → instant BLOCKED).
- Regression: `deno test` green (+ new error-path / payload-cap / route-lint tests) · `deno check` clean · `flutter analyze` 0 · full suite no NEW failures (beyond the 2 known UX-7).

### Next
On P1-CODE-3 EOS PASS + commit → **P1-CODE-4** (identity finish — change-phone/PLAT-4, ledger triggers, student 2-table integrity; **👤 PLAT-0** partial — pause + surface the identity-cluster owner decisions when reached) ∥ **P1-CODE-5** (HR payroll engine); then **P1-PROD-0** (XCT). Owner-scope tasks P1-CODE-6/7/8 (Finance-posting / Hostel / Alumni) pause + surface when reached.

> **Deferred live-lane tail (run in the dedicated live phase):** `P0-INFRA-1` off-site backup · `P0-INFRA-3` alert delivery · `P0-TEST-1/2/3` CI + isolation-in-CI + live-regression cron (starts the 7-day P7 clock). Plus every LIVE-graded re-verification across P0→P3.
> **Reliability P2 residual:** none open — REL-1..9 fully delivered (REL-9 reachability probe shipped, not deferred).

### Regression required
- `deno test` + `deno check` green for the touched `supabase/functions/**` · `flutter analyze` 0 · `flutter test` no NEW failures (beyond the 2 known UX-7).

### Exit criteria (all true → wave complete)
- [ ] No raw internal `error.message` reaches a client; server logs retain the detail.
- [ ] The 4 unbounded bulk arrays are capped (oversized payload rejected with a clear code).
- [ ] Error codes standardized; validation → 422; route-registry lint green; no unguarded route / auth-bypass path.
- [ ] DB-6 audit retention/partitioning code seam in place (or explicitly staged if it needs a live-only migration).
- [ ] `/eos` PASS for SECURITY + ARCH; journal row + roadmap P1-CODE-3 ✅ + ledger ENG-4/5/7/8/9/10+DB-6; advance this file to **P1-CODE-4** + refresh the dashboard.

> **Rule:** never begin the next wave with an open P0 or an EOS BLOCKED. Owner-decision (👤) tasks pause and surface in a batch; live-lane (⏳) tasks defer until provisioned; non-blocked tasks in the wave proceed.
