"""STAGE 2 — the REPAIRED QIE input contract.

QIE planning now consumes ONLY the certified knowledge index (`ki_concept.status='certified'`).
It may not read `kie.db.concepts`, and it may never infer curriculum truth from
`source_documents.class_label`.

THE DISTINCTION THIS FILE ENFORCES
    mentioned_in_source : this string appeared in this PDF. Provenance. NEVER a boundary.
    taught_at_class     : this concept is a numbered taught section of THAT class's own
                          single-subject textbook, proposed by a knowledge engineer and
                          accepted by an INDEPENDENT auditor.
Only `taught_at_class` reaches a generation brief.

WHY THE PRE-GENERATION GATE EXISTS (measured, 1,000-spec trial)
The deterministic gates were BLIND to a bad plan: they caught 20.0% of a known-garbage probe arm vs
20.1% of the legitimate arm — statistically identical — and the curriculum_boundary gate never fired
once in 684 candidates. The ONLY thing that caught bad plans was the generator refusing (49% vs 27%),
i.e. a model judgement, at full token price. ~66% of all refusals were the generator rejecting the
PLANNER's own defects: subject mismatch (49.7%), bogus composition (11.6%), incoherent archetype×depth
(2.2%), corpus junk (2.2%).

So every check below runs BEFORE a single Opus token is spent. A spec that cannot be defended is never
issued. Refusing a plan costs nothing; discovering it after generation costs ~3,043 tokens.
"""
from __future__ import annotations

import json
import re
import sqlite3
from typing import Dict, List, Optional, Tuple

from kie.qie.archetypes import ARCHETYPES

# archetype x reasoning-depth compatibility. The trial's generator refused specs like
# "direct_recall at depth 3", correctly: "direct recall is by definition a single lookup of a stored
# fact and carries no dependent steps". That was the PLANNER's incoherence, caught at token price.
# Encoded here so it is caught for free.
_ARCH_DEPTH: Dict[str, Tuple[int, int]] = {
    "direct_recall": (1, 1),
    "definition_recognition": (1, 1),
    "factual_single_best_answer": (1, 2),
    "property_application": (1, 3),
    "single_step_numerical": (1, 2),
    "multi_step_numerical": (2, 5),
    "reverse_numerical": (2, 4),
    "missing_variable_inference": (2, 4),
    "misconception_detection": (1, 3),
    "comparison": (1, 3),
    "cause_effect": (1, 3),
    "assertion_reason": (1, 3),
    "case_interpretation": (2, 4),
    "experiment_inference": (2, 4),
    "graph_interpretation": (1, 4),
    "table_interpretation": (1, 3),
    "diagram_interpretation": (1, 4),
    "error_analysis": (1, 3),
    "constraint_reasoning": (2, 5),
    "multi_concept_integration": (2, 5),
}

# Junk that must never appear as a concept name, regardless of what any model proposed.
# NOT a patch-list for individual examples — a structural class of string that is never a concept.
_JUNK_NAME = re.compile(
    r"^(contents?|contributors?|reviewers?|preamble|pledge|fundamental duties|national anthem|"
    r"foreword|preface|acknowledg|bibliograph|bibligraph|artwork|chief advisor|advisor|answers?|"
    r"appendix|index|glossary|syllabus|try these|think|figure it out|exercise|activity|"
    r"summary|introduction|what have we discussed|some applications|miscellaneous)\b", re.I)
# NOTE: a short name is NOT a garbage signal. An earlier `^\w{0,3}$` rule here silently refused the
# certified Class-6 concept "Ray", and would equally have killed "Set", "Arc", "LCM", "HCF", "Pi".
# Garbage is repeated characters or a vowel-less run — not brevity.
_OCR_CHAR = re.compile(r"(.)\1{3,}|^[bcdfghjklmnpqrstvwxyz]{5,}$", re.I)


def _ngram_repetition(s: str) -> float:
    """Fraction of the string covered by its most-repeated n-gram.

    The real OCR garbage in this corpus is SYLLABLE REPETITION, which a char-repeat or consonant-run
    check cannot see: `Telateltelt` (tel·atel·telt), `answeranswer` (answer·answer),
    `Scescescececert` (sce·sce·sce), `Langanaanannganngan` (ngan·ngan·ngan). All of those were ACTIVE
    concepts in the old table and the existing title sanitizer accepted every one of them.
    """
    t = re.sub(r"[^a-z]", "", (s or "").lower())
    if len(t) < 6:
        return 0.0
    best = 0.0
    for n in range(2, max(3, len(t) // 2) + 1):
        counts: Dict[str, int] = {}
        for i in range(len(t) - n + 1):
            g = t[i:i + n]
            counts[g] = counts.get(g, 0) + 1
        if not counts:
            continue
        g, c = max(counts.items(), key=lambda kv: kv[1] * len(kv[0]))
        if c > 1:
            best = max(best, c * n / len(t))
    return best


def is_ocr_garbage(name: str) -> bool:
    if _OCR_CHAR.search((name or "").replace(" ", "")):
        return True
    # syllable repetition is a garbage signal only WITHIN a single word ("Telateltelt", "answeranswer").
    # A repeated WHOLE word ("Common Multiples", "Cell Membrane (Plasma Membrane)",
    # "Gametogenesis (Spermatogenesis)") is legitimate curriculum, not OCR damage — so scan per word,
    # never across the space-collapsed string (which false-refused 18 certified concepts).
    return any(_ngram_repetition(w) >= 0.60 for w in re.findall(r"[A-Za-z]+", name or ""))


class PlanRefused(Exception):
    """A plan that cannot be defended is never issued. Costs zero tokens."""


def certified_universe(iconn: sqlite3.Connection, subject: str,
                       classes: Optional[List[int]] = None) -> List[dict]:
    """The ONLY legal planning input: independently-audited, certified knowledge records."""
    q = ("SELECT c.concept_id, c.canonical_name, c.subject, c.taught_at_class, c.sub_concepts, "
         "c.prerequisites, c.boundary, c.evidence_chunks, c.section_heading, "
         "ch.chapter_id, ch.chapter_no, ch.title AS chapter_title "
         "FROM ki_concept c JOIN ki_chapter ch ON ch.chapter_id = c.chapter_id "
         "WHERE c.subject=? AND c.status='certified' AND ch.status='accepted'")
    args: List = [subject]
    if classes:
        q += " AND c.taught_at_class IN (%s)" % ",".join("?" * len(classes))
        args += classes
    out = []
    # final tie-break on concept_id makes the scan order total (deterministic under ANY re-import,
    # not merely for the current physical row order of the frozen DB).
    for r in iconn.execute(q + " ORDER BY c.taught_at_class, ch.chapter_no, c.canonical_name, c.concept_id",
                           args):
        d = dict(r)
        d["sub_concepts"] = json.loads(d["sub_concepts"] or "[]")
        d["prerequisites"] = json.loads(d["prerequisites"] or "[]")
        d["boundary"] = json.loads(d["boundary"] or "{}")
        out.append(d)
    return out


def check_plan(spec: dict, universe_by_id: Dict[str, dict]) -> List[str]:
    """Deterministic PRE-GENERATION checks. Returns a list of violations; empty means the spec may be
    issued. Every one of these was a defect the trial's generator had to catch at token price."""
    v: List[str] = []

    # 1. non-concept / junk record — the class of defect that put a line of the national anthem into
    #    the old table as a Class-10 Mathematics concept.
    name = (spec.get("concept_name") or "").strip()
    if not name:
        v.append("junk_record: empty concept name")
    else:
        if _JUNK_NAME.match(name):
            v.append(f"junk_record: {name!r} is book apparatus / an activity label, not a concept")
        if is_ocr_garbage(name):
            v.append(f"junk_record: {name!r} is OCR garbage (repeated-syllable artifact)")

    # 2. the concept must exist in the CERTIFIED index — not in kie.db.concepts, not invented
    cid = spec.get("concept_id")
    kc = universe_by_id.get(cid)
    if not kc:
        v.append(f"uncertified_concept: {cid!r} is not a certified knowledge record")
        return v

    # 3. subject mismatch — 49.7% of the trial's refusals. Now free.
    if spec.get("subject") != kc["subject"]:
        v.append(f"subject_mismatch: spec says {spec.get('subject')!r}, certified index says {kc['subject']!r}")

    # 3b. name must match the certified canonical name — a resolving id carrying a MISLABELLED (non-junk)
    #     name is a defect a subject/junk check alone cannot see.
    if name and name != kc["canonical_name"]:
        v.append(f"name_mismatch: spec name {name!r} != certified {kc['canonical_name']!r}")

    # 4. class/chapter boundary mismatch — taught_at_class is authoritative, never the doc label
    if int(spec.get("class_level") or 0) != int(kc["taught_at_class"]):
        v.append(f"class_mismatch: spec says class {spec.get('class_level')}, "
                 f"certified taught_at_class is {kc['taught_at_class']}")
    ch = spec.get("chapter_id")
    if not ch:
        v.append("chapter_missing: a spec must name the concept's certified chapter (no fail-open on a blank id)")
    elif ch != kc["chapter_id"]:
        v.append(f"chapter_mismatch: {ch!r} vs certified {kc['chapter_id']!r}")

    # 5. archetype validity + archetype x depth coherence
    arch = spec.get("archetype")
    depth = int(spec.get("intended_depth") or 0)
    if arch not in ARCHETYPES:
        v.append(f"unknown_archetype: {arch!r}")
    else:
        lo, hi = _ARCH_DEPTH.get(arch, (1, 5))
        if not (lo <= depth <= hi):
            v.append(f"archetype_depth_incoherent: {arch!r} supports depth {lo}-{hi}, spec asks {depth}")

    # 6. composition must be a KNOWN kind and SUPPORTED by the index, not asserted by the planner.
    #    The trial's planner paired "Newton's law" with "Aufbau's principle"; the generator refused.
    #    An unknown composition token must NOT fail open — partners are validated on every non-single kind
    #    so a bogus kind ("dual", "sequential_chain") cannot smuggle a cross-subject/above-class partner past.
    comp = spec.get("composition")
    partners = spec.get("compose_with") or []
    if comp not in ("single", "multi"):
        v.append(f"unsupported_composition: unknown composition kind {comp!r}")
    if comp == "single":
        if partners:
            v.append("unsupported_composition: single composition must not declare partners")
    else:
        if comp == "multi" and not partners:
            v.append("unsupported_composition: multi requested with no partner concept")
        for pid in partners:
            p = universe_by_id.get(pid)
            if not p:
                v.append(f"unsupported_composition: partner {pid!r} is not a certified concept")
                continue
            if p["subject"] != kc["subject"]:
                v.append(f"unsupported_composition: partner {p['canonical_name']!r} is {p['subject']}, "
                         f"not {kc['subject']}")
            if p["taught_at_class"] > kc["taught_at_class"]:
                v.append(f"unsupported_composition: partner {p['canonical_name']!r} is taught at class "
                         f"{p['taught_at_class']} > {kc['taught_at_class']}")

    return v


def dedupe_universe(universe: List[dict]) -> Tuple[List[dict], List[dict]]:
    """Collapse duplicate canonical concepts within (subject, class). The old table had Gauss's law
    three times across three subjects because each document minted its own copy; the index is built
    per-concept, but a same-name duplicate inside one class is still a planner hazard."""
    seen: Dict[Tuple[str, int, str], dict] = {}
    dups: List[dict] = []
    for c in universe:
        k = (c["subject"], c["taught_at_class"], c["canonical_name"].strip().lower())
        if k in seen:
            dups.append(c)
        else:
            seen[k] = c
    return list(seen.values()), dups


def forbidden_terms(universe: List[dict], subject: str, class_level: int, limit: int = 25) -> List[str]:
    """Above-class vocabulary, derived from CERTIFIED taught_at_class — not from heuristic grade tags.
    Also folds in each concept's own evidenced `boundary.out_of_scope`, which is real curriculum
    evidence rather than a synthesized guess."""
    below = set()
    for c in universe:
        if c["subject"] != subject or c["taught_at_class"] > class_level:
            continue
        below.update(w.lower() for w in re.findall(r"[A-Za-z]{4,}", c["canonical_name"]))
    above: Dict[str, int] = {}
    for c in universe:
        if c["subject"] != subject or c["taught_at_class"] <= class_level:
            continue
        for w in re.findall(r"[A-Za-z]{5,}", c["canonical_name"]):
            w = w.lower()
            if w in below:
                continue
            above[w] = above.get(w, 0) + (c["taught_at_class"] - class_level)
    ranked = [w for w, _ in sorted(above.items(), key=lambda kv: (-kv[1], kv[0]))][:limit]
    # evidenced out-of-scope for THIS class beats any synthesized list
    oos: List[str] = []
    for c in universe:
        if c["subject"] == subject and c["taught_at_class"] == class_level:
            oos += [str(x) for x in (c.get("boundary") or {}).get("out_of_scope", [])][:2]
    return ranked + oos[:10]
