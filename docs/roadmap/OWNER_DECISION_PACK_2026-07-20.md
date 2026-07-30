# OWNER DECISION PACK — FINAL & APPROVED (2026-07-20)

**Status:** 🔒 **FINAL — approved by the product owner. Permanently resolved.** Do not re-ask unless a future architectural conflict makes an approved decision technically impossible (record such a conflict here with justification).
**Authority:** these are owner decisions — they sit **above** the roadmap in the authority chain (Constitution > owner decisions > roadmap > code). This document is the canonical architecture-decision record for the pack; the roadmap, W1 evidence ledger, and memory reference it.

For each: the **decision**, the **architecture** it mandates, and the **roadmap items it unblocks** (moving them from 👤 owner-gated → ⚪ buildable).

| # | Decision | Architecture / approach | Unblocks |
|---|---|---|---|
| **1** | **SaaS limits** | Enforce **STUDENT** limits per plan; **staff/admin are NOT plan-capped**; **SMS quotas** enforced per plan. **Config-driven** limits (plan-config source, never hardcoded). | PRC-A **cap 53** (SMS), **cap 54** (reframed: student-only; staff/admin exempt). Mechanism already built (cap 57 `evaluateCreateLimit`) — extend with config + SMS metering. |
| **2** | **Transport fee model** | **HYBRID**: distance-based **∪** route-based **∪** stop-based; **school chooses** the model (config per school). | PRC-A **cap 10** + transport fee pipeline (W4). |
| **3** | **Own transport / parent pickup** | Fully supported; may be **₹0 fee**; **configurable per student**. | PRC-A **cap 3** (requirement enum: bus / own-transport / parent-pickup). |
| **4** | **Canonical Expense Ledger** | Single source of truth aggregating: **payroll · inventory purchases · transport · maintenance · utilities · other approved modules**. Append-only ledger; each source posts typed expense entries. | PRC-A **caps 90–100** (cross-module cost intelligence) + PRA-P1-48 `expenseBreakdown` (W4). |
| **5** | **Transport assignment history** | **Valid-From / Valid-To** effective dating; **never overwrite** historical assignments; reconstruct historical allocation at any date. | PRC-A **caps 5/6/23** (effective-dates, proration, temporary assignments) (W4). |
| **6** | **Staff Duty model** | **Dedicated** data models for **Substitute Classes · Exam Invigilation · Non-Teaching Duties**. **Do NOT overload attendance records.** | PRC-A **caps 131/132/133** (staff workload) + PRA-P2-13 (substitution) (W4). |
| **7** | **Payment gateway** | **Multi-provider** with a **provider-abstraction** layer; school chooses its gateway. | PRA-**P0-02** (payment SDK) + owner-queue payment provider layer (W3/W6). |
| **8** | **Smart OMR** | APPROVED — proceed. (This resolves **D1**; the frozen Assessment Marks-Grid stays, OMR is an *additional* capture path — reconcile, don't replace.) | SOP-**F1/F2/F3** + Assessment-Intelligence OMR (W5/EIP). |
| **9** | **Statutory payroll** | APPROVED — PF / ESI / PT / TDS with a statutory-config source (per-state). | PRA-**P1-35** (W3/W4). |
| **10** | **Leave accrual engine** | APPROVED — automatic accrual + carry-forward policies. | PRA-**P1-34** (W4). |
| **11** | **Library accession register** | APPROVED — per-copy accession numbering + register. | PRA-**P1-41** (W4). |
| **12** | **Staff device management** | APPROVED — org asset/device **assignment + lifecycle** tracking. | PRA-**P0-15** device-management side (not the on-device GPS/face capture, which stays hardware-gated) + asset register (W4). |
| **13** | **Secure secrets vault** | APPROVED — **production-grade encrypted** secrets; replace placeholder/base64 storage. | PRA-**P1-54 + P2-30** (ship together) + owner-queue secrets vault (W6). |
| **14** | **Multi-school identity (PLAT-0)** | APPROVED — **one user across multiple schools** with **strict tenant isolation**; shared identity + per-school membership/role resolution. | SOP-**ID-3**, PRA-P1-04/51/52, P2-27; **D2** multi-school placement (W2/W9). |
| **15** | **Assessment Intelligence (W5)** | APPROVED — begin **after prerequisite roadmap dependencies** are satisfied (EIP-6 evidence spine + reconcile the two QI systems + certified-item seam). | **W5 / PROGRAM EIP**. |

## Execution policy (owner-set)
Unblock every dependent item; update dependency graph, roadmap, architecture + certification records; **continue autonomous execution; do not stop after each wave.** Stop ONLY for: a NEW genuine owner decision · a production blocker · an unresolvable external dependency · a constitutional/architectural conflict. **Multi-agent parallel execution** authorized for independent workstreams; merge continuously into the trunk with **full regression + certification at every merge**; never weaken tests, never fabricate completion, never bypass verification.

## Dependency-graph updates (owner-gated → buildable)
- **W3 Money:** payment-gateway abstraction (#7), statutory payroll (#9) → now buildable.
- **W4 Ops:** SaaS student+SMS limits (#1), transport hybrid-fee (#2) + own-transport (#3) + assignment-history (#5), expense-ledger (#4), staff-duty models (#6), leave-accrual (#10), library-accession (#11), device-management (#12) → now buildable.
- **W5/EIP:** Smart OMR (#8) + Assessment Intelligence (#15) → buildable **after** EIP-6 evidence spine + QI reconciliation prerequisites.
- **W2/W9:** PLAT-0 multi-school identity (#14) → buildable (D2 resolved).
- **W6:** secrets vault (#13) → buildable.
- **Still owner-gated (NOT in this pack):** live provisioning (R2/cron/CI runner + dark-flag activations), Meta App Review (FB/IG), beta cohort, K-3/A2/Assessment-Intelligence *live-promotion* timing.
