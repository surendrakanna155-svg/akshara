# Akshara ERP — NEXT ACTIVE WAVE

**This is the ONLY file Opus 4.8 reads before each autonomous wave** — together with its state companion [`../execution/EXECUTION_DASHBOARD.md`](../execution/EXECUTION_DASHBOARD.md). Keep it small — current work only.
**Updated by:** the executor at each wave boundary (on EOS PASS + commit → advance to the next wave; refresh the dashboard at the same moment).
**Authority:** [`FINAL_EXECUTION_MASTER_ROADMAP.md`](FINAL_EXECUTION_MASTER_ROADMAP.md) · run per [`AUTONOMOUS_EXECUTION_PLAN.md`](AUTONOMOUS_EXECUTION_PLAN.md) · journal to [`../execution/IMPLEMENTATION_PROGRESS.md`](../execution/IMPLEMENTATION_PROGRESS.md).

> **Previous waves:** **P1-CODE-1 (REL-1..5) ✅** · **P1-CODE-2 (REL-6..9) ✅** · **P1-CODE-3 — Backend hardening ✅ COMPLETE (2026-07-04)** — EOS SECURITY+ARCH PASS across `370028c`/`56e4942`/`3957fab`/`b4bee40`: central internal-error-leak fix, 6 bulk-array caps, 18 validation 400→422, forced-auth choke lint (13/13), error-code taxonomy lint, non-destructive audit-retention seam. Full `deno test` 2021 pass (0 new failures); `flutter analyze` 0.

---

## ▶ CURRENT

- **Phase:** **P1 — Backend & Code Fixes** 🟠
- **Wave:** **P1-CODE-5 — HR payroll engine** (MOD-2, MOD-3) — 🔵 ready to start (non-blocked sibling; keeps the pipeline moving while the P1-CODE-4 identity owner-decisions below are resolved)
- **Sequencing:** P1-CODE-4 ∥ P1-CODE-5 ∥ P1-PROD-0 all depend only on P0. **P1-CODE-4 (Identity) is owner-gated (👤 PLAT-0 + the identity-decision cluster) — surfaced below, NOT blocking the pipeline.** Per the rule "owner-decision tasks surface in a batch; non-blocked tasks proceed", execution proceeds on **P1-CODE-5** (fully non-👤). Live lane (`P0-INFRA-1/3`, `P0-TEST-1/2/3`) stays owner-deferred.

### P1-CODE-5 tasks (this wave) — findings MOD-2, MOD-3
| Sub | Sev | What |
|---|---|---|
| **MOD-2** | P1 | HR payroll engine: salary-structure + payroll-run / line-item generation; un-hide the payroll surface. Must run on a fresh school. |
| **MOD-3** | P1 | Fix hardcoded `employeeId`; enforce employee-code uniqueness. |

### EOS gate
- Scope: **FEATURE** (+ any SECURITY on the write path). PASS required. Regression: `deno test` + `deno check` green (payroll run on a fresh school; unique employee code) · `flutter analyze` 0 · `flutter test` no NEW failures (beyond the 2 known UX-7).

### 👤 SURFACED OWNER DECISIONS — identity cluster (gates P1-CODE-4, resolve in a batch)
See [[akshara-decision-queue]] + [[student-identity-architecture-decision]]. These do **not** pause the pipeline (P1-CODE-5 proceeds); they gate **P1-CODE-4 (Identity finish)** only:
- **PLAT-0** — build Public Student ID (PSID) now vs defer post-pilot.
- **C5 / ADM-D3** — admission-number immutability (set-once-locked vs editable).
- **IC-1…IC-6** — esp. `users.phone` NOT NULL UNIQUE = de-facto identity; is a **change-phone flow (PLAT-4)** in scope for P1-CODE-4, or deferred?
- **SIS-D1** — TC / no-dues gate on identity transitions.
- **Admissions approval SoD** — maker-checker on admission approval.

### Next
On P1-CODE-5 EOS PASS + commit → **P1-PROD-0** (XCT) then, once the identity batch above is resolved, **P1-CODE-4** (Identity finish). Owner-scope tasks P1-CODE-6/7/8 (Finance-posting / Hostel / Alumni) remain 👤 — surface when reached.

> **Deferred live-lane tail (run in the dedicated live phase):** `P0-INFRA-1` off-site backup · `P0-INFRA-3` alert delivery · `P0-TEST-1/2/3` CI + isolation-in-CI + live-regression cron.
> **Tracked pre-existing defect (NOT a P1-CODE-3 regression):** `ISO-COUNT` — 5 "tenant isolation probe count" tests (communication/payment/pilot/sis) assert stale totals (220/213) vs the registry's actual 233 probes; fails at pre-wave `3957fab` too. Reconcile the counts + verify the +13 probes are legitimate. Small, isolated.

### Regression required
- `deno test` + `deno check` green for touched `supabase/functions/**` · `flutter analyze` 0 · `flutter test` no NEW failures (beyond the 2 known UX-7).

### Exit criteria (all true → wave complete)
- [ ] Payroll salary-structure + run/line-item generation works on a FRESH school (test proves it).
- [ ] Payroll surface un-hidden (visible where entitled).
- [ ] No hardcoded `employeeId`; employee-code uniqueness enforced (test proves the dup rejection).
- [ ] `/eos` FEATURE PASS; journal row + roadmap P1-CODE-5 ✅ + ledger MOD-2/MOD-3; advance this file to **P1-PROD-0** + refresh the dashboard.

> **Rule:** never begin the next wave with an open P0 or an EOS BLOCKED. Owner-decision (👤) tasks surface in a batch and do not pause the pipeline; live-lane (⏳) tasks defer until provisioned; non-blocked tasks proceed.
