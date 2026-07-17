# P4-RT-1 — Red Team Execution Rounds (post-FREEZE-1)

**Program:** P4 Global Red Team, item P4-RT-1 (the 12-domain adversarial assault, loop-until-dry).
**Entry:** FREEZE-1 declared 2026-07-16 (`91324152`). RT-0 readiness ✅ (`RED_TEAM_P4_RT0_READINESS.md`).
**Method:** independent adversarial operators, per-finding adversarial verification against real code, findings → P5 fix → live re-verify. **Exit law:** repeated rounds until no *meaningful* (P0/P1) production issue is found — never a fixed round count.

## Round ledger

| Round | Domain focus | P0 | P1 | Result | Fix + cert |
|---|---|---|---|---|---|
| **R1** | New frozen PRC-A surface (Batches 6–10): RBAC, RLS, injection, money-units, escalation, fabrication | 0 | 1 | 6 domains CLEAN; 1 P1 = concurrent notification-drain double-send/double-escalate | Fixed + LIVE CERTIFIED `c059428a` (mig `20260895`, claim via FOR UPDATE SKIP LOCKED, 5/5 probes) |
| **R2** | Money-integrity terminal-write-without-guard defect class (finance/inventory/clearance/gate_pass/sis) | 0 | 1 | 1 P1 = `confirmQrSession` missing `status='pending'` guard; **defect class EXHAUSTED** (all other terminal writes guarded / atomic-upsert / unique-constrained) | Fixed + LIVE CERTIFIED `d2d39ad0` (3/3 probes, exactly-once confirm → 409) |
| **R3** | AI-abuse / prompt-injection / RBAC-scoping (W2 copilot, Universal Search, model gateway, quotas) | 0 | 0 | **CLEAN.** Tenant/role isolation (RLS WITH CHECK on parent-child), prompt-injection defense-in-depth, gateway sole-path for content, atomic money caps (pg_advisory_xact_lock), deterministic-not-delegated — all verified in code | — (no P0/P1) |
| **R4** | Cross-tenant RLS coverage sweep + broadened to school_id/context_school_id | 1 | 1 | **5 tables** with NO RLS + live `anon`/`authenticated` PostgREST grants (unauthenticated cross-org read/write): 3 platform tables (P1) + **`sessions`** (session enumeration/forge) + **`otp_requests`** (phone PII + OTP forge/consume) = **P0**. Every other tenant table was already FORCE-RLS'd. | Fixed + LIVE CERTIFIED — mig `20260896` (platform) `6b66719a` + mig `20260897` (auth) `<this>`: REVOKE anon/authenticated + FORCE RLS; auth flow verified intact (service_role read+write ok, anon denied). Isolation now CLEAN repo-wide (0 anon-exposed tenant tables). |
| **R5** | Prod-log-driven (real 500s from a live client) | 0 | 2 | 2 real prod 500s the fake-DB tests can't catch: `GET /academics/exams/progress` — `es.updated_at` not in GROUP BY; `GET /school/pilot/dashboard` — `permission denied for otp_requests` (tenant role querying an un-granted auth table). | Fixed: exams GROUP BY corrected + query verified on prod (`<commit>`); pilot dashboard OTP metric made SAVEPOINT-resilient (degrades vs 500) (`<commit>`). |

**Trend: 1 → 1 → 0 → (1 P0 + 1 P1) → 2 P1 per round. Each round sweeps a DISTINCT domain (money-race → AI → isolation → prod-correctness). R4 was the highest-value round — a P0 unauthenticated auth-table exposure. The fake-DB test blind spot (GROUP BY, grants, JOINs) is the recurring theme: real-Postgres probing + prod logs find what 3484 green tests can't.**

## Tracked residuals (bounded, non-blocking — do NOT gate freeze/VAL)
- **P2 (R3)** — embeddings provider call (`ai/embeddings_client.ts:46`) bypasses the gateway spend-cap/telemetry. **Dormant by default** (no `AI_EMBEDDINGS_API_KEY`), per-user copilot-quota-bounded, fails soft. Route through the gateway when embeddings are activated.
- **P2 (R3)** — daily copilot MESSAGE-count quota (`ai_copilot_quota.ts` + `copilot_handlers.ts:334`) is check-then-act; a concurrent burst at limit−1 can overshoot the *message count* (not money — the hourly rate limit + monthly spend cap are atomically enforced). Soft courtesy cap; low impact.
- **P2 (R1)** — transport-expense `POST` has no request-idempotency key (double-submit → duplicate expense row, admin-voidable).
- **Info (R3)** — output guard grounds ₹/percent but not bare integer counts (narrative-only, never persisted as a value).
- **Pre-existing (R1)** — SMS/email/push stub mode reports fabricated `sent` when a provider isn't configured (env-gated; WhatsApp's version was fixed in Batch 6). Prod sets real providers.

## Domains still to run (future rounds, toward VAL-1 dry)
Performance (N+1 / unbounded queries), Flutter client, DR/recovery, and a broad cross-tenant RLS sweep of the full table set. The pre-freeze P4-RT hardening rounds (reclassified at RECON-2, fixes preserved) covered much of the older backend; these rounds re-verify on the frozen tree.
