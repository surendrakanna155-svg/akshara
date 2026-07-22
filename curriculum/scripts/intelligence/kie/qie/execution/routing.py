"""Program C provider routing — the CROSS-FAMILY generator/judge pair (owner-locked config).

The certification architecture requires the proposer and the independent judge to be DIFFERENT actor families
(R2-1); OpenAI→OpenAI can only ever yield a product-invisible 'provisional' row. Program C's locked routing:

  * GENERATOR — OpenAI, directly (OPENAI_API_KEY), actor family 'openai'.
  * JUDGE     — Anthropic Claude, through OpenRouter (OPENROUTER_API_KEY), actor family 'anthropic'.
                OpenRouter is a gateway, never a family — the family is the underlying model's (R2-1, locked).

`build_generator_judge_pair` enforces generator_family != judge_family at CONSTRUCTION (defense-in-depth beneath
certify.py's cert-time re-derivation): a mis-configuration that would collapse the two into one family is refused
here, before any run. Providers read their credentials at CALL time, so building and validating the pair needs
NO network and NO key — only a live generate()/judge() does.
"""
from __future__ import annotations

from typing import Tuple

from kie.qie.execution.providers.openai import OpenAIProvider
from kie.qie.execution.providers.openrouter import OpenRouterProvider

GENERATOR_FAMILY = "openai"
JUDGE_FAMILY = "anthropic"

# Defaults, VERIFIED against OpenRouter's live catalog at provisioning (2026-07-22). The exact judge model is an
# owner choice tied to the cost/throughput envelope — verified-available Anthropic Sonnets are claude-sonnet-4,
# claude-sonnet-4.5, claude-sonnet-4.6, claude-sonnet-5 (older claude-3.x-sonnet ids are NOT in the catalog).
DEFAULT_GENERATOR_MODEL = "gpt-4o-mini"
DEFAULT_JUDGE_MODEL = "anthropic/claude-sonnet-4.5"


class CrossFamilyViolation(Exception):
    """A generator/judge pair whose actor families are EQUAL — refused fail-closed (R2-1). Certifying with a
    same-family judge is impossible by design, so a routing that would do so is a configuration error, not a
    run: it is caught here before any model is called."""


def build_generator(model: str = DEFAULT_GENERATOR_MODEL) -> OpenAIProvider:
    """The OpenAI generator (family 'openai'), credential OPENAI_API_KEY (read at call time)."""
    return OpenAIProvider(model=model, family_name=GENERATOR_FAMILY)


def build_judge(model: str = DEFAULT_JUDGE_MODEL) -> OpenRouterProvider:
    """The Anthropic-Claude-via-OpenRouter judge, credential OPENROUTER_API_KEY. `family()` derives to the real
    underlying family ('anthropic' for 'anthropic/…'), never 'openrouter'."""
    return OpenRouterProvider(model=model)


def build_generator_judge_pair(generator_model: str = DEFAULT_GENERATOR_MODEL,
                               judge_model: str = DEFAULT_JUDGE_MODEL
                               ) -> Tuple[OpenAIProvider, OpenRouterProvider]:
    """Construct the locked cross-family pair and REFUSE (CrossFamilyViolation) if the two families are equal.
    Needs no key and no network — family derivation is pure."""
    gen = build_generator(generator_model)
    jud = build_judge(judge_model)
    if gen.family() == jud.family():
        raise CrossFamilyViolation(
            f"generator family {gen.family()!r} == judge family {jud.family()!r} — a same-family judge can never "
            f"certify (R2-1). Route the judge through a genuinely different underlying family.")
    return gen, jud
