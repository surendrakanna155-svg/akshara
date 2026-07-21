"""ModelExecutor — the orchestrator that ties the R4-2 layer together (provider · cache · judge cache · queue ·
telemetry · budget · replay) and hands the factory ingest paths payloads + provenance that satisfy R2-3.

The request is PROVIDER-INDEPENDENT: it is built from the executor's LOGICAL model id (not the transport), so a
run RECORDED with a live OpenAIProvider replays byte-identically through a ReplayProvider (same request_sha256,
same cache key). The provider is only the transport; provenance is computed from the RESPONSE that actually ran.

Two model stages, mirroring the factory:
  * generate(briefs)  -> [(candidate_payload, generation_provenance)]  — one call per concept BRIEF, bounded
    concurrency, cached/idempotent. Each payload is the parsed JSON array of candidate dicts; each provenance is
    ready for run_generation.ingest_candidates.
  * judge(rows, ...)  -> (verdicts_payload, judge_provenance)          — one judge pass over a student-view
    WORKSHEET, with the item_hash-keyed JudgeCache short-circuiting already-judged identical items. The payload
    is ready for run_generation.ingest_judgements (controls included so its control check runs).

STANDING LAWS held here: briefs/worksheets only (never source text); the model PROPOSES/JUDGES, it never
certifies; missing key / budget-exceeded / unfetchable all fail closed via the queue/provider.
"""
from __future__ import annotations

import json
import sqlite3
from typing import Dict, List, Optional, Tuple

from kie.qie.execution import store as STORE
from kie.qie.execution.cache import JudgeCache, ResponseCache
from kie.qie.execution.provenance import generation_provenance, judge_provenance
from kie.qie.execution.provider import GENERATION, JUDGE, LLMRequest, Provider
from kie.qie.execution.queue import ExecutionQueue
from kie.qie.execution.telemetry import Budget, Telemetry
from kie.qie.factory import plan as PLAN


def parse_json_array(text: str) -> List[dict]:
    """Tolerantly parse a model's JSON-array output (optionally wrapped in a ```json fence). Mirrors
    run_generation.load_json_array so generation/judge payloads round-trip the same way whether they came from a
    file or from this executor."""
    txt = (text or "").strip()
    if txt.startswith("```"):
        txt = txt.split("```", 2)[1]
        if txt.startswith("json"):
            txt = txt[4:]
    out = json.loads(txt)
    if isinstance(out, dict):
        out = [out]
    return out


class ModelExecutor:
    def __init__(self, provider: Provider, *, model: str, conn: sqlite3.Connection = None,
                 model_version: str = "", actor: str = "", cache: Optional[ResponseCache] = None,
                 judge_cache: Optional[JudgeCache] = None, budget: Optional[Budget] = None,
                 telemetry: Optional[Telemetry] = None, params: Optional[dict] = None,
                 contract_version: Optional[str] = None, max_concurrency: int = 4, max_retries: int = 4,
                 **queue_kw):
        # one writable execution.db connection shared by cache / judge cache / queue / telemetry.
        self.conn = conn if conn is not None else STORE.open_execution_store(":memory:")
        self.provider = provider
        self.model = model                          # LOGICAL model id — stable across record/replay
        self.model_version = model_version or model
        self.actor = actor
        self.params = params or {}
        self.contract_version = contract_version or PLAN.CONTRACT_VERSION
        self.cache = cache if cache is not None else ResponseCache(self.conn)
        self.judge_cache = judge_cache if judge_cache is not None else JudgeCache(self.conn)
        self.budget = budget
        self.telemetry = telemetry if telemetry is not None else Telemetry(self.conn)
        self.queue = ExecutionQueue(provider, self.conn, cache=self.cache, telemetry=self.telemetry,
                                    budget=budget, max_concurrency=max_concurrency, max_retries=max_retries,
                                    **queue_kw)

    # ── generation ───────────────────────────────────────────────────────────────────────────────────
    def _gen_request(self, brief: str, run_id: Optional[str]) -> LLMRequest:
        return LLMRequest(stage=GENERATION, model=self.model, model_version=self.model_version, prompt=brief,
                          actor=self.actor, params=self.params, contract_version=self.contract_version,
                          meta={"run_id": run_id} if run_id else {})

    def generate(self, briefs: List[str], *, run_id: Optional[str] = None) -> List[Tuple[List[dict], dict]]:
        """Run each concept BRIEF once (bounded concurrency, cached). Returns [(payload, provenance)] aligned to
        `briefs`, each ready for run_generation.ingest_candidates."""
        reqs = [self._gen_request(b, run_id) for b in briefs]
        resps = self.queue.run_batch(reqs)
        out = []
        for req, resp in zip(reqs, resps):
            payload = parse_json_array(resp.text)
            prov = generation_provenance(req, resp, family=self.provider.family(),
                                         contract_version=self.contract_version)
            out.append((payload, prov))
        return out

    # ── judging ──────────────────────────────────────────────────────────────────────────────────────
    def _record_judge_cache_hit(self, run_id: Optional[str]) -> None:
        """A judge-cache reuse is not free of accountability — record a zero-cost cache_hit telemetry row so a
        reuse leaves a breadcrumb (adversarial-verifier fix; the reuse itself is family-scoped by JudgeCache)."""
        self.telemetry.note_cache_hit(stage=JUDGE, model=self.model, actor=self.actor, run_id=run_id)

    def judge(self, worksheet_rows: List[dict], *, item_hashes: Dict[str, str], brief: str,
              controls: Optional[List[dict]] = None,
              run_id: Optional[str] = None) -> Tuple[List[dict], dict]:
        """One judge pass over a student-view WORKSHEET. The item_hash-keyed JudgeCache serves any row whose
        content was already judged; only uncached rows (plus the seeded `controls`) are sent to the model. Fresh
        real verdicts are cached by item_hash. Returns (payload, provenance): payload = cached real verdicts +
        the model's fresh verdicts (real + control), ready for run_generation.ingest_judgements (which verifies
        and strips the controls). Provenance carries the judge's actor family so independence stays computed."""
        controls = controls or []
        cached_verdicts: List[dict] = []
        to_send: List[dict] = []
        ih_by_cid: Dict[str, str] = {}
        for row in worksheet_rows:
            cid = row.get("candidate_id")
            ih = item_hashes.get(cid)
            ih_by_cid[cid] = ih
            cv = self.judge_cache.get(ih, self.provider.family(), self.model) if ih else None
            if cv is not None:
                v = dict(cv)
                v["candidate_id"] = cid
                cached_verdicts.append(v)
                self._record_judge_cache_hit(run_id)   # a reuse is still accountable (telemetry breadcrumb)
            else:
                to_send.append(row)

        send_rows = to_send + controls
        if not send_rows:
            raise ValueError("judge(): nothing to send — every row was cache-served and no controls were "
                             "supplied; a real judge pass needs the seeded controls to verify the judge")

        prompt = self._render_judge_prompt(brief, send_rows)
        req = LLMRequest(stage=JUDGE, model=self.model, model_version=self.model_version, prompt=prompt,
                         actor=self.actor, params=self.params, meta={"run_id": run_id} if run_id else {})
        resp = self.queue.execute(req)
        fresh = parse_json_array(resp.text)

        prov = judge_provenance(req, resp, family=self.provider.family())
        control_ids = {c.get("candidate_id") for c in controls}
        for v in fresh:
            cid = v.get("candidate_id")
            if cid in control_ids:
                continue
            ih = ih_by_cid.get(cid)
            if ih:
                # cache the verdict under THIS judge's family+model, carrying its originating provenance —
                # so a reuse is family-consistent and can never launder a same-actor verdict cross-family (R2-1).
                self.judge_cache.put(ih, v, family=self.provider.family(), model=resp.model, provenance=prov)

        payload = cached_verdicts + fresh
        return payload, prov

    @staticmethod
    def _render_judge_prompt(brief: str, rows: List[dict]) -> str:
        lines = [brief]
        for r in rows:
            lines.append(json.dumps(r, ensure_ascii=False))
        lines.append(f"\nReturn ONLY the JSON array of {len(rows)} verdict objects.")
        return "\n".join(lines)

    def cost_summary(self, run_id: Optional[str] = None) -> dict:
        return self.telemetry.summary(run_id)
