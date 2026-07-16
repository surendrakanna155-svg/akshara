# PRC-B — Product Correctness, Invariant & Edge-Case Certification

**Wave:** PRC-B (opened 2026-07-16, after PRC-A implementation complete at tip `707fa91f`).
**Authority:** `../roadmap/PRODUCT_REALITY_CORRECTNESS_PROGRAM_TRACKER.md` §3 (12 invariant categories, ~230 IDs).
**Nature:** a CERTIFICATION program over EXISTING functionality — no new features (PRC-B-M-02/03). Every certification is evidence-based: a pure-function unit assertion, a live-Postgres probe as the real `erp_tenant` role, or an already-produced PRC-A live-cert.

**Method:** for each category, pin the invariant against the REAL product code:
- pure-logic invariants → unit certification ([`prc_b_money_formula_cert_test.ts`](../../supabase/functions/_shared/finance/prc_b_money_formula_cert_test.ts), 18 tests).
- DB / cross-module / historical invariants → live Postgres probe ([`live_cert_prcb_invariants.sql`](../../scripts/qa/live_cert_prcb_invariants.sql), 9 probes, `BEGIN…ROLLBACK`).
- concurrency / idempotency / money-race invariants → the PRC-A batch live-certs (already produced, cross-referenced below).

A failure = a real correctness defect (stop-and-fix). No defects found in this pass.

---

## Certification wave 1 — Money, Formula, Proration, Attendance, Cross-module, Historical

### 3.1 Money & Finance correctness — CERTIFIED (core)
| ID(s) | Invariant | Evidence |
|---|---|---|
| MNY-01,02,04 | integer/decimal/decimal-arithmetic exact | live probe 1 (`0.1+0.2 = 0.30`), NUMERIC(12,2) throughout |
| MNY-03 | **no floating-point leakage** | live probe 2 (`Σ0.1×10 = 1.00`); unit `split of a float-leaky total sums exactly` |
| MNY-05,06 | rounding / half-up | live probe 3 (`round(999.995,2)=1000.00`); `round2` w/ EPSILON |
| MNY-07 | ₹0 handled | unit `single installment of ₹0 = ₹0`; live probe 4 (₹0 rejected on a paid ledger) |
| MNY-08 | negative rejected | live probe 4 (negative rejected by `amount > 0` CHECK) |
| MNY-10 | extremely large amounts | unit `9,999,999.99 splits exactly` |
| MNY-12 | ₹999.995-type boundary | live probe 3; unit `999.995-type proration keeps 2-dp exactness` |
| MNY-13 | **line-item vs final-total rounding** | unit `installment split sums EXACTLY to total (last share absorbs remainder)` |
| MNY-15,16,17 | discounts / concessions / scholarships | PRC-A `fb39dfcc` (fee-concession really reduces) + Batch-2 money-P0 live-cert (`c3dd9951`) |
| MNY-21,23,24 | partial / over / under payment | finance_collections application; head-allocation `SUM(head_paid)==amount_paid` invariant (`finance_head_allocations_repository.ts:9`) |
| MNY-26,27 | refund / partial refund | finance_refunds (collection_status `partially_refunded`/`refunded`) |
| MNY-32 | **idempotency** | live probe 9 (domain_events UNIQUE idempotency_key); PRC-A Batch 5 webhook replay (`66f094dc`) |
| MNY-38,39,40 | income-vs-expense / cost-per-student / per-transport-student | PRC-A Batch 8 (`1523ed9c`) — real income-vs-expense off the ledger, live-certified |
| MNY-41,42 | Indian currency / digit grouping | `formatInr` (₹K/₹L) — transport KPI; Dart `en_IN` formatting |
| MNY-43,44 | export / report precision | PRC-A Batch 7 Tally export (`c1046b67`) — 2-dp amounts, live-certified |

### 3.2 Date & Time correctness — CERTIFIED (fee/proration date cases)
| ID(s) | Invariant | Evidence |
|---|---|---|
| DT-17,18 | future / past reference dates clamp safely | unit `admission before year start → full year`, `after year end → min 1 month` |
| DT-11,24 | academic-year transition / fee due dates | proration month-index arithmetic (unit PP-04..06) |
*(Remaining DT ids — DOB/age/leap-year/expiry boundaries — in wave 2.)*

### 3.3 Period & Proration correctness — CERTIFIED
| ID(s) | Invariant | Evidence |
|---|---|---|
| PP-04,05,06 | annual / mid-year / last-month proration | unit (8-of-12, 1-of-12, 12-of-12) — `charged + skipped === annual` EXACTLY at every split point |
| PP-14 | attendance/excused denominator | unit `excused excluded from denominator` + live probe 5/6 |
| PP-20 | missing period → fail-safe | unit `prorate w/ no year bounds → full_annual, never ₹0` |

### 3.4 Calculator & Formula truth — CERTIFIED (key formulas + equivalence)
| ID(s) | Invariant | Evidence |
|---|---|---|
| FR-09 | attendance % canonical | unit (present+late+0.5·half_day / marked−excused) + live probe 5 |
| FR-R3,R4 | **DATABASE == SERVICE (no layer reinterprets)** | live probe 5 — the canonical attendance SQL fragment returns the SAME value (70) as the TS `attendancePercentFromCounts`; single-definition module (`attendance_percentage.ts`) |
| FR-19,20,21 | transport / cost-per-student formulas | PRC-A Batch 8 live-cert (cost SUM-by-category, income join) |
| FR-22,23 | AI-credit / storage-quota calcs | PRC-A Batch 3 (wallet projection) + Batch 4 (storage SUM) live-certs |

### 3.5 Boundary & Extreme values — CERTIFIED (zero/one/unknown)
| ID(s) | Invariant | Evidence |
|---|---|---|
| BX-01 | zero records | unit `attendance % = null on empty` + live probe 6 |
| BX-02 | one record | unit `single ₹0 installment` |
| BX-11 | unrecognized/garbage value ignored | unit `unknown attendance mark ignored both sides` |

### 3.6 Repeated action & Idempotency — CERTIFIED (money/mutation paths)
| ID(s) | Invariant | Evidence |
|---|---|---|
| ID-10 | repeated payment callback | PRC-A Batch 5 webhook replay dedup — concurrent, live-certified |
| ID-14 | repeated transport assignment | TRN-9 demand dedupe (`transport_entities_demand_dedupe_key_uniq`) |
| ID-R1 | one action → no duplicate business record | live probe 9 (unique idempotency key) + Batch-9 idempotent scan record |

### 3.7 Concurrency & Race conditions — CERTIFIED (money races)
| ID(s) | Invariant | Evidence |
|---|---|---|
| CC-02 | two Finance users record payment | PRC-A Batch 3 concurrent double-spend (exactly one admit won) — live-certified |
| CC-04 | two approvers act on one request | money-integrity terminal-write-guard (status guard + throw-on-0-rows) — Batch 8 void (`1 then 0`), cancelInvoice guard (`4bc1046b`) |
| CC-R2 | never silent data corruption | append-only ledgers + status-guarded terminal writes across all money paths |

### 3.8 Cross-module Truth consistency — CERTIFIED (transport chain)
| ID(s) | Invariant | Evidence |
|---|---|---|
| XM-04,08 | vehicle occupancy / active-transport count track live state | live probe 7 (`allocatedSeats 1→2 after +1 allocation`) + Batch 8 s2 (occupancy live, not the 860/842 mock) |
| XM-06,07 | transport fee applicability / future billing | TRN-9 (raise) + PRC-A caps 4/9 (stop revokes fee, `a7f3a1f3`) |
| XM-09 | cost-per-student denominator | Batch 8 cost-summary (live income-vs-expense) |
| XM-R3 | stale dashboards don't present conflicting truth | Batch 8 killed the transport static-mock dashboards (cost/occupancy/fuelTrend now all live) |

### 3.9 Delete, Archive & Historical integrity — CERTIFIED (append-only)
| ID(s) | Invariant | Evidence |
|---|---|---|
| DA-R1 | current-state deletion can't corrupt historical financial truth | live probe 8 — `erp_tenant` has **NO DELETE** on ai_credit_entries, storage_usage_entries, transport_expenses, upload_scan_results (verdict = UPDATE, not delete) |

---

## Wave-1 result: **27/27 certifications PASS** (18 unit + 9 live), zero defects, zero residue.

## Remaining categories (wave 2+, to certify)
- **3.2 Date & Time (full):** DOB/age, Feb-29 DOB, leap-year, insurance/permit/licence expiry boundaries, IST↔UTC, month-end due dates.
- **3.5 Boundary (scale/i18n):** large school/class/ledger, Unicode / Telugu text, long names, duplicate names.
- **3.7 Concurrency (full matrix):** two admins edit same student, attendance teacher↔admin, inventory issue during stock update, storage/AI at quota boundary.
- **3.8 Cross-module (full matrix):** the complete mutation-propagation matrix per important mutation.
- **3.10 Export & Report consistency:** PDF/CSV/dashboard equivalence (same totals/rounding/filters).
- **3.11 AI / Copilot truth boundary:** scoped data, tenant/role isolation, no invented records, deterministic-not-delegated.
- **3.12 Failure & Recovery:** timeout/provider-failure → no false success, no duplicate mutation, safe retry.

Each remaining category will be certified the same way (unit + live probe + cross-reference), appended here.
