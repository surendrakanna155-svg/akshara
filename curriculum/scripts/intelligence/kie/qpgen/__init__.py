"""Question Paper Generation Engine — deterministic-first paper assembly over the local
certified Knowledge Intelligence Engine (KIE).

Reads `kie.db` (concepts, Concept Graph, Question Intelligence) as its ONLY knowledge source
and never mutates it. Pipeline: scope → blueprint → candidate pool → deterministic selection
→ materialize (deterministic stems; objective items are spec'd for a GATED AI fill) →
strict validation → assemble/render. AI enhances, never replaces, the deterministic path and
is never invoked unless explicitly authorized.

Reuses the completed KIE components; it does not reimplement or rewrite them.
"""
from __future__ import annotations

from kie.qpgen.models import (Blueprint, BlueprintCell, Bloom, Difficulty, GeneratedPaper,
                              PaperRequest, QuestionSlot, QuestionType, RenderMode, SlotStatus,
                              Subject)

__all__ = [
    "PaperRequest", "Blueprint", "BlueprintCell", "QuestionSlot", "GeneratedPaper",
    "Subject", "QuestionType", "Difficulty", "Bloom", "RenderMode", "SlotStatus",
]
