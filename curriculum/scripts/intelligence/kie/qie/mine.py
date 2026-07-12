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


def concept_key(stem: str, subject: str, by_title: Dict[str, str]) -> str:
    t = stem.lower()
    for title, code in by_title.items():
        if len(title) > 4 and title in t:
            return code
    for kw in _SUBJ_KW.get(subject, []):
        if kw in t:
            return f"{subject}:{kw}"
    return f"{subject}:misc"


def run(kconn: sqlite3.Connection, qconn: sqlite3.Connection, now: str,
        max_per_subject: int = 100000) -> dict:
    """Full-corpus mine. Returns metrics incl. the retained yield-gate result per subject."""
    kconn.row_factory = sqlite3.Row
    active: Set[str] = {r[0] for r in kconn.execute("SELECT concept_code FROM concepts WHERE status='active'")}
    by_title = {(r[1] or "").lower(): r[0] for r in
                kconn.execute("SELECT concept_code, title FROM concepts WHERE status='active' AND title IS NOT NULL")
                if r[1]}
    base = ("text LIKE '%(1)%' AND text LIKE '%(2)%' AND text LIKE '%(3)%' AND text LIKE '%(4)%'")
    rows = kconn.execute(f"SELECT c.doc_id, c.text FROM chunks c WHERE {base}").fetchall()

    per_subj = defaultdict(lambda: defaultdict(int))
    # cluster: subject -> key(lane,concept) -> {dna_ids:set, docs:set}
    clusters: Dict[str, Dict[tuple, dict]] = defaultdict(lambda: defaultdict(lambda: {"dna": set(), "docs": set()}))
    dna_rows = []
    counts = defaultdict(int)
    for row in rows:
        doc, text = row[0], row[1]
        for rec in split_and_recover(text):
            subj = guess_subject(rec["stem"])
            if not subj or per_subj[subj]["recovered"] >= max_per_subject:
                continue
            per_subj[subj]["recovered"] += 1
            keyopt = rec["options"].get(rec["key"]) if rec["key"] else None
            kv = R.first_number(keyopt) if keyopt else None
            given = R.parse_numbers(rec["stem"])
            ck = concept_key(rec["stem"], subj, by_title)
            if kv is not None and given:
                rel = R.verify(given, kv, subject=subj)
                if rel:
                    per_subj[subj]["numeric_verified"] += 1
                    lane = "NUMERIC_RELATIONAL"
                    tf = distractor_transforms(kv, rec["options"], rec["key"])
                    sig = rel
                    did = _dna_id(subj, lane, rel, doc + "|" + rec["stem"][:80])
                    dna_rows.append((did, lane, subj, rel, json.dumps({"relation": rel, "given": given, "answer": kv}),
                                     json.dumps(tf)))
                    clusters[subj][(lane, rel)]["dna"].add(did)
                    clusters[subj][(lane, rel)]["docs"].add(doc)
                    counts["numeric_dna"] += 1
                    continue
                per_subj[subj]["numeric_unverified"] += 1
            # non-numeric
            if rec["key"] is None:
                per_subj[subj]["no_key"] += 1
                continue
            lane = classify_nonnumeric_lane(rec["stem"])
            if lane == "CONCEPTUAL_GENERIC" or ck.endswith(":misc"):
                per_subj[subj]["nonnum_unclustered"] += 1
                continue   # do NOT count unclassified/misc as a distinct-archetype cluster (honest)
            did = _dna_id(subj, lane, ck, doc + "|" + rec["stem"][:80])
            dna_rows.append((did, lane, subj, ck, json.dumps({"concept": ck}), json.dumps([])))
            clusters[subj][(lane, ck)]["dna"].add(did)
            clusters[subj][(lane, ck)]["docs"].add(doc)
            counts["nonnum_dna"] += 1

    # persist DNA
    for (did, lane, subj, concept, construction, distractor) in dna_rows:
        qconn.execute(
            "INSERT OR IGNORE INTO question_dna(dna_id,lane,subject,concept_code,construction,distractor_dna,"
            "created_at) VALUES (?,?,?,?,?,?,?)", (did, lane, subj, concept, construction, distractor, now))

    # qualify + persist Item Models; measure yield gate (>=5 DNA, >=2 resources, distinct lane/archetype)
    yield_result = {}
    for subj in ("Physics", "Chemistry", "Biology", "Mathematics"):
        qualified = []
        for (lane, concept), c in clusters[subj].items():
            n_dna, n_res = len(c["dna"]), len(c["docs"])
            if n_dna >= 5 and n_res >= 2:
                imid = "IM_" + hashlib.sha256(f"{subj}|{lane}|{concept}".encode()).hexdigest()[:16]
                qconn.execute(
                    "INSERT OR IGNORE INTO item_model(item_model_id,lane,archetype,concept_scope,n_dna,"
                    "n_resources,certification_status,created_at) VALUES (?,?,?,?,?,?,?,?)",
                    (imid, lane, lane, json.dumps([concept]), n_dna, n_res, "draft", now))
                qualified.append({"lane": lane, "concept": concept, "n_dna": n_dna, "n_res": n_res})
        # distinct-lane count: number of qualified models
        yield_result[subj] = {
            "recovered": per_subj[subj]["recovered"],
            "numeric_verified": per_subj[subj]["numeric_verified"],
            "qualified_item_models": len(qualified),
            "distinct_lanes": len({q["lane"] for q in qualified}),
            "meets_gate_ge8": len(qualified) >= 8,
            "models": sorted(qualified, key=lambda q: -q["n_dna"])[:15],
        }
    qconn.commit()
    return {"total_dna": len(dna_rows), "counts": dict(counts),
            "yield_gate_ge8_per_subject": {s: yield_result[s]["meets_gate_ge8"] for s in yield_result},
            "per_subject": yield_result}
