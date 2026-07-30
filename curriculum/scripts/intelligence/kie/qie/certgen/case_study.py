"""Case-study / paragraph questions — a shared stimulus with dependent sub-questions.

WHY THIS IS DETERMINISTICALLY CONSTRUCTIBLE. A case study looks like a new capability and is really an
existing one re-presented. A depth-3 chain already computes a sequence of intermediates, each verified
independently and each reproduced by two separate routes. A case study is exactly that sequence, printed
with the data stated once at the top and the intermediates asked for in order:

    PASSAGE      the scenario, stating every given once
      Q1         asks for the FIRST intermediate          (chain step 1)
      Q2         asks for the SECOND intermediate          (chain step 2, needs Q1's answer)
      Q3         asks for the final quantity               (chain step 3)

Nothing new is computed and nothing new has to be trusted: every sub-answer is a value the chain already
produced and `gates.replay_steps` already re-derived. What the format adds is the pedagogy real papers use
it for — a candidate who gets Q1 wrong will carry that error into Q2 and Q3, so the item measures whether
a multi-step method is held together rather than whether one formula is remembered.

CBSE sets case-based questions in classes 10 and 12; JEE Advanced sets paragraph questions on the same
principle. Both are covered by this construction.

EACH SUB-QUESTION IS A FULL ITEM. It carries the passage in its stem and faces the whole gate battery on
its own, exactly like any other question — there is no weaker path for a sub-question. `case_id` and
`sub_index` link the group so a paper can print them together and so the shared stimulus is never
duplicated in a bank.

Deterministic, no model calls, read-only against every store.
"""
from __future__ import annotations

import hashlib
import re
from typing import Dict, List, Optional, Sequence

from kie.qie.certgen import engine as E
from kie.qie.certgen import solution as SOL
from kie.qie.knowledge import difficulty as DIFF

LANE = "CASE_STUDY"
LABELS = ("a", "b", "c", "d")


def _tidy(text: str) -> str:
    """Collapse whitespace runs. `sanitize.stem_quality_ok` treats ANY run of two or more whitespace
    characters as an extraction artifact, so an empty `elaboration` or `condition` — which leaves a
    newline followed by a space — fails the gate. A single newline between the passage and the ask is
    legitimate and is preserved."""
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r"\s*\n\s*", "\n", text)
    return text.strip()


def _passage(rc, params: Dict[str, float]) -> str:
    """The shared stimulus. States every given ONCE — a case study that repeats its data in each
    sub-question is three questions with a decorative heading, not a case study."""
    ch = rc.chain
    givens = ", ".join(
        f"{g.symbol} = {SOL.fmt_number(params[g.symbol])} {g.unit}".strip().replace(" 1", "")
        if g.unit == "1" else f"{g.symbol} = {SOL.fmt_number(params[g.symbol])} {g.unit}"
        for g in ch.givens)
    passage = (f"Read the following passage and answer the questions that follow.\n"
            f"{ch.elaboration if hasattr(ch, 'elaboration') and ch.elaboration else ''} "
            f"A situation is described in which {givens}. "
            f"{ch.condition if hasattr(ch, 'condition') and ch.condition else ''} "
            f"The quantities below are to be determined in order.")
    return _tidy(passage)


def _distractors_for(value: float, seed: str, round_to: int) -> List[str]:
    """Three wrong values for an intermediate, each a nameable slip: doubled, halved, and an off-by-a-tenth
    magnitude error. Kept in a plausible band so no option is dismissible on sight."""
    out: List[str] = []
    for factor, _name in ((2.0, "doubled"), (0.5, "halved"), (10.0, "order-of-magnitude slip")):
        t = SOL.fmt_exact(value * factor, round_to)
        if t is not None and t not in out:
            out.append(t)
    return out


def build_case(rc, seed: str, i: int) -> List[dict]:
    """One case study — the passage plus one item per chain step. Returns [] if anything refused it."""
    ch = rc.chain
    params = E.sample_params(ch, seed, i)
    if ch.accept and not ch.accept(params):
        return []
    env = E.execute_chain(rc, params)
    if env is None:
        return []

    passage = _passage(rc, params)
    case_id = "CASE_" + hashlib.sha256(f"{ch.binding_id}|{seed}|{i}|{passage}".encode()).hexdigest()[:14]
    out: List[dict] = []

    for n, st in enumerate(ch.steps):
        value = env.get(st.out)
        if value is None or value <= 0:
            return []
        key_text = SOL.fmt_exact(value, ch.round_to)
        if key_text is None:
            return []
        wrongs = [w for w in _distractors_for(value, f"{seed}|{i}|{n}", ch.round_to) if w != key_text]
        if len(wrongs) < 3:
            return []

        pool = [(key_text, True)] + [(w, False) for w in wrongs[:3]]
        if len({p[0] for p in pool}) != 4:
            return []
        pool.sort(key=lambda p: hashlib.sha256(f"{seed}|{case_id}|{n}|{p[0]}".encode()).hexdigest())

        options: Dict[str, str] = {}
        answer_label = ""
        rationale: Dict[str, Dict[str, str]] = {}
        for lab, (text, is_key) in zip(LABELS, pool):
            options[lab] = text
            if is_key:
                answer_label = lab
            else:
                ratio = float(text) / float(key_text) if float(key_text) else 0
                named = ("doubled the result" if abs(ratio - 2) < 0.01 else
                         "halved the result" if abs(ratio - 0.5) < 0.01 else
                         "made an order-of-magnitude slip")
                rationale[lab] = {
                    "misconception": f"{named} — the certified relation {SOL.pretty_equation(st.relation)} "
                                     f"gives {key_text}, not {text}",
                    "mis_relation": ""}
        if not answer_label or len(rationale) != 3:
            return []

        concept = rc.concept_names[n] if n < len(rc.concept_names) else st.concept_name
        cid = rc.concept_ids[n] if n < len(rc.concept_ids) else rc.concept_ids[0]
        head = rc.section_headings[n] if n < len(rc.section_headings) else ""

        ask = _tidy(f"{passage}\n"
                    f"Question {n + 1} of {len(ch.steps)}: Using the passage above, {st.narrate}. "
                    f"What is the value of {st.out}"
                    f"{' in ' + st.out_unit if st.out_unit and st.out_unit != '1' else ''}?")

        steps = [f"Step 1 — Read the required quantity from the passage: {st.out}.",
                 f"Step 2 — The certified Class-{st.taught_at_class} concept '{concept}' ({head}) gives "
                 f"{SOL.pretty_equation(st.relation)}."]
        sub = st.relation.split("=", 1)[1].strip()
        for sym in sorted(set(st.inputs), key=len, reverse=True):
            if sym in env:
                sub = sub.replace(sym, SOL.fmt_number(env[sym]))
        steps.append(f"Step 3 — Substituting the values available at this stage, {st.out} = "
                     f"{SOL.pretty_equation(sub)}.")
        steps.append(f"Step 4 — Therefore {st.out} = "
                     f"{key_text}{' ' + st.out_unit if st.out_unit and st.out_unit != '1' else ''}.")

        depth = n + 1
        diff = DIFF.predict(depth, 1, misconception_pressure=0.0, calculation_load=0.8)
        gen_id = "CCASE_" + hashlib.sha256(f"{case_id}|{n}".encode()).hexdigest()[:16]

        out.append({
            "gen_id": gen_id, "binding_id": ch.binding_id,
            "case_id": case_id, "sub_index": n + 1, "sub_total": len(ch.steps),
            "concept_id": cid, "concept_name": concept, "concept_ids": [cid],
            "chapter_id": rc.chapter_ids[n] if n < len(rc.chapter_ids) else rc.chapter_ids[0],
            "chapter_title": "", "section_heading": head,
            "class_level": ch.taught_at_class, "subject": rc.subject, "discipline": ch.discipline,
            "archetype": "case_interpretation", "lane": LANE,
            "stem": ask, "options": options, "answer_label": answer_label,
            "answer_value": key_text, "answer_unit": st.out_unit,
            # a case sub-question is answered FROM THE PASSAGE, so it declares no independent structure of
            # its own; the chain that produced it is recorded in provenance and was verified there
            "structure": {},
            "solution": {"steps": steps, "final": key_text},
            "distractor_rationale": rationale,
            "common_mistake": "carrying an error from an earlier part of the case into this one",
            "reasoning": (
                f"This is part {n + 1} of a {len(ch.steps)}-part case built on one shared situation. The "
                f"quantity asked for here is {'read directly from the passage data' if n == 0 else 'not available in the passage — it depends on the value established in the previous part'}, "
                f"which is what the format is for: an error made early is carried forward, so the case "
                f"measures whether a multi-step method holds together rather than whether one formula is "
                f"remembered."),
            "reasoning_depth": depth, "difficulty": diff,
            "claimed": {"concepts": [concept], "concept_ids": [cid],
                        "archetype": "case_interpretation", "depth": depth},
            "provenance": {
                "lane": "CERTGEN_CASE_STUDY",
                "evidence_class": "deterministic_computed",
                "certified_concept_id": cid,
                "grounding": list(st.grounding),
                "relation": st.relation,
                "case_id": case_id, "sub_index": n + 1,
                "chain": ch.binding_id,
                "params": params,
                "intermediates": {k: v for k, v in env.items() if k not in params},
                "key_derivation": ("computed — the value the chain produced at this step, re-derived by "
                                   "gates.replay_steps when the parent chain was verified"),
                "corpus_basis": "CBSE sets case-based questions; JEE Advanced sets paragraph questions",
                "boundary": rc.boundary,
            },
            "_params": params,
        })
    return out


def generate(resolved_chains: Sequence, per_chain: int = 1, seed: str = "CS1") -> List[dict]:
    """Emit whole cases only.

    Two chains that share a leading prefix produce identical early sub-questions — `CHARGE_TO_HEAT` and
    `CHARGE_TO_ENERGY` both open with I = Q/t then V = IR over the same givens, and their first two parts
    were byte-identical (4 duplicate failures, correctly caught). A case is therefore accepted or rejected
    AS A WHOLE: dropping just the duplicated part would leave a case numbered "Question 2 of 3" with no
    question 1, which is worse than not emitting it.
    """
    from kie.qie.factory import gates as _G
    out: List[dict] = []
    seen_norm: set = set()
    for rc in resolved_chains:
        made = attempt = 0
        while made < per_chain and attempt < 12:
            case = build_case(rc, seed, attempt)
            attempt += 1
            if not case:
                continue
            norms = [_G.norm_hash(it["stem"]) for it in case]
            if len(set(norms)) != len(norms) or any(n in seen_norm for n in norms):
                continue                       # this case repeats a part already emitted — skip it whole
            seen_norm.update(norms)
            out += case
            made += 1
    return out


def verify_case(items: Sequence[dict]) -> dict:
    """A case is sound when its parts share one passage, are numbered contiguously, and each carries a
    distinct key. A group whose parts disagree about the passage is not one case study."""
    by_case: Dict[str, List[dict]] = {}
    for it in items:
        by_case.setdefault(it["case_id"], []).append(it)
    bad: List[str] = []
    for cid, group in by_case.items():
        group.sort(key=lambda r: r["sub_index"])
        if [r["sub_index"] for r in group] != list(range(1, len(group) + 1)):
            bad.append(f"{cid}: sub_index not contiguous")
        passages = {r["stem"].split("\nQuestion ")[0] for r in group}
        if len(passages) != 1:
            bad.append(f"{cid}: parts do not share one passage")
        if len({r["answer_value"] for r in group}) != len(group):
            bad.append(f"{cid}: two parts share an answer, so the case is not progressive")
    return {"ok": not bad, "cases": len(by_case), "detail": "; ".join(bad) or f"{len(by_case)} cases sound"}
