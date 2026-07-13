"""Certified-model-driven generation bridge (Phase D, narrowest vertical slice).

Connects the CERTIFIED Question-Intelligence Item Models (the thing capability.py proved) to actual
new-question generation — the primary verified blocker. Scope of THIS slice: NEET Biology
factual_single_best_answer ONLY.

It authors GENUINELY NEW stems (fixed, authored association frames — never source-question wording) whose
CORRECT answer is a verified fact token of the certified concept and whose DISTRACTORS are verified fact
tokens of OTHER certified concepts (governed evidence, wrong for this concept). Every candidate is then run
through an INDEPENDENT correctness verifier (pluggable — the governed Tier-2 lane in production); candidates
are PASS / REJECT / QUARANTINE-d on answer disagreement, unsupported content, boundary violation, near-copy /
duplicate, or uncertainty. Full provenance (generated → item_model → concept → evidence fact_keys →
verification) is preserved. Nothing is fabricated: answers and distractors are only ever verified tokens.

Deterministic (seeded by content hash), stdlib-only. Writes nothing here — the caller persists results.
"""
from __future__ import annotations

import hashlib
import re
from dataclasses import dataclass, field
from typing import Callable, Dict, Iterable, List, Optional, Set, Tuple

from kie.qie import mine

# authored frames — the STEM is ours, never copied from a source question. {topic} = certified concept title.
FRAMES: Tuple[Tuple[str, str], ...] = (
    ("assoc", "Which one of the following is most closely associated with {topic}?"),
    ("belongs", "In the study of {topic}, which one of the following is the correct term?"),
)

_STOP_START = re.compile(r"^(during|emerging|depletion|no |not |all |none|both|only|increasing|reusable|"
                         r"breakdown|contracts|the )", re.I)


def is_entity_token(a: str) -> bool:
    """Accept only clean 1–2 word noun-like entity tokens; reject phrases/fragments/option-labels/numbers."""
    a = (a or "").strip()
    if not (1 <= len(a.split()) <= 2 and 4 <= len(a) <= 25):
        return False
    if not re.match(r"^[A-Za-z][A-Za-z0-9 \-/]+$", a):
        return False
    if _STOP_START.match(a) or " and " in f" {a.lower()} " or " of " in f" {a.lower()} ":
        return False
    return True


def _norm(s: str) -> str:
    return re.sub(r"[^a-z0-9]+", "", (s or "").lower())


@dataclass
class Evidence:
    tokens_by_concept: Dict[str, Set[str]]           # concept -> verified entity tokens
    topic_by_concept: Dict[str, str]                 # concept -> title (for the stem frame)
    token_concepts: Dict[str, Set[str]]              # normalized token -> set of concepts it is verified under
    source_option_sigs: Set[frozenset]               # normalized option-sets of SOURCE MCQs (near-copy guard)

    def exclusive_tokens(self, concept: str) -> List[str]:
        """Verified entity tokens that belong to THIS concept and to no other certified concept (cleaner
        membership → fewer false-association candidates before verification)."""
        out = [t for t in self.tokens_by_concept.get(concept, set())
               if len(self.token_concepts.get(_norm(t), set())) == 1]
        return sorted(out)


def build_evidence(stream: Iterable[Tuple[str, str, Optional[list]]], verified_facts: Set[str],
                   concept_titles: Dict[str, str]) -> Evidence:
    """stream: iterable of (concept_code, answer_text, source_options|None) for resolved Biology items.
    Only VERIFIED (concept, answer) facts with entity-clean answers become tokens. source option-sets are
    captured for the near-copy guard."""
    tokens: Dict[str, Set[str]] = {}
    token_concepts: Dict[str, Set[str]] = {}
    sigs: Set[frozenset] = set()
    for concept, answer, options in stream:
        if options:
            sigs.add(frozenset(_norm(o) for o in options if o))
        if not answer or not is_entity_token(answer):
            continue
        if mine.fact_key(concept, answer) not in verified_facts:
            continue
        tokens.setdefault(concept, set()).add(answer.strip())
        token_concepts.setdefault(_norm(answer), set()).add(concept)
    return Evidence(tokens, {c: concept_titles.get(c, c) for c in tokens}, token_concepts, sigs)


def select_certified_concepts(models: List[dict]) -> List[str]:
    """From capability records, the certified Biology × NEET factual models on genuine BIO_ concepts."""
    seen, out = set(), []
    for m in models:
        if (m.get("subject") == "Biology" and m.get("profile") == "NEET" and m.get("certifiable")
                and m.get("archetype") == "factual_single_best_answer"
                and str(m.get("concept", "")).startswith("BIO_") and m["concept"] not in seen):
            seen.add(m["concept"]); out.append(m["concept"])
    return out


def _seed_sort(items: List[str], seed: str) -> List[str]:
    return sorted(items, key=lambda x: hashlib.sha256(f"{seed}|{x}".encode()).hexdigest())


def generate_candidates(concepts: List[str], ev: Evidence, seed: str = "D1",
                        n_distractors: int = 3, per_concept: int = 2) -> List[dict]:
    """Deterministically author candidate MCQs. Correct = an exclusive verified token of the concept;
    distractors = verified tokens of OTHER concepts (never of this concept). Returns raw candidates
    (pre-gate, pre-verify)."""
    cands: List[dict] = []
    for concept in concepts:
        correct_pool = ev.exclusive_tokens(concept)
        if not correct_pool:
            continue
        topic = ev.topic_by_concept.get(concept, concept)
        for i, correct in enumerate(_seed_sort(correct_pool, seed)[:per_concept]):
            # distractor pool: entity tokens NOT verified for this concept
            pool = [t for c2, ts in ev.tokens_by_concept.items() if c2 != concept for t in ts
                    if concept not in ev.token_concepts.get(_norm(t), set()) and _norm(t) != _norm(correct)]
            pool = list(dict.fromkeys(_seed_sort(pool, f"{seed}|{concept}|{correct}")))
            if len(pool) < n_distractors:
                continue
            distractors = pool[:n_distractors]
            frame_id, frame = FRAMES[i % len(FRAMES)]
            opts = _seed_sort([correct] + distractors, f"{seed}|opt|{concept}|{correct}")
            options = {str(j + 1): t for j, t in enumerate(opts)}
            gen_id = "GEN_" + hashlib.sha256(f"{concept}|{correct}|{frame_id}".encode()).hexdigest()[:16]
            cands.append({
                "gen_id": gen_id, "item_model_id": "IMC_" + hashlib.sha256(
                    f"Biology|NEET|{concept}|factual_single_best_answer".encode()).hexdigest()[:16],
                "concept": concept, "profile": "NEET", "subject": "Biology",
                "archetype": "factual_single_best_answer", "frame_id": frame_id,
                "stem": frame.format(topic=topic), "options": options, "answer_text": correct,
                "correct_fact_key": mine.fact_key(concept, correct),
                "distractor_fact_keys": [mine.fact_key(next(iter(ev.token_concepts[_norm(d)])), d)
                                         for d in distractors],
                "provenance": {"certified_model": True, "correct_source_concept": concept,
                               "distractor_tokens": distractors},
            })
    return cands


def gate(cand: dict, ev: Evidence, seen_sigs: Set[tuple]) -> Optional[str]:
    """Return a rejection reason or None. Enforces boundary, evidence-support, near-copy, duplicate."""
    opts = list(cand["options"].values())
    ans = cand["answer_text"]
    # boundary + evidence-support: answer must be a verified token OF this concept; distractors must NOT be
    if ans not in ev.tokens_by_concept.get(cand["concept"], set()):
        return "UNSUPPORTED_ANSWER"
    # quality: reject a tautological item whose answer merely restates the concept topic (e.g. Mitochondria
    # -> "Mitochondria") — deterministically, before spending a verification call
    if _norm(ans) == _norm(ev.topic_by_concept.get(cand["concept"], "")):
        return "TAUTOLOGY"
    if any(cand["concept"] in ev.token_concepts.get(_norm(o), set()) for o in opts if o != ans):
        return "DISTRACTOR_IN_CONCEPT"
    if len({_norm(o) for o in opts}) != len(opts):
        return "DUPLICATE_OPTION"
    # near-copy of a source MCQ (same option set)
    if frozenset(_norm(o) for o in opts) in ev.source_option_sigs:
        return "NEAR_COPY_OF_SOURCE"
    # duplicate generated item
    sig = (cand["concept"], _norm(ans), tuple(sorted(_norm(o) for o in opts)))
    if sig in seen_sigs:
        return "DUPLICATE_GENERATED"
    seen_sigs.add(sig)
    return None


def run(concepts: List[str], ev: Evidence, verify_fn: Callable[[dict], str], seed: str = "D1",
        per_concept: int = 2) -> dict:
    """Generate → gate → independently verify. verify_fn(candidate) -> 'agree'|'disagree'|'unverifiable'.
    Returns {passed, rejected, quarantined, items} with full provenance + verification on each item."""
    seen: Set[tuple] = set()
    passed, rejected, quarantined = [], [], []
    for cand in generate_candidates(concepts, ev, seed, per_concept=per_concept):
        reason = gate(cand, ev, seen)
        if reason:
            rejected.append({**cand, "status": "REJECT", "reason": reason})
            continue
        verdict = verify_fn(cand)
        cand = {**cand, "verification": {"verdict": verdict}}
        if verdict == "agree":
            passed.append({**cand, "status": "PASS"})
        elif verdict == "disagree":
            rejected.append({**cand, "status": "REJECT", "reason": "ANSWER_DISAGREEMENT"})
        else:
            quarantined.append({**cand, "status": "QUARANTINE", "reason": "UNVERIFIABLE"})
    return {"attempted": len(passed) + len(rejected) + len(quarantined),
            "passed": len(passed), "rejected": len(rejected), "quarantined": len(quarantined),
            "items": passed + rejected + quarantined}
