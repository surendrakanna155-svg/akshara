"""Read-only adapter: qcorpus staging lane -> QIE (Phase B6).

The isolated, non-certified `curriculum/staging/qcorpus_noncert/` lane already parsed ~819 third-party PDFs
(loss-minimising: PyMuPDF + OCR + tables), preserving question boundaries, options, answer association,
solutions, equations, and visual assets. This adapter READS its manifests and yields normalized items into
the QIE miner/KVS/Tier-2 pipeline. It is strictly READ-ONLY on the staging tree and writes NOTHING to kie.db
or the certified bank — no re-parsing, no duplicate pipeline (owner instruction).

Answers are used ONLY where qcorpus associated one from the source (`answer_associated` + `answer_ref`); none
are fabricated. `visual_dependent` items are surfaced so diagram-locked evidence can be handled honestly.
"""
from __future__ import annotations

import json
import os
import re
from typing import Dict, Iterator, Optional

# default staging root (local-only, gitignored)
STAGING_ROOT = "/Users/surendrakanna/Documents/Akshara_ERP/curriculum/staging/qcorpus_noncert"

_SUBJECT_PATTERNS = [
    ("Biology", re.compile(r"biolog|/bio/|_bio_|neet", re.I)),
    ("Chemistry", re.compile(r"chemis|/chem", re.I)),
    ("Mathematics", re.compile(r"mathemat|/math|maths", re.I)),
    ("Physics", re.compile(r"physic|/phy", re.I)),
]


def _doc_subject(rel_path: str, priority: str, group: str) -> Optional[str]:
    """Attribute subject from the qcorpus rel_path / priority / group (reliable folder-based signal)."""
    hay = f"{rel_path} {priority} {group}"
    # rel_path subject folder is the strongest signal; check specific subjects before the NEET->Biology default
    for subj, pat in _SUBJECT_PATTERNS:
        if subj != "Biology" and pat.search(rel_path or ""):
            return subj
    for subj, pat in _SUBJECT_PATTERNS:
        if pat.search(hay):
            return subj
    return None


def load_doc_subjects(root: str = STAGING_ROOT) -> Dict[str, str]:
    inv = os.path.join(root, "manifests", "corpus_inventory.jsonl")
    out: Dict[str, str] = {}
    with open(inv) as f:
        for line in f:
            r = json.loads(line)
            s = _doc_subject(r.get("rel_path", ""), r.get("priority", ""), r.get("group", ""))
            if s:
                out[r["doc_id"]] = s
    return out


def recovered_items(root: str = STAGING_ROOT, include_visual_dependent: bool = False) -> Iterator[dict]:
    """Yield normalized recovered items from qcorpus, compatible with mine.measure_yield().

    A normalized item = {stem, options{label:text}, answer_label, answer_text, subject, doc_id,
    visual_dependent}. Only answer-associated MCQs are yielded (verifiable evidence). By default
    visual-dependent items are EXCLUDED from text-based verification (they are surfaced separately) so we
    never treat a diagram-locked item as text-verifiable.
    """
    subjects = load_doc_subjects(root)
    qpath = os.path.join(root, "manifests", "extracted_questions.jsonl")
    with open(qpath) as f:
        for line in f:
            q = json.loads(line)
            if not q.get("is_mcq") or not q.get("answer_associated"):
                continue
            if q.get("visual_dependent") and not include_visual_dependent:
                continue
            subj = subjects.get(q.get("doc_id"))
            if not subj:
                continue
            # de-duplicate option labels (qcorpus option lists can carry cross-question bleed; keep first per label)
            opts: Dict[str, str] = {}
            for o in q.get("options") or []:
                lab, txt = str(o.get("label", "")).strip().lower(), (o.get("text") or "").strip()
                if lab and lab not in opts and txt:
                    # trim obvious next-question bleed ("... Q.14 ...")
                    txt = re.split(r"\s+Q\.?\s*\d+\b|\bDIRECTIONS\b", txt)[0].strip()
                    opts[lab] = txt
            ans_label = str(q.get("answer_ref", "")).strip().lower()
            ans_text = opts.get(ans_label)
            if not ans_text or len(opts) < 2:
                continue
            yield {
                "stem": (q.get("stem") or q.get("stem_search_text") or "").strip(),
                "options": opts,
                "answer_label": ans_label,
                "answer_text": ans_text,
                "subject": subj,
                "doc_id": q.get("doc_id"),
                "visual_dependent": bool(q.get("visual_dependent")),
            }


def coverage(root: str = STAGING_ROOT) -> dict:
    from collections import Counter
    subj = Counter()
    vdep = 0
    total = 0
    for it in recovered_items(root, include_visual_dependent=True):
        total += 1
        subj[it["subject"]] += 1
        if it["visual_dependent"]:
            vdep += 1
    return {"answer_associated_items": total, "by_subject": dict(subj), "visual_dependent": vdep}
