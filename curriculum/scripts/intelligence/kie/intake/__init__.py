"""Knowledge Intake Center — the ONLY entry point for adding new knowledge to the KIE.

Incremental ingestion: the processed 360-document repository is the immutable, certified
baseline; the Intake Center processes ONLY newly added / modified / newer-version files
and runs each through the SAME deterministic pipeline (verify → dedup → version → parse →
metadata → chunk → concept → graph → questions) into a staging store, then a human
review gate, then additive promotion into the production Knowledge Base.

It ORCHESTRATES the existing kie.phaseN components; it never duplicates the parser,
metadata engine, chunker, concept extractor, knowledge graph, or question intelligence.

See docs/knowledge-intelligence-engine/KNOWLEDGE_INTAKE_CENTER_CERTIFICATION.md.
"""
from __future__ import annotations

from kie.intake.models import (BatchStatus, Disposition, IntakeItemView,
                               IntakeSource, ItemStats, ReviewStatus, SourceKind)

__all__ = [
    "SourceKind", "Disposition", "ReviewStatus", "BatchStatus",
    "IntakeSource", "ItemStats", "IntakeItemView",
]
