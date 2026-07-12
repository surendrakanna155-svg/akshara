"""KVS v0 seed — the non-numeric independent-verification backbone (Phase A3).

Seeds the Knowledge Verification Substrate in qie.db from what the certified kie.db genuinely offers:
`concept_edges` (related / parent_child) and `concepts.reference_facts` (associated law/principle names).
Everything is filtered against the POST-CANONICALIZATION active concept set, so the quarantined junk (A2)
never pollutes the KVS — this is exactly why A2 precedes A3.

HONEST v0 LIMITS (reported, not hidden): reference_facts are bare law NAMES (no relations), and many edges
are noisy; each seeded assertion carries only the evidence the edge/fact provides, so most are
`evidence_count < 2` and are therefore seed-only — NOT yet promotable to verification use (the promotion bar
is >=2 independent sources). A real assertion base needs dedicated mining (Phase B), not just harvesting.
Read-only on kie.db; writes qie.db (local). Deterministic, stdlib-only.
"""
from __future__ import annotations

import hashlib
import json
import sqlite3
from typing import Dict, Set


def _active_codes(kconn: sqlite3.Connection) -> Set[str]:
    return {r[0] for r in kconn.execute("SELECT concept_code FROM concepts WHERE status='active'")}


def _titles(kconn: sqlite3.Connection) -> Dict[str, str]:
    return {r[0]: (r[1] or r[0]) for r in kconn.execute("SELECT concept_code, title FROM concepts")}


def _aid(*parts) -> str:
    return "A_" + hashlib.sha256("|".join(str(p) for p in parts).encode()).hexdigest()[:16]


def seed_assertions_from_edges(kconn: sqlite3.Connection, qconn: sqlite3.Connection, now: str) -> dict:
    """Each concept_edge with BOTH endpoints active -> one kvs_assertion (subject/predicate/object)."""
    active = _active_codes(kconn)
    titles = _titles(kconn)
    seeded = skipped_junk = 0
    for r in kconn.execute("SELECT from_concept, relationship_type, to_concept, evidence FROM concept_edges"):
        frm, rel, to, ev = r[0], r[1], r[2], r[3]
        if frm not in active or to not in active:      # skip edges touching quarantined/junk concepts
            skipped_junk += 1
            continue
        ev_list = [e for e in (ev,) if e]
        qconn.execute(
            "INSERT OR IGNORE INTO kvs_assertion(assertion_id,subject_term,predicate,object_term,concept_code,"
            "evidence,evidence_count,created_at) VALUES (?,?,?,?,?,?,?,?)",
            (_aid(frm, rel, to), titles.get(frm, frm), rel, titles.get(to, to), frm,
             json.dumps(ev_list), len(ev_list), now))
        seeded += 1
    qconn.commit()
    return {"assertions_seeded": seeded, "edges_skipped_junk_endpoint": skipped_junk}


def seed_taxonomy_from_parent_child(kconn: sqlite3.Connection, qconn: sqlite3.Connection, now: str) -> dict:
    """parent_child edges (active endpoints) -> kvs_taxonomy membership (child is-a member-of parent)."""
    active = _active_codes(kconn)
    titles = _titles(kconn)
    n = 0
    for r in kconn.execute(
            "SELECT from_concept, to_concept FROM concept_edges WHERE relationship_type='parent_child'"):
        frm, to = r[0], r[1]
        if frm not in active or to not in active:
            continue
        qconn.execute(
            "INSERT OR IGNORE INTO kvs_taxonomy(node_id,class_name,member,is_member,discriminating_attr,"
            "evidence,created_at) VALUES (?,?,?,1,NULL,NULL,?)",
            (_aid("tax", frm, to), titles.get(to, to), titles.get(frm, frm), now))
        n += 1
    qconn.commit()
    return {"taxonomy_rows_seeded": n}


def seed_reference_facts(kconn: sqlite3.Connection, qconn: sqlite3.Connection, now: str) -> dict:
    """concepts.reference_facts (bare law/principle names) -> weak 'concept has_principle X' assertions."""
    active = _active_codes(kconn)
    titles = _titles(kconn)
    n = skipped = 0
    for r in kconn.execute(
            "SELECT concept_code, reference_facts FROM concepts WHERE status='active' "
            "AND reference_facts IS NOT NULL AND TRIM(reference_facts) != ''"):
        code, raw = r[0], r[1]
        if code not in active:
            continue
        try:
            facts = json.loads(raw)
        except (ValueError, TypeError):
            skipped += 1
            continue
        for f in facts if isinstance(facts, list) else []:
            expr = (f or {}).get("expression") if isinstance(f, dict) else None
            if not expr:
                continue
            qconn.execute(
                "INSERT OR IGNORE INTO kvs_assertion(assertion_id,subject_term,predicate,object_term,"
                "concept_code,evidence,evidence_count,created_at) VALUES (?,?,?,?,?,?,?,?)",
                (_aid("rf", code, expr), titles.get(code, code), "has_%s" % (f.get("kind") or "principle"),
                 expr, code, json.dumps([code]), 1, now))
            n += 1
    qconn.commit()
    return {"reference_fact_assertions": n, "skipped_unparseable": skipped}


def seed_all(kconn: sqlite3.Connection, qconn: sqlite3.Connection, now: str) -> dict:
    out = {}
    out.update(seed_assertions_from_edges(kconn, qconn, now))
    out.update(seed_taxonomy_from_parent_child(kconn, qconn, now))
    out.update(seed_reference_facts(kconn, qconn, now))
    total = qconn.execute("SELECT COUNT(*) FROM kvs_assertion").fetchone()[0]
    promotable = qconn.execute("SELECT COUNT(*) FROM kvs_assertion WHERE evidence_count >= 2").fetchone()[0]
    out["kvs_assertions_total"] = total
    out["kvs_assertions_promotable_ge2_evidence"] = promotable    # honest: how many are verification-usable
    return out
