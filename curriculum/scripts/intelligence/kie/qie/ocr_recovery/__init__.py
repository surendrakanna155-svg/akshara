"""OCR Recovery Lane — a DERIVED, honest-null re-OCR layer built ON TOP of the frozen kie.db.

Produces VERIFIED-IMPROVEMENT candidates for low-quality scanned/sparse documents; it NEVER mutates
the frozen substrate (kie.db is opened mode=ro and left byte-identical) and NEVER applies its results.
Re-integration into kie.db is a separate, gated, future step. Local-only derived store: ocr_recovery.db.
"""
