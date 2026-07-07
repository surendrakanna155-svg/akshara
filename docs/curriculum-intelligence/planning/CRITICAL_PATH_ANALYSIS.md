# Curriculum Intelligence — Critical Path Analysis

**Date:** 2026-07-06 · Wave IDs from [`IMPLEMENTATION_SEQUENCE.md`](IMPLEMENTATION_SEQUENCE.md); effort figures from [`SPRINT_PLAN.md`](SPRINT_PLAN.md) (dev-day estimates, single-owner assumptions).

---

## 1. Program goal lines

Two distinct "done" definitions, with different critical paths:

- **G1 — Board-compliant generation live:** every generated paper conforms to a governed blueprint template (v3.0 §18 Phase-1 KPI).
- **G2 — Full program exit:** repository complete (4 boards), knowledge datasets delivered, engine complete (CI-C1..C9), dormant Phase-2 seed landed → handoff to v3.0 Phase 2.

*(Amendment A1: the asset-factory waves CI-C10/C11 sit **beyond G2** at the v3.0 Phase-1→2 boundary — they move neither goal line and add no pre-G2 dependencies.)*

## 2. Critical path to G1 (shortest path to user value)

```
D-1..D-4 owner decisions  ──►  CI-B3 hand-seed (CBSE SQP transcription, ~2d)
                                      │
                                      ▼
                    CI-C1 golden tests (2d) → template schema (2d) → solver upgrade (6–8d)
                                      │
                                      ▼
                              CI-C3 multi-set + PDF v2 (5–7d)
```

**Length:** ~15–19 code-lane dev-days after decisions. **Everything else is off this path** — acquisition (CI-A*) enriches breadth but a single hand-transcribed CBSE template unblocks G1. This is the single most important sequencing insight of the program: *do not let the data lane gate the flagship code wave.*

**Critical-path guards for G1:**
- Owner-decision latency (D-1) is the first bottleneck → decisions batched and surfaced now.
- CI-C1 is the riskiest wave (touches the certified solver) → golden-test pinning is inside the path deliberately; budget it, don't skip it.

## 3. Critical path to G2 (full program)

```
D-1/D-2 ─► CI-A0 (1–2d) ─► CI-A1 CBSE (8–12d) ─► CI-A2 AP (6–10d) ─► CI-A3 TS (6–10d) ─► CI-A4 CISCE (5–8d)
        ─► CI-A5 (4–6d) ─► CI-A6 incl. Repository Certification (3–4d) ─► CI-B4 (4–6d) ─► CI-E1b (2–3d)
```

**Length:** ~39–61 data-lane dev-days + terminal 2–3 code days. The **data lane dominates G2** — acquisition of four boards is the long pole, driven by external factors (portal availability, discovery churn, D-3 scope). Code waves CI-C1..C9 (~30–40 dev-days total) fit entirely inside the data lane's window when run in parallel, so **G2 ≈ data-lane length**, not the sum of both lanes.

## 4. Slack analysis (what can slip without moving G2)

| Wave | Slack | Notes |
|---|---|---|
| CI-C6 (cold-start) | Medium | After CI-C5 (D-6 lifecycle: AI validation precedes teacher validation) |
| CI-C8 (paper↔exam) | High | No upstream deps; any idle slot (lands in P1-CI-0) |
| CI-C4 (tagging) | Medium | Needs CI-B2 + CI-C1; not on either goal line |
| CI-C5 (AI validation) | Medium | Needed before profile content scales, not for G1 |
| CI-C9 (sync) | Medium | Needs CI-A6; last-mile |
| CI-B1/B2 for boards 2–4 | Medium | Pipelined; only CBSE increment gates CI-C2's first slice |
| CI-A2..A4 | **Zero (G2)** | Board-sequential mandate makes acquisition strictly serial |
| CI-C10/C11 *(A1)* | **High** | Post-G2 factories; gated by CI-C5 + E1b/B4, off both goal lines; owner-timed (A1-O1) |

## 5. Bottlenecks & mitigations

| Bottleneck | Mitigation |
|---|---|
| Board-sequential acquisition (serial by spec) | Pipeline B-wave extraction behind each board; parallelize *discovery* (read-only) within a board across subjects |
| Single shared backend module (`education/*` files) | One code wave at a time in that territory (PARALLEL_EXECUTION_PLAN §2); pre-agree contracts so FE/BE halves overlap |
| Owner decisions D-1..D-4 | Batched now; program idles at zero cost until resolved |
| Government-portal availability (external) | Retry queues + alternates per spec Part 03 failure ladder; never stall the pipeline on one resource |
| EOS/live-cert bandwidth per code wave | Waves sized to one commit unit each; live-cert additions scripted once in CI-C1 and reused |
