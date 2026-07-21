"""The provider-agnostic contract — the seam every model backend implements (R4-2).

OpenAI is the first adapter; Anthropic/Gemini slot in later behind the SAME `Provider` ABC with no change to the
queue, cache, telemetry, provenance or engine. The two data carriers (`LLMRequest`, `LLMResponse`) and the pure
`request_sha256` (the cache / replay / idempotency key) are the whole coupling surface.

STANDING LLM POLICY (non-negotiable): a request's `prompt` is a concept BRIEF (generation) or a student-view
WORKSHEET (judging) — NEVER a source PDF / book body. This layer only ever transports briefs/worksheets. The
model PROPOSES/JUDGES; the deterministic factory gates CERTIFY. Nothing here promotes anything.
"""
from __future__ import annotations

import hashlib
import json
from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional

# stages a request may carry — the two model stages the factory certification lane knows (R2-3).
GENERATION = "generation"
JUDGE = "judge"
_STAGES = (GENERATION, JUDGE)


# ── error taxonomy: the queue retries TRANSIENT, refuses PERMANENT, and fails closed on BudgetExceeded ──
class ProviderError(Exception):
    """Base for any provider-surfaced failure."""


class TransientError(ProviderError):
    """A retryable failure — a timeout, a 5xx, or a 429 rate-limit. The queue backs off and retries these."""


class PermanentError(ProviderError):
    """A non-retryable failure — a 4xx (bad request / auth), a malformed response, a missing API key. The queue
    does NOT retry; it surfaces the error so the caller fails closed rather than looping."""


class ReplayMiss(ProviderError):
    """A ReplayProvider was asked for a request_sha256 it never recorded and has no fall-through. Deterministic
    replay must be exact, so an un-recorded request is an error, not a silent live call."""


@dataclass
class LLMRequest:
    """One model call. `prompt` is the EXACT brief/worksheet text sent (and the string prompt_sha256 hashes);
    `system` is an optional system message. `params` are the sampling controls that make a call reproducible
    (temperature/max_tokens/seed). `actor` is WHO issued the stage (the R2-3 provenance actor). `item_hash` is
    carried on judge requests so the JudgeCache can key on it."""
    stage: str
    model: str
    prompt: str
    model_version: str = ""
    system: str = ""
    params: Dict[str, Any] = field(default_factory=dict)
    actor: str = ""
    item_hash: Optional[str] = None
    contract_version: Optional[str] = None
    # free-form pass-through the caller may attach (e.g. spec_ids); NOT part of the cache key.
    meta: Dict[str, Any] = field(default_factory=dict)

    def __post_init__(self):
        if self.stage not in _STAGES:
            raise ValueError(f"unknown stage {self.stage!r} (expected one of {_STAGES})")
        if not str(self.prompt or "").strip():
            raise ValueError("LLMRequest.prompt is empty — a brief/worksheet is required (LLM policy)")

    def messages(self) -> List[Dict[str, str]]:
        """Chat-shaped messages an adapter sends on the wire: optional system, then the brief/worksheet as user."""
        msgs: List[Dict[str, str]] = []
        if self.system:
            msgs.append({"role": "system", "content": self.system})
        msgs.append({"role": "user", "content": self.prompt})
        return msgs

    def to_json(self) -> str:
        return json.dumps({
            "stage": self.stage, "model": self.model, "model_version": self.model_version,
            "prompt": self.prompt, "system": self.system, "params": self.params, "actor": self.actor,
            "item_hash": self.item_hash, "contract_version": self.contract_version, "meta": self.meta,
        }, sort_keys=True, ensure_ascii=False)

    @classmethod
    def from_json(cls, s: str) -> "LLMRequest":
        d = json.loads(s)
        return cls(stage=d["stage"], model=d["model"], prompt=d["prompt"],
                   model_version=d.get("model_version", ""), system=d.get("system", ""),
                   params=d.get("params") or {}, actor=d.get("actor", ""), item_hash=d.get("item_hash"),
                   contract_version=d.get("contract_version"), meta=d.get("meta") or {})


@dataclass
class LLMResponse:
    """One model result. Token counts + cost + latency are the cost-accounting/telemetry evidence; `raw` keeps the
    provider's untouched payload for audit. `cache_hit`/`attempt` are stamped by the cache/queue, not the model."""
    text: str
    model: str
    model_version: str = ""
    input_tokens: int = 0
    output_tokens: int = 0
    cost_usd: float = 0.0
    latency_ms: int = 0
    finish_reason: str = ""
    raw: Dict[str, Any] = field(default_factory=dict)
    cache_hit: bool = False
    attempt: int = 1

    def to_dict(self) -> Dict[str, Any]:
        return {
            "text": self.text, "model": self.model, "model_version": self.model_version,
            "input_tokens": self.input_tokens, "output_tokens": self.output_tokens,
            "cost_usd": self.cost_usd, "latency_ms": self.latency_ms, "finish_reason": self.finish_reason,
            "raw": self.raw, "cache_hit": self.cache_hit, "attempt": self.attempt,
        }

    @classmethod
    def from_dict(cls, d: Dict[str, Any]) -> "LLMResponse":
        return cls(text=d["text"], model=d.get("model", ""), model_version=d.get("model_version", ""),
                   input_tokens=int(d.get("input_tokens") or 0), output_tokens=int(d.get("output_tokens") or 0),
                   cost_usd=float(d.get("cost_usd") or 0.0), latency_ms=int(d.get("latency_ms") or 0),
                   finish_reason=d.get("finish_reason", ""), raw=d.get("raw") or {},
                   cache_hit=bool(d.get("cache_hit")), attempt=int(d.get("attempt") or 1))


def _canonical(obj: Any) -> str:
    return json.dumps(obj, sort_keys=True, ensure_ascii=False, separators=(",", ":"))


def request_sha256(req: LLMRequest) -> str:
    """The pure cache / replay / idempotency key: a sha256 over the CANONICAL (model, params, prompt) — the
    material that determines the model's output. Deterministic and order-stable (sort_keys), so the same logical
    request always maps to the same key and a completed request is never re-sent. It deliberately EXCLUDES the
    actor, stage-label metadata and `meta` (they do not change what the model returns); `system` is included
    because it does. This is a free function of the request alone — no DB, no state."""
    material = _canonical({
        "model": req.model,
        "params": req.params or {},
        "system": req.system or "",
        "prompt": req.prompt,
    })
    return hashlib.sha256(material.encode("utf-8")).hexdigest()


class Provider(ABC):
    """The backend seam. `name()` is the concrete model/provider label; `family()` is the ACTOR FAMILY used for
    R2-1 proposer/judge independence (e.g. 'openai', 'anthropic', 'human-review') — two calls in the same family
    are NOT independent and can only ever produce a provisional (product-invisible) certification. `complete`
    turns a request into a response and MUST fail closed: a transport/rate error raises TransientError, a
    bad-request/auth/malformed error raises PermanentError, and success never fabricates token/cost fields."""

    @abstractmethod
    def name(self) -> str:
        ...

    @abstractmethod
    def family(self) -> str:
        ...

    @abstractmethod
    def complete(self, req: LLMRequest) -> LLMResponse:
        ...
