"""Bounded, cached governed examiner harness (Phase-6 scaled conversion).

The deterministic subject gate + OCR filter (candidates.py) do the mechanical work; the examiner is reserved
for the decision-critical judgment the machine cannot cheaply make: is the source answer key CORRECT (by
independent re-derivation, not agreement), is the item genuinely ON-TOPIC for its bound chapter/concept, and
what is the clean, self-contained STRUCTURED fact. Governance (locked hierarchy): the examiner NEVER certifies
by agreement alone — it must independently re-derive; a wrong/ambiguous key is a REJECT even if the source
marked it. Every verdict is CACHED by item_hash so evidence is never re-examined (owner token discipline).

This module does deterministic batch selection + worksheet emit + verdict ingest. The examiner pass itself is
performed by the caller (an independent model reading the worksheet) and returned as verdicts — exactly the
Tier-2/3 boundary the architecture defines.
"""
from __future__ import annotations

import json
from collections import defaultdict
from typing import Dict, List, Optional

from kie.qie import tier2_verify as T2
from kie.qie.convert import register as R

# lanes whose verified facts fill the currently-EMPTY typed KVS stores → highest generation leverage first
STRUCTURED_LANES = ("STRUCTURE_FUNCTION", "PROCESS_SEQUENCE", "COMPARATIVE", "CLASSIFICATION_TAXONOMIC")


def _item_hash(cand) -> str:
    return T2.item_hash(cand.stem, cand.options, cand.answer_text)


def select_batch(cands: List, qconn, n: int = 60, lanes: Optional[tuple] = None,
                 subjects: Optional[tuple] = None, prioritize_subjects: tuple = ("Chemistry",)) -> List:
    """Prioritized, deduped, cache-aware batch. Order: structured lanes first, then prioritized subjects
    (Chemistry = the 0-coverage gap), then OCR-cleanest. One representative per distinct fact_key. Skips any
    item already examined (verdict persisted)."""
    examined = R.already_examined(qconn)
    seen_fact = set()
    pool = []
    for c in cands:
        if lanes and c.lane not in lanes:
            continue
        if subjects and c.subject not in subjects:
            continue
        ih = _item_hash(c)
        if ih in examined or c.fact_key in seen_fact:
            continue
        seen_fact.add(c.fact_key)
        c._item_hash = ih                                   # stash for worksheet/ingest
        pool.append(c)

    def rank(c):
        return (0 if c.lane in STRUCTURED_LANES else 1,
                0 if c.subject in prioritize_subjects else 1,
                -c.ocr_score)
    pool.sort(key=rank)
    return pool[:n]


TOPIC_BRIEF = (
    "topic: REQUIRED (owner decision B). The smallest GENUINE curriculum concept this fact teaches — "
    "'Uricotelism' inside the chapter 'Excretory Products And Their Elimination'. Author it SHORT (<=5 words, "
    "the qpgen sanitizer cap); NEVER truncate the stem/subject_term prose. Every significant word must appear "
    "in the fact's own evidence — an ungrounded or invented name is refused by kie.qie.convert.topics.certify "
    "and the fact falls back to chapter binding. Two facts teaching the SAME concept SHOULD share a topic; "
    "never split a topic to win an extra paper slot. Never restate the ANSWER (a title is a giveaway)."
)


def worksheet(batch: List) -> List[dict]:
    """The examination worksheet the independent examiner reads. Includes the SOURCE answer key (evidence to
    be re-derived, NOT trusted) and the doc-grounded concept binding (to confirm on-topic)."""
    out = []
    for c in batch:
        out.append({
            "item_hash": getattr(c, "_item_hash", _item_hash(c)),
            "subject": c.subject, "exam": c.exam, "lane": c.lane,
            "concept_candidate": c.concept_candidate,
            "stem": c.stem, "options": c.options,
            "source_answer_key": c.answer_text,
        })
    return out


def write_worksheet_brief(path: str) -> None:
    """Emit the authoring brief alongside a worksheet, so a new batch's facts carry topics from the start
    (without it, every new fact silently reverts to chapter binding — the ceiling decision B removed)."""
    with open(path, "w") as f:
        f.write(TOPIC_BRIEF + "\n")


def write_worksheet(batch: List, path: str) -> None:
    with open(path, "w") as f:
        json.dump({"n": len(batch), "items": worksheet(batch)}, f, indent=2)


def ingest_verdicts(qconn, batch: List, verdicts: List[dict], now: str,
                    verifier_model: str = "governed_examiner") -> dict:
    """Apply examiner verdicts: register verified facts (projected to KVS + distractors), persist rejects.
    Verdict schema per item: {item_hash, keep:bool, answer_correct:bool, on_topic:bool, fact_text, structured,
    topic?, corrected_answer?, reason}. A fact is admitted only when keep && answer_correct && on_topic.
    `topic` (owner decision B) is PROPOSED here and certified deterministically by
    `kie.qie.convert.topics.certify` — an ungrounded/invented/truncated topic is refused and the fact keeps
    its chapter binding. See TOPIC_BRIEF."""
    by_hash = {getattr(c, "_item_hash", _item_hash(c)): c for c in batch}
    v_by_hash = {v.get("item_hash"): v for v in verdicts}
    metrics = {"in": len(batch), "verified": 0, "rejected": 0, "kvs": defaultdict(int),
               "distractors": 0, "by_subject_verified": defaultdict(int), "unmatched": 0}
    for ih, cand in by_hash.items():
        v = v_by_hash.get(ih)
        if not v:
            metrics["unmatched"] += 1
            continue
        v.setdefault("item_hash", ih)
        admit = bool(v.get("keep")) and bool(v.get("answer_correct", True)) and bool(v.get("on_topic", True)) \
            and bool((v.get("fact_text") or "").strip())
        if admit:
            res = R.register_verified(qconn, cand, v, now, verifier_model)
            metrics["verified"] += 1
            metrics["by_subject_verified"][cand.subject] += 1
            if res["kvs_store"]:
                metrics["kvs"][res["kvs_store"]] += 1
            metrics["distractors"] += res["distractors"]
        else:
            R.register_rejected(qconn, cand, v, now, verifier_model)
            metrics["rejected"] += 1
    metrics["kvs"] = dict(metrics["kvs"])
    metrics["by_subject_verified"] = dict(metrics["by_subject_verified"])
    metrics["survival_pct"] = round(100 * metrics["verified"] / max(1, metrics["verified"] + metrics["rejected"]), 1)
    return metrics
