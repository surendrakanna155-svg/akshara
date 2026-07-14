"""Canonical evidence lifecycle model + store taxonomy (owner governance correction 2026-07-14).

Fixes the recurring confusion class the owner named: a file being DOWNLOADED must never again be confused
with usable knowledge; a file being OCR'd must never be confused with verified structured knowledge; an
extracted question must never be confused with a QIE-available knowledge record. Each evidence store is placed
at exactly one lifecycle STATE (the furthest state it has actually reached), so the state itself answers
"is this raw / ocr'd / extracted / verified / QIE-usable?" without another filesystem hunt.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from enum import Enum
from typing import List, Optional, Tuple


class State(str, Enum):
    """The canonical processing lifecycle. Order is meaningful (monotonic progression)."""
    RAW_SOURCE = "1_raw_source"                       # acquired bytes (PDF/ZIP/image); nothing derived
    OCR_NORMALIZED = "2_ocr_normalized"               # text/page normalization done (may include tables)
    EXTRACTED_EVIDENCE = "3_extracted_evidence"       # questions/options/answer-keys/equations extracted
    RECOVERED_NOTATION = "4_recovered_notation"       # damaged math/notation re-recovered + structured
    VERIFIED_KNOWLEDGE = "5_verified_knowledge"       # structured facts/relations, independently verified
    CONCEPT_BOUND = "6_concept_bound"                 # verified knowledge safely bound to a certified concept
    QIE_AVAILABLE = "7_qie_available"                 # exposed to the unified engine -> qpgen product path
    QUARANTINE = "q_quarantine"                       # rejected / out-of-scope / superseded (not usable)

    @property
    def rank(self) -> int:
        order = [State.RAW_SOURCE, State.OCR_NORMALIZED, State.EXTRACTED_EVIDENCE, State.RECOVERED_NOTATION,
                 State.VERIFIED_KNOWLEDGE, State.CONCEPT_BOUND, State.QIE_AVAILABLE]
        return order.index(self) if self in order else -1


class Role(str, Enum):
    RAW = "raw_source"                # bulk raw acquisition (local-only)
    STAGING = "staging_derived"       # OCR/extraction lane outputs + manifests (local-only)
    KNOWLEDGE_DB = "knowledge_db"     # the governed knowledge substrate (kie.db / qie.db, local-only)
    GOVERNANCE = "governance_index"   # compact tracked registries/manifests/indexes (git-tracked)
    QUARANTINE = "quarantine"         # out-of-scope / duplicate / failed (retained for provenance)


class Scope(str, Enum):
    IN_SCOPE = "in_scope"             # JEE Main/Adv, NEET, NCERT/CBSE 6-12 STEM (current mandate)
    HELD = "held"                     # Classes 1-5, AP/TS/ICSE/other boards, non-STEM (deferred, not deleted)
    OUT_OF_SCOPE = "out_of_scope"     # never in the QIE mandate
    MIXED = "mixed"                   # store spans in-scope + held (must be split logically, not physically)
    N_A = "n_a"                       # governance/index stores (scope-neutral)


class Git(str, Enum):
    TRACKED = "git_tracked"
    IGNORED_LOCAL = "gitignored_local_only"


@dataclass
class Store:
    """One canonical evidence store. Declarative identity + intent; live metrics are probed at scan time."""
    canonical_id: str                 # stable logical id (survives physical relocation)
    physical_path: str                # current path, relative to curriculum/ workspace root
    role: Role
    state: State                      # furthest lifecycle state this store has reached
    scope: Scope
    purpose: str
    source_type: str                  # e.g. "cursor_download", "official_ncert", "third_party_dpp", "derived"
    media: str                        # "pdf" | "image" | "ocr_text" | "extracted_json" | "sqlite" | "manifest"
    provenance_level: str             # "official" | "trusted_third_party" | "mixed" | "derived"
    git: Git
    detail_manifest: Optional[str] = None   # pointer to the per-file/per-doc manifest that details this store
    depends_on_code: Tuple[str, ...] = ()   # code paths that hard-reference this physical path (move = breaks)
    duplicate_of: Optional[str] = None      # canonical_id this duplicates/supersedes
    subjects: Tuple[str, ...] = ()
    exams_boards: Tuple[str, ...] = ()
    classes: Tuple[str, ...] = ()
    languages: Tuple[str, ...] = ("en",)
    notes: str = ""


# ── The canonical store universe (owner correction: Cursor downloads + archive + NCERT/CBSE + JEE + NEET
#    all discoverable through ONE inventory). Declarative; the scanner attaches live size/count/db metrics.
STORES: List[Store] = [
    # ---- RAW SOURCE (local-only) --------------------------------------------------------------------------
    Store("RAW_FOUNDATION", "resources/foundation", Role.RAW, State.RAW_SOURCE, Scope.IN_SCOPE,
          "Organized raw JEE/NEET/NCERT-STEM acquisition (the frozen foundation corpus).",
          "mixed_official_third_party", "pdf", "mixed", Git.IGNORED_LOCAL,
          detail_manifest="knowledge/repository_verification.json",
          depends_on_code=("scripts/intelligence/kie/config.py",
                           "scripts/intelligence/repository_verifier.py"),
          subjects=("Physics", "Chemistry", "Mathematics", "Biology"),
          exams_boards=("JEE_MAIN", "JEE_ADVANCED", "NEET", "AIIMS", "AIPMT", "NCERT"),
          classes=("11", "12"),
          notes="1199 PDFs incl. NCERT 11-12 STEM textbooks (canonical formula/law source)."),
    Store("RAW_CURSOR_DOWNLOADS", "resources/foundation/Cursor_Downloads", Role.RAW, State.RAW_SOURCE,
          Scope.IN_SCOPE, "Cursor-agent-acquired JEE/NEET PDFs (the previously 'invisible' download universe).",
          "cursor_download", "pdf", "trusted_third_party", Git.IGNORED_LOCAL,
          depends_on_code=("scripts/staging/qcorpus/config.py",
                           "scripts/acquisition/sequential_board_fetch.py"),
          subjects=("Physics", "Chemistry", "Mathematics", "Biology"),
          exams_boards=("JEE_MAIN", "JEE_ADVANCED", "NEET"),
          notes="Feeds the qcorpus OCR/extraction lane (STG_QCORPUS)."),
    Store("RAW_CURRICULUM_CBSE", "resources/curriculum/cbse", Role.RAW, State.RAW_SOURCE, Scope.IN_SCOPE,
          "NCERT/CBSE board textbooks (Classes 6-12) — in-scope Math/Science subset.",
          "official_ncert_cbse", "pdf", "official", Git.IGNORED_LOCAL,
          detail_manifest="PROVENANCE_MANIFEST.json",
          subjects=("Mathematics", "Science", "Physics", "Chemistry", "Biology"),
          exams_boards=("CBSE", "NCERT"), classes=("6", "7", "8", "9", "10", "11", "12"),
          notes="MIXED at the folder level: 6-12 STEM is IN-SCOPE; non-STEM/1-5 HELD (split logically)."),
    Store("RAW_CURRICULUM_AP", "resources/curriculum/ap", Role.RAW, State.RAW_SOURCE, Scope.HELD,
          "Andhra Pradesh state-board curriculum — HELD (state-board conversion deferred).",
          "official_state_board", "pdf", "official", Git.IGNORED_LOCAL,
          detail_manifest="PROVENANCE_MANIFEST.json", exams_boards=("AP_SCERT",),
          notes="Held per mandate; retained, not deleted."),
    Store("RAW_CURRICULUM_TS", "resources/curriculum/telangana", Role.RAW, State.RAW_SOURCE, Scope.HELD,
          "Telangana state-board curriculum — HELD.", "official_state_board", "pdf", "official",
          Git.IGNORED_LOCAL, exams_boards=("TS_SCERT",), notes="Held per mandate."),
    Store("RAW_CURRICULUM_ICSE", "resources/curriculum/icse", Role.RAW, State.RAW_SOURCE, Scope.HELD,
          "ICSE/CISCE curriculum — HELD.", "official_board", "pdf", "official", Git.IGNORED_LOCAL,
          exams_boards=("ICSE", "CISCE"), notes="Held per mandate."),
    Store("RAW_INTAKE", "resources/intake", Role.RAW, State.RAW_SOURCE, Scope.MIXED,
          "Knowledge Intake Center managed resources (content-addressed new/updated imports).",
          "intake_managed", "pdf", "mixed", Git.IGNORED_LOCAL,
          depends_on_code=("scripts/intelligence/kie/config.py",),
          notes="Sole sanctioned new-knowledge entry point (intake baseline)."),
    # ---- QUARANTINE / OUT-OF-SCOPE / DUPLICATES (retained for provenance) ---------------------------------
    Store("ARCH_BOARD_OUT_OF_SCOPE", "resources/archive/board_out_of_scope", Role.QUARANTINE,
          State.QUARANTINE, Scope.OUT_OF_SCOPE, "Archived board material outside JEE/NEET scope.",
          "archive", "pdf", "mixed", Git.IGNORED_LOCAL, notes="27 GB; correctly out-of-scope, retained."),
    Store("ARCH_NCERT_NON_STEM", "resources/archive/NCERT_non_stem", Role.QUARANTINE, State.QUARANTINE,
          Scope.HELD, "NCERT non-STEM subjects — held (not in current STEM mandate).", "archive", "pdf",
          "official", Git.IGNORED_LOCAL, notes="Retained; re-scopable if mandate widens."),
    Store("ARCH_DUPLICATES", "resources/archive/duplicates", Role.QUARANTINE, State.QUARANTINE, Scope.N_A,
          "Archived duplicate copies.", "archive_dedup", "pdf", "derived", Git.IGNORED_LOCAL,
          duplicate_of="RAW_FOUNDATION"),
    Store("DL_DUPLICATES", "downloads/duplicates", Role.QUARANTINE, State.QUARANTINE, Scope.N_A,
          "Deduplicated download copies (safe-delete candidates once dedup map is confirmed).",
          "download_dedup", "pdf", "derived", Git.IGNORED_LOCAL,
          detail_manifest="indexes/duplicate_map.json", duplicate_of="RAW_FOUNDATION"),
    Store("DL_FAILED", "downloads/failed", Role.QUARANTINE, State.QUARANTINE, Scope.N_A,
          "Failed/partial downloads (retained for retry provenance).", "download_failed", "pdf", "derived",
          Git.IGNORED_LOCAL),
    # ---- STAGING / DERIVED (OCR + extraction lanes, local-only) -------------------------------------------
    Store("STG_QCORPUS", "staging/qcorpus_noncert", Role.STAGING, State.EXTRACTED_EVIDENCE, Scope.IN_SCOPE,
          "The Cursor OCR/extraction lane: normalized pages + extracted questions/answer-keys/equations/"
          "visual assets for JEE/NEET DPPs. NOT merged into kie.db (isolated by design).",
          "derived_ocr_extraction", "extracted_json", "trusted_third_party", Git.IGNORED_LOCAL,
          detail_manifest="staging/qcorpus_noncert/manifests/_manifest_counts.json",
          depends_on_code=("scripts/intelligence/kie/qie/qcorpus_adapter.py",
                           "scripts/staging/qcorpus/config.py"),
          subjects=("Physics", "Chemistry", "Mathematics", "Biology"),
          exams_boards=("NEET", "JEE_MAIN", "JEE_ADVANCED"),
          notes="THE conversion prize: 22,759 questions / 10,354 answer-keys, extracted but NOT structured."),
    Store("STG_BOARD_CURRICULUM", "staging/board_curriculum", Role.STAGING, State.OCR_NORMALIZED, Scope.MIXED,
          "Board-curriculum staging (OCR/normalization of CBSE/AP curriculum).", "derived_ocr",
          "ocr_text", "official", Git.IGNORED_LOCAL,
          depends_on_code=("scripts/staging/board_curriculum/config.py",)),
    # ---- KNOWLEDGE SUBSTRATE (governed DBs, local-only) ---------------------------------------------------
    Store("KDB_KIE", "knowledge/kie/kie.db", Role.KNOWLEDGE_DB, State.EXTRACTED_EVIDENCE, Scope.IN_SCOPE,
          "Certified corpus DB: chunks + concepts + question_patterns + formulas (names). Notation NOT "
          "recovered (formulas.expression=name, symbols NULL).",
          "derived_certified", "sqlite", "derived", Git.IGNORED_LOCAL,
          depends_on_code=("scripts/intelligence/kie/config.py", "scripts/intelligence/kie/store.py"),
          notes="Concept/pattern layer present; quantitative relations notation-damaged."),
    Store("KDB_QIE", "knowledge/kie/qie.db", Role.KNOWLEDGE_DB, State.QIE_AVAILABLE, Scope.IN_SCOPE,
          "QIE derived knowledge substrate: KVS (assertion/taxonomy/sequence/structure_function/comparison), "
          "question_dna, item_model, tier2_verdict, distractor_dna, pilot_verified_item.",
          "derived_knowledge", "sqlite", "derived", Git.IGNORED_LOCAL,
          depends_on_code=("scripts/intelligence/kie/qie/store.py",),
          notes="The canonical verified-knowledge store. Governed-conversion target for structured facts."),
    Store("KDB_INTAKE_STAGING", "knowledge/kie/intake/staging", Role.KNOWLEDGE_DB, State.OCR_NORMALIZED,
          Scope.MIXED, "Per-batch intake staging DBs (incremental ingestion).", "derived_intake", "sqlite",
          "derived", Git.IGNORED_LOCAL, depends_on_code=("scripts/intelligence/kie/config.py",)),
    Store("KDB_PARSED", "knowledge/kie/parsed", Role.STAGING, State.OCR_NORMALIZED, Scope.IN_SCOPE,
          "Per-document parsed outputs (phase2/phase4 intermediate).", "derived_parse", "ocr_text",
          "derived", Git.IGNORED_LOCAL),
    # ---- GOVERNANCE / INDEX LAYER (git-tracked, compact) -------------------------------------------------
    Store("GOV_PROVENANCE_MANIFEST", "PROVENANCE_MANIFEST.json", Role.GOVERNANCE, State.RAW_SOURCE,
          Scope.MIXED, "Per-file provenance manifest for the curriculum/board acquisition universe (839 "
          "resources): id/board/class/subject/doctype/sha256/local_path/license.",
          "governance", "manifest", "official", Git.TRACKED,
          notes="Detail layer for RAW_CURRICULUM_*; does NOT cover foundation/qcorpus/DBs (this registry does)."),
    Store("GOV_INDEXES", "indexes", Role.GOVERNANCE, State.RAW_SOURCE, Scope.N_A,
          "Acquisition indexes: master_index / checksum_index / download_index / duplicate_map.",
          "governance", "manifest", "derived", Git.TRACKED),
    Store("GOV_REPORTS", "reports", Role.GOVERNANCE, State.RAW_SOURCE, Scope.N_A,
          "Curriculum coverage/audit reports + canonical curriculum matrix.", "governance", "manifest",
          "derived", Git.TRACKED),
    Store("GOV_DISCOVERY", "discovery", Role.GOVERNANCE, State.RAW_SOURCE, Scope.N_A,
          "Official-universe discovery + trusted-source catalogues.", "governance", "manifest", "official",
          Git.TRACKED),
]


def store_by_id(cid: str) -> Store:
    for s in STORES:
        if s.canonical_id == cid:
            return s
    raise KeyError(cid)
