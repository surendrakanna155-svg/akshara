"""Governed evidence conversion (scaled) — the state-6 structuring step.

Turns already-owned, OCR'd, answer-keyed JEE/NEET evidence into VERIFIED, safely concept-bound structured
knowledge in the existing KVS substrate. Deterministic-first (subject gate + multi-source corroboration);
a bounded, cached model-examiner tier handles only the genuinely-ambiguous residual. Nothing is admitted
unless it survives independent verification and safe (subject-gated, context-aware) concept binding.
Wrong knowledge is worse than missing knowledge — gates are never weakened to raise yield.
"""
