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
| **R4** | Cross-tenant RLS coverage sweep (every public table with organization_id vs its rls/forced/policy state) | 0 | 1 | 1 P1 = 3 platform tables (`platform_provider_configs`/`_feature_enablements`/`_usage_events`) had NO RLS + live `anon`/`authenticated` PostgREST grants (unauthenticated cross-org read/write). **Every other tenant table is FORCE-RLS'd** — these 3 were the only gap. | Fixed + LIVE CERTIFIED `<this>` (mig `20260896`: REVOKE anon/authenticated + FORCE RLS + erp_platform policy; anon/auth denied=1/1, erp_platform ok=1) |

**Trend: 1 → 1 → 0 → 1 P1 per round. Each round sweeps a DISTINCT domain (money-race → AI → isolation), each closed once found. Isolation domain now clean (0 real RLS gaps repo-wide).**

## Tracked residuals (bounded, non-blocking — do NOT gate freeze/VAL)
- **P2 (R3)** — embeddings provider call (`ai/embeddings_client.ts:46`) bypasses the gateway spend-cap/telemetry. **Dormant by default** (no `AI_EMBEDDINGS_API_KEY`), per-user copilot-quota-bounded, fails soft. Route through the gateway when embeddings are activated.
- **P2 (R3)** — daily copilot MESSAGE-count quota (`ai_copilot_quota.ts` + `copilot_handlers.ts:334`) is check-then-act; a concurrent burst at limit−1 can overshoot the *message count* (not money — the hourly rate limit + monthly spend cap are atomically enforced). Soft courtesy cap; low impact.
- **P2 (R1)** — transport-expense `POST` has no request-idempotency key (double-submit → duplicate expense row, admin-voidable).
- **Info (R3)** — output guard grounds ₹/percent but not bare integer counts (narrative-only, never persisted as a value).
- **Pre-existing (R1)** — SMS/email/push stub mode reports fabricated `sent` when a provider isn't configured (env-gated; WhatsApp's version was fixed in Batch 6). Prod sets real providers.

## Domains still to run (future rounds, toward VAL-1 dry)
Performance (N+1 / unbounded queries), Flutter client, DR/recovery, and a broad cross-tenant RLS sweep of the full table set. The pre-freeze P4-RT hardening rounds (reclassified at RECON-2, fixes preserved) covered much of the older backend; these rounds re-verify on the frozen tree.
