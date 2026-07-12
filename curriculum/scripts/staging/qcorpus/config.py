"""Question-Corpus STAGING lane — configuration (paths, priorities, source-group map).

ISOLATION CONTRACT (read this before touching anything):
  This lane is RAW DOCUMENT -> LOSS-MINIMISING EXTRACTION -> STRUCTURED STAGING CORPUS.
  It NEVER writes to the active KIE DB, the Phase-0 corpora, kie/qpgen/, or the Certified
  Question Bank. It only READS source PDFs (never mutates them) and writes derived staging
  artifacts under STAGING_ROOT (which is gitignored). The extraction PRIMITIVE is reused
  from the proven kie.phase2_parse (PyMuPDF primary / pdfplumber tables / Tesseract
  detection-first OCR) — we import its pure `parse_pdf_file`, which does not open kie.db.

All outputs are LOCAL-ONLY, NON-CERTIFIED, NON-PRODUCTION.
"""
from __future__ import annotations

from pathlib import Path

# curriculum/ workspace root (this file: curriculum/scripts/staging/qcorpus/config.py).
WORKSPACE = Path(__file__).resolve().parents[3]

# Source corpus (READ-ONLY; gitignored; never mutated).
SOURCE_ROOT = WORKSPACE / "resources" / "foundation" / "Cursor_Downloads"

# Staging root — clearly NON-CERTIFIED / NON-PRODUCTION; gitignored via curriculum/.gitignore.
STAGING_ROOT = WORKSPACE / "staging" / "qcorpus_noncert"
STATE_DIR = STAGING_ROOT / "state"
DOC_STATE_DIR = STATE_DIR / "docs"            # one crash-safe record per document
PROCESSING_STATE = STATE_DIR / "processing_state.json"
MANIFESTS_DIR = STAGING_ROOT / "manifests"    # derived JSONL manifests (rebuilt from records)
RAW_DIR = STAGING_ROOT / "raw"                # RAW extraction per doc (never overwritten)
NORMALIZED_DIR = STAGING_ROOT / "normalized"  # normalized extraction per doc
ASSETS_DIR = STAGING_ROOT / "assets"          # extracted raster images per doc
REPORTS_DIR = STAGING_ROOT / "reports"
BENCHMARK_DIR = STAGING_ROOT / "benchmark"

# KIE artifacts that must remain BYTE-IDENTICAL across a run (isolation gate checks these).
KIE_DB = WORKSPACE / "knowledge" / "kie" / "kie.db"
PHASE0_PREREG = WORKSPACE.parent / "docs" / "question-intelligence-quality" / "PHASE0_PREREGISTRATION.md"

# ── source-group registry ────────────────────────────────────────────────────────
# exam_profile / default subject / default doc_type per known download group. Subject is
# refined per-file from path/filename/provenance; UNKNOWN where evidence is insufficient.
SOURCE_GROUPS = {
    "studentbro_neet_dpps":         {"exam": "NEET",           "doc_type": "DPP",                     "subject": None},
    "mathongo_jee_main_chapterwise":{"exam": "JEE_Main",       "doc_type": "CHAPTERWISE_QUESTION_SET","subject": None},
    "mathongo_jee_advanced_dpps":   {"exam": "JEE_Advanced",   "doc_type": "DPP",                     "subject": None},
    "physicsaholics_dpps":          {"exam": "NEET_JEE",       "doc_type": "DPP",                     "subject": "Physics"},
    "jeeadv_ac_in_archive":         {"exam": "JEE_Advanced",   "doc_type": "PREVIOUS_PAPER",          "subject": None},
    "allen_jee_main_mock":          {"exam": "JEE_Main",       "doc_type": "MOCK_PAPER",              "subject": None},
    "jeebooks_dpp":                 {"exam": "JEE_Main",       "doc_type": "DPP",                     "subject": None},
}

# ── processing priority (owner-specified) ─────────────────────────────────────────
# Each entry: (label, matcher(rel_path_parts) -> bool). Priority 1 = Biology first
# (question-intelligence audit flagged Biology / non-numeric assessment as the evidence gap).
def _sb(subject):
    def m(parts):
        return parts and parts[0] == "studentbro_neet_dpps" and subject in parts
    return m

PRIORITIES = [
    ("P1_studentbro_biology",      _sb("Biology")),
    ("P2_studentbro_chemistry",    _sb("Chemistry")),
    ("P3_studentbro_physics",      _sb("Physics")),
    ("P4_mathongo_jee_main",       lambda p: bool(p) and p[0] == "mathongo_jee_main_chapterwise"),
    ("P5_studentbro_mathematics",  _sb("Mathematics")),
    ("P6_mathongo_jee_advanced",   lambda p: bool(p) and p[0] == "mathongo_jee_advanced_dpps"),
    ("P7_jee_advanced_archive",    lambda p: bool(p) and p[0] == "jeeadv_ac_in_archive"),
    ("P8_physicsaholics",          lambda p: bool(p) and p[0] == "physicsaholics_dpps"),
    ("P9_allen_and_jeebooks",      lambda p: bool(p) and p[0] in ("allen_jee_main_mock", "jeebooks_dpp")),
]
PRIORITY_UNRANKED = "P99_unranked"


def priority_for(rel_parts) -> str:
    """Return the priority label for a source rel-path (tuple of path parts)."""
    for label, matcher in PRIORITIES:
        try:
            if matcher(list(rel_parts)):
                return label
        except Exception:
            continue
    return PRIORITY_UNRANKED


def ensure_dirs() -> None:
    for d in (STAGING_ROOT, STATE_DIR, DOC_STATE_DIR, MANIFESTS_DIR, RAW_DIR,
              NORMALIZED_DIR, ASSETS_DIR, REPORTS_DIR, BENCHMARK_DIR):
        d.mkdir(parents=True, exist_ok=True)
