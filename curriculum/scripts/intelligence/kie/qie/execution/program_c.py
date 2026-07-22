"""Program C — controlled-run configuration (owner-approved, TESTING-ONLY, 2026-07-22).

This module is the single, reviewable source of truth for the FIRST controlled Program C run. It only CONFIGURES
(budget, throughput, cohort scope) and provides builders that assemble the configured objects — it does NOT
execute anything. Live generation/judging is a separate, explicitly-gated step.

Owner decisions encoded here:
  * BUDGET (testing-only): hard cap $0.25 (fail-closed), soft alert $0.10 (advisory).
  * THROUGHPUT: max concurrency 1, max 5 requests/minute (=> ≥12.0s between request starts).
  * COHORT: ONLY the 22 recalled factory questions (the R0-2 recall). No expansion to other held cohorts.
  * NO BULK GENERATION: the recalled items are re-certified via the cross-family JUDGE (OpenAI-generated content,
    Anthropic-judged) plus the deterministic gates — the generator model is NOT invoked in this run.

The cross-family routing (generator = OpenAI 'openai'; judge = Anthropic-via-OpenRouter 'anthropic') lives in
`kie.qie.execution.routing`; this module wraps the judge in the approved rate governor and builds the budget.
"""
from __future__ import annotations

from typing import Callable, Optional

from kie.qie.execution.providers.ratelimit import RateLimitedProvider
from kie.qie.execution.routing import DEFAULT_JUDGE_MODEL, build_judge
from kie.qie.execution.telemetry import Budget

# ── owner-approved budget envelope (testing-only) ──────────────────────────────────────────────────
HARD_BUDGET_USD = 0.25          # fail-closed hard cap (Budget.check refuses to START a call once reached)
SOFT_ALERT_USD = 0.10           # advisory threshold — fires on_soft once, never blocks

# ── owner-approved throughput envelope ─────────────────────────────────────────────────────────────
MAX_CONCURRENCY = 1
MAX_REQUESTS_PER_MIN = 5
MIN_REQUEST_INTERVAL_S = 60.0 / MAX_REQUESTS_PER_MIN     # 12.0s between request starts

# ── owner-approved first cohort ────────────────────────────────────────────────────────────────────
COHORT = "recalled_factory_22"  # the R0-2 recall: 22 factory-lane questions flipped certified -> quarantined
COHORT_SIZE = 22
EXPAND_COHORTS = False          # do NOT touch the 7 QDI / 15 / 14 / 128 held cohorts in this run
GENERATION_ENABLED = False      # re-certify via cross-family JUDGE only — never invoke the generator model

JUDGE_MODEL = DEFAULT_JUDGE_MODEL   # 'anthropic/claude-sonnet-4.5' (verified-available; priced in PRICE_TABLE)


def build_budget(on_soft: Optional[Callable[[float], None]] = None) -> Budget:
    """The approved fail-closed budget: $0.25 hard cap + $0.10 advisory soft alert."""
    return Budget(cap_usd=HARD_BUDGET_USD, soft_usd=SOFT_ALERT_USD, on_soft=on_soft)


def build_rate_limited_judge(model: str = JUDGE_MODEL, **rl_kw) -> RateLimitedProvider:
    """The Anthropic-via-OpenRouter judge (family 'anthropic') wrapped in the approved 5-requests/minute governor.
    Constructs without a key or network; the OpenRouter credential is read at call time (fail-closed)."""
    return RateLimitedProvider(build_judge(model), requests_per_min=MAX_REQUESTS_PER_MIN, **rl_kw)
