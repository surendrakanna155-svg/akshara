"""KIE configuration — paths, corpus selection, stage list. Outputs are local-only."""
from __future__ import annotations

from pathlib import Path

# curriculum/ workspace root  (this file lives at curriculum/scripts/intelligence/kie/config.py)
WORKSPACE = Path(__file__).resolve().parents[3]
KNOWLEDGE = WORKSPACE / "knowledge"
KIE_HOME = KNOWLEDGE / "kie"
DB_PATH = KIE_HOME / "kie.db"
PARSED_DIR = KIE_HOME / "parsed"
REPORTS_DIR = KIE_HOME / "reports"

# Phase-1 input manifest, produced by the reused repository_verifier.py.
VERIFICATION_MANIFEST = KNOWLEDGE / "repository_verification.json"

# Corpora (relative to WORKSPACE). Foundation (JEE/NEET/NCERT-STEM) is primary.
CORPORA = {
    "foundation": "resources/foundation",
    "board": "resources/curriculum",
}
DEFAULT_CORPUS = "foundation"

# Pipeline stages, in order.
STAGES = (
    "verify", "parse", "metadata", "chunk",
    "concept", "graph", "questions", "generate",
)

# Only these certify_status values are eligible for downstream (KB) processing (D-5).
CERTIFIED = "certified"


def ensure_dirs() -> None:
    for d in (KIE_HOME, PARSED_DIR, REPORTS_DIR):
        d.mkdir(parents=True, exist_ok=True)
