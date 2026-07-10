"""Knowledge Layer — optional AI authoring provider (Phase 5).

The engine's AI seam (materialize.ai_fill) hands a provider a STRUCTURAL spec
(concept, subject, question type, bloom, difficulty, marks, chapter) and expects back
{stem, answer, options, solution} — or nothing (decline). The provider is the only piece the
frozen engine leaves unimplemented; supplying one is a pure knowledge-layer concern.

Two providers are shipped:

  * NullProvider          — the DEFAULT. Declines every spec (returns None). With it wired, the
                            AI path is a guaranteed no-op: the deterministic engine stands alone
                            and nothing is ever fabricated. This is what "AI is optional / never
                            mandatory" means in code.

  * GovernedAiProvider    — the contract for a REAL author. It NEVER calls a model directly: it
                            delegates to an injected `author_fn(spec) -> dict|None` that a caller
                            wires to the approved W1 governed gateway (RBAC + domain firewall +
                            deterministic-first per the Adaptive-AI governance). It enforces the
                            grounding contract locally: any authored stem that does not reference
                            the concept by name is DROPPED (the engine's validator would reject it
                            anyway — this fails fast and never spends the result).

Whatever a provider returns is re-validated by the engine's SAME validation gate downstream
(materialize → validate_paper); ungrounded / out-of-syllabus / malformed output is rejected and
never shipped. Providers are optional and pluggable; the engine is never modified.
"""
from __future__ import annotations

import re
from typing import Callable, Dict, Optional


class NullProvider:
    """Declines every spec — the safe default (AI path becomes a no-op, zero fabrication)."""

    def author(self, spec: Dict) -> Optional[Dict]:      # noqa: D401 - protocol method
        return None


def _mentions_concept(text: str, concept_title: str) -> bool:
    """True if `text` references the concept by name (grounding precondition)."""
    if not text or not concept_title:
        return False
    core = re.sub(r"[^a-z0-9 ]", " ", concept_title.lower())
    tokens = [w for w in core.split() if len(w) >= 4]
    low = text.lower()
    if not tokens:
        return concept_title.lower() in low
    return any(tok in low for tok in tokens)


class GovernedAiProvider:
    """Adapts an approved governed-gateway author function to the engine's provider protocol.

    `author_fn(spec) -> {stem, answer, options?, solution?} | None`. This class adds NO model
    access of its own; it only enforces the local grounding contract before returning, so a
    result that could never pass validation is dropped early (and, with a persistent cache, is
    never even stored). Keeps a call counter for auditing API usage."""

    def __init__(self, author_fn: Callable[[Dict], Optional[Dict]]):
        self._author_fn = author_fn
        self.calls = 0

    def author(self, spec: Dict) -> Optional[Dict]:
        self.calls += 1
        out = self._author_fn(spec) or None
        if not out or not out.get("stem"):
            return None
        # local grounding gate — the stem MUST name the concept (defence in depth; the engine
        # re-validates grounding + boundary + structure downstream and rejects anything unsafe).
        if not _mentions_concept(out.get("stem", ""), spec.get("concept_title", "")):
            return None
        return out
