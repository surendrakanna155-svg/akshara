"""Knowledge Layer — deterministic quality passes over the certified KIE store.

The KIE build phases (1–8) mine a noisy concept spine from the corpus; the frozen
QP engine (`kie.qpgen`) then defends itself at query time with `qpgen.sanitize`.
This package raises the quality of the KNOWLEDGE ITSELF, at rest, so enrichment
and the graph build on clean data instead of OCR noise:

  * cleanup  (Phase 1) — normalize titles, reject non-concepts, merge OCR-split
                         duplicates, map canonical chapters.

Every pass is deterministic, idempotent, and recovery-safe, and REUSES the frozen
engine's own helpers (`qpgen.sanitize`, `qpgen.chapters`) so a concept cleaned at
rest is treated identically to how the engine would treat it at runtime — the
certified engine's output never changes. No AI. No fabrication.
"""
