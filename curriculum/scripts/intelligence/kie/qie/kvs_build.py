"""KVS v1 — multi-source assertion base from corpus MCQ answer keys (Phase B5).

A3 seeded the KVS from thin single-source concept edges and got 0 promotable assertions. KVS v1 instead
mines FACTS from the answer keys of the recovered corpus MCQs and CROSS-CORROBORATES them across independent
source documents: a fact (concept, correct-answer) attested by >=2 distinct docs is `promotable` and can back
INDEPENDENT non-numeric verification (a deterministic multi-source analogue of the Phase-0b model-agreement
proxy). This is what turns Biology/Chemistry structural clusters into verification-backed Item Models.

Read-only on kie.db; writes qie.db (local). Deterministic, stdlib-only.
"""
from __future__ import annotations

import hashlib
import json
import re
import sqlite3
from collections import defaultdict
from typing import Dict, Optional, Set, Tuple

from kie.qie import mine

PROMOTE_MIN_DOCS = 2   # a fact needs >=2 independent source docs to be verification-usable

# fact_key / norm_answer live in mine (shared with the verification lookup there) to avoid drift.
norm_answer = mine.norm_answer
fact_key = mine.fact_key


def build_from_corpus(kconn: sqlite3.Connection, qconn: sqlite3.Connection, now: str, extra_items=None) -> dict:
    """Mine (concept, correct-answer) facts from all keyed non-numeric MCQs across kie.db AND (optionally)
    the qcorpus adapter items; corroborate across INDEPENDENT source docs. More independent sources ->
    more facts reach the >=2-doc promotion bar."""
    kconn.row_factory = sqlite3.Row
    by_title = mine.build_by_title(kconn)
    # fact -> {docs, concept, answer, subject}
    facts: Dict[str, dict] = defaultdict(lambda: {"docs": set(), "concept": None, "answer": None, "subject": None})

    def add(stem, keyopt, subj, doc):
        if not subj or not keyopt or mine.R.first_number(keyopt) is not None:
            return   # numeric-answer facts are verified by the relation library, not the KVS
        ck = mine.concept_key(stem, subj, by_title)
        # A fact must be on a RESOLVED concept (not a coarse subject:keyword bucket) with a SEMANTIC answer
        # (not an option-label) — kills the B5 over-corroboration (junk-concept + "a-ii,b-i" collisions).
        if not mine.is_resolved_concept(ck) or not mine.is_semantic_answer(keyopt):
            return
        fk = fact_key(ck, keyopt)
        f = facts[fk]
        f["docs"].add(doc)
        f["concept"], f["answer"], f["subject"] = ck, norm_answer(keyopt), subj

    for item in mine.iter_kie_items(kconn):
        add(item["stem"], item.get("answer_text"), item["subject"], item["doc_id"])
    for item in (extra_items or []):
        add(item.get("stem", ""), item.get("answer_text"), item.get("subject"), item.get("doc_id"))
    promotable = 0
    for fk, f in facts.items():
        n = len(f["docs"])
        if n >= PROMOTE_MIN_DOCS:
            promotable += 1
            qconn.execute(
                "INSERT OR REPLACE INTO kvs_assertion(assertion_id,subject_term,predicate,object_term,"
                "concept_code,evidence,evidence_count,created_at) VALUES (?,?,?,?,?,?,?,?)",
                ("KV1_" + fk, f["subject"], "correct_answer_is", f["answer"], f["concept"],
                 json.dumps(sorted(f["docs"])), n, now))
    qconn.commit()
    return {"distinct_facts": len(facts), "promotable_ge2docs": promotable}


def promotable_fact_keys(qconn: sqlite3.Connection) -> Set[str]:
    """The set of fact_keys (concept|answer) that reached >=2 evidence — usable for verification."""
    out = set()
    for r in qconn.execute("SELECT assertion_id FROM kvs_assertion WHERE evidence_count >= ? AND assertion_id LIKE 'KV1_%'",
                           (PROMOTE_MIN_DOCS,)):
        out.add(r[0][4:])   # strip the 'KV1_' prefix -> the raw fact_key
    return out
