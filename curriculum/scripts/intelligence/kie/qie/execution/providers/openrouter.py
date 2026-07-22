"""OpenRouterProvider — the independent JUDGE gateway for Program C (cross-family certification).

Program C routes its GENERATOR through OpenAI directly (OpenAIProvider, family 'openai') and its independent
JUDGE through OpenRouter. OpenRouter is a routing GATEWAY, **never an actor family** (owner decision, locked):
proposer/judge independence (R2-1) is a property of the UNDERLYING model, so this adapter records and validates
the REAL family behind the gateway ('anthropic' for 'anthropic/…', 'google' for 'google/…', …) and REFUSES
fail-closed to route a model whose underlying family it cannot name. It never reports 'openrouter' as a family —
doing so could mask a same-family generator/judge collision and defeat the whole cross-family gate.

Transport-wise OpenRouter speaks the OpenAI Chat Completions dialect, so this subclasses OpenAIProvider and
reuses its request build / response map / status→error mapping unchanged; only the credential
(OPENROUTER_API_KEY), the base URL, the derived family, and the label differ. Fully unit-testable with an
injected fake transport — NO network, NO key.
"""
from __future__ import annotations

import os
from typing import Callable, Dict, Optional, Tuple

from kie.qie.execution.provider import PermanentError
from kie.qie.execution.providers.openai import OpenAIProvider

OPENROUTER_BASE_URL = "https://openrouter.ai/api/v1/chat/completions"

# underlying-vendor slug (the part before '/' in an OpenRouter model id) -> the QIE actor family. The family is
# the unit of proposer/judge independence (R2-1). 'openrouter' is deliberately ABSENT — the gateway is never a
# family. Extend this map as new judge families are provisioned (google, meta, …).
_UNDERLYING_FAMILY: Dict[str, str] = {
    "openai": "openai",
    "anthropic": "anthropic",
    "google": "google",
    "meta-llama": "meta",
    "mistralai": "mistral",
    "x-ai": "xai",
    "deepseek": "deepseek",
    "cohere": "cohere",
    "qwen": "qwen",
}


def underlying_family(model_id: str) -> str:
    """Derive the REAL actor family behind an OpenRouter model id ('anthropic/claude-3.5-sonnet' -> 'anthropic').

    Fails closed (PermanentError) on a bare or unknown-vendor id: a model whose underlying family we cannot name
    must not be routed, because recording it as 'openrouter' (or guessing) could let a same-family generator and
    judge slip through the cross-family independence gate. NEVER returns 'openrouter'."""
    slug = str(model_id or "").strip().lower()
    vendor = slug.split("/", 1)[0] if "/" in slug else ""
    fam = _UNDERLYING_FAMILY.get(vendor)
    if not fam:
        raise PermanentError(
            f"cannot derive an underlying actor family from OpenRouter model {model_id!r} — refusing to route. "
            f"An OpenRouter model id must be '<vendor>/<model>' with a known vendor "
            f"({sorted(_UNDERLYING_FAMILY)}); the gateway is NEVER an actor family, so an unnamed underlying "
            f"family fails closed (R2-1).")
    return fam


class OpenRouterProvider(OpenAIProvider):
    """OpenAI-compatible Chat Completions over the OpenRouter gateway, credential OPENROUTER_API_KEY. `family()`
    is the UNDERLYING model's family (derived + validated at construction), never 'openrouter'. `name()` is
    transparent that the call was routed. The API key is read at CALL time (fail-closed if absent), so building
    and family-checking a provider needs no key and no network."""

    def __init__(self, model: str = "anthropic/claude-3.5-sonnet", *, api_key: Optional[str] = None,
                 transport: Optional[Callable] = None, base_url: str = OPENROUTER_BASE_URL,
                 timeout: float = 60.0, prices: Optional[Dict[str, Tuple[float, float]]] = None):
        family = underlying_family(model)   # derive + validate BEFORE construction; fail-closed on unknown vendor
        super().__init__(model=model, api_key=api_key, transport=transport, base_url=base_url,
                         family_name=family, timeout=timeout, prices=prices)

    def name(self) -> str:
        # transparent that the call is ROUTED through the gateway, while family() reports the real family.
        return f"openrouter:{self.model}"

    def _key(self) -> str:
        key = self._api_key or os.environ.get("OPENROUTER_API_KEY")
        if not key:
            raise PermanentError(
                "OPENROUTER_API_KEY is not set — refusing to call the OpenRouter judge gateway fail-closed "
                "(never fake success). Set the env var for live use; unit tests inject a fake transport and "
                "never need a key.")
        return key
