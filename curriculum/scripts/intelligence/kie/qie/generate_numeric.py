"""Certified-relation → numeric question generation (Phase D expansion: NEET Physics/Chemistry).

Extends the certified→generate→verify bridge to NUMERIC single_step_numerical items. The certified capability
here is the set of relation-solver-verified relations with >=5-doc NEET support (measured: V=IR, n=m/M, R=V/I,
KE=.5mv2, M1V1=M2V2, m=nM, P=I2R, ...). Each relation gets an AUTHORED template whose stem semantically matches
the relation (never source-question wording). Generation is parametric: sample NEW parameter values →
compute the answer via the relation library → build plausible numeric distractors via governed transforms.

Verification is DETERMINISTIC and INDEPENDENT of the generator's own arithmetic path: `relations.verify`
(the second solver, which tries the WHOLE library) must reproduce the stated answer from the given numbers,
AND no distractor may be reproduced (unique key), AND the parameters must be genuinely new (originality).
Template SEMANTIC correctness is validated ONCE by an independent model (validate_templates), so per-instance
generation needs no AI. Nothing is fabricated: answers are computed by the certified relation.

Deterministic (seeded), stdlib-only, read-only.
"""
from __future__ import annotations

import hashlib
import re
from dataclasses import dataclass
from typing import Callable, Dict, List, Optional, Tuple

from kie.qie import relations as R


@dataclass(frozen=True)
class NumTemplate:
    template_id: str
    relation: str                 # name in relations.LIBRARY (the certified structure)
    subject: str                  # Physics | Chemistry
    concept_scope: str            # relation-based concept identity (provenance)
    stem: str                     # authored; formats {p0},{p1},... in relation.fn arg order
    param_ranges: Tuple[Tuple[int, int], ...]   # (lo,hi) integer range per relation arg
    answer_unit: str
    round_to: int = 2


# authored templates — stem semantically matches the relation's fn(args...) in order. Ranges chosen for clean,
# NEET-plausible magnitudes. (Validated once by an independent model via validate_templates.)
TEMPLATES: Tuple[NumTemplate, ...] = (
    NumTemplate("T_VIR", "V=IR", "Physics", "REL_OHMS_LAW",
                "A resistor of {p0} ohm carries a steady current of {p1} A. The potential difference across "
                "it (in volt) is:", ((2, 40), (1, 12)), "V"),
    NumTemplate("T_RVI", "R=V/I", "Physics", "REL_OHMS_LAW",
                "A potential difference of {p0} V drives a steady current of {p1} A through a conductor. Its "
                "resistance (in ohm) is:", ((10, 240), (1, 12)), "ohm"),
    NumTemplate("T_KE", "KE=.5mv2", "Physics", "REL_KINETIC_ENERGY",
                "A body of mass {p0} kg moves with a speed of {p1} m/s. Its kinetic energy (in joule) is:",
                ((1, 20), (1, 12)), "J"),
    NumTemplate("T_PI2R", "P=I2R", "Physics", "REL_ELECTRIC_POWER",
                "A current of {p0} A flows through a resistor of {p1} ohm. The power dissipated (in watt) is:",
                ((1, 10), (2, 40)), "W"),
    NumTemplate("T_WMG", "W=mg10", "Physics", "REL_WEIGHT",
                "Taking g = 10 m/s^2, the weight (in newton) of a body of mass {p0} kg is:",
                ((1, 50),), "N"),
    NumTemplate("T_RSER", "Rseries", "Physics", "REL_SERIES_RESISTANCE",
                "Two resistors of {p0} ohm and {p1} ohm are connected in series. Their equivalent resistance "
                "(in ohm) is:", ((2, 60), (2, 60)), "ohm"),
    NumTemplate("T_NMM", "n=m/M", "Chemistry", "REL_MOLE_MASS",
                "The number of moles present in {p0} g of a substance of molar mass {p1} g/mol is:",
                ((10, 400), (2, 100)), "mol"),
    NumTemplate("T_MNM", "m=nM", "Chemistry", "REL_MOLE_MASS",
                "The mass (in gram) of {p0} mol of a substance of molar mass {p1} g/mol is:",
                ((1, 10), (2, 120)), "g"),
    NumTemplate("T_MV", "M1V1=M2V2", "Chemistry", "REL_DILUTION",
                "{p1} mL of a {p0} M solution is diluted with water to a final volume of {p2} mL. The molarity "
                "(in M) of the diluted solution is:", ((1, 12), (10, 100), (100, 1000)), "M"),
    NumTemplate("T_NV", "n=V/22.4", "Chemistry", "REL_MOLAR_VOLUME",
                "The number of moles in {p0} litre of an ideal gas at STP is:", ((1, 112),), "mol"),
)


def _seed_int(seed: str, lo: int, hi: int) -> int:
    h = int(hashlib.sha256(seed.encode()).hexdigest(), 16)
    return lo + (h % (hi - lo + 1))


def _relation(name: str):
    return next((r for r in R.LIBRARY if r.name == name), None)


def sample_params(t: NumTemplate, seed: str) -> Tuple[float, ...]:
    return tuple(_seed_int(f"{seed}|{t.template_id}|{i}", lo, hi) for i, (lo, hi) in enumerate(t.param_ranges))


def numeric_distractors(answer: float, t: NumTemplate) -> List[float]:
    """Governed, evidence-grounded wrong values: standard learner errors (double, half, sign flip / off-by-a
    factor). All are transforms of the correct value — never random. Kept distinct and != answer."""
    cands = [answer * 2, answer / 2, answer + max(1, round(abs(answer) * 0.1, t.round_to)),
             answer * 10 if abs(answer) < 100 else answer / 10]
    out: List[float] = []
    for c in cands:
        c = round(c, t.round_to)
        if abs(c - round(answer, t.round_to)) > 10 ** (-t.round_to) and c not in out:
            out.append(c)
    return out[:3]


def generate(templates=TEMPLATES, per_template: int = 4, seed: str = "N1") -> List[dict]:
    cands: List[dict] = []
    for t in templates:
        rel = _relation(t.relation)
        if rel is None or rel.arity != len(t.param_ranges):
            continue
        for j in range(per_template):
            params = sample_params(t, f"{seed}|{j}")
            answer = rel.fn(*params)
            if answer is None:
                continue
            answer = round(answer, t.round_to)
            distr = numeric_distractors(answer, t)
            if len(distr) < 3:
                continue
            opts_vals = sorted([answer] + distr,
                               key=lambda v: hashlib.sha256(f"{seed}|{t.template_id}|{j}|{v}".encode()).hexdigest())
            options = {str(i + 1): _fmt(v) for i, v in enumerate(opts_vals)}
            gen_id = "GENN_" + hashlib.sha256(f"{t.template_id}|{params}".encode()).hexdigest()[:16]
            cands.append({
                "gen_id": gen_id,
                "item_model_id": "IMN_" + hashlib.sha256(
                    f"{t.subject}|NEET|{t.concept_scope}|single_step_numerical|{t.relation}".encode()).hexdigest()[:16],
                "subject": t.subject, "profile": "NEET", "concept": t.concept_scope,
                "archetype": "single_step_numerical", "frame_id": t.template_id, "relation": t.relation,
                "stem": t.stem.format(**{f"p{i}": _fmt(p) for i, p in enumerate(params)}),
                "options": options, "answer_text": _fmt(answer),
                "params": list(params), "answer_value": answer, "unit": t.answer_unit,
                "provenance": {"certified_relation": t.relation, "params": list(params),
                               "distractor_values": distr, "template_id": t.template_id},
            })
    return cands


def _fmt(v: float) -> str:
    return str(int(v)) if float(v).is_integer() else str(round(v, 4))


def verify_numeric(cand: dict, tol: float = 0.02) -> str:
    """DETERMINISTIC independent verification (the second solver). Returns 'agree'|'disagree'.
    (a) relations.verify reproduces the stated answer from the params; (b) it reproduces via the CERTIFIED
    relation; (c) the answer is unique among the options (no distractor equals it)."""
    params = cand.get("params") or []
    ans = cand.get("answer_value")
    if not params or ans is None:
        return "disagree"
    got = R.verify([float(p) for p in params], float(ans), tol=tol, subject=cand["subject"])
    if got is None:
        return "disagree"
    # the certified relation itself must reproduce it (not merely some coincidental library relation)
    rel = _relation(cand["relation"])
    import itertools
    ok = False
    for combo in itertools.permutations([float(p) for p in params], rel.arity):
        v = rel.fn(*combo)
        if v is not None and abs(v - float(ans)) <= tol * max(abs(float(ans)), 1e-9):
            ok = True
            break
    if not ok:
        return "disagree"
    vals = [v for v in cand["options"].values()]
    if vals.count(cand["answer_text"]) != 1:
        return "disagree"
    return "agree"


def gate_numeric(cand: dict, source_param_sigs: set, seen: set) -> Optional[str]:
    """Originality + duplicate gates. `source_param_sigs` = normalized param tuples seen in the SOURCE corpus
    (so we never reproduce a source question's exact numbers). Also dedup generated items."""
    sig = (cand["relation"], tuple(round(float(p), 3) for p in cand["params"]))
    if (cand["relation"], tuple(round(float(p), 3) for p in cand["params"])) in source_param_sigs:
        return "NEAR_COPY_OF_SOURCE_PARAMS"
    if len({str(o) for o in cand["options"].values()}) != len(cand["options"]):
        return "DUPLICATE_OPTION"
    if sig in seen:
        return "DUPLICATE_GENERATED"
    seen.add(sig)
    return None


def run(templates=TEMPLATES, per_template: int = 4, seed: str = "N1",
        source_param_sigs: Optional[set] = None,
        verify_fn: Callable[[dict], str] = verify_numeric) -> dict:
    """Generate → gate → DETERMINISTIC verify. Only PASS proceeds. verify_fn defaults to the deterministic
    second-solver check (no AI needed per item)."""
    source_param_sigs = source_param_sigs or set()
    seen: set = set()
    passed, rejected = [], []
    for cand in generate(templates, per_template, seed):
        reason = gate_numeric(cand, source_param_sigs, seen)
        if reason:
            rejected.append({**cand, "status": "REJECT", "reason": reason})
            continue
        verdict = verify_fn(cand)
        cand = {**cand, "verification": {"verdict": verdict, "method": "deterministic_relation_solver"}}
        if verdict == "agree":
            passed.append({**cand, "status": "PASS"})
        else:
            rejected.append({**cand, "status": "REJECT", "reason": "SOLVER_DISAGREEMENT"})
    return {"attempted": len(passed) + len(rejected), "passed": len(passed), "rejected": len(rejected),
            "quarantined": 0, "items": passed + rejected, "verified_bank": passed}
