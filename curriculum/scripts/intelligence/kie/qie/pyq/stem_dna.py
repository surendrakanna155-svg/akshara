"""Corpus DNA mining — recover per-question stems and link them to certified concepts.

WHY. The corpus study established that `pyq_item.concept_kc` is populated on 132 of 15,803 items (0.8%),
which makes concept-selection and concept-combination DNA unminable. The items themselves are span
pointers: several can resolve to one OCR chunk, and that chunk often opens with exam instruction
boilerplate. This module turns those pointers into per-question stems and links the stems to the certified
concept index, so those two DNA dimensions become measurable.

WHAT IT DELIBERATELY DOES NOT DO.

  * It does not recover ANSWER KEYS. There are none in the corpus, and per the owner decision of
    2026-07-29 they are treated as permanently unavailable. Nothing here infers, reconstructs or guesses a
    key, and no downstream consumer may treat a mined item as keyed.
  * It does not mine DISTRACTOR DNA. Verified by inspection: option text in this corpus is OCR-damaged
    wherever it is mathematical — a real NEET option set reads `1+b / a+f / (2)2b-1 / co)`. Deriving a
    misconception taxonomy from that would be deriving it from noise.
  * It does not write to any store. It reads `pyq_corpus.db` and `kie.db` read-only and returns values.

WHAT IT DOES RECOVER: the stem prose (which OCRs far better than the options), and from it the certified
concepts a real examiner actually chose — and, where a stem names more than one, the combinations they
actually paired.

CONCEPT LINKING IS DELIBERATELY STRICT. A certified concept counts as present only when its full canonical
name appears in the stem on word boundaries, and only when that name carries at least two significant
words. Matching short names would be worse than useless: the certified Class-6 concept "Ray" would fire on
every stem containing the word "ray", and "Series" on any mention of a series. A low recall of correct
links is recoverable; a high recall of wrong links would silently corrupt every DNA figure built on it.

Deterministic, stdlib-only, read-only.
"""
from __future__ import annotations

import json
import re
import sqlite3
from collections import Counter
from dataclasses import dataclass
from typing import Dict, Iterable, List, Optional, Sequence, Tuple

# A question marker: a number, a full stop, then the start of the question. Anchored to a line start or
# whitespace so decimals inside a stem ("2.5 m") cannot masquerade as a new question.
_MARKER = re.compile(r"(?m)(?:^|\s)(\d{1,3})\.\s+(?=[A-Z(])")

# Boilerplate that precedes the first real question on a booklet's opening chunk. Recorded rather than
# silently trimmed, so a stem that is really instructions is dropped instead of being mined as a question.
_BOILERPLATE = re.compile(
    r"test booklet|answer sheet|attendance sheet|do not open|rough work|instructions to candidates|"
    r"candidates will write|use blue/black|omr", re.I)

_STOPWORDS = {"the", "of", "and", "in", "a", "an", "to", "for", "with", "by", "at", "on", "from", "its",
              "their", "as", "is", "are", "or", "using", "use", "between", "than", "into"}


def significant_words(name: str) -> List[str]:
    return [w for w in re.findall(r"[A-Za-z][A-Za-z\-]*", (name or "").lower())
            if len(w) >= 4 and w not in _STOPWORDS]


@dataclass(frozen=True)
class MinedStem:
    item_id: str
    exam: str
    year: Optional[int]
    question_number: Optional[int]
    question_type: str
    stem: str
    is_boilerplate: bool


def segment_chunk(text: str) -> Dict[int, str]:
    """Split an OCR chunk into `{question_number: segment}` by its question markers."""
    marks = [(m.start(), int(m.group(1))) for m in _MARKER.finditer(text or "")]
    out: Dict[int, str] = {}
    for i, (pos, num) in enumerate(marks):
        end = marks[i + 1][0] if i + 1 < len(marks) else len(text)
        seg = text[pos:end].strip()
        if seg and num not in out:            # first occurrence wins; a repeated number is OCR noise
            out[num] = seg
    return out


def mine_stem(item: sqlite3.Row, chunk_text_of: Dict[str, str]) -> Optional[MinedStem]:
    """Recover one item's own question text from the chunk(s) it spans."""
    try:
        cids = json.loads(item["chunk_ids"] or "[]")
    except (TypeError, ValueError):
        return None
    qnum = item["question_number"]
    joined = "\n".join(chunk_text_of.get(c, "") for c in cids)
    if not joined.strip():
        return None
    segments = segment_chunk(joined)
    seg = segments.get(qnum) if qnum is not None else None
    if seg is None:
        return None
    # keep only the stem: cut at the first option marker, since option text is OCR-damaged and is not mined
    cut = re.split(r"\n?\s*\(\s*[1-4a-dA-D]\s*\)", seg, maxsplit=1)[0].strip()
    return MinedStem(item["item_id"], item["exam"], item["year"], qnum, item["question_type"],
                     cut, bool(_BOILERPLATE.search(cut)))


def build_concept_matchers(universe: Sequence[dict]) -> List[Tuple[re.Pattern, str, str, int]]:
    """(pattern, concept_id, canonical_name, taught_at_class) for concepts safe to match by name."""
    out = []
    for c in universe:
        name = c.get("canonical_name") or ""
        if len(significant_words(name)) < 2:
            continue                          # "Ray", "Series", "Density" — too generic to match safely
        core = re.sub(r"\s*\([^)]*\)", "", name).strip()      # drop parenthetical glosses
        if len(significant_words(core)) < 2:
            core = name
        pat = re.compile(r"\b" + re.escape(core).replace(r"\ ", r"\s+") + r"\b", re.I)
        out.append((pat, c["concept_id"], name, c.get("taught_at_class")))
    return out


def link_concepts(stem: str, matchers: Sequence[Tuple[re.Pattern, str, str, int]]) -> List[str]:
    return sorted({cid for pat, cid, _n, _cl in matchers if pat.search(stem or "")})


def mine(pconn: sqlite3.Connection, kconn: sqlite3.Connection,
         universe: Sequence[dict], limit: Optional[int] = None,
         exam: Optional[str] = None) -> Dict[str, object]:
    """Recover stems for the corpus and measure the concept DNA that becomes visible.

    Returns counts plus `concept_frequency` (which certified concepts real examiners chose) and
    `concept_pairs` (which they combined in one question) — the two DNA dimensions this unlocks.
    """
    q = "SELECT item_id, exam, year, question_number, question_type, chunk_ids FROM pyq_item"
    args: List = []
    if exam:
        q += " WHERE exam=?"
        args.append(exam)
    q += " ORDER BY item_id"
    if limit:
        q += f" LIMIT {int(limit)}"
    items = pconn.execute(q, args).fetchall()

    # bulk-load only the chunks these items reference
    needed = set()
    for it in items:
        try:
            needed.update(json.loads(it["chunk_ids"] or "[]"))
        except (TypeError, ValueError):
            pass
    chunk_text: Dict[str, str] = {}
    for ref in needed:
        if "#" not in ref:
            continue
        doc, ordi = ref.rsplit("#", 1)
        try:
            row = kconn.execute("SELECT text FROM chunks WHERE doc_id=? AND ordinal=?",
                                (doc, int(ordi))).fetchone()
        except (ValueError, sqlite3.Error):
            continue
        if row:
            chunk_text[ref] = row["text"] or ""

    matchers = build_concept_matchers(universe)
    freq: Counter = Counter()
    pairs: Counter = Counter()
    stems_ok = boiler = linked = 0
    per_type_len: Dict[str, List[int]] = {}

    for it in items:
        ms = mine_stem(it, chunk_text)
        if ms is None or not ms.stem:
            continue
        if ms.is_boilerplate:
            boiler += 1
            continue
        stems_ok += 1
        per_type_len.setdefault(ms.question_type, []).append(len(ms.stem))
        cids = link_concepts(ms.stem, matchers)
        if cids:
            linked += 1
            freq.update(cids)
            for i in range(len(cids)):
                for j in range(i + 1, len(cids)):
                    pairs[(cids[i], cids[j])] += 1

    name_of = {cid: n for _p, cid, n, _c in matchers}
    return {
        "items_scanned": len(items),
        "stems_recovered": stems_ok,
        "boilerplate_dropped": boiler,
        "stems_with_a_certified_concept": linked,
        "concept_frequency": [(name_of.get(c, c), n) for c, n in freq.most_common(25)],
        "concept_pairs": [((name_of.get(a, a), name_of.get(b, b)), n) for (a, b), n in pairs.most_common(15)],
        "median_stem_len_by_type": {t: sorted(v)[len(v) // 2] for t, v in per_type_len.items() if v},
    }
