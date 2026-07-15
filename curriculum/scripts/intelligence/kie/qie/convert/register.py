"""Governed registration — write VERIFIED, safely-bound facts into the canonical KVS substrate (Phase-6).

Single admission path. A fact reaches here only after: deterministic subject gate (candidates) + independent
examiner verdict (keep && answer_correct && on_topic). This module:
  1. writes the provenance-complete `governed_fact` audit record (verified | rejected | quarantined),
  2. PROJECTS verified facts into the typed KVS table the engine verifies against (structure_function /
     sequence / comparison / taxonomy / assertion), and
  3. seeds `distractor_dna` from the item's REAL wrong options (misconception evidence — learned, not cloned).

Rejected/quarantined verdicts are also persisted (by item_hash) so already-refuted evidence is never
re-examined. No typed-KVS row is ever written without a backing verified `governed_fact`. Writes qie.db only.
"""
from __future__ import annotations

import hashlib
import json
import sqlite3
from typing import Dict, List, Optional


def fact_id(concept_candidate: str, fact_text: str) -> str:
    return "GF_" + hashlib.sha256(f"{concept_candidate}|{fact_text.strip().lower()}".encode()).hexdigest()[:18]


def already_examined(qconn: sqlite3.Connection) -> set:
    """item_hashes with a persisted verdict (verified OR rejected) — never re-send to the examiner."""
    return {r[0] for r in qconn.execute(
        "SELECT item_hash FROM governed_fact WHERE item_hash IS NOT NULL")}


def _project_kvs(qconn: sqlite3.Connection, lane: str, fid: str, subject: str, concept: str,
                 structured: dict, answer: str, evidence: str, now: str) -> Optional[str]:
    """Project a verified fact into the typed KVS store for its lane. Returns the store name, or None if the
    lane has no typed store (assertion fallback)."""
    s = structured or {}
    if lane == "STRUCTURE_FUNCTION" and s.get("structure") and s.get("function"):
        qconn.execute(
            "INSERT OR REPLACE INTO kvs_structure_function(sf_id,structure,function,location,system,evidence,"
            "created_at) VALUES (?,?,?,?,?,?,?)",
            (fid, s["structure"], s["function"], s.get("location"), s.get("system"), evidence, now))
        return "kvs_structure_function"
    if lane == "PROCESS_SEQUENCE" and s.get("process") and isinstance(s.get("ordered_steps"), list) \
            and len(s["ordered_steps"]) >= 3:
        qconn.execute(
            "INSERT OR REPLACE INTO kvs_sequence(seq_id,process_name,ordered_steps,evidence,created_at) "
            "VALUES (?,?,?,?,?)", (fid, s["process"], json.dumps(s["ordered_steps"]), evidence, now))
        return "kvs_sequence"
    if lane == "CLASSIFICATION_TAXONOMIC" and s.get("class_name") and s.get("member"):
        qconn.execute(
            "INSERT OR REPLACE INTO kvs_taxonomy(node_id,class_name,member,is_member,discriminating_attr,"
            "evidence,created_at) VALUES (?,?,?,?,?,?,?)",
            (fid, s["class_name"], s["member"], int(bool(s.get("is_member", True))),
             s.get("discriminating_attr"), evidence, now))
        return "kvs_taxonomy"
    if lane == "COMPARATIVE" and s.get("entity") and s.get("attribute") and s.get("value"):
        qconn.execute(
            "INSERT OR REPLACE INTO kvs_comparison(cmp_id,entity,attribute,value,evidence,created_at) "
            "VALUES (?,?,?,?,?,?)", (fid, s["entity"], s["attribute"], s["value"], evidence, now))
        return "kvs_comparison"
    # assertion fallback (CONCEPTUAL_CAUSAL / ASSERTION_RELATION / GENERIC): subject-predicate-object
    subj_t = s.get("subject_term") or concept.split(" :: ")[-1]
    pred = s.get("predicate") or "fact_about"
    obj_t = s.get("object_term") or answer
    qconn.execute(
        "INSERT OR REPLACE INTO kvs_assertion(assertion_id,subject_term,predicate,object_term,concept_code,"
        "evidence,evidence_count,created_at) VALUES (?,?,?,?,?,?,?,?)",
        ("GFA_" + fid[3:], subj_t, pred, obj_t, concept, evidence, 1, now))
    return "kvs_assertion"


def _seed_distractors(qconn: sqlite3.Connection, fid: str, options: Dict[str, str], answer: str,
                      concept: str, now: str) -> int:
    """Each real wrong option is a misconception token for this concept — learned distractor evidence."""
    n = 0
    ans_norm = (answer or "").strip().lower()
    for lab, txt in (options or {}).items():
        t = (txt or "").strip()
        if not t or t.lower() == ans_norm:
            continue
        did = "DD_" + hashlib.sha256(f"{fid}|{lab}|{t.lower()}".encode()).hexdigest()[:16]
        qconn.execute(
            "INSERT OR REPLACE INTO distractor_dna(distractor_id,item_model_id,misconception_type,transform,"
            "provenance,created_at) VALUES (?,?,?,?,?,?)",
            (did, None, "real_exam_distractor", t,
             json.dumps({"fact_id": fid, "concept": concept, "option_label": lab}), now))
        n += 1
    return n


def register_verified(qconn: sqlite3.Connection, cand, verdict: dict, now: str,
                      verifier_model: str) -> dict:
    """Admit one examiner-verified fact. `cand` is a candidates.Candidate; `verdict` the examiner output.
    Returns {registered, kvs_store, distractors, fact_id}."""
    fact_text = (verdict.get("fact_text") or "").strip()
    answer = (verdict.get("corrected_answer") or cand.answer_text or "").strip()
    fid = fact_id(cand.concept_candidate, fact_text)
    provenance = {
        "doc_id": cand.doc_id, "exam": cand.exam, "chapter": cand.chapter_hint,
        "concept_candidate": cand.concept_candidate, "ocr_score": round(cand.ocr_score, 2),
        "source_answer_label": cand.answer_label, "stem_excerpt": cand.stem[:180],
    }
    verification = {
        "subject_gate": "deterministic_pass", "examiner_verdict": "keep",
        "answer_correct": bool(verdict.get("answer_correct", True)),
        "on_topic": bool(verdict.get("on_topic", True)),
        "independent_method": verdict.get("method", "examiner_re_derivation"),
        "note": verdict.get("reason", ""),
    }
    evidence = json.dumps({"provenance": provenance, "verification": verification})
    qconn.execute(
        "INSERT OR REPLACE INTO governed_fact(fact_id,subject,exam,concept_candidate,certified_concept_code,"
        "lane,fact_text,structured,answer_text,distractors,provenance,verification,verifier_model,status,"
        "reject_reason,item_hash,created_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
        (fid, cand.subject, cand.exam, cand.concept_candidate, verdict.get("certified_concept_code"),
         cand.lane, fact_text, json.dumps(verdict.get("structured") or {}), answer,
         json.dumps([t for l, t in (cand.options or {}).items() if (t or '').strip().lower() != answer.lower()]),
         json.dumps(provenance), json.dumps(verification), verifier_model, "verified", None,
         verdict.get("item_hash"), now))
    # Owner decision B: the examiner PROPOSES a topic; the deterministic gates decide. An ungrounded,
    # invented or truncated topic is refused and the fact keeps its chapter binding (honest fallback), so a
    # bad proposal can never mint a concept — it can only fail to add one.
    topic_verdict = _certify_topic(qconn, fid, verdict, cand, answer)

    store = _project_kvs(qconn, cand.lane, fid, cand.subject, cand.concept_candidate,
                         verdict.get("structured") or {}, answer, evidence, now)
    nd = _seed_distractors(qconn, fid, cand.options, answer, cand.concept_candidate, now)
    qconn.commit()
    return {"registered": True, "kvs_store": store, "distractors": nd, "fact_id": fid,
            "topic": topic_verdict.get("topic"), "topic_status": topic_verdict.get("status")}


def _certify_topic(qconn: sqlite3.Connection, fid: str, verdict: dict, cand, answer: str) -> dict:
    """Certify a proposed topic against the fact's own evidence and persist it when it survives."""
    proposed = (verdict.get("topic") or "").strip()
    if not proposed:
        return {"status": "absent", "topic": None}
    from kie.qie.convert import topics as TP
    fact = {"subject": cand.subject, "concept_candidate": cand.concept_candidate,
            "fact_text": verdict.get("fact_text") or "", "answer_text": answer,
            "structured": json.dumps(verdict.get("structured") or {}),
            "provenance": json.dumps({"stem_excerpt": cand.stem[:180], "chapter": cand.chapter_hint})}
    v = TP.certify(proposed, fact)
    if v["status"] != "certified":
        return {"status": "rejected", "topic": None, "failed_gates": v["failed_gates"]}
    safe = {g: {k: x for k, x in d.items() if isinstance(x, (bool, str, int, float, list))}
            for g, d in v["gates"].items()}
    qconn.execute("UPDATE governed_fact SET topic=?, topic_evidence=? WHERE fact_id=?",
                  (v["topic"], json.dumps({"gates": safe, "proposed": proposed}), fid))
    return {"status": "certified", "topic": v["topic"]}


def register_rejected(qconn: sqlite3.Connection, cand, verdict: dict, now: str, verifier_model: str) -> None:
    """Persist a reject/quarantine so the same evidence is never re-examined."""
    fid = fact_id(cand.concept_candidate, verdict.get("item_hash", cand.signature))
    prov = {"doc_id": cand.doc_id, "chapter": cand.chapter_hint, "stem_excerpt": cand.stem[:180]}
    qconn.execute(
        "INSERT OR REPLACE INTO governed_fact(fact_id,subject,exam,concept_candidate,lane,fact_text,"
        "answer_text,provenance,verification,verifier_model,status,reject_reason,item_hash,created_at) "
        "VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
        (fid, cand.subject, cand.exam, cand.concept_candidate, cand.lane, "", cand.answer_text,
         json.dumps(prov), json.dumps({"examiner_verdict": "reject"}), verifier_model,
         "rejected", verdict.get("reason", "examiner_reject"), verdict.get("item_hash"), now))
    qconn.commit()


def counts(qconn: sqlite3.Connection) -> dict:
    def q(sql):
        try:
            return qconn.execute(sql).fetchone()[0]
        except Exception:
            return None
    return {
        "governed_fact_verified": q("SELECT COUNT(*) FROM governed_fact WHERE status='verified'"),
        "governed_fact_rejected": q("SELECT COUNT(*) FROM governed_fact WHERE status='rejected'"),
        "kvs_structure_function": q("SELECT COUNT(*) FROM kvs_structure_function"),
        "kvs_sequence": q("SELECT COUNT(*) FROM kvs_sequence"),
        "kvs_comparison": q("SELECT COUNT(*) FROM kvs_comparison"),
        "kvs_taxonomy_gf": q("SELECT COUNT(*) FROM kvs_taxonomy WHERE node_id LIKE 'GF_%'"),
        "kvs_assertion_gf": q("SELECT COUNT(*) FROM kvs_assertion WHERE assertion_id LIKE 'GFA_%'"),
        "distractor_dna": q("SELECT COUNT(*) FROM distractor_dna"),
    }
