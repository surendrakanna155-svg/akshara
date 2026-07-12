"""Corrected QIE mining / grouping path (Phase C, slice 3).

Fixes the B-series conflation. For every recovered item it records FOUR independent axes:
  * subject                (guess_subject)
  * assessment_profile     (source provenance -> profiles.profile_for_source)   [NEW — was dropped]
  * canonical concept      (combined bio_resolve + strict resolver)
  * archetype              (assessment FORM, archetypes.classify)               [was written == lane]
and a separate VERIFICATION lane (how the answer is independently checked). Candidate Item Models are grouped
by (subject, profile, concept, archetype) — NOT (lane, concept). The per-model support bar is unchanged
(>=5 distinct DNA from >=2 resources); verification stays lane-specific (numeric relation-match; conceptual
KVS multi-source / Tier-2 agreement). An Item Model can only be CERTIFIED when its archetype is valid for its
profile and the profile is permitted — so profile-invalid evidence cannot certify.

Reuses all B1-B10 evidence sources (kie.db chunks + qcorpus + doc_recover + stranded_recover) and verification
substrates (relations / KVS / Tier-2). Read-only on kie.db; writes qie.db. Deterministic, stdlib-only.
"""
from __future__ import annotations

import hashlib
import json
import os
import sqlite3
from collections import defaultdict
from typing import Dict, Iterator, List, Optional, Set, Tuple

from kie.qie import (mine, relations as R, qcorpus_adapter as QA, doc_recover, stranded_recover as SR,
                     archetypes as A, profiles as P)


def build_profile_lookup(kconn: sqlite3.Connection) -> Tuple[Dict[str, str], Dict[str, str]]:
    """(kie_doc_id -> exam, qcorpus_doc_id -> group) — the source-provenance maps used for profile attribution."""
    kmeta = {r[0]: (r[1] or "") for r in kconn.execute("SELECT doc_id, exam FROM source_documents")}
    qgroup: Dict[str, str] = {}
    inv = os.path.join(QA.STAGING_ROOT, "manifests", "corpus_inventory.jsonl")
    if os.path.exists(inv):
        with open(inv) as f:
            for line in f:
                r = json.loads(line)
                qgroup[r["doc_id"]] = r.get("group", "")
    return kmeta, qgroup


def _profile(it: dict, origin: str, kmeta: Dict[str, str], qgroup: Dict[str, str]) -> Optional[str]:
    if it.get("source"):                       # stranded_recover carries the exam directly
        return P.profile_for_source(it["source"])
    doc = it.get("doc_id") or ""
    src = kmeta.get(doc, "") if origin == "kie" else qgroup.get(doc, "")
    return P.profile_for_source(src)


def stream_items(kconn: sqlite3.Connection) -> Iterator[Tuple[dict, Optional[str]]]:
    """Yield (item, profile) over every reused evidence source (no re-OCR, no new data)."""
    kmeta, qgroup = build_profile_lookup(kconn)
    for it in mine.iter_kie_items(kconn):
        yield it, _profile(it, "kie", kmeta, qgroup)
    for it in QA.recovered_items():
        yield it, _profile(it, "qcorpus", kmeta, qgroup)
    for it in doc_recover.recovered_delta_items():
        yield it, _profile(it, "qcorpus", kmeta, qgroup)
    for it in SR.recovered_items(kconn):
        yield it, _profile(it, "stranded", kmeta, qgroup)


def _dna_id(subject, profile, concept, archetype, lane, doc, stem) -> str:
    return "DC_" + hashlib.sha256(
        f"{subject}|{profile}|{concept}|{archetype}|{lane}|{doc}|{stem[:80]}".encode()).hexdigest()[:16]


def mine_capability(kconn: sqlite3.Connection, qconn: sqlite3.Connection, now: str,
                    resolver, verified_facts: Optional[Set[str]] = None,
                    tier2_verified: Optional[Set[str]] = None, min_dna: int = 5, min_res: int = 2,
                    min_distinct_stems: int = 5, stream=None) -> dict:
    """Build corrected DNA + (subject, profile, concept, archetype) Item-Model candidates and measure them.

    A candidate model is QUALIFIED at >=min_dna distinct DNA from >=min_res resources; GENUINE additionally at
    >=min_distinct_stems distinct stems (anti-replication, honest); VERIFIED per-lane (numeric relation-match,
    or >=50% conceptual DNA facts KVS/Tier-2-verified); CERTIFIABLE only when also profile-valid + permitted."""
    verified_facts = verified_facts or set()
    tier2_verified = tier2_verified or set()
    by_title = mine.build_by_title(kconn)

    clusters: Dict[tuple, dict] = defaultdict(
        lambda: {"dna": set(), "docs": set(), "stems": set(), "verified": set(), "lane": None})
    dna_rows = []
    n_items = 0
    for it, profile in (stream if stream is not None else stream_items(kconn)):
        subj = it.get("subject")
        stem = (it.get("stem") or "").strip()
        if not subj or not stem:
            continue
        n_items += 1
        ans = it.get("answer_text")
        doc = it.get("doc_id") or ""
        concept = mine.item_concept(stem, ans, subj, by_title, resolver)
        # numeric verification / lane
        kv = R.first_number(ans) if ans else None
        given = R.parse_numbers(stem)
        rel = R.verify(given, kv, subject=subj) if (kv is not None and given) else None
        if rel:
            archetype = A.classify(stem, is_numeric=True, relation_verified=True)
            lane = "NUMERIC_RELATIONAL"
            is_verified = True
        else:
            archetype = A.classify(stem, is_numeric=False, relation_verified=False)
            lane = A.verification_lane(archetype) or "CONCEPTUAL_CAUSAL"
            fk = mine.fact_key(concept, ans) if ans else None
            is_verified = bool(fk and mine.is_resolved_concept(concept) and mine.is_semantic_answer(ans or "")
                               and (fk in verified_facts or fk in tier2_verified))
        did = _dna_id(subj, profile, concept, archetype, lane, doc, stem)
        dna_rows.append((did, lane, subj, concept, archetype, profile,
                         json.dumps({"relation": rel} if rel else {"concept": concept})))
        key = (subj, profile, concept, archetype)
        c = clusters[key]
        c["dna"].add(did); c["docs"].add(doc); c["stems"].add(mine.norm_answer(stem)[:60])
        c["lane"] = lane
        if is_verified:
            c["verified"].add(did)

    # persist corrected DNA (assessment_profile + independent archetype/lane)
    for (did, lane, subj, concept, archetype, profile, construction) in dna_rows:
        qconn.execute(
            "INSERT OR IGNORE INTO question_dna(dna_id,lane,subject,concept_code,archetype,assessment_profile,"
            "construction,created_at) VALUES (?,?,?,?,?,?,?,?)",
            (did, lane, subj, concept, archetype, profile, construction, now))

    models = []
    for (subj, profile, concept, archetype), c in clusters.items():
        n_dna, n_res, n_stems = len(c["dna"]), len(c["docs"]), len(c["stems"])
        if n_dna < min_dna or n_res < min_res:
            continue
        lane = c["lane"]
        verified = (lane == "NUMERIC_RELATIONAL") or (len(c["verified"]) / n_dna >= 0.5)
        resolved = mine.is_resolved_concept(concept)
        # a GENUINE Item Model is on a canonical concept with diverse (non-replicated) support
        genuine = resolved and n_stems >= min_distinct_stems
        profile_valid = bool(profile) and P.is_valid_archetype_for(profile, archetype) and P.is_permitted(profile)
        certifiable = verified and genuine and profile_valid
        rec = {"subject": subj, "profile": profile, "concept": concept, "archetype": archetype, "lane": lane,
               "n_dna": n_dna, "n_resources": n_res, "distinct_stems": n_stems, "verified": verified,
               "genuine": genuine, "resolved_concept": resolved, "profile_valid": profile_valid,
               "certifiable": certifiable}
        models.append(rec)
        if certifiable:
            imid = "IMC_" + hashlib.sha256(f"{subj}|{profile}|{concept}|{archetype}".encode()).hexdigest()[:16]
            qconn.execute(
                "INSERT OR REPLACE INTO item_model(item_model_id,lane,archetype,concept_scope,n_dna,"
                "n_resources,allowed_profiles,certification_status,created_at) VALUES (?,?,?,?,?,?,?,?,?)",
                (imid, lane, archetype, json.dumps([concept]), n_dna, n_res, json.dumps([profile]),
                 "ai_validated", now))
    qconn.commit()
    models.sort(key=lambda m: (-m["certifiable"], -m["n_dna"]))
    return {"n_items": n_items, "n_dna": len(dna_rows), "candidate_models": len(models),
            "certifiable_models": sum(1 for m in models if m["certifiable"]), "models": models}
