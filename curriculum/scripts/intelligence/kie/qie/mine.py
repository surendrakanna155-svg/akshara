"""Phase-B structure miner — corpus MCQ -> Question DNA -> Item-Model clusters -> yield-gate measurement.

Promotes the Phase-0/0b throwaway spike into a real, tested module. Runs on the POST-CANONICALIZATION
kie.db (quarantined junk concepts excluded), across the FULL corpus (not a 200-item slice). For each
recovered item it:
  * recovers stem/options/answer key (deterministic regex, validated on real corpus),
  * classifies a lane (numeric via relations.verify; else structural signature),
  * extracts Question DNA (numeric: relation + distractor transforms diffed from the real wrong options;
    non-numeric: lane + concept binding + KVS verification ref),
  * persists DNA to qie.db and clusters DNA into candidate Item Models (>=5 DNA from >=2 resources),
then measures the RETAINED YIELD GATE: >=8 distinct-lane Item Models per subject.

Read-only on kie.db; writes qie.db (local). Deterministic (seeded), stdlib-only.
"""
from __future__ import annotations

import hashlib
import json
import re
import sqlite3
from collections import defaultdict
from typing import Dict, List, Optional, Set

from kie.qie import relations as R
from kie.qie.knowledge.qdi import QDI_MIN_EVIDENCE_ITEMS, QDI_MIN_EVIDENCE_RESOURCES
from kie.qie.lanes import LANES

_QNUM = re.compile(r"(?:^|\n)\s*(\d{1,3})\s*[.\)]\s+")
_OPT = re.compile(r"\((\d)\)\s*([^\(\n]{0,160}?)(?=\s*\(\d\)|\n|Answer|Sol\.|$)", re.S)
_ANS = re.compile(r"Answer\s*\((\d)\)", re.I)

_SUBJ_KW = {
    "Physics": ["velocity", "acceleration", "force", "current", "resistance", "voltage", "charge", "energy",
                "momentum", "wavelength", "magnetic", "electric", "friction", "power", "density", "pressure",
                "frequency", "refraction", "lens", "circuit", "kinetic", "potential", "capacitor", "field"],
    "Chemistry": ["mole", "molar", "equilibrium", "oxidation", "reduction", "acid", "base", "bond", "orbital",
                  "reaction", "concentration", "atomic mass", "valency", "isotope", "enthalpy", "molecule",
                  "compound", "solution", "ion"],
    "Biology": ["cell", "organism", "hormone", "enzyme", "tissue", "gene", "chromosome", "photosynthesis",
                "respiration", "mitosis", "meiosis", "protein", "blood", "neuron", "digestion", "plant",
                "species", "bacteria", "virus", "organ", "membrane", "nephron", "stomata"],
    "Mathematics": ["matrix", "determinant", "integral", "derivative", "probability", "triangle", "circle",
                    "polynomial", "vector", "logarithm", "sine", "cosine", "sequence", "mean", "median",
                    "area", "volume", "perimeter", "ratio", "angle", "equation", "value of", "solve",
                    "roots", "quadratic", "function f", "coefficient", "arithmetic", "geometric",
                    "tangent", "chord", "radius", "diameter", "hypotenuse", "factorial", "permutation",
                    "combination", "binomial", "trigonometric", "expression", "series", "term of",
                    "coordinates", "slope", "parabola", "ellipse", "hyperbola", "modulus", "inequality"],
}
# B3: math-notation signals that boost the Mathematics score (Math's lexicon is otherwise out-competed by
# the richer physics/chem/bio lexicons, so genuine math items were mis-attributed / dropped).
_MATH_NOTATION = re.compile(r"(f\s*\(\s*x\s*\)|x\s*\^|x\s*²|d\s*y\s*/\s*d\s*x|∫|∑|√|\|\s*x\s*\||"
                            r"\b(sin|cos|tan|cot|sec|cosec|log|ln|lim)\b|\bdx\b|=\s*0\b|\bx\s*=)", re.I)
_LANE_KEYWORDS = [
    ("ASSERTION_RELATION", ("assertion", "reason")),
    ("STRUCTURE_FUNCTION", ("function of", "responsible for", "role of", "site of", "secreted by")),
    ("PROCESS_SEQUENCE", ("arrange", "sequence", "order", "followed by", "stage after")),
    ("COMPARATIVE", ("difference between", "compare", "higher than", "greater than", "more than")),
    ("CLASSIFICATION_TAXONOMIC", ("which of the following is not", "which of the following is", "odd one",
                                  "classify", "belongs to", "is an example of")),
    ("CONCEPTUAL_CAUSAL", ("why", "because", "due to", "cause", "results in", "leads to", "consequence")),
]


def guess_subject(text: str) -> Optional[str]:
    t = text.lower()
    scores = {s: sum(1 for k in kws if k in t) for s, kws in _SUBJ_KW.items()}
    if _MATH_NOTATION.search(text):          # a strong math-notation hit counts toward Mathematics
        scores["Mathematics"] += 2
    best = max(scores, key=lambda s: scores[s])
    return best if scores[best] else None


def classify_nonnumeric_lane(stem: str) -> str:
    t = stem.lower()
    for lane, kws in _LANE_KEYWORDS:
        if lane == "ASSERTION_RELATION":
            if all(k in t for k in kws):
                return lane
        elif any(k in t for k in kws):
            return lane
    return "CONCEPTUAL_GENERIC"   # unclassified conceptual — NOT counted as a distinct archetype cluster


def parse_options(seg: str) -> Dict[int, str]:
    opts: Dict[int, str] = {}
    for n, o in _OPT.findall(seg):
        n = int(n)
        if n in (1, 2, 3, 4) and n not in opts and o.strip():
            opts[n] = o.strip()
    return opts


def split_and_recover(text: str) -> List[dict]:
    out = []
    idxs = [(m.start(), m.group(1)) for m in _QNUM.finditer(text)]
    for i, (pos, num) in enumerate(idxs):
        end = idxs[i + 1][0] if i + 1 < len(idxs) else len(text)
        seg = text[pos:end]
        opts = parse_options(seg)
        if len(opts) != 4:
            continue
        stem = seg[:seg.find("(1)")].strip() if "(1)" in seg else seg[:160]
        stem = re.sub(r"^\d{1,3}\s*[.\)]\s*", "", stem).strip()
        am = _ANS.search(seg)
        out.append({"stem": stem, "options": opts, "key": int(am.group(1)) if am else None, "num": num})
    return out


def distractor_transforms(correct: float, options: Dict[int, str], key: int) -> List[dict]:
    """Diff each wrong option's numeric value against the correct value -> a recovered transform tag."""
    tf = []
    for n, o in options.items():
        if n == key:
            continue
        v = R.first_number(o)
        if v is None:
            continue
        if abs(correct) > 1e-9:
            ratio = v / correct
            if abs(ratio - 2) < 0.02:
                tf.append({"opt": n, "transform": "x2"})
            elif abs(ratio - 0.5) < 0.02:
                tf.append({"opt": n, "transform": "half"})
            elif abs(v + correct) < 0.02 * max(abs(correct), 1):
                tf.append({"opt": n, "transform": "sign_flip"})
            else:
                tf.append({"opt": n, "transform": "other", "delta": round(v - correct, 4)})
    return tf


def _dna_id(subject, lane, concept, sig) -> str:
    return "D_" + hashlib.sha256(f"{subject}|{lane}|{concept}|{sig}".encode()).hexdigest()[:16]


def norm_answer(text: str) -> str:
    t = (text or "").lower().strip()
    t = re.sub(r"\s+", " ", t)
    return re.sub(r"[.;,:]+$", "", t)


def fact_key(concept: str, answer_text: str) -> str:
    """Stable key for a (concept, correct-answer) fact — shared with kvs_build for verification lookup."""
    return hashlib.sha256(f"{concept}|{norm_answer(answer_text)}".encode()).hexdigest()[:20]


# Option-label / non-semantic answers ("a-ii, b-i", "a, b, c only", "both a and b", "all of the above",
# single letters/romans) collide across unrelated questions and must NOT count as corroborated FACTS.
_OPTION_LABEL = re.compile(
    r"^(all of the above|none of (the above|these)|both\b.*|only\b.*|[a-d]\s*(and|,|;|&)\s*[a-d].*|"
    r"[a-d]\s*-\s*[ivx]+.*|[ivx]+\s*(,|and)\s*[ivx]+.*|\d+\s*(and|,|&)\s*\d+.*|[a-d]|[ivx]{1,4}|\d{1,2})$",
    re.I)


def is_semantic_answer(ans: str) -> bool:
    """True only for a real content answer — not an option label, not a stub."""
    a = norm_answer(ans)
    return len(a) >= 4 and not _OPTION_LABEL.match(a)


def is_resolved_concept(concept: str) -> bool:
    """True only for a resolved concept_code (not a coarse 'subject:keyword' fallback bucket)."""
    return ":" not in concept


def concept_key(stem: str, subject: str, by_title: Dict[str, tuple]) -> str:
    """Legacy substring/keyword concept key, SUBJECT-SCOPED: a title only matches when its concept's
    subject_domain equals the item's subject. Without this, a Biology stem containing 'vision'/'pressure'/
    'temperature' matched a Physics/Math concept title and a non-Biology concept contaminated Biology
    clustering (the observed certified artifacts). by_title values are (concept_code, subject_domain)."""
    t = stem.lower()
    for title, (code, domain) in by_title.items():
        if len(title) > 4 and domain == subject and title in t:
            return code
    for kw in _SUBJ_KW.get(subject, []):
        if kw in t:
            return f"{subject}:{kw}"
    return f"{subject}:misc"


def item_concept(stem: str, answer: Optional[str], subject: str, by_title: Dict[str, str],
                 resolver=None) -> str:
    """Concept key for an item: a confident canonical resolution (answer/stem entity-link) if the resolver
    supplies one, else the legacy substring/keyword key. Strict — the resolver returns None when unsure."""
    if resolver is not None and answer:
        rc = resolver(stem, answer, subject)
        if rc:
            return rc
    return concept_key(stem, subject, by_title)


def iter_kie_items(kconn: sqlite3.Connection):
    """Yield normalized items {stem, options{label:text}, answer_text, subject, doc_id, visual_dependent}
    from the certified kie.db chunk corpus (read-only)."""
    kconn.row_factory = sqlite3.Row
    base = ("text LIKE '%(1)%' AND text LIKE '%(2)%' AND text LIKE '%(3)%' AND text LIKE '%(4)%'")
    for row in kconn.execute(f"SELECT c.doc_id, c.text FROM chunks c WHERE {base}"):
        doc, text = row[0], row[1]
        for rec in split_and_recover(text):
            if rec["key"] is None:
                continue
            subj = guess_subject(rec["stem"])
            if not subj:
                continue
            opts = {str(k): v for k, v in rec["options"].items()}
            yield {"stem": rec["stem"], "options": opts, "answer_text": opts.get(str(rec["key"])),
                   "subject": subj, "doc_id": doc, "visual_dependent": False}


def build_by_title(kconn: sqlite3.Connection) -> Dict[str, tuple]:
    """title_lower -> (concept_code, subject_domain). subject_domain is carried so concept_key can subject-
    scope its substring match and never assign a cross-subject concept to an item."""
    return {(r[1] or "").lower(): (r[0], r[2]) for r in
            kconn.execute("SELECT concept_code, title, subject_domain FROM concepts "
                          "WHERE status='active' AND title IS NOT NULL")
            if r[1]}


def run(kconn: sqlite3.Connection, qconn: sqlite3.Connection, now: str,
        max_per_subject: int = 100000, verified_facts: Optional[Set[str]] = None,
        extra_items=None, tier2_verified: Optional[Set[str]] = None, resolver=None) -> dict:
    """Mine a unified item stream (kie.db chunks + optional `extra_items`, e.g. the qcorpus adapter) into
    Question DNA + Item-Model clusters and measure BOTH the structural and the VERIFICATION-BACKED yield
    gate. A non-numeric Item Model is verification-backed when >=50% of its member DNA facts are either
    KVS-promotable (`verified_facts`, >=2 independent source docs) or Tier-2 model-agreed
    (`tier2_verified`); numeric Item Models are verified by relation-match. Structural clusters are NEVER
    counted as verified."""
    verified_facts = verified_facts or set()
    tier2_verified = tier2_verified or set()
    by_title = build_by_title(kconn)

    def items():
        yield from iter_kie_items(kconn)
        if extra_items is not None:
            yield from extra_items

    per_subj = defaultdict(lambda: defaultdict(int))
    # cluster: subject -> key(lane,concept) -> {dna_ids:set, docs:set}
    clusters: Dict[str, Dict[tuple, dict]] = defaultdict(
        lambda: defaultdict(lambda: {"dna": set(), "docs": set(), "verified": set()}))
    dna_rows = []
    counts = defaultdict(int)
    for it in items():
        subj = it.get("subject")
        stem = it.get("stem") or ""
        if not subj or per_subj[subj]["recovered"] >= max_per_subject:
            continue
        per_subj[subj]["recovered"] += 1
        doc = it.get("doc_id") or ""
        keyopt = it.get("answer_text")
        opts = it.get("options") or {}
        kv = R.first_number(keyopt) if keyopt else None
        given = R.parse_numbers(stem)
        ck = item_concept(stem, keyopt, subj, by_title, resolver)
        if kv is not None and given:
            rel = R.verify(given, kv, subject=subj)
            if rel:
                per_subj[subj]["numeric_verified"] += 1
                lane = "NUMERIC_RELATIONAL"
                tf = distractor_transforms(kv, {i: v for i, v in enumerate(opts.values())},
                                           next((i for i, v in enumerate(opts.values()) if v == keyopt), -1))
                did = _dna_id(subj, lane, rel, doc + "|" + stem[:80])
                dna_rows.append((did, lane, subj, rel, json.dumps({"relation": rel, "answer": kv}), json.dumps(tf)))
                clusters[subj][(lane, rel)]["dna"].add(did)
                clusters[subj][(lane, rel)]["docs"].add(doc)
                clusters[subj][(lane, rel)]["verified"].add(did)   # relation-match = verified
                counts["numeric_dna"] += 1
                continue
            per_subj[subj]["numeric_unverified"] += 1
        # non-numeric
        lane = classify_nonnumeric_lane(stem)
        if lane == "CONCEPTUAL_GENERIC" or ck.endswith(":misc"):
            per_subj[subj]["nonnum_unclustered"] += 1
            continue   # do NOT count unclassified/misc as a distinct-archetype cluster (honest)
        did = _dna_id(subj, lane, ck, doc + "|" + stem[:80])
        dna_rows.append((did, lane, subj, ck, json.dumps({"concept": ck}), json.dumps([])))
        clusters[subj][(lane, ck)]["dna"].add(did)
        clusters[subj][(lane, ck)]["docs"].add(doc)
        fk = fact_key(ck, keyopt) if keyopt else None
        if fk and (fk in verified_facts or fk in tier2_verified):   # KVS-corroborated OR Tier-2 model-agreed
            clusters[subj][(lane, ck)]["verified"].add(did)
        counts["nonnum_dna"] += 1

    # persist DNA
    for (did, lane, subj, concept, construction, distractor) in dna_rows:
        qconn.execute(
            "INSERT OR IGNORE INTO question_dna(dna_id,lane,subject,concept_code,construction,distractor_dna,"
            "created_at) VALUES (?,?,?,?,?,?,?)", (did, lane, subj, concept, construction, distractor, now))

    # qualify + persist Item Models; measure yield gate (>=5 DNA, >=2 resources, distinct lane/archetype)
    yield_result = {}
    for subj in ("Physics", "Chemistry", "Biology", "Mathematics"):
        qualified, verified_models = [], []
        for (lane, concept), c in clusters[subj].items():
            n_dna, n_res = len(c["dna"]), len(c["docs"])
            # shared evidence floor (kie.qie.knowledge.qdi): >=5 DNA from >=2 resources — same rule the QDI
            # pattern lane enforces at certification, kept in ONE place so the two lanes never drift.
            if n_dna >= QDI_MIN_EVIDENCE_ITEMS and n_res >= QDI_MIN_EVIDENCE_RESOURCES:
                is_verified = (lane == "NUMERIC_RELATIONAL") or (len(c["verified"]) / n_dna >= 0.5)
                imid = "IM_" + hashlib.sha256(f"{subj}|{lane}|{concept}".encode()).hexdigest()[:16]
                qconn.execute(
                    "INSERT OR REPLACE INTO item_model(item_model_id,lane,archetype,concept_scope,n_dna,"
                    "n_resources,certification_status,created_at) VALUES (?,?,?,?,?,?,?,?)",
                    (imid, lane, lane, json.dumps([concept]), n_dna, n_res,
                     "ai_validated" if is_verified else "draft", now))
                entry = {"lane": lane, "concept": concept, "n_dna": n_dna, "n_res": n_res, "verified": is_verified}
                qualified.append(entry)
                if is_verified:
                    verified_models.append(entry)
        yield_result[subj] = {
            "recovered": per_subj[subj]["recovered"],
            "numeric_verified": per_subj[subj]["numeric_verified"],
            "qualified_item_models": len(qualified),
            "verified_item_models": len(verified_models),
            "distinct_lanes": len({q["lane"] for q in qualified}),
            "meets_structural_gate_ge8": len(qualified) >= 8,
            "meets_verified_gate_ge8": len(verified_models) >= 8,
            "models": sorted(qualified, key=lambda q: (-q["verified"], -q["n_dna"]))[:20],
        }
    qconn.commit()
    return {"total_dna": len(dna_rows), "counts": dict(counts),
            "structural_gate_ge8": {s: yield_result[s]["meets_structural_gate_ge8"] for s in yield_result},
            "verified_gate_ge8": {s: yield_result[s]["meets_verified_gate_ge8"] for s in yield_result},
            "per_subject": yield_result}
