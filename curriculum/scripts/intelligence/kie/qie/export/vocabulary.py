"""Program D · M0.2 — the KC_ ↔ UUID concept vocabulary (offline, deterministic).

Bridges the QIE certified concept spine (KC_<sha14>, from the frozen knowledge_index `ki_concept`) to the
ERP concept namespace (UUID). This is the SINGLE source of truth the exporter consults: a certified item
whose KC_ id is not in the vocabulary is **not exported** (honest-null — never a guessed UUID; R5-3 D2,
readiness red-team #5).

Minting, not guessing. The ERP `canonical_concepts` table is dormant/empty, so there is no pre-existing
UUID to match against. A KC_ id's ERP handle is therefore a DETERMINISTIC `uuid5(namespace, kc_id)` — a
pure, reproducible function of the KC_ id (same kc_id → same UUID in every environment). That is a stable
*identity*, not a guess at some other concept. The honest-null discipline still bites: only KC_ ids present
in the certified concept SOURCE (the frozen index certified `ki_concept`, or — for fixtures — the declared
fixture concepts) are admitted to the vocabulary; anything else resolves to None.
"""
from __future__ import annotations

import sqlite3
import uuid
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Iterable, List, Optional

# A fixed Program-D namespace UUID for concept minting. Derived once, deterministically, from a stable URN
# — uuid5(NAMESPACE_URL, "urn:akshara:program-d:concept-vocabulary:v1") — then FROZEN here as a literal so
# the minting is stable forever, independent of the derivation code above it.
PROGRAM_D_CONCEPT_NAMESPACE = uuid.UUID("2aca17e6-3720-5c54-8eee-7b9726328692")


def mint_uuid(kc_id: str) -> str:
    """The KC_ id's stable ERP-namespace UUID handle. Pure + deterministic; never a guess at an existing row."""
    kc = (kc_id or "").strip()
    if not kc:
        raise ValueError("kc_id must be non-empty")
    return str(uuid.uuid5(PROGRAM_D_CONCEPT_NAMESPACE, kc))


@dataclass(frozen=True)
class Concept:
    """A certified concept from the source spine — the unit the vocabulary is built from."""
    kc_id: str
    subject: Optional[str] = None
    canonical_name: Optional[str] = None


class Vocabulary:
    """An immutable KC_ → row map. Built from a certified concept SOURCE; `resolve` is honest-null against it."""

    def __init__(self, rows: List[Dict]):
        self._by_kc: Dict[str, Dict] = {}
        for r in rows:
            self._by_kc.setdefault(r["kc_id"], r)   # first wins; dedup by kc_id

    @classmethod
    def from_concepts(cls, concepts: Iterable[Concept], frozen_version: str) -> "Vocabulary":
        rows: List[Dict] = []
        seen = set()
        for c in concepts:
            kc = (c.kc_id or "").strip()
            if not kc or kc in seen:
                continue
            seen.add(kc)
            rows.append({
                "kc_id": kc,
                "concept_uuid": mint_uuid(kc),
                "subject": c.subject,
                "canonical_name": c.canonical_name,
                "frozen_version": frozen_version,
            })
        return cls(rows)

    def resolve(self, kc_id: str) -> Optional[str]:
        """The concept_uuid for kc_id, or None (honest-null) when kc_id is absent from the certified source."""
        r = self._by_kc.get((kc_id or "").strip())
        return r["concept_uuid"] if r else None

    def rows(self) -> List[Dict]:
        """The vocabulary rows (for seeding edu_concept_vocabulary), deterministic order by kc_id."""
        return [dict(self._by_kc[k]) for k in sorted(self._by_kc)]

    def __len__(self) -> int:
        return len(self._by_kc)

    def __contains__(self, kc_id: str) -> bool:
        return (kc_id or "").strip() in self._by_kc


def load_certified_concepts(index_path=None) -> List[Concept]:
    """Read certified concepts from the FROZEN knowledge index (`ki_concept WHERE status='certified'`).

    Read-only. Raises FileNotFoundError when the (gitignored, local-only) frozen index is absent, so a
    caller/test self-skips honestly rather than fabricating a vocabulary. This is the PRODUCTION seed
    source; fixtures build a Vocabulary directly from their declared concepts instead.
    """
    from kie import config
    path = Path(index_path) if index_path else (config.KIE_HOME / "knowledge_index.db")
    if not path.exists():
        raise FileNotFoundError(f"frozen knowledge_index.db not present at {path} (gitignored, local-only)")
    conn = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
    conn.row_factory = sqlite3.Row
    try:
        return [Concept(kc_id=r["concept_id"], subject=r["subject"], canonical_name=r["canonical_name"])
                for r in conn.execute(
                    "SELECT concept_id, subject, canonical_name FROM ki_concept WHERE status='certified'")]
    finally:
        conn.close()
