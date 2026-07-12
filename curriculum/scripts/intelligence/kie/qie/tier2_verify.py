"""Tier-2 independent model-verification lane (Phase B6) — governed, cached, OFFLINE.

Non-numeric clusters the deterministic KVS cannot reach (esp. Biology: poorly-resolved concepts, no numeric
fallback) are verified by an INDEPENDENT model that reads only stem + options + the stated answer and judges
whether the key is correct — the exact architecture the Phase-0b Biology agreement result validated (91.7%).

Governance (reconciliation §MODEL_ROUTING): model use is offline, at certification only (never runtime, I9),
and every verdict is CACHED by item content hash so the model is never re-run. This module does the
candidate selection, caching, and fact aggregation; the actual model pass is orchestrated by the caller
(judge agents), which writes verdicts back through `record_verdict`. A fact is Tier-2-verified only on real
model agreement — structural clustering is NEVER counted as verified, and no answer is fabricated.
"""
from __future__ import annotations

import hashlib
import sqlite3
from collections import OrderedDict
from typing import Dict, Iterable, Optional, Set

from kie.qie import mine


def item_hash(stem: str, options: Dict, answer_text: str) -> str:
    payload = f"{stem}|{sorted((options or {}).items())}|{answer_text}"
    return hashlib.sha256(payload.encode()).hexdigest()[:24]


def record_verdict(qconn: sqlite3.Connection, ih: str, fk: str, subject: str, verdict: str,
                   model: str, note: str, now: str) -> None:
    qconn.execute(
        "INSERT OR REPLACE INTO tier2_verdict(item_hash,fact_key,subject,verdict,model,note,created_at) "
        "VALUES (?,?,?,?,?,?,?)", (ih, fk, subject, verdict, model, note, now))
    qconn.commit()


def cached_hashes(qconn: sqlite3.Connection) -> Set[str]:
    return {r[0] for r in qconn.execute("SELECT item_hash FROM tier2_verdict")}


def collect_candidates(items: Iterable[dict], by_title: Dict[str, str], verified_facts: Set[str],
                       subject: str = "Biology", max_facts: int = 300, resolver=None
                       ) -> "OrderedDict[str, dict]":
    """Return {fact_key: representative_item} for DISTINCT non-numeric `subject` facts that are NOT already
    KVS-verified and are on a resolved concept with a semantic answer (so verification is meaningful and
    bounded — one model check per distinct fact, not per item)."""
    out: "OrderedDict[str, dict]" = OrderedDict()
    for it in items:
        if it.get("subject") != subject:
            continue
        ans = it.get("answer_text")
        stem = it.get("stem") or ""
        if not ans or mine.R.first_number(ans) is not None:      # non-numeric only
            continue
        lane = mine.classify_nonnumeric_lane(stem)
        if lane == "CONCEPTUAL_GENERIC":
            continue
        ck = mine.item_concept(stem, ans, subject, by_title, resolver)
        if not mine.is_resolved_concept(ck) or not mine.is_semantic_answer(ans):
            continue
        fk = mine.fact_key(ck, ans)
        if fk in verified_facts or fk in out:
            continue
        out[fk] = {"fact_key": fk, "stem": stem, "options": it.get("options"),
                   "answer_text": ans, "concept": ck, "subject": subject,
                   "item_hash": item_hash(stem, it.get("options"), ans)}
        if len(out) >= max_facts:
            break
    return out


def tier2_verified_facts(qconn: sqlite3.Connection) -> Set[str]:
    """A fact_key is Tier-2-verified when the model AGREED and did NOT disagree (>=1 agree, 0 disagree)."""
    agg: Dict[str, list] = {}
    for r in qconn.execute("SELECT fact_key, verdict FROM tier2_verdict WHERE fact_key IS NOT NULL"):
        agg.setdefault(r[0], []).append(r[1])
    out = set()
    for fk, verds in agg.items():
        if any(v == "agree" for v in verds) and not any(v == "disagree" for v in verds):
            out.add(fk)
    return out


def agreement_stats(qconn: sqlite3.Connection, subject: Optional[str] = None) -> dict:
    q = "SELECT verdict, COUNT(*) FROM tier2_verdict"
    args = ()
    if subject:
        q += " WHERE subject=?"
        args = (subject,)
    q += " GROUP BY verdict"
    d = {r[0]: r[1] for r in qconn.execute(q, args)}
    tot = sum(d.values())
    agree = d.get("agree", 0)
    return {"agree": agree, "disagree": d.get("disagree", 0), "unverifiable": d.get("unverifiable", 0),
            "total": tot, "agree_pct": round(100 * agree / tot, 1) if tot else 0.0}
