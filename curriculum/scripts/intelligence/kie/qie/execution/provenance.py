"""Provenance — turn an executed (request, response) into the EXACT bundle the factory certification lane demands.

The whole point of this layer feeding the factory is that provenance is COMPUTED from what actually ran, never
asserted by a caller (R2-3 / RI-8):
  * generation bundle -> {model, model_version, prompt_sha256, actor, contract_version} — the shape
    corpus._require_provenance(kind='generation') checks; run_generation.ingest_candidates consumes it directly.
    We ALSO attach `generator_family` (the provider's actor family) so proposer/judge independence is real, plus
    the token/wall/note fields run_generation forwards into the R2-3 run_telemetry row.
  * judge bundle      -> {model, model_version, prompt_sha256, actor} (+ `judge_family`) — the shape
    corpus._require_provenance(kind='judge') / _JUDGE_PROVENANCE_FIELDS checks; ingest_judgements consumes it.

`prompt_sha256` is sha256 of the EXACT prompt sent (the brief for generation, the worksheet for judging) — the
same hash the factory expects (plan.brief_sha256). It is never accepted from a caller; it is derived from the
request that produced the response.
"""
from __future__ import annotations

from typing import Optional

from kie.qie.execution.provider import LLMRequest, LLMResponse
from kie.qie.factory import plan as PLAN


def _prompt_sha256(req: LLMRequest) -> str:
    # bind provenance to the precise brief/worksheet string — identical to the factory's plan.brief_sha256.
    return PLAN.brief_sha256(req.prompt)


def generation_provenance(req: LLMRequest, resp: LLMResponse, *, family: str,
                          contract_version: Optional[str] = None, note: Optional[str] = None) -> dict:
    """The generation bundle run_generation.ingest_candidates consumes. `family` is the provider's actor family
    (generator_family) so a same-family judge cannot later fake independence. Token/wall/cost ride along for the
    run_telemetry row the factory writes; `payload_sha256` is deliberately NOT here — the factory computes it
    inside ingest over the exact stored bytes."""
    return {
        "model": resp.model or req.model,
        "model_version": resp.model_version or req.model_version,
        "prompt_sha256": _prompt_sha256(req),
        "actor": req.actor,
        "contract_version": contract_version or req.contract_version or PLAN.CONTRACT_VERSION,
        "generator_family": family,
        # telemetry pass-through (run_generation -> CO.telemetry -> R2-3 run_telemetry):
        "input_tokens": resp.input_tokens,
        "output_tokens": resp.output_tokens,
        "wall_seconds": round((resp.latency_ms or 0) / 1000.0, 3),
        "cost_usd": resp.cost_usd,
        "note": note or f"generation via {resp.model or req.model} (cache_hit={resp.cache_hit})",
    }


def judge_provenance(req: LLMRequest, resp: LLMResponse, *, family: str, note: Optional[str] = None) -> dict:
    """The judge bundle run_generation.ingest_judgements consumes. `family` is the judge's actor family
    (judge_family) — independence stays COMPUTED in judge.ingest from judge_family vs generator_family, never a
    caller-asserted flag."""
    return {
        "model": resp.model or req.model,
        "model_version": resp.model_version or req.model_version,
        "prompt_sha256": _prompt_sha256(req),
        "actor": req.actor,
        "judge_family": family,
        "input_tokens": resp.input_tokens,
        "output_tokens": resp.output_tokens,
        "wall_seconds": round((resp.latency_ms or 0) / 1000.0, 3),
        "cost_usd": resp.cost_usd,
        "note": note or f"judge via {resp.model or req.model} (cache_hit={resp.cache_hit})",
    }
