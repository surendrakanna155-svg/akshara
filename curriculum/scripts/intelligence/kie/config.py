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

# Knowledge Intake Center — incremental ingestion of NEW/UPDATED resources only.
# Staging DBs (one per import batch) and copied raw inputs are LOCAL-ONLY (gitignored).
INTAKE_HOME = KIE_HOME / "intake"
STAGING_DIR = INTAKE_HOME / "staging"
INTAKE_REPORTS_DIR = INTAKE_HOME / "reports"
# Managed resource root for imported files (content-addressed under <doc_id>/).
INTAKE_RESOURCES = WORKSPACE / "resources" / "intake"

# Phase-1 input manifest, produced by the reused repository_verifier.py.
VERIFICATION_MANIFEST = KNOWLEDGE / "repository_verification.json"

# Corpora (relative to WORKSPACE). Foundation (JEE/NEET/NCERT-STEM) is primary.
# "intake" is where the Intake Center parks NEW files it ingests incrementally.
CORPORA = {
    "foundation": "resources/foundation",
    "board": "resources/curriculum",
    "intake": "resources/intake",
}
DEFAULT_CORPUS = "foundation"

# Pipeline stages, in order.
STAGES = (
    "verify", "parse", "metadata", "chunk",
    "concept", "graph", "questions", "generate",
)

# Only these certify_status values are eligible for downstream (KB) processing (D-5).
CERTIFIED = "certified"


def assert_under_kie_home(path) -> Path:
    """Assert a resolved store path lives under KIE_HOME (remediation R0-4).

    Guards against wrong-cwd sqlite opens that silently create stray zero-byte
    DBs (e.g. the repo-root / curriculum/ `qie.db` artifacts the audit found).
    Returns the resolved Path so callers can use it directly. Store openers
    should route their path through this before connecting.
    """
    p = Path(path).resolve()
    home = KIE_HOME.resolve()
    if home not in p.parents and p != home:
        raise ValueError(
            f"refusing to open store outside KIE_HOME: {p} (KIE_HOME={home})"
        )
    return p


def ensure_dirs() -> None:
    for d in (KIE_HOME, PARSED_DIR, REPORTS_DIR):
        d.mkdir(parents=True, exist_ok=True)


def ensure_intake_dirs() -> None:
    """Create the Intake Center's local working directories (idempotent)."""
    for d in (INTAKE_HOME, STAGING_DIR, INTAKE_REPORTS_DIR, INTAKE_RESOURCES):
        d.mkdir(parents=True, exist_ok=True)
