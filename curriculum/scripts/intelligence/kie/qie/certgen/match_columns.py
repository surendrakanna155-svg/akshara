"""Match-the-columns — the largest authentic gap in Lane C, measured against the certified PYQ corpus.

WHY THIS FORM, AND WHY NOW. The corpus study (`QIE_PYQ_CORPUS_DNA_STUDY_2026-07-29.md`) measured the
question-type mix over 15,803 real items spanning 2011-2025:

    NEET          mcq 87.5%   match 11.0%   assertion_reason 1.6%
    JEE_ADVANCED  mcq 74.3%   numerical 18.0%   match 7.6%
    Lane C        numerical 82%   assertion_reason 18%   match 0%

`match` is 11% of NEET — 1,661 real items — and Lane C produced none of it. On the corpus's structural
difficulty proxy it is also the hardest COMMON form: 55% hard, 45% moderate, **0% easy**, against plain
MCQ's 93% easy. So this is not a form chosen to raise a depth score; it is the form the real papers use
heavily, that we were not writing at all.

WHY IT IS DETERMINISTICALLY CONSTRUCTIBLE. A match item is a set of pairs plus a permutation. The key is
the permutation that reproduces every certified pairing — computed, never chosen — and each wrong option
is a permutation in which at least one specific pair contradicts the certified evidence, which is exactly
what makes it provably wrong rather than merely different.

WHAT MAKES IT HARD, HONESTLY. Four pairs mean the candidate cannot succeed by recognising one item: a
single confident pairing eliminates only some options, and the near-miss distractors below differ from the
key by a single transposition, so partial knowledge is not enough. That is the authentic difficulty of the
form as the corpus uses it — not extra arithmetic.

Deterministic, no model calls, read-only against every store.
"""
from __future__ import annotations

import hashlib
import itertools
import json
import re
import sqlite3
from dataclasses import dataclass
from typing import Dict, List, Optional, Sequence, Tuple

from kie.qie.certgen import solution as SOL
from kie.qie.certgen.binding import evidence_blob, normalize_evidence
from kie.qie.knowledge import difficulty as DIFF
from kie.qie.knowledge import planner as P

LANE = "MATCH_COLUMNS"
ARCHETYPE = "comparison"                 # the nearest member of the frozen archetype vocabulary
LEFT_LABELS = ("A", "B", "C", "D")
RIGHT_LABELS = ("I", "II", "III", "IV")
OPTION_LABELS = ("a", "b", "c", "d")


@dataclass(frozen=True)
class MatchPair:
    """One certified correspondence. `grounding` must appear in the concept's own evidence."""
    left: str
    right: str
    concept_name: str
    discipline: str
    taught_at_class: int
    grounding: Tuple[str, ...]


@dataclass(frozen=True)
class MatchBinding:
    binding_id: str
    discipline: str
    taught_at_class: int
    list_i_label: str
    list_ii_label: str
    pairs: Tuple[MatchPair, ...]          # exactly 4 are used per item
    stems: Tuple[str, ...]
    quantity: str


@dataclass(frozen=True)
class ResolvedMatch:
    binding: MatchBinding
    concept_ids: Tuple[str, ...]
    concept_names: Tuple[str, ...]
    chapter_ids: Tuple[str, ...]
    section_headings: Tuple[str, ...]
    subject: str
    boundary: dict


# ══ THE BINDINGS ══════════════════════════════════════════════════════════════════════════════════════
MATCH_BINDINGS: Tuple[MatchBinding, ...] = (

    MatchBinding(
        "MTC_PHY10_ELECTRICITY", "Physics", 10,
        "Physical quantity", "Defining relation",
        (MatchPair("Electric current", "Q / t", "Electric Current and Circuit", "Physics", 10,
                   ("electric current as rate of flow of charge (i = q/t)",)),
         MatchPair("Potential difference across a conductor", "I x R", "Ohm's Law", "Physics", 10,
                   ("v = ir",)),
         MatchPair("Electric power dissipated in a resistor", "I^2 x R", "Electric Power", "Physics", 10,
                   ("p = vi = i^2 r = v^2/r",)),
         MatchPair("Heat produced in a resistor", "V x I x t",
                   "Heating Effect of Electric Current (Joule's Law of Heating)", "Physics", 10,
                   ("heat produced h = vit",))),
        ("Match the physical quantities in List-I with their defining relations in List-II and choose "
         "the correct option.",
         "Each quantity in List-I is defined by one of the relations in List-II. Choose the option that "
         "pairs them correctly.",
         "Column I lists four electrical quantities and Column II four relations. Select the option in "
         "which every quantity is matched with the relation that defines it."),
        "the correct pairing of each quantity with its defining relation",
    ),

    MatchBinding(
        "MTC_PHY8_MECHANICS", "Physics", 8,
        "Physical quantity", "Defining relation",
        (MatchPair("Pressure on a surface", "Force / Area", "Pressure (Force per Unit Area)", "Physics", 8,
                   ("pressure = force / area",)),
         MatchPair("Density of a substance", "Mass / Volume", "Density (Mass per Unit Volume)",
                   "Physics", 8, ("density = mass / volume",)),
         MatchPair("Distance covered at a steady speed", "Speed x Time",
                   "Relationship between Speed, Distance, and Time", "Physics", 7,
                   ("distance = speed x time",)),
         MatchPair("Volume of a cuboidal block", "Length x Breadth x Height", "Volume of a Cuboid",
                   "Mathematics", 8, ("volume of a cuboid = l x b x h",))),
        ("Match the quantities in List-I with the relations that define them in List-II and choose the "
         "correct option.",
         "Each quantity in List-I is obtained from one of the expressions in List-II. Choose the option "
         "that pairs them correctly.",
         "Column I names four quantities and Column II four expressions. Select the option in which "
         "every quantity is paired with the expression that gives it."),
        "the correct pairing of each quantity with its defining relation",
    ),

    MatchBinding(
        "MTC_MAT8_MENSURATION", "Mathematics", 8,
        "Measurement required", "Expression",
        (MatchPair("Area of a rectangle", "length x width", "Area of a Rectangle", "Mathematics", 6,
                   ("area = length x width",)),
         MatchPair("Perimeter of a rectangle", "2 x (length + breadth)", "Perimeter of a Rectangle",
                   "Mathematics", 6, ("perimeter = 2 x (length + breadth)",)),
         MatchPair("Simple interest for one year", "(P x R) / 100", "Simple Interest", "Mathematics", 7,
                   ("interest for one year = (p x r) / 100",)),
         MatchPair("Volume of a cuboid", "l x b x h", "Volume of a Cuboid", "Mathematics", 8,
                   ("volume of a cuboid = l x b x h",))),
        ("Match each measurement in List-I with the expression that gives it in List-II and choose the "
         "correct option.",
         "Every entry in List-I is computed by one of the expressions in List-II. Choose the option that "
         "pairs them correctly.",
         "Column I lists four quantities to be found and Column II four expressions. Select the option "
         "in which each is correctly paired."),
        "the correct pairing of each measurement with its expression",
    ),
)


# ══ RESOLUTION ════════════════════════════════════════════════════════════════════════════════════════
def _certified(iconn, disc: str, cls: int, name: str) -> List[dict]:
    return [c for c in P.certified_universe_by_discipline(iconn, disc, [cls])
            if c["canonical_name"] == name]


def resolve_one(iconn: sqlite3.Connection, b: MatchBinding) -> Tuple[Optional[ResolvedMatch], List[str]]:
    v: List[str] = []
    ids, names, chapters, heads, oos, ins = [], [], [], [], [], []
    subject = ""

    if len(b.pairs) != 4:
        v.append(f"wrong_pair_count: a match item uses exactly 4 pairs, got {len(b.pairs)}")

    for i, pr in enumerate(b.pairs):
        m = _certified(iconn, pr.discipline, pr.taught_at_class, pr.concept_name)
        if not m:
            v.append(f"unresolved_concept[{i}]: no CERTIFIED {pr.discipline} concept named "
                     f"{pr.concept_name!r} at class {pr.taught_at_class}")
            continue
        if len(m) > 1:
            v.append(f"ambiguous_concept[{i}]: {len(m)} matches for {pr.concept_name!r}")
            continue
        kc = m[0]
        blob = evidence_blob(kc)
        for term in pr.grounding:
            if normalize_evidence(term) not in blob:
                v.append(f"ungrounded_pair[{i}]: {pr.left!r} -> {pr.right!r} claims {term!r} but "
                         f"{kc['concept_id']}'s certified evidence does not contain it")
        if pr.taught_at_class > b.taught_at_class:
            v.append(f"above_class_pair[{i}]: {pr.concept_name!r} is taught at class "
                     f"{pr.taught_at_class}, above the question's class {b.taught_at_class}")
        ids.append(kc["concept_id"])
        names.append(kc["canonical_name"])
        chapters.append(kc["chapter_id"])
        heads.append(kc.get("section_heading") or "")
        bd = kc.get("boundary") or {}
        oos += [str(t) for t in (bd.get("out_of_scope") or [])]
        ins += [str(t) for t in (bd.get("in_scope") or [])] + [str(t) for t in (kc.get("sub_concepts") or [])]
        if pr.taught_at_class == b.taught_at_class:
            subject = kc["subject"]

    # every LEFT entry and every RIGHT entry must be distinct, or the "correct" pairing is not unique
    lefts = [normalize_evidence(p.left) for p in b.pairs]
    rights = [normalize_evidence(p.right) for p in b.pairs]
    if len(set(lefts)) != len(lefts):
        v.append("duplicate_left_entries: List-I entries must be distinct")
    if len(set(rights)) != len(rights):
        v.append("duplicate_right_entries: List-II entries must be distinct — a repeated relation would "
                 "make more than one permutation correct")
    if len({normalize_evidence(s) for s in b.stems}) != len(b.stems):
        v.append("duplicate_scenarios: every authored instruction line must differ")

    if v:
        return None, v

    from kie.qie.certgen.composition import chain_boundary_terms
    return ResolvedMatch(b, tuple(ids), tuple(names), tuple(chapters), tuple(heads),
                         subject or "Science",
                         {"out_of_scope": chain_boundary_terms(oos, names, ins), "in_scope": ins}), []


def resolve(iconn: sqlite3.Connection, bindings: Sequence[MatchBinding] = MATCH_BINDINGS,
            strict: bool = False) -> Tuple[List[ResolvedMatch], Dict[str, List[str]]]:
    ok: List[ResolvedMatch] = []
    refusals: Dict[str, List[str]] = {}
    for b in bindings:
        r, why = resolve_one(iconn, b)
        if r is not None:
            ok.append(r)
        else:
            refusals[b.binding_id] = why
    if strict and refusals:
        raise ValueError(f"{len(refusals)} match binding(s) refused: {refusals}")
    return ok, refusals


# ══ GENERATION ════════════════════════════════════════════════════════════════════════════════════════
def _h(seed: str) -> int:
    return int(hashlib.sha256(seed.encode()).hexdigest(), 16)


def _render_mapping(mapping: Dict[str, str]) -> str:
    """{'A': 'III', ...} -> 'A-III, B-I, C-IV, D-II' — the way real papers print it."""
    return ", ".join(f"{L}-{mapping[L]}" for L in LEFT_LABELS)


def build_item(rm: ResolvedMatch, seed: str, i: int) -> Optional[dict]:
    b = rm.binding
    pairs = list(b.pairs)

    # deterministic, independent orderings for the two columns, so the correct pairing is never the
    # identity permutation (A-I, B-II, C-III, D-IV), which a candidate could guess without reading
    left_order = sorted(range(4), key=lambda k: hashlib.sha256(f"{seed}|{b.binding_id}|{i}|L{k}".encode()).hexdigest())
    right_order = sorted(range(4), key=lambda k: hashlib.sha256(f"{seed}|{b.binding_id}|{i}|R{k}".encode()).hexdigest())

    list_i = {LEFT_LABELS[pos]: pairs[idx].left for pos, idx in enumerate(left_order)}
    list_ii = {RIGHT_LABELS[pos]: pairs[idx].right for pos, idx in enumerate(right_order)}

    # THE KEY, COMPUTED: for each left entry, the right label whose text is that pair's certified partner
    right_label_of_pair = {idx: RIGHT_LABELS[pos] for pos, idx in enumerate(right_order)}
    correct = {LEFT_LABELS[pos]: right_label_of_pair[idx] for pos, idx in enumerate(left_order)}
    if all(correct[L] == R for L, R in zip(LEFT_LABELS, RIGHT_LABELS)):
        return None                       # identity permutation — guessable, resample

    # distractors: permutations that differ from the key by exactly ONE transposition. A candidate who
    # knows a single pair cannot discard them wholesale, which is what the real form demands.
    variants: List[Dict[str, str]] = []
    for x, y in itertools.combinations(LEFT_LABELS, 2):
        alt = dict(correct)
        alt[x], alt[y] = alt[y], alt[x]
        if alt not in variants:
            variants.append(alt)
    variants.sort(key=lambda m: hashlib.sha256(f"{seed}|{b.binding_id}|{i}|{_render_mapping(m)}".encode()).hexdigest())
    chosen = variants[:3]
    if len(chosen) < 3:
        return None

    pool = [(_render_mapping(correct), True, None)] + \
           [(_render_mapping(m), False, m) for m in chosen]
    if len({p[0] for p in pool}) != 4:
        return None
    pool.sort(key=lambda p: hashlib.sha256(f"{seed}|{b.binding_id}|{i}|opt|{p[0]}".encode()).hexdigest())

    options: Dict[str, str] = {}
    answer_label = ""
    rationale: Dict[str, Dict[str, str]] = {}
    left_text_of_label = {L: t for L, t in list_i.items()}
    right_text_of_label = {R: t for R, t in list_ii.items()}
    for lab, (text, is_key, mapping) in zip(OPTION_LABELS, pool):
        options[lab] = text
        if is_key:
            answer_label = lab
        else:
            wrong = [L for L in LEFT_LABELS if mapping[L] != correct[L]]
            bits = []
            for L in wrong:
                bits.append(f"it pairs {L} ({left_text_of_label[L]}) with "
                            f"{mapping[L]} ({right_text_of_label[mapping[L]]}), but the certified relation "
                            f"for {left_text_of_label[L]} is {right_text_of_label[correct[L]]}")
            rationale[lab] = {"misconception": "; ".join(bits), "mis_relation": ""}
    if not answer_label:
        return None

    stem_body = b.stems[i % len(b.stems)]
    stem = (f"{stem_body}\n"
            f"List-I ({b.list_i_label}): " + "; ".join(f"({L}) {list_i[L]}" for L in LEFT_LABELS) + "\n"
            f"List-II ({b.list_ii_label}): " + "; ".join(f"({R}) {list_ii[R]}" for R in RIGHT_LABELS))

    steps = [f"Step 1 — Take each entry of List-I in turn and recall the certified relation that defines it."]
    for n, L in enumerate(LEFT_LABELS, start=2):
        idx = left_order[LEFT_LABELS.index(L)]
        pr = pairs[idx]
        head = rm.section_headings[idx] or pr.concept_name
        steps.append(f"Step {n} — {L}: {list_i[L]}. The certified Class-{pr.taught_at_class} concept "
                     f"'{rm.concept_names[idx]}' ({head}) gives {pr.right}, which is List-II entry "
                     f"{correct[L]}. So {L}-{correct[L]}.")
    steps.append(f"Step {len(LEFT_LABELS) + 2} — Collecting the four pairings gives "
                 f"{_render_mapping(correct)}, which is option ({answer_label}).")

    depth = 2
    diff = DIFF.predict(depth, len(set(rm.concept_ids)), misconception_pressure=0.0, calculation_load=0.2)

    gen_id = "CMTC_" + hashlib.sha256(f"{b.binding_id}|{stem}".encode()).hexdigest()[:16]
    return {
        "gen_id": gen_id,
        "binding_id": b.binding_id,
        "concept_id": rm.concept_ids[0],
        "concept_name": rm.concept_names[0],
        "concept_ids": list(dict.fromkeys(rm.concept_ids)),
        "chapter_id": rm.chapter_ids[0],
        "chapter_title": "",
        "section_heading": rm.section_headings[0],
        "class_level": b.taught_at_class,
        "subject": rm.subject,
        "discipline": b.discipline,
        "archetype": ARCHETYPE,
        "lane": LANE,
        "stem": stem,
        "options": options,
        "answer_label": answer_label,
        "answer_value": options[answer_label],
        "answer_unit": "",
        "structure": {},                  # non-numeric lane: no relation/givens are declared
        "solution": {"steps": steps, "final": options[answer_label]},
        "distractor_rationale": rationale,
        "common_mistake": "matching only the pair one is sure of and guessing the rest",
        "reasoning": (
            "The item cannot be answered from a single recognition: every option agrees with the key on "
            "two of the four pairings and differs on exactly two, so a candidate who is confident about "
            "one entry still cannot discard three options. All four correspondences have to be settled "
            "independently, each against the concept that certifies it, which is the difficulty this form "
            "carries in real papers — breadth of secure knowledge rather than length of calculation."),
        "reasoning_depth": depth,
        "difficulty": diff,
        "claimed": {"concepts": list(dict.fromkeys(rm.concept_names)),
                    "concept_ids": list(dict.fromkeys(rm.concept_ids)),
                    "archetype": ARCHETYPE, "depth": depth,
                    "composition": "multi" if len(set(rm.concept_ids)) > 1 else "single",
                    # each pairing is grounded in its OWN certified concept and the key depends on all of
                    # them — the checkable non-numeric backing `composition_backed` now accepts
                    "composition_components": list(dict.fromkeys(rm.concept_ids))},
        "provenance": {
            "lane": "CERTGEN_MATCH_COLUMNS",
            "evidence_class": "deterministic_computed",
            "certified_concept_id": rm.concept_ids[0],
            "certified_concept_ids": list(dict.fromkeys(rm.concept_ids)),
            "grounding": [g for pr in b.pairs for g in pr.grounding],
            "correct_mapping": correct,
            "key_derivation": "computed — the permutation reproducing every certified pairing",
            "corpus_basis": ("match is 11.0% of NEET and 7.6% of JEE_ADVANCED across 15,803 measured PYQ "
                             "items (2011-2025); structurally 55% hard / 0% easy"),
            "boundary": rm.boundary,
        },
        "_params": {},
    }


def verify_key(item: dict) -> dict:
    """Exactly one option may reproduce every certified pairing.

    The analogue of the numeric distractor proof: a wrong option is proved wrong by naming a specific pair
    it contradicts, and an option that contradicts nothing would be a second correct answer.
    """
    correct = item["provenance"]["correct_mapping"]
    target = _render_mapping(correct)
    matching = [lab for lab, text in item["options"].items() if text == target]
    unrefuted = [lab for lab, r in item["distractor_rationale"].items() if not r.get("misconception")]
    ok = (len(matching) == 1 and matching[0] == item["answer_label"] and not unrefuted
          and len(item["distractor_rationale"]) == 3)
    return {"ok": ok, "matching": matching, "unrefuted": unrefuted,
            "detail": f"options_reproducing_certified_pairing={matching} key={item['answer_label']} "
                      f"unrefuted={unrefuted}"}


def generate(resolved: Sequence[ResolvedMatch], per_binding: int = 3, seed: str = "M1") -> List[dict]:
    out: List[dict] = []
    for rm in resolved:
        used: set = set()
        attempt = 0
        n_scen = len(rm.binding.stems)
        while len(used) < min(per_binding, n_scen) and attempt < n_scen * 24:
            scen = attempt % n_scen
            if scen in used:
                attempt += 1
                continue
            it = build_item(rm, seed, attempt)
            attempt += 1
            if it is None:
                continue
            used.add(scen)
            out.append(it)
    return out
