"""Governed document-structure recovery for stranded qcorpus MCQs (Phase B8, Track 1).

The B7 audit showed Biology loss is NOT bulk extraction loss (the adapter already recovers ~90% of Biology
MCQs as text) but a thin band of STRANDED STRUCTURE: MCQs whose options were OCR-glued onto one line/column
so the answer option text lands inside a *sibling* option ({'a':'foo (b) bar', 'c':.., 'd':..}), which the
base adapter drops because the answer label parses empty. This module recovers that structure DETERMINISTICALLY
by splitting embedded '(x)' option markers back into their own labels — no image answer-inference, no new
parse of the source PDF, no fabrication.

It is strictly ADDITIVE and READ-ONLY on the staging manifests: it yields ONLY the delta items the base
`qcorpus_adapter` drops (so it never double-counts already-recovered evidence), each tagged with recovery
provenance. Visual-dependent items are surfaced through a SEPARATE generator and are NEVER emitted into the
text-verification stream — a diagram-locked answer is not text-verifiable and must not be treated as if it were.

Answers come only from the source-associated `answer_ref`; none are invented. Deterministic, stdlib-only.
"""
from __future__ import annotations

import json
import os
import re
from typing import Dict, Iterator, List, Optional, Tuple

from kie.qie import qcorpus_adapter as QA

# an embedded option marker inside another option's text: " (b) " / " b) " for a *later* label letter
_EMB = re.compile(r"\(?([a-d])\)\s+")
_BLEED = re.compile(r"\s+Q\.?\s*\d+\b|\bDIRECTIONS\b")


def _base_parse(raw_options: List[dict]) -> Dict[str, str]:
    """The exact option parse the base adapter uses (first non-empty text per label, next-Q bleed trimmed)."""
    out: Dict[str, str] = {}
    for o in raw_options or []:
        lab = str(o.get("label", "")).strip().lower()
        txt = (o.get("text") or "").strip()
        if lab and lab not in out and txt:
            out[lab] = _BLEED.split(txt)[0].strip()
    return out


def deglue_options(raw_options: List[dict]) -> Dict[str, str]:
    """Split OCR-merged options: within each option's text, an embedded later-label marker '(x)' begins a new
    option x. Only splits when x is a *distinct, later* letter not already seen — conservative, so a stray
    '(a)' inside prose is not mistaken for an option boundary. Returns {label: text}."""
    out: Dict[str, str] = {}
    for o in raw_options or []:
        lab = str(o.get("label", "")).strip().lower()
        txt = _BLEED.split((o.get("text") or "").strip())[0].strip()
        if not lab or not txt:
            continue
        cur, pos, parts = lab, 0, []
        for m in _EMB.finditer(txt):
            nxt = m.group(1)
            if nxt != cur and nxt not in out and ord(nxt) > ord(cur):
                seg = txt[pos:m.start()].strip()
                if seg:
                    parts.append((cur, seg))
                cur, pos = nxt, m.end()
        seg = txt[pos:].strip()
        if seg:
            parts.append((cur, seg))
        for l, t in parts:
            if l not in out and t:
                out[l] = t
    return out


def _normalize(q: dict, subject: str, opts: Dict[str, str], recovery: str) -> Optional[dict]:
    ans_label = str(q.get("answer_ref", "")).strip().lower()
    ans_text = opts.get(ans_label)
    if not ans_text or len(opts) < 2:
        return None
    return {
        "stem": (q.get("stem") or q.get("stem_search_text") or "").strip(),
        "options": opts,
        "answer_label": ans_label,
        "answer_text": ans_text,
        "subject": subject,
        "doc_id": q.get("doc_id"),
        "question_id": q.get("question_id"),
        "visual_dependent": bool(q.get("visual_dependent")),
        "recovery": recovery,          # provenance: how this item was recovered
    }


def recovered_delta_items(root: str = QA.STAGING_ROOT, subject: Optional[str] = None) -> Iterator[dict]:
    """Yield ONLY the additional text-verifiable MCQs that the base adapter drops but option de-glue rescues.

    These are answer-associated, NON-visual MCQs whose base parse loses the answer option (empty / merged) but
    whose de-glued parse recovers a valid answer option. Never overlaps the base adapter stream."""
    subjects = QA.load_doc_subjects(root)
    qpath = os.path.join(root, "manifests", "extracted_questions.jsonl")
    with open(qpath) as f:
        for line in f:
            q = json.loads(line)
            if not q.get("is_mcq") or not q.get("answer_associated") or q.get("visual_dependent"):
                continue
            subj = subjects.get(q.get("doc_id"))
            if not subj or (subject and subj != subject):
                continue
            base = _base_parse(q.get("options") or [])
            ans = str(q.get("answer_ref", "")).strip().lower()
            if base.get(ans) and len(base) >= 2:
                continue                       # already recovered by the base adapter — skip (no double count)
            dg = deglue_options(q.get("options") or [])
            item = _normalize(q, subj, dg, recovery="option_deglue")
            if item is not None:
                yield item


def visual_dependent_items(root: str = QA.STAGING_ROOT, subject: Optional[str] = None) -> Iterator[dict]:
    """Surface answer-associated VISUAL-dependent MCQs separately. These carry a source-associated answer but
    are diagram-locked, so they are NOT text-verifiable and MUST NOT enter the text-verification stream. Yielded
    only for honest accounting / future Phase-E visual verification."""
    subjects = QA.load_doc_subjects(root)
    qpath = os.path.join(root, "manifests", "extracted_questions.jsonl")
    with open(qpath) as f:
        for line in f:
            q = json.loads(line)
            if not q.get("is_mcq") or not q.get("answer_associated") or not q.get("visual_dependent"):
                continue
            subj = subjects.get(q.get("doc_id"))
            if not subj or (subject and subj != subject):
                continue
            opts = deglue_options(q.get("options") or []) or _base_parse(q.get("options") or [])
            item = _normalize(q, subj, opts, recovery="visual_surfaced")
            if item is not None:
                yield item


def coverage(root: str = QA.STAGING_ROOT) -> dict:
    from collections import Counter
    deg, vis = Counter(), Counter()
    for it in recovered_delta_items(root):
        deg[it["subject"]] += 1
    for it in visual_dependent_items(root):
        vis[it["subject"]] += 1
    return {"deglue_recovered": dict(deg), "visual_dependent_surfaced": dict(vis)}
