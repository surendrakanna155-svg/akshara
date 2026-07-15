"""Admission path for recovered relations — certify first, then register. Writes qie.db only.

Nothing reaches `governed_relation` without passing the locked hierarchy in `verify.certify`. Rejects are
persisted with their failing gates so the same damaged transcription is never re-processed.
"""
from __future__ import annotations

import hashlib
import json
import sqlite3
from typing import List, Optional

from kie.qie.convert.notation import verify as V


def relation_id(subject: str, equation: str) -> str:
    canon = equation.replace(" ", "").lower()
    return "GR_" + hashlib.sha256(f"{subject}|{canon}".encode()).hexdigest()[:18]


def register(qconn: sqlite3.Connection, rel: dict, now: str, extractor: str,
             corroboration_items: Optional[List[dict]] = None) -> dict:
    """Certify + admit one recovered relation. Returns the verdict (status/failed gates)."""
    verdict = V.certify(rel, corroboration_items)
    rid = relation_id(rel["subject"], rel["equation"])
    gates = verdict["gates"]
    # gate objects can hold sympy exprs (parse) — keep only json-safe evidence
    safe_gates = {g: {k: v for k, v in d.items() if isinstance(v, (bool, str, int, float, list, dict))}
                  for g, d in gates.items()}
    qconn.execute(
        "INSERT OR REPLACE INTO governed_relation(relation_id,name,subject,concept_candidate,exam,equation,"
        "display,lhs_unit,symbols,meanings,constants,constraints,value_ranges,provenance,verification,status,"
        "reject_reason,extractor,created_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
        (rid, rel["name"], rel["subject"], rel["concept_candidate"], rel.get("exam"), rel["equation"],
         rel.get("display"), rel.get("lhs_unit", ""), json.dumps(rel.get("symbols") or {}),
         json.dumps(rel.get("meanings") or {}), json.dumps(rel.get("constants") or []),
         json.dumps(rel.get("constraints") or []), json.dumps(rel.get("value_ranges") or {}),
         json.dumps(rel.get("provenance") or {}),
         json.dumps({"gates": safe_gates, "corroboration": verdict.get("corroboration")}),
         verdict["status"], ", ".join(verdict["failed_gates"]) or None, extractor, now))
    qconn.commit()
    return {**verdict, "relation_id": rid}


def counts(qconn: sqlite3.Connection) -> dict:
    def q(sql):
        try:
            return qconn.execute(sql).fetchone()[0]
        except Exception:
            return None
    return {
        "certified": q("SELECT COUNT(*) FROM governed_relation WHERE status='certified'"),
        "rejected": q("SELECT COUNT(*) FROM governed_relation WHERE status='rejected'"),
        "by_subject": dict(qconn.execute(
            "SELECT subject, COUNT(*) FROM governed_relation WHERE status='certified' GROUP BY subject")
            .fetchall()),
    }


def certified(qconn: sqlite3.Connection, subject: Optional[str] = None) -> List[dict]:
    qconn.row_factory = sqlite3.Row
    q = "SELECT * FROM governed_relation WHERE status='certified'"
    args: tuple = ()
    if subject:
        q += " AND subject=?"
        args = (subject,)
    out = []
    for r in qconn.execute(q, args):
        d = dict(r)
        for k in ("symbols", "meanings", "constants", "constraints", "value_ranges", "provenance", "verification"):
            try:
                d[k] = json.loads(d[k] or "{}")
            except Exception:
                d[k] = {}
        out.append(d)
    return out
