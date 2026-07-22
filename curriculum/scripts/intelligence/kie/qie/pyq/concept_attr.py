"""Program B · B2 (part 2) — subject-scoped concept resolution (the D3 mislabel fix).

The old mined patterns carry concept codes whose SUBJECT PREFIX is wrong (`BIO_MOTION`, `BIO_POWER`,
`CHE_NUMBERS` — physics/maths topics stamped Biology/Chemistry). OD-4's rule makes the fix structural: attribute
the SUBJECT from the source document FIRST (B2 subject_seg), then resolve the concept NAME **within that subject
only**. The broken prefix is never consulted, so a "Motion" question in a Physics section resolves to a Physics
concept (or honest-null) and can NEVER land on a Biology concept.

Resolution is STRICT and honest-null: a unique in-subject name match resolves; 0 matches or a within-subject
ambiguity → None (never a guess, never a cross-subject fallback — a Physics question must not borrow a Biology
concept). Reuses the certified frozen-index crosswalk (canonical_name + aliases), opened mode=ro.
"""
from __future__ import annotations

import json
from typing import Dict, Optional, Set, Tuple

from kie.qie.inventory import crosswalk as XW
from kie.qie.pyq import source_class as SC

# legacy concept-code prefix → the subject it CLAIMS (used only to MEASURE the mislabel, never to attribute)
_PREFIX_SUBJECT = {"BIO": "Biology", "PHY": "Physics", "CHE": "Chemistry", "CHEM": "Chemistry",
                   "MAT": "Mathematics", "MATH": "Mathematics"}

SubjectIndex = Tuple[Dict[Tuple[str, str], Set[str]], str]   # ((subject,norm)->{kc}, version)


def build_subject_index(index_path=XW.INDEX_DB_PATH) -> SubjectIndex:
    """(multimap (subject, norm(name)) -> {concept_id}, version). A MULTIMAP so within-subject ambiguity is
    surfaced honestly (never first-wins). Certified concepts only. READ-ONLY over the frozen index."""
    idx = XW.open_index_ro(index_path)
    try:
        mm: Dict[Tuple[str, str], Set[str]] = {}
        for r in idx.execute("SELECT concept_id, subject, canonical_name, aliases FROM ki_concept "
                             "WHERE status='certified'"):
            subj = r["subject"] or ""
            names = [r["canonical_name"]]
            try:
                names += json.loads(r["aliases"] or "[]")
            except (json.JSONDecodeError, TypeError):
                pass
            for nm in names:
                n = XW._norm(nm)
                if n:
                    mm.setdefault((subj, n), set()).add(r["concept_id"])
        fp = idx.execute("SELECT value FROM ki_meta WHERE key='certified_knowledge_fingerprint_v1.5'").fetchone()
        version = f"v1.5:{fp[0][:12]}" if fp else "v1.5"
        return mm, version
    finally:
        idx.close()


def resolve(subject_index: SubjectIndex, subject: Optional[str], *candidates: str) -> Tuple[Optional[str], str]:
    """(concept_id, method). STRICT subject-scoped resolution of the FIRST candidate that uniquely matches a
    certified concept IN `subject`. honest-null (None) on: no subject (OD-4), unresolved, or within-subject
    ambiguity. NEVER cross-subject, NEVER the legacy prefix."""
    mm, _ = subject_index
    if not subject:
        return None, "no_subject"                       # OD-4: subject must come first; without it, don't guess
    for cand in candidates:
        if not cand:
            continue
        tries = [cand]
        if "::" in cand:
            tries.append(cand.split("::", 1)[1])         # "Physics :: Work Energy" -> chapter tail
        for t in tries:
            n = XW._norm(t)
            if not n:
                continue
            hits = mm.get((subject, n), set())
            if len(hits) == 1:
                return next(iter(hits)), "subject_scoped"
            if len(hits) > 1:
                return None, "ambiguous"                 # within-subject ambiguity → honest-null (never guessed)
    return None, "unresolved"


def _index_name_subjects(index_path=XW.INDEX_DB_PATH) -> Dict[str, Set[str]]:
    """norm(name) -> {subjects} across the certified frozen index — an INDEPENDENT subject source (NOT the
    co-mislabelled kie.db `concepts.subject_domain`)."""
    idx = XW.open_index_ro(index_path)
    try:
        by_norm: Dict[str, Set[str]] = {}
        for r in idx.execute("SELECT subject, canonical_name, aliases FROM ki_concept WHERE status='certified'"):
            subj = r["subject"] or ""
            names = [r["canonical_name"]]
            try:
                names += json.loads(r["aliases"] or "[]")
            except (json.JSONDecodeError, TypeError):
                pass
            for nm in names:
                n = XW._norm(nm)
                if n and subj:
                    by_norm.setdefault(n, set()).add(subj)
        return by_norm
    finally:
        idx.close()


def mislabel_report(index_path=XW.INDEX_DB_PATH) -> Dict[str, object]:
    """Live EVIDENCE for defect D3, measured INDEPENDENTLY: take each old mined concept code, drop its subject
    PREFIX, and resolve the remaining NAME against the certified frozen index (a source independent of the
    prefix). Where the name resolves UNIQUELY to a subject that differs from the prefix's claim, the prefix is
    demonstrably wrong. Read-only over kie.db + the frozen index. This is why B2 attributes subject from the
    document and resolves the concept within that subject — never via the prefix."""
    by_norm = _index_name_subjects(index_path)
    kie = SC._open_kie_ro()
    try:
        codes = [r[0] for r in kie.execute(
            "SELECT DISTINCT concept_code FROM question_patterns "
            "WHERE concept_code IS NOT NULL AND concept_code<>''").fetchall()]
    finally:
        kie.close()
    _CANON = {"Physics", "Chemistry", "Mathematics", "Biology"}
    checkable = disagree = unresolved = clean_swap = 0
    examples = []
    for code in codes:
        head, _, tail = code.partition("_")
        claimed = _PREFIX_SUBJECT.get(head.upper())
        if claimed is None or not tail:
            continue
        subs = by_norm.get(XW._norm(tail.replace("_", " ")), set())
        if len(subs) != 1:                                # name absent or cross-subject in the index → can't judge
            unresolved += 1
            continue
        checkable += 1
        true_subj = next(iter(subs))
        if true_subj != claimed:
            disagree += 1
            # a CLEAN cross-subject swap = both sides are canonical subjects (e.g. physics-topic stamped Biology),
            # distinct from a granularity mismatch where the index uses the coarse NCERT subject "Science".
            if true_subj in _CANON:
                clean_swap += 1
                if len(examples) < 12:
                    examples.append({"concept_code": code, "prefix_claims": claimed, "index_subject": true_subj})
    return {"prefixed_codes_checkable": checkable, "prefix_disagrees_with_index": disagree,
            "clean_cross_subject_swaps": clean_swap, "name_not_uniquely_in_index": unresolved,
            "disagreement_rate": round(disagree / checkable, 4) if checkable else 0.0,
            "clean_swap_rate": round(clean_swap / checkable, 4) if checkable else 0.0,
            "examples": examples,
            "note": "measured against the INDEPENDENT frozen index (not the co-mislabelled concepts.subject_"
                    "domain). `disagreement_rate` counts ALL prefix≠index cases (incl. coarse 'Science' vs a "
                    "subject-specific prefix); `clean_swap_rate` counts only prefix↔canonical-subject swaps. Both "
                    "are honest evidence the prefix is unusable (D3) — B2 resolves within the document-derived "
                    "subject, never the prefix."}


if __name__ == "__main__":
    print(json.dumps(mislabel_report(), indent=2))
