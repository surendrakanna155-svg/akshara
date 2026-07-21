"""R4-2 — the production-ready, provider-agnostic model-execution layer for QIE.

The canonical infrastructure for generation, judging, certification input, and future QIE automation:
provider-agnostic (OpenAI first; Anthropic/Gemini later behind the same seam), with an execution queue, retry
policy, caching, provenance, deterministic replay, an item_hash-keyed judge cache, telemetry, cost accounting,
budget cap, and crash-resume failure recovery. Everything is unit-testable with a Fake/Replay provider — NO
network, NO API key. The model PROPOSES/JUDGES; the deterministic factory gates CERTIFY.

Public surface:
  * provider   — Provider ABC, LLMRequest, LLMResponse, request_sha256, error taxonomy
  * providers  — OpenAIProvider (live), FakeProvider / RecordingProvider / ReplayProvider / ReplayLog
  * cache      — ResponseCache (request_sha256), JudgeCache (item_hash)
  * queue      — ExecutionQueue (bounded concurrency + retry + persistence + resume + budget)
  * telemetry  — cost_usd, PRICE_TABLE, Budget, Telemetry, BudgetExceeded
  * provenance — generation_provenance / judge_provenance (R2-3 bundles)
  * engine     — ModelExecutor (the orchestrator)
  * store      — open_execution_store (execution.db via the R3-4 shared opener)
"""
from kie.qie.execution.cache import JudgeCache, ResponseCache
from kie.qie.execution.engine import ModelExecutor, parse_json_array
from kie.qie.execution.provenance import generation_provenance, judge_provenance
from kie.qie.execution.provider import (
    GENERATION, JUDGE, LLMRequest, LLMResponse, PermanentError, Provider, ProviderError,
    ReplayMiss, TransientError, request_sha256,
)
from kie.qie.execution.providers import (
    FakeProvider, OpenAIProvider, RecordingProvider, ReplayLog, ReplayProvider,
)
from kie.qie.execution.queue import ExecutionQueue
from kie.qie.execution.store import EXECUTION_DB_PATH, open_execution_store
from kie.qie.execution.telemetry import PRICE_TABLE, Budget, BudgetExceeded, Telemetry, cost_usd

__all__ = [
    "ModelExecutor", "parse_json_array",
    "Provider", "LLMRequest", "LLMResponse", "request_sha256",
    "ProviderError", "TransientError", "PermanentError", "ReplayMiss",
    "GENERATION", "JUDGE",
    "OpenAIProvider", "FakeProvider", "RecordingProvider", "ReplayProvider", "ReplayLog",
    "ResponseCache", "JudgeCache", "ExecutionQueue",
    "Budget", "BudgetExceeded", "Telemetry", "cost_usd", "PRICE_TABLE",
    "generation_provenance", "judge_provenance",
    "open_execution_store", "EXECUTION_DB_PATH",
]
