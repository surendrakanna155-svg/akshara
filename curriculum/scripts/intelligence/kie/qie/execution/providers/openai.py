"""OpenAIProvider — the first real adapter (R4-2). Chat Completions over stdlib `urllib.request`, NO new dep.

Two seams keep it fully unit-testable with NO network and NO API key:
  * `transport` is an injectable callable `(url, headers, body_bytes) -> (status:int, body:bytes)`. The default is
    a real HTTPS POST via urllib; tests inject a fake transport that returns a canned Chat Completions body, so
    the request-building, response-mapping, usage/cost accounting and the HTTP-status -> error-class mapping are
    all exercised deterministically.
  * the API key is read from `OPENAI_API_KEY` at CALL time and, if absent, raises a clear PermanentError (a
    standing law: missing key -> refuse, never fake success). LIVE use therefore needs `OPENAI_API_KEY` set —
    an external/owner tail, never hardcoded.

Failure mapping (so the queue can retry the right things): HTTP 429 / 5xx and network timeouts -> TransientError
(retryable); other non-2xx and a malformed body -> PermanentError (not retried).
"""
from __future__ import annotations

import json
import os
import time
import urllib.error
import urllib.request
from typing import Callable, Dict, Optional, Tuple

from kie.qie.execution import telemetry as TEL
from kie.qie.execution.provider import (
    LLMRequest, LLMResponse, PermanentError, Provider, TransientError,
)

Transport = Callable[[str, Dict[str, str], bytes], Tuple[int, bytes]]

DEFAULT_BASE_URL = "https://api.openai.com/v1/chat/completions"
_RETRYABLE_STATUS = frozenset({429, 500, 502, 503, 504})


def _real_transport(timeout: float) -> Transport:
    """A real HTTPS POST via stdlib urllib. Network timeouts / URL errors raise TransientError so the queue
    retries; other exceptions surface. Non-2xx statuses are returned as (status, body) for complete() to map."""
    def _t(url: str, headers: Dict[str, str], body: bytes) -> Tuple[int, bytes]:
        req = urllib.request.Request(url, data=body, headers=headers, method="POST")
        try:
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                return resp.getcode(), resp.read()
        except urllib.error.HTTPError as e:               # a status came back — hand it to the mapper
            return e.code, e.read()
        except (urllib.error.URLError, TimeoutError) as e:  # no status — a transport failure is retryable
            raise TransientError(f"openai transport error: {e}") from e
    return _t


class OpenAIProvider(Provider):
    def __init__(self, model: str = "gpt-4o-mini", *, model_version: Optional[str] = None,
                 api_key: Optional[str] = None, transport: Optional[Transport] = None,
                 base_url: str = DEFAULT_BASE_URL, family_name: str = "openai", timeout: float = 60.0,
                 prices: Optional[Dict[str, Tuple[float, float]]] = None):
        self.model = model
        self.model_version = model_version or model      # OpenAI has no separate version string; model IS the id
        self._api_key = api_key                          # if None, read from env at call time (fail-closed)
        self.transport = transport or _real_transport(timeout)
        self.base_url = base_url
        self._family = family_name
        self.prices = prices

    def name(self) -> str:
        return f"openai:{self.model}"

    def family(self) -> str:
        return self._family

    def _key(self) -> str:
        key = self._api_key or os.environ.get("OPENAI_API_KEY")
        if not key:
            raise PermanentError(
                "OPENAI_API_KEY is not set — refusing to call OpenAI fail-closed (never fake success). Set the "
                "env var for live use; unit tests inject a fake transport and never need a key.")
        return key

    def _payload(self, req: LLMRequest) -> dict:
        body = {"model": self.model, "messages": req.messages()}
        p = req.params or {}
        for k in ("temperature", "max_tokens", "seed", "top_p"):
            if p.get(k) is not None:
                body[k] = p[k]
        return body

    def complete(self, req: LLMRequest) -> LLMResponse:
        headers = {"Authorization": f"Bearer {self._key()}", "Content-Type": "application/json"}
        body = json.dumps(self._payload(req)).encode("utf-8")
        t0 = time.monotonic()
        status, raw_bytes = self.transport(self.base_url, headers, body)
        latency_ms = int((time.monotonic() - t0) * 1000)

        if status in _RETRYABLE_STATUS:
            raise TransientError(f"openai HTTP {status} (retryable): {raw_bytes[:300]!r}")
        if status < 200 or status >= 300:
            raise PermanentError(f"openai HTTP {status} (not retryable): {raw_bytes[:300]!r}")

        try:
            data = json.loads(raw_bytes.decode("utf-8"))
            choice = data["choices"][0]
            text = choice["message"]["content"]
            finish = choice.get("finish_reason", "")
            usage = data.get("usage") or {}
            model_id = data.get("model", self.model)
        except (ValueError, KeyError, IndexError, TypeError) as e:
            raise PermanentError(f"openai malformed response: {e}: {raw_bytes[:300]!r}") from e

        in_tok = int(usage.get("prompt_tokens") or 0)
        out_tok = int(usage.get("completion_tokens") or 0)
        return LLMResponse(
            text=text, model=model_id, model_version=self.model_version,
            input_tokens=in_tok, output_tokens=out_tok,
            cost_usd=TEL.cost_usd(model_id, in_tok, out_tok, prices=self.prices),
            latency_ms=latency_ms, finish_reason=finish, raw=data)
