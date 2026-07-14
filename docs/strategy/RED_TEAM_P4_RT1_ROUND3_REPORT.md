# P4-RT-1 — Global Red Team · Round 3 Report (re-audit + defect-class sweep)

**Date:** 2026-07-14 · **Phase:** P4-RT-1 (round 3) · **Framework:** [`GLOBAL_RED_TEAM_FRAMEWORK.md`](GLOBAL_RED_TEAM_FRAMEWORK.md)
**Method:** 3 perspective-diverse operators — (a) a money/state-integrity **defect-class sweep** for the round-1 pattern across modules round 1 didn't cover, (b) Domains 5+6 (UX + workflow), (c) Domain 11 (performance). Every finding orchestrator-verified against source before triage.

## Verdict: **round 3 did NOT converge** — it surfaced new P0/P1s (the round law working). All *surgical* P1s FIXED + regression-locked; the *architectural* performance P1s are TRACKED to a dedicated hardening wave (rushing them into the frozen tree is riskier than the defect). **RT-1 continues** — a further clean re-audit round is still owed after these land + deploy.

Regression at round close: deno **2874/0/3-ignored** · `flutter analyze` **0** · flutter suite (running at write time; result appended to the journal).

---

## FIXED this round (freeze-compatible correctness)

### Money/state defect-class survivors (same pattern as round 1 — all edge/Deno code, no migration)
| ID | Sev | Site | Fix | Test |
|---|---|---|---|---|
| **S1** | P1 | `inventory_finance_repository.ts` `receiveGoods` — concurrent double-receipt stacks the `quantity_received` delta (10-qty line → 20) + double stock | terminal `AND quantity_received + $2 <= quantity` + throw-on-0-rows | `inventory_finance_repository_test.ts` (new fake + loser test) |
| **S2** | P1 | `inventory_distribution_repository.ts` `fulfillReplacementRequest` — concurrent double-fulfill issues a 2nd free item + double stock decrement | terminal `AND d.replacement_status = 'approved'` (requireUpdatedRow throws) | existing `P0-3` test already forces the empty-terminal → throw+rollback path |
| **S3** | P1 | `payment_repository.ts` `markIntentCaptured` — client-confirm vs webhook race double-credits a PARTIAL online payment (latent until the live gateway is enabled) | terminal `AND status <> 'captured'` (existing throw-on-empty → rollback of the collection) | `payment_repository_test.ts` (new loser + happy tests) |
| **S4** | P2 | `admissions_repository.ts` `setApprovalDecision` — a decided maker-checker approval can be re-decided/flipped (approved↔rejected) | terminal `AND decision = 'pending'` (returns null → no flip) | `admissions_approval_sod_test.ts` (new loser test) |

### UX / Workflow P1s
| ID | Sev | Site | Fix | Test |
|---|---|---|---|---|
| **RT-5-3** | P1 | Branch & Franchise providers are mock-only and were reachable by a chain-org schoolAdmin → fabricated multi-branch **revenue** dashboard rendered as real (same class as the CFC-1 item-2 Trust-Hub hole; 2 of 6 sibling modules had been dropped from the 2026-07-04 gate wave) | added `/branches` + `/franchise` to `surface_backend_gate._backendLessSurfaces` behind new OFF-in-live flags → routes hidden + nav dropped in a live build | `test/router/surface_backend_gate_test.dart` (added both routes; 4/4) |
| **RT-6-1** | P1 | `exam_administration_repository.ts` `publishExamResults` — no completeness gate (unlike `processExamResults`), so an incomplete exam publishes only the entered subset + flips to `published`, **permanently stranding** students with no marks (no republish path); reachable via the generic approval endpoint | added the same completeness invariant (`marks_entered = false` count > 0 → throw before any grade write) | `exm_d6_absent_status_test.ts` (new stranded-student test; happy path preserved) |

### Other runnable findings closed earlier this session
- **RT-4-1 (P2)** parent-facing AI number-guard omission → `guard: true` on `parent_insights_ai.ts` (corrected direction — percent-check ON) + fabricated-% drop test.
- **RT-9-2 (P2)** `student_clearance_waivers` missing FK/CHECK → corrective migration `20260879` (deploy-pending; VPS dropped mid-session).
- **RT-11-6 (P1)** `comm_broadcasts` full-scan search → index migration `20260880` (deploy-pending).
- **Empty-actor SoD** (informational) → waiver `decideWaiver` fails closed on a subject-less actor + test.

## TRACKED — architectural performance P1s (NOT rushed into the frozen tree; → dedicated perf-hardening wave / P5)
These are real and verified, but each is a non-surgical refactor whose risk in a frozen tree exceeds the (scale-dependent, not-currently-triggered) defect. Precise anchors for the fix wave:
- **RT-11-1 (P1)** — the AI/copilot model gateway holds the tenant DB **pool connection** open across the 20s external LLM `fetch` (`model_gateway.ts` runGateway → `anthropic_client.ts`; `POOL_SIZE=10`), replicated at ~10 AI call sites → isolate-wide pool exhaustion at ~10 concurrent AI requests. Fix = release the outer connection before the external call (the reservation pool already does this for its own connection). **Design + test carefully.**
- **RT-11-2 (P1)** — `finance_late_fee_repository.ts` `accrueLateFees` holds `FOR UPDATE` on every overdue invoice across a sequential per-invoice loop → payment-path lock contention. Fix = set-based `UPDATE … WHERE id = ANY($1)`.
- **RT-11-5 (conditional P1)** — notification drain sends sequentially per batch holding a pool connection; degrades to a request-timeout P1 **only if** the self-hosted edge runtime lacks `EdgeRuntime.waitUntil`. **Ops check needed** (confirm `waitUntil` is available on the deployed runtime).

## TRACKED — P2 / P3 (fix-before-GA or backlog)
- **RT-5-1 (P2)** — systemic raw-exception leak: `api_error_interceptor.dart` wraps `DioException.error` but leaves the thrown object a `DioException`, so ~50 unmapped call sites show a doubled technical string. Root-cause fix (unwrap in the interceptor) is high-leverage but broad — route to the P2-UX-2 mapping pass, treating it as a trust defect not just refactor debt.
- **RT-5-2 (P2)** — the freshness chip reads device connectivity, not data provenance (the interceptor's `offlineCacheHeader` is tagged but never consumed), so it can show "Live" over stale cached money/attendance data after reconnect. Wire the provenance flag (or invalidate the read providers on reconnect).
- **RT-11-3/4/7/8/9 (P2)** — per-row insert loops (risk snapshots, seating), `finance_invoices` lower() prefix index, sequential search categories, parent multi-child feed round trips. Set-based rewrites / functional indexes; scale-dependent.
- **Broadcast composer (P3)** — no draft/autosave guard (admin free-text, not money/marks).
- **ISO-C1 (info)** — `ai_call_reservations` org-only RLS (add a school clause only if a school-scoped API is ever added).

## Domains that converged clean (no surviving finding)
- Money sweep CLEARED (guarded): finance collections/late-fee/fee-assignments/day-close/recovery/offline/qr, inventory stock adjustments, PO approve (unique-constraint), staff-attendance decide, clearance waiver, exam mark FSM (idempotent absolute writes + row_version), attendance correction (absolute), HR payroll (snapshot, no DB delta), admission→enrollment (atomic + idempotent).
- Perf CLEARED: director cross-school (set-based), ops-hub/widget bundle (Promise.all + cache), aggregate persona feed (fixed query count), teacher feed (batched), the new AI/waiver/face tables (index-covered), enqueue fan-out (PERF-1 bulk insert).

## Round-law status
Round 3 = NOT a clean round. **RT-1 has not reached its exit.** Owed before exit: (1) deploy the round-3 edge fixes + the 2 migrations (VPS was down at round close); (2) the architectural perf-hardening wave (RT-11-1/2/5); (3) close RT-5-1/5-2 (P2, fix-before-GA); (4) one further full re-audit round finding no new meaningful (P0/P1) issues; (5) the data-bearing live isolation + live money-race re-verify once the pilot has data.

**EOS gate (round 3): CONDITIONAL** — all surgical P0/P1s fixed + regression-locked; architectural P1s tracked to a named wave with owner visibility; P2/P3 tracked. Not a PASS-to-exit; RT-1 continues.
