"""Concrete Provider adapters for the R4-2 execution layer."""
from kie.qie.execution.providers.openai import OpenAIProvider
from kie.qie.execution.providers.openrouter import OpenRouterProvider, underlying_family
from kie.qie.execution.providers.ratelimit import RateLimitedProvider
from kie.qie.execution.providers.replay import (
    FakeProvider, RecordingProvider, ReplayLog, ReplayProvider,
)

__all__ = [
    "OpenAIProvider",
    "OpenRouterProvider", "underlying_family",
    "RateLimitedProvider",
    "FakeProvider", "RecordingProvider", "ReplayProvider", "ReplayLog",
]
