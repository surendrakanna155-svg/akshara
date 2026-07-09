"""Knowledge Intelligence Engine (KIE).

Deterministic, local-only pipeline that turns the acquired curriculum repository
(JEE/NEET foundation corpus first) into concept-level knowledge — chunks, canonical
concepts, a concept graph, and question intelligence — reusing the existing
verification/metadata substrate and mirroring the dormant Postgres edu_* schema.

Subordinate to Assessment-Intelligence-Platform v3.0 / AIMS (see
docs/curriculum-intelligence/KIE_ARCHITECTURE.md). Phases 1-7 are deterministic;
Phase 8 (AI generation) is wired but gated.
"""

__version__ = "0.1.0"
