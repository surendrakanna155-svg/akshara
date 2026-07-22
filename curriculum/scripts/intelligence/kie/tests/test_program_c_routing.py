"""Program C routing locks — the cross-family generator (OpenAI) / judge (Anthropic-via-OpenRouter) pair.

Everything here is DETERMINISTIC: a mock urllib-style transport, NO network, NO API key. The invariants pinned:

  * OpenRouter is a GATEWAY, never an actor family: OpenRouterProvider.family() derives the REAL underlying
    family from the model id ('anthropic/…' -> 'anthropic'), NEVER 'openrouter', and fails closed on a
    bare/unknown-vendor id.
  * credential isolation: the judge gateway reads OPENROUTER_API_KEY (fail-closed if absent) and does NOT fall
    back to OPENAI_API_KEY.
  * the judge request goes to the OpenRouter base URL, carries the routed model id, and maps usage->tokens->cost
    exactly like the OpenAI adapter (same Chat Completions dialect).
  * the locked pair is cross-family (openai != anthropic); a routing that would collapse the two families is
    refused fail-closed (CrossFamilyViolation) BEFORE any model call.
"""
from __future__ import annotations

import json
import os
import unittest
from unittest import mock

from kie.qie.execution.provider import LLMRequest, PermanentError
from kie.qie.execution.providers.openrouter import (
    OPENROUTER_BASE_URL, OpenRouterProvider, underlying_family,
)
from kie.qie.execution.routing import (
    CrossFamilyViolation, build_generator, build_generator_judge_pair, build_judge,
)


def _capturing_transport(status: int = 200, model: str = "anthropic/claude-sonnet-4.5",
                         content: str = "[]"):
    """A fake (url, headers, body) -> (status, body) transport that records what it was called with and returns a
    canned OpenAI-compatible Chat Completions body."""
    captured = {}

    def _t(url, headers, body):
        captured["url"] = url
        captured["headers"] = headers
        captured["body"] = json.loads(body.decode("utf-8"))
        resp = {"model": model, "choices": [{"message": {"content": content}, "finish_reason": "stop"}],
                "usage": {"prompt_tokens": 12, "completion_tokens": 5}}
        return status, json.dumps(resp).encode("utf-8")

    return _t, captured


def _judge_request(model: str = "anthropic/claude-sonnet-4.5") -> LLMRequest:
    return LLMRequest(stage="judge", model=model, prompt="worksheet: solve and judge", actor="judge-agent")


class TestUnderlyingFamily(unittest.TestCase):
    def test_known_vendors_map_to_real_family(self):
        self.assertEqual(underlying_family("anthropic/claude-sonnet-4.5"), "anthropic")
        self.assertEqual(underlying_family("openai/gpt-4o"), "openai")
        self.assertEqual(underlying_family("google/gemini-1.5-pro"), "google")
        self.assertEqual(underlying_family("meta-llama/llama-3.1-70b-instruct"), "meta")

    def test_never_returns_openrouter(self):
        # the gateway is never a family — there is no vendor slug that yields 'openrouter'.
        for m in ("anthropic/claude-sonnet-4.5", "openai/gpt-4o", "google/gemini-1.5-pro"):
            self.assertNotEqual(underlying_family(m), "openrouter")

    def test_bare_id_fails_closed(self):
        # no '<vendor>/' prefix -> cannot name the underlying family -> refuse, never guess.
        with self.assertRaises(PermanentError):
            underlying_family("claude-3.5-sonnet")

    def test_unknown_vendor_fails_closed(self):
        with self.assertRaises(PermanentError):
            underlying_family("acme/mystery-model")
        with self.assertRaises(PermanentError):
            underlying_family("openrouter/auto")   # the gateway's own pseudo-vendor is NOT a family


class TestOpenRouterProvider(unittest.TestCase):
    def test_family_is_underlying_not_gateway(self):
        p = OpenRouterProvider(model="anthropic/claude-sonnet-4.5", api_key="test-key")
        self.assertEqual(p.family(), "anthropic")
        self.assertTrue(p.name().startswith("openrouter:"))
        self.assertIn("anthropic/claude-sonnet-4.5", p.name())

    def test_construction_fails_closed_on_unnameable_family(self):
        with self.assertRaises(PermanentError):
            OpenRouterProvider(model="claude-3.5-sonnet", api_key="test-key")   # no vendor prefix

    def test_request_targets_openrouter_and_maps_usage(self):
        transport, captured = _capturing_transport(model="anthropic/claude-sonnet-4.5", content='[{"ok":true}]')
        p = OpenRouterProvider(model="anthropic/claude-sonnet-4.5", api_key="test-key", transport=transport)
        resp = p.complete(_judge_request())
        self.assertEqual(captured["url"], OPENROUTER_BASE_URL)
        self.assertEqual(captured["body"]["model"], "anthropic/claude-sonnet-4.5")
        self.assertEqual(captured["headers"]["Authorization"], "Bearer test-key")
        self.assertEqual(resp.input_tokens, 12)
        self.assertEqual(resp.output_tokens, 5)
        self.assertEqual(resp.model, "anthropic/claude-sonnet-4.5")
        self.assertIsInstance(resp.cost_usd, float)   # unpriced judge model -> 0.0 (honest), still a float

    def test_reads_openrouter_key_not_openai_key(self):
        transport, _ = _capturing_transport()
        p = OpenRouterProvider(model="anthropic/claude-sonnet-4.5", transport=transport)  # no explicit api_key
        # OPENAI present but OPENROUTER absent -> must fail closed, never borrow the OpenAI key.
        with mock.patch.dict(os.environ, {"OPENAI_API_KEY": "openai-only"}, clear=True):
            os.environ.pop("OPENROUTER_API_KEY", None)
            with self.assertRaises(PermanentError):
                p.complete(_judge_request())
        # OPENROUTER present -> resolves.
        with mock.patch.dict(os.environ, {"OPENROUTER_API_KEY": "router-key"}, clear=True):
            resp = p.complete(_judge_request())
            self.assertEqual(resp.output_tokens, 5)


class TestRouting(unittest.TestCase):
    def test_locked_pair_is_cross_family(self):
        gen, jud = build_generator_judge_pair()
        self.assertEqual(gen.family(), "openai")
        self.assertEqual(jud.family(), "anthropic")
        self.assertNotEqual(gen.family(), jud.family())

    def test_defaults(self):
        self.assertEqual(build_generator().family(), "openai")
        self.assertEqual(build_judge().family(), "anthropic")

    def test_same_family_routing_refused(self):
        # routing the "judge" through an OpenAI model via the gateway collapses both to family 'openai' -> refuse.
        with self.assertRaises(CrossFamilyViolation):
            build_generator_judge_pair(generator_model="gpt-4o-mini", judge_model="openai/gpt-4o")


if __name__ == "__main__":
    unittest.main()
