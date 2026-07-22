"""Program C provisioning locks — judge pricing, budget soft-alert, rate governor, and the run config.

Deterministic: injected clock/sleep, no network, no key. Invariants pinned:
  * the judge model (anthropic/claude-sonnet-4.5) is priced, so cost_usd is real (not the 0.0 unpriced fallback)
    and the Budget cap can enforce judge spend.
  * the soft alert fires ONCE when spend crosses it and is ADVISORY — it never blocks; the hard cap still
    fail-closes independently.
  * the rate governor enforces the minimum inter-request interval (5/min => 12s) and delegates family/name so the
    wrapped judge still reports family 'anthropic'.
  * program_c run-config carries the exact owner-approved envelope (0.25 / 0.10 / concurrency 1 / 5 rpm) and the
    22-question recalled cohort with generation disabled.
"""
from __future__ import annotations

import unittest

from kie.qie.execution import program_c as PC
from kie.qie.execution.providers.ratelimit import RateLimitedProvider
from kie.qie.execution.provider import LLMRequest
from kie.qie.execution.providers.replay import FakeProvider
from kie.qie.execution.telemetry import PRICE_TABLE, Budget, cost_usd


class TestJudgePricing(unittest.TestCase):
    def test_judge_model_is_priced(self):
        self.assertIn("anthropic/claude-sonnet-4.5", PRICE_TABLE)
        self.assertEqual(PRICE_TABLE["anthropic/claude-sonnet-4.5"], (0.003, 0.015))

    def test_cost_is_real_not_unpriced_fallback(self):
        # 10k in + 2k out at (0.003, 0.015)/1k -> 0.03 + 0.03 = 0.06, NOT the 0.0 unknown-model fallback.
        c = cost_usd("anthropic/claude-sonnet-4.5", 10_000, 2_000)
        self.assertAlmostEqual(c, 0.06, places=6)
        self.assertGreater(c, 0.0)

    def test_all_provisioned_sonnets_priced(self):
        for m in ("anthropic/claude-sonnet-4", "anthropic/claude-sonnet-4.6", "anthropic/claude-sonnet-5"):
            self.assertIn(m, PRICE_TABLE)


class TestBudgetSoftAlert(unittest.TestCase):
    def test_soft_alert_fires_once_and_is_advisory(self):
        fired = []
        b = Budget(cap_usd=0.25, soft_usd=0.10, on_soft=lambda spent: fired.append(spent))
        b.add(0.05)
        self.assertFalse(b.soft_exceeded())
        self.assertEqual(fired, [])
        b.add(0.06)                       # crosses 0.10
        self.assertTrue(b.soft_exceeded())
        self.assertEqual(len(fired), 1)
        b.add(0.02)                       # already fired -> does NOT fire again
        self.assertEqual(len(fired), 1)
        # advisory only: crossing the soft line never raised and the hard cap is not yet reached.
        b.check()                         # no BudgetExceeded — still under 0.25

    def test_hard_cap_still_fail_closed_independently(self):
        b = Budget(cap_usd=0.25, soft_usd=0.10)
        b.add(0.25)
        self.assertTrue(b.exceeded())
        with self.assertRaises(Exception):   # BudgetExceeded
            b.check()

    def test_no_soft_is_default_off(self):
        b = Budget(cap_usd=0.25)          # no soft_usd -> unchanged R4-2 behaviour
        b.add(0.20)
        self.assertFalse(b.soft_exceeded())


class _FakeClock:
    def __init__(self):
        self.t = 0.0
        self.slept = []

    def now(self):
        return self.t

    def sleep(self, s):
        self.slept.append(s)
        self.t += s                        # advancing the clock models the wait actually elapsing


class TestRateLimiter(unittest.TestCase):
    def _provider(self, clk):
        inner = FakeProvider("[]", name="anthropic/claude-sonnet-4.5", family="anthropic")
        return RateLimitedProvider(inner, requests_per_min=5, clock=clk.now, sleep=clk.sleep), inner

    def test_min_interval_enforced(self):
        clk = _FakeClock()
        p, inner = self._provider(clk)
        req = LLMRequest(stage="judge", model="anthropic/claude-sonnet-4.5", prompt="x")
        p.complete(req)                    # first call: no wait
        self.assertEqual(clk.slept, [])
        p.complete(req)                    # immediately after: must wait the full 12s
        self.assertEqual(clk.slept, [12.0])
        self.assertEqual(inner.calls, 2)

    def test_no_wait_if_interval_already_elapsed(self):
        clk = _FakeClock()
        p, _ = self._provider(clk)
        req = LLMRequest(stage="judge", model="anthropic/claude-sonnet-4.5", prompt="x")
        p.complete(req)
        clk.t += 20.0                      # 20s pass -> more than the 12s minimum
        p.complete(req)
        self.assertEqual(clk.slept, [])    # no throttling needed

    def test_delegates_family_and_name(self):
        clk = _FakeClock()
        p, _ = self._provider(clk)
        self.assertEqual(p.family(), "anthropic")   # cross-family gate sees the real family, not the governor
        self.assertEqual(p.name(), "anthropic/claude-sonnet-4.5")


class TestRunConfig(unittest.TestCase):
    def test_owner_approved_envelope(self):
        self.assertEqual(PC.HARD_BUDGET_USD, 0.25)
        self.assertEqual(PC.SOFT_ALERT_USD, 0.10)
        self.assertEqual(PC.MAX_CONCURRENCY, 1)
        self.assertEqual(PC.MAX_REQUESTS_PER_MIN, 5)
        self.assertEqual(PC.MIN_REQUEST_INTERVAL_S, 12.0)

    def test_cohort_scope_locked(self):
        self.assertEqual(PC.COHORT, "recalled_factory_22")
        self.assertEqual(PC.COHORT_SIZE, 22)
        self.assertFalse(PC.EXPAND_COHORTS)
        self.assertFalse(PC.GENERATION_ENABLED)      # no bulk generation

    def test_build_budget_matches_envelope(self):
        b = PC.build_budget()
        self.assertEqual(b.cap_usd, 0.25)
        self.assertEqual(b.soft_usd, 0.10)

    def test_rate_limited_judge_is_anthropic_family(self):
        j = PC.build_rate_limited_judge()
        self.assertIsInstance(j, RateLimitedProvider)
        self.assertEqual(j.family(), "anthropic")    # judge family for the cross-family gate
        self.assertEqual(j.min_interval_s, 12.0)


if __name__ == "__main__":
    unittest.main()
