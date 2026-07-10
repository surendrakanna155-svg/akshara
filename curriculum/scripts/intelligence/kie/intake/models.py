"""Knowledge Intake Center — value types (enums + dataclasses).

Deterministic + stdlib-only. Enums are plain string constants so they round-trip
through SQLite text columns and JSON without adapters.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import List, Optional


class SourceKind:
    """How a batch of files entered the Intake Center."""
    SINGLE = "single"
    MULTIPLE = "multiple"
    FOLDER = "folder"
    ZIP = "zip"
    DRAG_DROP = "drag_drop"
    WATCH = "watch"
    URL = "url"                # placeholder only — no online downloading
    ALL = (SINGLE, MULTIPLE, FOLDER, ZIP, DRAG_DROP, WATCH, URL)


class Disposition:
    """What Duplicate/Version detection decided about a file."""
    NEW = "new"                       # never seen before → full pipeline
    NEW_VERSION = "new_version"       # newer content for a known logical document
    EXACT_DUPLICATE = "exact_duplicate"  # identical sha256 already in the KB → skip
    QUARANTINED = "quarantined"       # corrupt/encrypted → never processed
    ALL = (NEW, NEW_VERSION, EXACT_DUPLICATE, QUARANTINED)
    STAGEABLE = (NEW, NEW_VERSION)    # only these run the extraction pipeline


class ReviewStatus:
    """Lifecycle of a reviewable knowledge item."""
    PENDING = "pending"
    NEEDS_REVIEW = "needs_review"
    APPROVED = "approved"
    REJECTED = "rejected"
    SKIPPED = "skipped"               # exact duplicate / quarantined — nothing to review
    ALL = (PENDING, NEEDS_REVIEW, APPROVED, REJECTED, SKIPPED)
    # Only APPROVED items may be promoted into the production Knowledge Base.
    OPEN = (PENDING, NEEDS_REVIEW)
    TERMINAL = (APPROVED, REJECTED, SKIPPED)


class BatchStatus:
    OPEN = "open"        # created, files not yet staged
    STAGED = "staged"    # verified + extracted into a staging DB, awaiting review
    CLOSED = "closed"    # every item reached a terminal review status
    ALL = (OPEN, STAGED, CLOSED)


@dataclass(frozen=True)
class IntakeSource:
    """A single local file the collector resolved for ingestion.

    `staged_path` is the managed content-addressed copy under resources/intake/;
    `origin_path` is where it came from (audit); `category` is a coarse top-folder
    hint (metadata Phase 3 refines subject/doc-type from content).
    """
    original_name: str
    origin_path: str
    category: str = "Intake"
    lineage_key: Optional[str] = None   # explicit override; else derived deterministically


@dataclass
class ItemStats:
    chunks: int = 0
    concepts: int = 0
    formulas: int = 0
    patterns: int = 0
    sections: int = 0

    def to_dict(self) -> dict:
        return {"chunks": self.chunks, "concepts": self.concepts,
                "formulas": self.formulas, "patterns": self.patterns,
                "sections": self.sections}


@dataclass
class IntakeItemView:
    """A row of the review queue, decorated for humans/CLI."""
    item_id: str
    batch_id: str
    doc_id: Optional[str]
    original_name: str
    category: Optional[str]
    disposition: str
    version_of: Optional[str]
    version_no: Optional[int]
    review_status: str
    verify_status: Optional[str]
    certify_status: Optional[str]
    flags: List[str] = field(default_factory=list)
    stats: dict = field(default_factory=dict)
    lineage_key: Optional[str] = None
    notes: Optional[str] = None
