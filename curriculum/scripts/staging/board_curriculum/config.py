"""Board curriculum OCR/extraction staging — CBSE + AP only (isolated from qcorpus/KIE foundation).

Reads verified textbook PDFs/ZIPs under resources/curriculum/{cbse,ap}/.
Writes parsed output to staging/board_curriculum/ (gitignored).
Does NOT touch kie.db, qcorpus_noncert, or the frozen QP engine.
"""
from __future__ import annotations

from pathlib import Path

WORKSPACE = Path(__file__).resolve().parents[3]
SOURCE_ROOTS = (
    WORKSPACE / "resources" / "curriculum" / "cbse",
    WORKSPACE / "resources" / "curriculum" / "ap",
)
STAGING_ROOT = WORKSPACE / "staging" / "board_curriculum"
STATE_DIR = STAGING_ROOT / "state"
DOC_STATE_DIR = STATE_DIR / "docs"
PROCESSING_STATE = STATE_DIR / "processing_state.json"
MANIFESTS_DIR = STAGING_ROOT / "manifests"
PARSED_DIR = STAGING_ROOT / "parsed"
REPORTS_DIR = STAGING_ROOT / "reports"

# AP bilingual markers in filename or medium metadata
BILINGUAL_MARKERS = ("Telugu-English", "Non_Languages", "Thb", "Sem-", "SEM-")
