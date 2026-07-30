"""Statement-based questions (Statement I / Statement II) — JEE Main's current staple.

STRUCTURALLY this is the assertion-reason truth table with the explanation link removed. The candidate
judges TWO independent statements and reports which are true; nobody is asked whether one accounts for the
other. That makes the option set different and the key derivation simpler, but both truths are settled by
exactly the same computed probe the assertion-reason lane uses — solve the certified relation at a working
point, solve it again with one quantity scaled, and compare the ratio the statement claims against the
ratio the arithmetic produces.

So nothing new has to be trusted here. What the format adds is that the two statements are INDEPENDENT: a
candidate confident about one still has to evaluate the other, and there is no structural hint about how
many are true.

Kept in its own module rather than appended to `assertion_reason` so the two lanes can evolve separately —
they share a probe, not a purpose.

Deterministic, no model calls, read-only against every store.
"""
from __future__ import annotations

import hashlib
from typing import Dict, List, Optional, Sequence

from kie.qie.certgen import solution as SOL
from kie.qie.certgen.assertion_reason import ResolvedAR, ScalingClaim, claim_is_true
from kie.qie.knowledge import difficulty as DIFF

LANE = "STATEMENT_BASED"

STATEMENT_OPTIONS: Dict[str, str] = {
    "a": "Both Statement I and Statement II are true",
    "b": "Both Statement I and Statement II are false",
    "c": "Statement I is true but Statement II is false",
    "d": "Statement I is false but Statement II is true",
}

# (truth of Statement I, truth of Statement II) -> the option that says so
_KEY_FOR = {(True, True): "a", (False, False): "b", (True, False): "c", (False, True): "d"}
_FACTS = {v: k for k, v in _KEY_FOR.items()}


def build_variant(ra: ResolvedAR, key: str) -> Optional[dict]:
    """One item whose key follows from two independently computed truths."""
    b = ra.binding
    want1, want2 = _FACTS[key]

    # Statement I draws on the binding's first true claim (or its false claim); Statement II on the
    # second. Both are claims about the SAME certified relation, so both are decidable by the same probe.
    s1 = b.true_claims[0] if want1 else b.false_claim
    s2 = (b.true_claims[1] if len(b.true_claims) > 1 else b.true_claims[0]) if want2 else b.false_claim
    if s1.text == s2.text:
        return None                    # two identical statements is not a two-statement item

    got1 = claim_is_true(b.relation, b.base_params, b.solve_for, s1)
    got2 = claim_is_true(b.relation, b.base_params, b.solve_for, s2)
    if got1 is None or got2 is None:
        return None
    if _KEY_FOR[(bool(got1), bool(got2))] != key:
        return None                    # construction and truth table disagree — never ship

    stem = (f"Statement I: {s1.text}\n"
            f"Statement II: {s2.text}\n"
            f"In the light of the above statements, choose the correct answer.")

    steps = [
        f"Step 1 — Test Statement I against the certified relation "
        f"{SOL.pretty_equation(b.relation)}. Evaluating it at a working point "
        f"({', '.join(f'{k} = {SOL.fmt_number(v)}' for k, v in b.base_params.items())}) and again after "
        f"the stated change shows Statement I is {'TRUE' if got1 else 'FALSE'}.",
        f"Step 2 — Test Statement II the same way, independently of the first: it is "
        f"{'TRUE' if got2 else 'FALSE'}.",
        f"Step 3 — Two truths judged separately give option ({key}) {STATEMENT_OPTIONS[key]}.",
    ]

    rationale: Dict[str, Dict[str, str]] = {}
    for lab, (w1, w2) in _FACTS.items():
        if lab == key:
            continue
        why = []
        if w1 != bool(got1):
            why.append(f"it requires Statement I to be {'true' if w1 else 'false'}, but the certified "
                       f"relation makes it {'true' if got1 else 'false'}")
        if w2 != bool(got2):
            why.append(f"it requires Statement II to be {'true' if w2 else 'false'}, but the certified "
                       f"relation makes it {'true' if got2 else 'false'}")
        rationale[lab] = {"misconception": "; ".join(why), "mis_relation": ""}

    depth = 2                          # settle each statement, then combine the two verdicts
    diff = DIFF.predict(depth, 1, misconception_pressure=0.0, calculation_load=0.2)
    gen_id = "CSTM_" + hashlib.sha256(f"{b.binding_id}|stmt|{key}|{stem}".encode()).hexdigest()[:16]

    return {
        "gen_id": gen_id, "binding_id": b.binding_id, "concept_id": ra.concept_id,
        "concept_name": b.concept_name, "concept_ids": [ra.concept_id],
        "chapter_id": ra.chapter_id, "chapter_title": "", "section_heading": ra.section_heading,
        "class_level": b.taught_at_class, "subject": ra.subject, "discipline": b.discipline,
        "archetype": "misconception_detection", "lane": LANE,
        "stem": stem, "options": dict(STATEMENT_OPTIONS), "answer_label": key,
        "answer_value": STATEMENT_OPTIONS[key], "answer_unit": "", "structure": {},
        "solution": {"steps": steps, "final": STATEMENT_OPTIONS[key]},
        "distractor_rationale": rationale,
        "common_mistake": "judging the second statement by the first instead of independently",
        "reasoning": (
            "The two statements are settled separately and neither constrains the other, so a candidate "
            "confident about one still has to evaluate the other and gets no hint about how many are "
            "true. The format rewards knowing the relation well enough to predict how the quantity "
            "responds to a change, and gives no credit for recognising a familiar-looking sentence."),
        "reasoning_depth": depth, "difficulty": diff,
        "claimed": {"concepts": [b.concept_name], "concept_ids": [ra.concept_id],
                    "archetype": "misconception_detection", "depth": depth},
        "provenance": {
            "lane": "CERTGEN_STATEMENT_BASED", "evidence_class": "deterministic_computed",
            "certified_concept_id": ra.concept_id, "grounding": list(b.grounding),
            "relation": b.relation,
            "truth_table": {"statement_1_true": bool(got1), "statement_2_true": bool(got2)},
            "key_derivation": "computed from (truth(S1), truth(S2)) — never hard-coded",
            "probe_params": b.base_params,
            "corpus_basis": "Statement I / Statement II is a current JEE Main staple",
            "boundary": ra.boundary,
        },
        "_params": {},
    }


def generate(resolved: Sequence[ResolvedAR],
             keys: Sequence[str] = ("a", "b", "c", "d")) -> List[dict]:
    out: List[dict] = []
    for ra in resolved:
        for k in keys:
            it = build_variant(ra, k)
            if it is not None:
                out.append(it)
    return out


def verify_options(item: dict) -> dict:
    """Every non-key option must be contradicted by a computed truth value; an unrefuted option would be
    a second correct answer."""
    tt = item["provenance"]["truth_table"]
    actual = (tt["statement_1_true"], tt["statement_2_true"])
    key = item["answer_label"]
    unrefuted = [l for l, e in _FACTS.items() if l != key and e == actual]
    ok = (not unrefuted and _FACTS.get(key) == actual
          and len(item.get("distractor_rationale") or {}) == 3
          and all(v.get("misconception") for v in item["distractor_rationale"].values()))
    return {"ok": ok, "unrefuted": unrefuted,
            "detail": f"truths={actual} key={key} unrefuted={unrefuted}"}
