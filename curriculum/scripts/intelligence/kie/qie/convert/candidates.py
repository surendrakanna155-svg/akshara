"""Deterministic candidate preparation — the cheap, no-model funnel (Phase-6 governed).

Turns raw answer-keyed qcorpus MCQs into clean, subject-gated, chapter-bound candidate FACTS ready for
verification. Everything here is deterministic:

  1. SUBJECT HARD GATE      — from docmeta (rel_path+priority); unknown-subject docs are dropped (a homonym
                              cannot slip through because the item text alone never decides the subject).
  2. OCR-QUALITY FILTER     — reject garbled stems/answers (glyph soup, truncation, non-semantic answers).
                              Damaged OCR must never be trusted as truth (owner rule).
  3. CONCEPT CANDIDATE      — canonical (subject :: chapter_hint) from the DOC's own chapter, not item-text
                              substring. Context-aware binding; examiner confirms it later.
  4. FACT-TYPE LANE         — structure_function / sequence / comparison / taxonomy / cause_effect / assertion
                              (routes the fact to the right KVS store).
  5. DEDUP                  — collapse near-identical stems (option-set signature) so the model never re-checks
                              the same fact and the duplicate rate is measured, not hidden.

Numeric-answer items are split out (they belong to the relation/notation-recovery lane, not the KVS).
Read-only. Deterministic, stdlib-only.
"""
from __future__ import annotations

import hashlib
import re
from dataclasses import dataclass, field
from typing import Dict, List, Optional

from kie.qie import mine
from kie.qie import qcorpus_adapter as QA
from kie.qie.convert import docmeta as DM

# ── OCR quality ────────────────────────────────────────────────────────────────────────────────────────
# Genuine OCR-noise only: the Unicode replacement char, box-drawing/bullet artifacts, and repeated stray
# symbols (e.g. "®®0@", "@@0@", "____"). Deliberately NOT ordinary science symbols (°/±/×/÷ are legit).
_NOISE = re.compile("[�◊○●■□▪▫◦]|@{2,}|®{2,}|_{3,}|\\.{4,}")
_WORD = re.compile(r"[A-Za-z]{2,}")
# runs of 4+ non-content symbols = garbled OCR (science symbols ²³½¼¾°±×÷ and '.' are excluded)
_NONWORD_RUN = re.compile("[^\\w\\s²³½¼¾°±×÷.]{4,}")


def ocr_quality(text: str) -> float:
    """0..1 cleanliness score. High = clean prose we can trust; low = garbled OCR to reject/quarantine.
    Driven by alphabetic ratio + word density; penalties fire only on genuine OCR junk."""
    if not text:
        return 0.0
    t = text.strip()
    n = len(t)
    if n < 3:
        return 0.0
    letters = sum(c.isalpha() or c.isspace() for c in t)
    alpha_ratio = letters / n
    words = _WORD.findall(t)
    word_ratio = min(1.0, len(words) / max(1.0, n / 6.5))   # ~expect a word per ~6.5 chars in clean prose
    noise_pen = 0.40 if _NOISE.search(t) else 0.0
    run_pen = 0.20 if _NONWORD_RUN.search(t) else 0.0
    score = 0.55 * alpha_ratio + 0.45 * word_ratio - noise_pen - run_pen
    return max(0.0, min(1.0, score))


def _clean_prose(text: str, min_score: float) -> bool:
    return ocr_quality(text) >= min_score and len(_WORD.findall(text or "")) >= 2


# ── fact-type lane (which KVS store the verified fact belongs in) ─────────────────────────────────────────
def fact_lane(stem: str) -> str:
    """Map an item to a KVS-backed lane. Reuses the miner's classifier, then refines for the structured
    stores (structure_function / sequence / comparison / taxonomy)."""
    t = (stem or "").lower()
    if any(k in t for k in ("function of", "responsible for", "role of", "site of", "secreted by",
                            "which organ", "which system", "located in", "found in")):
        return "STRUCTURE_FUNCTION"
    if any(k in t for k in ("arrange", "sequence", "order of", "correct order", "followed by",
                            "stage after", "next step", "steps of", "pathway")):
        return "PROCESS_SEQUENCE"
    if any(k in t for k in ("difference between", "compare", "higher than", "greater than", "more than",
                            "less than", "stronger than", "smaller than", "larger than")):
        return "COMPARATIVE"
    if any(k in t for k in ("which of the following is not", "which of the following is an example",
                            "belongs to", "is an example of", "classify", "odd one",
                            "which of the following is a")):
        return "CLASSIFICATION_TAXONOMIC"
    return mine.classify_nonnumeric_lane(stem)   # ASSERTION_RELATION / CONCEPTUAL_CAUSAL / CONCEPTUAL_GENERIC


def concept_candidate(subject: str, chapter_hint: Optional[str]) -> Optional[str]:
    """Canonical (subject :: chapter) concept identity from the DOC's own chapter — safe, context-aware.
    Returns None when the doc has no usable chapter (we won't guess a concept from item text)."""
    if not chapter_hint:
        return None
    ch = re.sub(r"\s+", " ", chapter_hint).strip()
    if len(ch) < 3:
        return None
    return f"{subject} :: {ch}"


def stem_signature(stem: str, options: Dict[str, str]) -> str:
    """A dedup signature: normalized stem head + sorted option value set. Near-identical items collide."""
    s = re.sub(r"[^a-z0-9 ]", "", (stem or "").lower())
    s = re.sub(r"\s+", " ", s).strip()[:120]
    opts = "|".join(sorted(re.sub(r"[^a-z0-9]", "", (o or "").lower()) for o in options.values()))
    return hashlib.sha256(f"{s}||{opts}".encode()).hexdigest()[:20]


@dataclass
class Candidate:
    doc_id: str
    subject: str
    exam: Optional[str]
    chapter_hint: Optional[str]
    concept_candidate: Optional[str]
    lane: str
    stem: str
    options: Dict[str, str]
    answer_label: str
    answer_text: str
    numeric: bool
    ocr_score: float
    fact_key: str
    signature: str


@dataclass
class Funnel:
    seen: int = 0
    dropped_unknown_subject: int = 0
    dropped_subject_unconfident: int = 0
    dropped_ocr: int = 0
    dropped_no_semantic_answer: int = 0
    dropped_no_concept: int = 0
    duplicates: int = 0
    numeric: int = 0
    nonnumeric_kept: int = 0
    by_subject: Dict[str, int] = field(default_factory=dict)
    by_lane: Dict[str, int] = field(default_factory=dict)

    def as_dict(self) -> dict:
        return {k: (dict(v) if isinstance(v, dict) else v) for k, v in self.__dict__.items()}


def prepare(root: str = QA.STAGING_ROOT, min_ocr: float = 0.55, require_confident: bool = True
            ) -> "tuple[List[Candidate], Funnel]":
    """Deterministic funnel: qcorpus answer-keyed MCQs -> clean, subject-gated, chapter-bound candidates.
    Numeric-answer items are counted (numeric) for the relation/notation lane but excluded from KVS facts."""
    metas = DM.load(root)
    fn = Funnel()
    seen_sig: Dict[str, int] = {}
    out: List[Candidate] = []
    for it in QA.recovered_items(root, include_visual_dependent=False):
        fn.seen += 1
        dm = metas.get(it["doc_id"])
        if not dm or not dm.subject:
            fn.dropped_unknown_subject += 1
            continue
        if require_confident and not dm.subject_confident:
            fn.dropped_subject_unconfident += 1
            continue
        subject = dm.subject
        stem, ans = it.get("stem") or "", it.get("answer_text") or ""
        opts = it.get("options") or {}
        if mine.R.first_number(ans) is not None:            # numeric answers -> relation/notation lane
            fn.numeric += 1
            continue
        if not mine.is_semantic_answer(ans):
            fn.dropped_no_semantic_answer += 1
            continue
        if not (_clean_prose(stem, min_ocr) and _clean_prose(ans, min_ocr)):
            fn.dropped_ocr += 1
            continue
        cc = concept_candidate(subject, dm.chapter_hint)
        if not cc:
            fn.dropped_no_concept += 1
            continue
        sig = stem_signature(stem, opts)
        if sig in seen_sig:
            fn.duplicates += 1
            continue
        seen_sig[sig] = 1
        lane = fact_lane(stem)
        fk = mine.fact_key(cc, ans)
        out.append(Candidate(it["doc_id"], subject, dm.exam, dm.chapter_hint, cc, lane, stem, opts,
                             it.get("answer_label", ""), ans, False, ocr_quality(stem), fk, sig))
        fn.nonnumeric_kept += 1
        fn.by_subject[subject] = fn.by_subject.get(subject, 0) + 1
        fn.by_lane[lane] = fn.by_lane.get(lane, 0) + 1
    return out, fn
