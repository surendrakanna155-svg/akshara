"""Deterministic providers — the layer's whole unit-test story (NO network, NO key) AND its deterministic replay.

  * FakeProvider     — returns canned responses (or a caller-supplied responder(req) -> text|LLMResponse). Token
                       counts are estimated from text length and cost comes from the real price table, so cache /
                       telemetry / cost accounting are exercised with zero live calls.
  * ReplayLog        — a persistent request_sha256 -> LLMResponse map (JSONL file, or in-memory). The record of
                       what a live provider actually returned.
  * RecordingProvider — wraps a real provider and RECORDS every (request_sha256 -> response) to a ReplayLog as it
                       goes. Run once live, keep the log.
  * ReplayProvider   — replays a ReplayLog: for a request_sha256 it returns the recorded response EXACTLY; a miss
                       raises ReplayMiss (or falls through to a configured provider if asked). This IS the
                       deterministic replay — record once, replay identically forever with no network.
"""
from __future__ import annotations

import json
import os
import threading
from pathlib import Path
from typing import Callable, Dict, Optional, Union

from kie.qie.execution import telemetry as TEL
from kie.qie.execution.provider import (
    LLMRequest, LLMResponse, Provider, ReplayMiss, request_sha256,
)


def _estimate_tokens(text: str) -> int:
    # a coarse, deterministic token estimate (~4 chars/token) so fake runs produce non-zero cost/telemetry.
    return max(1, len((text or "")) // 4)


class FakeProvider(Provider):
    """Deterministic stand-in. `responder(req)` returns either the response TEXT (str) or a full LLMResponse; a
    dict of {prompt -> text} or a single canned text also work. Used everywhere the tests need a model without a
    model."""

    def __init__(self, responder: Union[Callable[[LLMRequest], object], Dict[str, str], str],
                 *, name: str = "fake-model", family: str = "fake", model_version: str = "fake-v1"):
        self._responder = responder
        self._name = name
        self._family = family
        self.model_version = model_version
        self.calls = 0                      # observable call count — tests assert cache/replay avoided a re-call

    def name(self) -> str:
        return self._name

    def family(self) -> str:
        return self._family

    def _resolve(self, req: LLMRequest):
        r = self._responder
        if callable(r):
            return r(req)
        if isinstance(r, dict):
            return r.get(req.prompt, "")
        return r

    def complete(self, req: LLMRequest) -> LLMResponse:
        self.calls += 1
        out = self._resolve(req)
        if isinstance(out, LLMResponse):
            return out
        text = out if isinstance(out, str) else json.dumps(out)
        in_tok = _estimate_tokens(req.system + req.prompt)
        out_tok = _estimate_tokens(text)
        return LLMResponse(
            text=text, model=self._name, model_version=self.model_version,
            input_tokens=in_tok, output_tokens=out_tok,
            cost_usd=TEL.cost_usd(self._name, in_tok, out_tok), latency_ms=1, finish_reason="stop",
            raw={"fake": True})


class ReplayLog:
    """A request_sha256 -> LLMResponse store. In-memory by default; give a `path` to persist as JSONL (one
    {"key":..., "response":...} object per line) so a recording survives the process."""

    def __init__(self, path: Optional[Union[str, Path]] = None):
        self.path = str(path) if path else None
        self._mem: Dict[str, LLMResponse] = {}
        self._lock = threading.Lock()
        if self.path and os.path.exists(self.path):
            self._load()

    def _load(self) -> None:
        with open(self.path, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                obj = json.loads(line)
                self._mem[obj["key"]] = LLMResponse.from_dict(obj["response"])

    def get(self, key: str) -> Optional[LLMResponse]:
        return self._mem.get(key)

    def put(self, key: str, resp: LLMResponse) -> None:
        with self._lock:
            self._mem[key] = resp
            if self.path:
                Path(self.path).parent.mkdir(parents=True, exist_ok=True)
                with open(self.path, "a", encoding="utf-8") as f:
                    f.write(json.dumps({"key": key, "response": resp.to_dict()}, ensure_ascii=False) + "\n")

    def __len__(self) -> int:
        return len(self._mem)

    def __contains__(self, key: str) -> bool:
        return key in self._mem


class RecordingProvider(Provider):
    """Wrap a real provider; RECORD every (request_sha256 -> response) to a ReplayLog. The response returned is
    the inner provider's, unchanged — recording is a side effect."""

    def __init__(self, inner: Provider, log: ReplayLog):
        self.inner = inner
        self.log = log

    def name(self) -> str:
        return self.inner.name()

    def family(self) -> str:
        return self.inner.family()

    def complete(self, req: LLMRequest) -> LLMResponse:
        resp = self.inner.complete(req)
        self.log.put(request_sha256(req), resp)
        return resp


class ReplayProvider(Provider):
    """Replay a ReplayLog deterministically. A recorded request_sha256 returns its EXACT response; a miss raises
    ReplayMiss unless `fall_through` (another provider) is given, in which case the miss is delegated live and
    (if `record` and the log is writable) recorded. name()/family() default to the log's provenance but can be
    pinned so provenance stays stable across a replay."""

    def __init__(self, log: ReplayLog, *, fall_through: Optional[Provider] = None, record: bool = False,
                 name: str = "replay", family: str = "replay"):
        self.log = log
        self.fall_through = fall_through
        self.record = record
        self._name = name
        self._family = family

    def name(self) -> str:
        return self.fall_through.name() if self.fall_through else self._name

    def family(self) -> str:
        return self.fall_through.family() if self.fall_through else self._family

    def complete(self, req: LLMRequest) -> LLMResponse:
        key = request_sha256(req)
        hit = self.log.get(key)
        if hit is not None:
            # return a copy so a caller stamping cache_hit/attempt does not mutate the stored record.
            return LLMResponse.from_dict(hit.to_dict())
        if self.fall_through is not None:
            resp = self.fall_through.complete(req)
            if self.record:
                self.log.put(key, resp)
            return resp
        raise ReplayMiss(f"no recorded response for request_sha256={key[:12]}… (deterministic replay is exact; "
                         f"record it first or configure a fall_through provider)")
