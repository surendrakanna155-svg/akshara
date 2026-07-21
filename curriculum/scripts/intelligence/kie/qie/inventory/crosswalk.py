"""Legacy / topic / "Subject :: Chapter" -> KC_ concept-id crosswalk (R4-1 / R5-2 edge-table pattern).

The three live ontologies (audit C14): pilot_verified_item LEGACY codes (REL_*/CALC_*/JMATH_*/BIO_*/…),
governed_fact / governed_relation `"Subject :: Chapter"` strings, and the frozen index's KC_ ids. A unified
inventory cannot join them without a crosswalk. This module builds a DERIVED, versioned map on TOP of the
frozen index — it opens `knowledge_index.db` mode=ro and NEVER writes it (freeze discipline, R1-5/RI-10).

Resolution is name+subject match against certified `ki_concept` rows (canonical_name + aliases). Anything that
does not match is kept as an HONEST NULL — never guessed, never back-filled. The resolution RATE is reported,
not inflated: most pilot legacy codes carry no concept name and legitimately do not resolve.
"""
from __future__ import annotations

import re
import sqlite3
from dataclasses import dataclass
from typing import Dict, List, Optional, Tuple

from kie import config

INDEX_DB_PATH = config.KIE_HOME / "knowledge_index.db"

_NON_ALNUM = re.compile(r"[^a-z0-9]+")
_STOP = {"and", "of", "the", "a", "an", "their", "its", "to", "in", "on", "for", "with"}


def _norm(name: str) -> str:
    s = _NON_ALNUM.sub(" ", (name or "").lower()).strip()
    return " ".join(w for w in s.split() if w not in _STOP)


def open_index_ro(path=INDEX_DB_PATH) -> sqlite3.Connection:
    """Open the FROZEN v1.5 index read-only (mode=ro). A write attempt raises — freeze is not our hatch."""
    conn = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
    conn.row_factory = sqlite3.Row
    return conn


@dataclass
class Crosswalk:
    version: str
    by_name: Dict[Tuple[str, str], str]        # (subject, norm(name)) -> concept_id  (certified only)
    _resolved: int = 0
    _attempted: int = 0

    def resolve(self, subject: Optional[str], *candidates: str) -> Optional[str]:
        """Resolve the FIRST candidate string that name-matches a certified concept in `subject`.
        A "Subject :: Chapter" string is also tried on its chapter tail. Returns a KC_ id or None (honest-null).
        """
        self._attempted += 1
        subj = subject or ""
        tries: List[str] = []
        for cand in candidates:
            if not cand:
                continue
            tries.append(cand)
            if "::" in cand:                      # "Physics :: Work Energy And Power" -> chapter tail
                tries.append(cand.split("::", 1)[1])
            # legacy code tail: REL_OHMS_LAW -> "ohms law"
            if "_" in cand and cand.split("_", 1)[0] in ("REL", "CALC", "JMATH", "BIO", "COMPOSE", "AUTO", "MAT"):
                tries.append(cand.split("_", 1)[1].replace("_", " "))
        for t in tries:
            key = (subj, _norm(t))
            if key[1] and key in self.by_name:
                self._resolved += 1
                return self.by_name[key]
            # subject-agnostic fallback (a few legacy codes carry no subject)
            for (s, n), cid in self.by_name.items():
                if n == key[1] and n:
                    self._resolved += 1
                    return cid
        return None

    @property
    def resolution_rate(self) -> float:
        return (self._resolved / self._attempted) if self._attempted else 0.0

    def stats(self) -> dict:
        return {"attempted": self._attempted, "resolved": self._resolved,
                "rate": round(self.resolution_rate, 4), "index_concepts": len(self.by_name)}


def build(path=INDEX_DB_PATH, version: str = "v1.5") -> Crosswalk:
    """Build the crosswalk from the certified ki_concept rows of the frozen index (read-only)."""
    conn = open_index_ro(path)
    try:
        by_name: Dict[Tuple[str, str], str] = {}
        for r in conn.execute("SELECT concept_id, subject, canonical_name, aliases FROM ki_concept "
                              "WHERE status='certified'"):
            subj = r["subject"] or ""
            names = [r["canonical_name"]]
            import json
            try:
                names += json.loads(r["aliases"] or "[]")
            except (json.JSONDecodeError, TypeError):
                pass
            for nm in names:
                key = (subj, _norm(nm))
                if key[1]:
                    by_name.setdefault(key, r["concept_id"])
        # record the frozen fingerprint for provenance/reproducibility
        fp = conn.execute("SELECT value FROM ki_meta WHERE key='certified_knowledge_fingerprint_v1.5'").fetchone()
        version = f"{version}:{fp[0][:12]}" if fp else version
        return Crosswalk(version=version, by_name=by_name)
    finally:
        conn.close()
