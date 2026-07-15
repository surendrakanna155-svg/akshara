"""Governed math-capable NOTATION RECOVERY — a reusable evidence-processing layer (owner decision A).

The problem (measured, `GOVERNED_CONVERSION_BATCH2_AND_NOTATION_FINDING.md`): every existing OCR/text
representation of our owned STEM sources has DESTROYED the math — NCERT's Coulomb's law text-extracts as the
token soup `0 1 2 2 1 4 q q F r ε = π (1.2)`. Arithmetic relation-induction over that damage is ~90% false
positives and was refused.

The fix, per the owner's locked hierarchy: go back to the ACTUAL SOURCE page image and recover the exact
notation — symbols, subscripts, superscripts, units, constants, symbol→given bindings — then certify the
relation DETERMINISTICALLY. A model may only *propose* the transcription (extraction assistant); it never
certifies. Certification is:

  1. SYMBOLIC   — the equation must parse (sympy) into a well-formed relation.
  2. DIMENSIONAL— declared symbol units must make LHS and RHS dimensionally identical (base-reduced, sympy SI).
                  This independently catches transcription/OCR damage: `F = q1q2/(4πε0 r)` (lost exponent) and
                  `F = 4πε0 q1q2/r²` (misplaced constant) are both REJECTED.
  3. DOMAIN     — the relation must belong to the subject/chapter it was recovered from (no cross-domain drift).
  4. ANSWER-KEY — where real answer-keyed numeric questions exist for the chapter, the givens must solve to the
                  stated answer under the recovered relation (corroboration, catches coefficient errors).
  5. ROUND-TRIP — solving for each symbol and re-substituting must reproduce the original.

This is a general layer over ANY owned PDF/zip source (addressed by the canonical EVIDENCE_REGISTRY), not a
one-off for a fixed formula list. Nothing guessed or arithmetic-induced is ever registered.
"""
