"""Reconcile qie.db + the two factory stores + the frozen-index crosswalk into per-asset manifest records.

Classifies every verified/certified asset (asset_class, is_deterministic, evidence_class), re-verifies it with
the ported battery (deterministic-certifies law), computes the factory dedup keys (item_hash / norm_hash — the
RI-9 keys), and resolves the KC_ crosswalk (honest-null when unresolved). Emits plain dicts; `manifest.py`
dedups + writes them. READ-ONLY over every source store.

Promotion classes (assigned here from the re-verification result, deterministic):
  * relation, notation-recovery re-certifies      -> `promotable`   (evidence_class=source_proven)  [highest]
  * numeric pilot item, rendered re-verify AGREES -> `practice_tier_eligible` (reverify_ok=1)
  * other deterministic pilot item (payload not persisted) -> `practice_tier_eligible` (reverify_ok=NULL, honest-null)
  * model-agreement pilot item (`agree`)          -> `held_qualitative`  (R4-3; is_deterministic=0)
  * governed_fact (model examiner)                -> `held_qualitative`  (R4-3)
  * kvs_assertion, >=2 source refs                -> `eligible` evidence fact; else `held_low_quality` (honest-null)
  * anything whose re-verify REFUTES it           -> `quarantined`
  * a source-rejected row                         -> `rejected_source` (rejected evidence is PRESERVED, audit §11)
"""
from __future__ import annotations

import hashlib
import json
import sqlite3
from typing import Any, Dict, Iterator, Optional

from kie.qie.factory.gates import item_hash, norm_hash
from kie.qie.inventory.crosswalk import Crosswalk
from kie.qie.verifiers import battery, notation_recovery

# source-store logical names (used in uid + provenance; the physical path lives in the opener)
QIE = "qie.db"
BANK = "qpl_question_bank.db"
CORPUS = "factory_corpus.db"


def _uid(store: str, table: str, sid: str) -> str:
    return "UI_" + hashlib.sha256(f"{store}|{table}|{sid}".encode()).hexdigest()[:24]


def _opts_dict(v) -> Dict[str, str]:
    if isinstance(v, dict):
        return v
    try:
        d = json.loads(v or "{}")
        return d if isinstance(d, dict) else {}
    except (json.JSONDecodeError, TypeError):
        return {}


def _rec(**kw) -> Dict[str, Any]:
    base = dict(source_status=None, subject=None, exam=None, concept_code_src=None, compose_concept=None,
                concept_kc=None, verification_methods=None, is_deterministic=0, evidence_class=None,
                evidence_refs=None, item_hash=None, norm_hash=None, promotion_status="honest_null",
                qualitative_grounding=None, promotion_target=None, reverify_method=None, reverify_ok=None)
    base.update(kw)
    base["uid"] = _uid(base["source_store"], base["source_table"], base["source_id"])
    return base


# ── qie.db: pilot_verified_item (the 1,496) ───────────────────────────────────────────────────────────
def iter_pilot_items(qie: sqlite3.Connection, xw: Crosswalk) -> Iterator[Dict[str, Any]]:
    for r in qie.execute("SELECT * FROM pilot_verified_item"):
        row = dict(r)
        method = str(row.get("refuter_verdict") or "")
        opts = _opts_dict(row.get("options"))
        v = battery.reverify_from_record(row)
        ih = item_hash(row.get("stem") or "", opts, str(row.get("answer_text")))
        nh = norm_hash(row.get("stem") or "")
        is_det = 1 if battery.is_deterministic_method(method) else 0
        if method == "agree":                              # model agreement -> R4-3
            status, ev = "held_qualitative", "model_agreed_on_owned_evidence"
        elif v.ok is False:                                # re-verify REFUTED it
            status, ev = "quarantined", None
        else:                                              # agree (ok=True) or honest-null (ok=None)
            status = "practice_tier_eligible"
            ev = "sympy_rederived" if v.ok is True else None
        yield _rec(
            source_store=QIE, source_table="pilot_verified_item", source_id=row["gen_id"],
            source_status="verified", asset_class="question_item", subject=row.get("subject"),
            exam=row.get("profile"), concept_code_src=row.get("concept_code"),
            concept_kc=xw.resolve(row.get("subject"), row.get("concept_code")),
            verification_methods=json.dumps([method]), is_deterministic=is_det, evidence_class=ev,
            evidence_refs=json.dumps({"correct_fact_key": row.get("correct_fact_key"),
                                      "item_model_id": row.get("item_model_id")}),
            item_hash=ih, norm_hash=nh, promotion_status=status,
            reverify_method=method, reverify_ok=(None if v.ok is None else int(v.ok)))


# ── qie.db: governed_relation (41 certified + 8 rejected) — RE-RUN the 5-gate certifier ────────────────
def iter_relations(qie: sqlite3.Connection, xw: Crosswalk) -> Iterator[Dict[str, Any]]:
    for r in qie.execute("SELECT * FROM governed_relation"):
        row = dict(r)
        v = notation_recovery.reverify_relation_row(row)
        if row.get("status") != "certified":
            status = "rejected_source"
        elif v.ok:
            status = "promotable"
        else:
            status = "quarantined"                          # was certified but no longer re-certifies
        yield _rec(
            source_store=QIE, source_table="governed_relation", source_id=row["relation_id"],
            source_status=row.get("status"), asset_class="relation", subject=row.get("subject"),
            exam=row.get("exam"), concept_code_src=row.get("concept_candidate"),
            # RI-6: the product-binding key the relation_compose generator emits ("Subject :: name"). Computed
            # here so the manifest is the ONE surface qp_bridge reads for scope; keys match the generator by
            # construction. Only a `promotable` (re-certified) relation is admitted to a paper's boundary.
            compose_concept=(f"{row.get('subject')} :: {row.get('name')}" if row.get("name") else None),
            concept_kc=xw.resolve(row.get("subject"), row.get("concept_candidate")),
            verification_methods=json.dumps(["notation_recovery"]),
            is_deterministic=1, evidence_class=("source_proven" if v.ok else None),
            evidence_refs=json.dumps({"equation": row.get("equation"), "gates": v.evidence.get("gates"),
                                      "provenance": _loads(row.get("provenance"))}),
            promotion_status=status, reverify_method="notation_recovery",
            reverify_ok=(1 if v.ok else 0))


# ── qie.db: governed_fact (128 verified, model examiner) -> HELD for R4-3 ──────────────────────────────
def iter_facts(qie: sqlite3.Connection, xw: Crosswalk, corroboration_index=None) -> Iterator[Dict[str, Any]]:
    from kie.qie.convert import topics as TP
    from kie.qie.verifiers import qualitative as QUAL
    idx = corroboration_index if corroboration_index is not None else QUAL.build_corroboration_index(qie)
    for r in qie.execute("SELECT * FROM governed_fact"):
        row = dict(r)
        verified = row.get("status") == "verified"
        # R4-3: the NON-MODEL qualitative re-derivation verdict (independent >=2-source KVS corroboration).
        # Orthogonal to promotion_status; a model examiner can never certify here (assert_not_model_agreement).
        grounding = QUAL.grounding_label(QUAL.reverify_fact(row, idx)) if verified else None
        yield _rec(
            source_store=QIE, source_table="governed_fact", source_id=row["fact_id"],
            source_status=row.get("status"), asset_class="fact", subject=row.get("subject"),
            exam=row.get("exam"), concept_code_src=row.get("concept_candidate"),
            # RI-6: the product-binding key the kvs_compose generator emits — the fact's certified TOPIC
            # ("Biology :: Uricotelism"), chapter fallback — computed via the SAME topics.concept_key the
            # generator + old qp_bridge used, so binding is identical. A fact is `held_qualitative` (model
            # examiner, non-deterministic); it defines curriculum membership only and is honestly labelled as
            # such until R4-3 supplies the non-model re-derivation.
            compose_concept=(TP.concept_key(row) if verified else None),
            concept_kc=xw.resolve(row.get("subject"), row.get("certified_concept_code"),
                                  row.get("topic"), row.get("concept_candidate")),
            verification_methods=json.dumps(["subject_gate+model_examiner"]),
            is_deterministic=0,                             # examiner is a MODEL — never independently certified
            evidence_class=("model_agreed_on_owned_evidence" if verified else None),
            evidence_refs=json.dumps({"topic": row.get("topic"), "verifier_model": row.get("verifier_model"),
                                      "item_hash": row.get("item_hash")}),
            item_hash=row.get("item_hash"),
            promotion_status=("held_qualitative" if verified else "rejected_source"),
            qualitative_grounding=grounding,                # R4-3 non-model examination verdict (independent KVS)
            reverify_method=("independent_kvs_corroboration" if verified else None),
            reverify_ok=(1 if grounding == QUAL.GROUNDING_CORROBORATED else None))  # honest-null unless corroborated


# ── qie.db: kvs_assertion (>=2 source refs = evidence fact; else honest-null) ──────────────────────────
def iter_kvs(qie: sqlite3.Connection, xw: Crosswalk) -> Iterator[Dict[str, Any]]:
    for r in qie.execute("SELECT * FROM kvs_assertion"):
        row = dict(r)
        ec = row.get("evidence_count") or 0
        grounded = ec >= 2                                  # QDI's own >=2-resource rule
        yield _rec(
            source_store=QIE, source_table="kvs_assertion", source_id=row["assertion_id"],
            source_status=f"evidence_count={ec}", asset_class="kvs_assertion", subject=None,
            concept_code_src=row.get("concept_code"),
            concept_kc=xw.resolve(None, row.get("concept_code")),
            verification_methods=json.dumps(["source_ref_count"]),
            is_deterministic=1,                             # deterministic clustering
            evidence_class=("source_proven" if grounded else None),
            evidence_refs=json.dumps({"subject_term": row.get("subject_term"),
                                      "predicate": row.get("predicate"),
                                      "object_term": row.get("object_term"), "evidence_count": ec}),
            promotion_status=("eligible" if grounded else "held_low_quality"),
            reverify_method="source_ref_count", reverify_ok=(1 if grounded else None))


# ── factory stores: candidates (already carry item_hash/stem_norm_hash) ────────────────────────────────
def iter_factory(conn: sqlite3.Connection, store_name: str, xw: Crosswalk) -> Iterator[Dict[str, Any]]:
    specs = {r["spec_id"]: r for r in conn.execute(
        "SELECT spec_id, subject, exam_profile, concept_code FROM generation_spec")}
    for r in conn.execute("SELECT * FROM candidate WHERE stem IS NOT NULL AND stem!=''"):
        row = dict(r)
        sp = specs.get(row.get("spec_id"))
        subj = sp["subject"] if sp else None
        st = row.get("status")
        cc = row.get("certification_class")
        if st == "certified" and cc == "trial_certified":
            status = "held_trial"                           # trial store: product-invisible by design
        elif st == "certified":
            status = "promotable"
        elif st == "quarantined":
            status = "quarantined"
        elif st == "rejected":
            status = "rejected_source"
        else:                                               # expired_unjudged / candidate
            status = "honest_null"
        yield _rec(
            source_store=store_name, source_table="candidate", source_id=row["candidate_id"],
            source_status=st, asset_class="question_item", subject=subj,
            exam=(sp["exam_profile"] if sp else None),
            concept_code_src=(sp["concept_code"] if sp else None),
            concept_kc=xw.resolve(subj, sp["concept_code"] if sp else None),
            verification_methods=json.dumps(["factory_sympy_gate"]),
            is_deterministic=1, evidence_class=row.get("evidence_class"),
            evidence_refs=json.dumps({"run_id": row.get("run_id"), "certification_class": cc}),
            item_hash=row.get("item_hash"), norm_hash=row.get("stem_norm_hash"),
            promotion_status=status, reverify_method=None, reverify_ok=None)


def _loads(v):
    try:
        return json.loads(v) if v else None
    except (json.JSONDecodeError, TypeError):
        return None
