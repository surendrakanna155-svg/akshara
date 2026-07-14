"""Safe-binding substrate: deterministic per-document SUBJECT / EXAM / CHAPTER / CLASS (Phase-6 governed).

The checkpoint proved that naive title-substring concept binding is UNSAFE (cross-subject homonyms: chemistry
"decomposition" -> ecological Decomposition; physics "nucleus" -> cell Nucleus). The fix is to bind INSIDE a
deterministically-known subject, using the document's own provenance (rel_path / priority / normalized filename
/ chapter_boundaries) — never the item text alone. This module computes that provenance per doc:

  * SUBJECT  — hard gate; from the rel_path subject segment, corroborated by the priority tag. Disagreement -> None
    (conservative: an item on an unknown-subject doc is never certified, so a homonym can't slip through).
  * EXAM     — NEET | JEE_MAIN | JEE_ADVANCED | FOUNDATION (provenance; not a hard filter).
  * CHAPTER  — a clean topic hint from the normalized filename (e.g. "Basic Concepts Of Chemistry"); the
               context for concept binding WITHIN the gated subject.

Read-only over the qcorpus corpus_inventory manifest. Deterministic, stdlib-only.
"""
from __future__ import annotations

import json
import os
import re
from dataclasses import dataclass
from typing import Dict, Optional

from kie.qie.qcorpus_adapter import STAGING_ROOT

SUBJECTS = ("Biology", "Chemistry", "Physics", "Mathematics")

# rel_path segment / token -> subject (word-boundary matched, case-insensitive)
_SUBJ_SEG = {
    "biology": "Biology", "bio": "Biology", "botany": "Biology", "zoology": "Biology",
    "chemistry": "Chemistry", "chem": "Chemistry",
    "physics": "Physics", "phy": "Physics", "physicsaholics": "Physics",
    "mathematics": "Mathematics", "maths": "Mathematics", "math": "Mathematics",
}
# priority-tag suffix -> subject (secondary corroboration)
_PRI_SUBJ = {
    "biology": "Biology", "chemistry": "Chemistry", "physics": "Physics",
    "mathematics": "Mathematics", "physicsaholics": "Physics",
}
_EXAM_SEG = [
    ("JEE_ADVANCED", re.compile(r"\bjee[_ ]?advanced\b|jeeadv", re.I)),
    ("JEE_MAIN", re.compile(r"\bjee[_ ]?main\b", re.I)),
    ("NEET", re.compile(r"\bneet\b", re.I)),
    ("AIIMS", re.compile(r"\baiims\b", re.I)),
]


def _seg_subject(rel_path: str) -> Optional[str]:
    segs = re.split(r"[/_\-. ]+", (rel_path or "").lower())
    for seg in segs:
        if seg in _SUBJ_SEG:
            return _SUBJ_SEG[seg]
    return None


def _priority_subject(priority: str) -> Optional[str]:
    p = (priority or "").lower()
    for key, subj in _PRI_SUBJ.items():
        if key in p:
            return subj
    return None


def _exam(rel_path: str, group: str) -> Optional[str]:
    hay = f"{rel_path} {group}"
    for exam, pat in _EXAM_SEG:
        if pat.search(hay):
            return exam
    if "physicsaholics" in (group or "").lower():
        return "FOUNDATION"          # general physics DPPs (JEE/NEET foundation)
    return None


_FN_DROP = re.compile(
    r"\b(neet|jee|main|advanced|dpp|dpps|part|topic|wise|chapterwise|mock|leader|paper|answerkey|"
    r"answer|key|solution|solutions|physics|chemistry|biology|mathematics|maths|math|general|"
    r"\d{4}|january|february|march|april|may|june|july|august|september|october|november|december|"
    r"th|st|nd|rd)\b", re.I)


def _chapter_hint(rel_path: str, chapter_boundaries=None) -> Optional[str]:
    """Clean topic string from the file's own name (strongest per-doc chapter signal), e.g.
    'NEET_Chemistry_DPP_Basic_Concepts_Of_Chemistry.pdf' -> 'Basic Concepts Of Chemistry'."""
    fn = os.path.basename(rel_path or "")
    fn = re.sub(r"\.(pdf|json)$", "", fn, flags=re.I)
    toks = re.split(r"[_\-. ]+", fn)
    kept = [t for t in toks if t and not _FN_DROP.fullmatch(t) and not t.isdigit() and len(t) > 1]
    hint = " ".join(kept).strip()
    hint = re.sub(r"\s+", " ", hint)
    return hint.title() if len(hint) >= 3 else None


@dataclass(frozen=True)
class DocMeta:
    doc_id: str
    subject: Optional[str]     # HARD gate; None => not certifiable (unknown subject)
    exam: Optional[str]
    chapter_hint: Optional[str]
    rel_path: str
    priority: str
    subject_confident: bool    # True only when rel_path AND priority agree (or one is decisive, other absent)


def classify(rec: dict) -> DocMeta:
    rel = rec.get("rel_path", "")
    pri = rec.get("priority", "")
    grp = rec.get("group", "")
    seg = _seg_subject(rel)
    prs = _priority_subject(pri)
    # SUBJECT hard gate: agree -> confident; one present & other absent -> that one; disagree -> None
    if seg and prs:
        subject = seg if seg == prs else None
        confident = seg == prs
    else:
        subject = seg or prs
        confident = bool(subject)
    return DocMeta(rec.get("doc_id", ""), subject, _exam(rel, grp),
                   _chapter_hint(rel), rel, pri, confident)


def load(root: str = STAGING_ROOT) -> Dict[str, DocMeta]:
    """doc_id -> DocMeta for every doc in the qcorpus inventory."""
    inv = os.path.join(root, "manifests", "corpus_inventory.jsonl")
    out: Dict[str, DocMeta] = {}
    with open(inv) as f:
        for line in f:
            rec = json.loads(line)
            dm = classify(rec)
            if dm.doc_id:
                out[dm.doc_id] = dm
    return out


def coverage(root: str = STAGING_ROOT) -> dict:
    from collections import Counter
    metas = load(root)
    subj = Counter(m.subject or "UNKNOWN" for m in metas.values())
    exam = Counter(m.exam or "UNKNOWN" for m in metas.values())
    conf = sum(1 for m in metas.values() if m.subject_confident)
    haschap = sum(1 for m in metas.values() if m.chapter_hint)
    return {"docs": len(metas), "by_subject": dict(subj), "by_exam": dict(exam),
            "subject_confident": conf, "with_chapter_hint": haschap}
