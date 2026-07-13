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


# ── blocker 2: distractor plausibility — biological-family grouping (deterministic, from concept titles) ──
_FAMILY_KEYWORDS: Tuple[Tuple[str, str], ...] = (
    ("reproduction", r"reproduc|fertilis|pollinat|menstr|gamet|embryo|ovul"),
    ("cell", r"\bcell\b|mitochond|membrane|organelle|nucleus|ribosom|cytoplasm|plastid|plasma"),
    ("metabolism", r"photosynth|energy releasing|energy producing|glycolysis|krebs|respiration.*energy"),
    ("molecular", r"molecular|inherit|\bdna\b|\bgene|nucleic|protein"),
    ("ecology", r"ecosystem|biodivers|population|evolution|environ|conservation|habitat"),
    ("immunology", r"immun|antibod|pathogen|microb|vaccine"),
    ("human_systems", r"endocrine|neural|nervous|circulat|respirat|excret|digest|heart|blood|kidney|"
                      r"coordination|hormone|breathing|transport"),
)


def concept_family(title: str) -> str:
    t = (title or "").lower()
    for fam, pat in _FAMILY_KEYWORDS:
        if re.search(pat, t):
            return fam
    return "other"


@dataclass
class Plausibility:
    family_by_concept: Dict[str, str]
    concepts_by_family: Dict[str, List[str]]
    neighbors: Dict[str, Set[str]] = field(default_factory=dict)   # concept -> edge-neighbour concepts


def build_plausibility(concept_titles: Dict[str, str],
                       edges: Optional[Iterable[Tuple[str, str]]] = None) -> Plausibility:
    fam_by = {c: concept_family(t) for c, t in concept_titles.items()}
    by_fam: Dict[str, List[str]] = {}
    for c, f in fam_by.items():
        by_fam.setdefault(f, []).append(c)
    nbr: Dict[str, Set[str]] = {}
    for a, b in (edges or ()):
        nbr.setdefault(a, set()).add(b); nbr.setdefault(b, set()).add(a)
    return Plausibility(fam_by, by_fam, nbr)


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


def select_distractors(concept: str, correct: str, ev: Evidence, plaus: Plausibility, seed: str,
                       n: int = 3) -> List[Tuple[str, str, str]]:
    """Bounded, validated, PLAUSIBLE distractor selection (blocker 2). Priority tiers, all evidence-backed
    (verified tokens of OTHER concepts, never of this concept): (1) same biological FAMILY, (2) edge
    NEIGHBOUR, (3) cross. Within a tier prefer the SAME word-count as the correct answer (shape/difficulty
    plausibility). Returns [(token, source_concept, tier)] — never fabricates."""
    cw = len(correct.split())
    fam = plaus.family_by_concept.get(concept)
    fam_concepts = set(plaus.concepts_by_family.get(fam, ())) - {concept}
    nbr_concepts = set(plaus.neighbors.get(concept, ())) - {concept}

    def valid(tok: str) -> bool:
        return (concept not in ev.token_concepts.get(_norm(tok), set())
                and _norm(tok) != _norm(correct))

    def pool(concept_set):
        items = [(t, c2) for c2 in concept_set for t in ev.tokens_by_concept.get(c2, set()) if valid(t)]
        # prefer same word-count, then deterministic hash order
        return _seed_sort2(items, f"{seed}|{concept}|{correct}", cw)

    chosen: List[Tuple[str, str, str]] = []
    seen: Set[str] = set()
    for concept_set, tier in ((fam_concepts, "family"), (nbr_concepts, "neighbour"),
                              (set(ev.tokens_by_concept) - {concept}, "cross")):
        for tok, c2 in pool(concept_set):
            if _norm(tok) in seen:
                continue
            seen.add(_norm(tok)); chosen.append((tok, c2, tier))
            if len(chosen) == n:
                return chosen
    return chosen


def _seed_sort2(items: List[Tuple[str, str]], seed: str, target_words: int) -> List[Tuple[str, str]]:
    return sorted(items, key=lambda it: (abs(len(it[0].split()) - target_words),
                                         hashlib.sha256(f"{seed}|{it[0]}".encode()).hexdigest()))


def generate_candidates(concepts: List[str], ev: Evidence, plaus: Plausibility, seed: str = "D1",
                        n_distractors: int = 3, per_concept: int = 2) -> List[dict]:
    """Deterministically author candidate MCQs. Correct = an exclusive verified token of the concept;
    distractors = PLAUSIBLE verified tokens of OTHER concepts (family/neighbour-preferred). Raw (pre-gate)."""
    cands: List[dict] = []
    for concept in concepts:
        correct_pool = ev.exclusive_tokens(concept)
        if not correct_pool:
            continue
        topic = ev.topic_by_concept.get(concept, concept)
        for i, correct in enumerate(_seed_sort(correct_pool, seed)[:per_concept]):
            dsel = select_distractors(concept, correct, ev, plaus, seed, n_distractors)
            if len(dsel) < n_distractors:
                continue
            distractors = [d[0] for d in dsel]
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
                "distractor_fact_keys": [mine.fact_key(c2, t) for t, c2, _ in dsel],
                "provenance": {"certified_model": True, "correct_source_concept": concept,
                               "distractors": [{"token": t, "source_concept": c2, "plausibility_tier": tier}
                                               for t, c2, tier in dsel]},
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


def persist_pilot_bank(qconn, items: List[dict], verifier_model: str, now: str) -> int:
    """Write ONLY fully-verified PASS items to the SEPARATE pilot_verified_item bank (never the Certified
    Bank). Refuses anything not status==PASS — a hard boundary so REJECT/QUARANTINE cannot leak in."""
    import json as _json
    n = 0
    for it in items:
        if it.get("status") != "PASS":
            raise ValueError(f"refusing to bank a non-PASS item: {it.get('gen_id')} ({it.get('status')})")
        v = it.get("verification", {})
        qconn.execute(
            "INSERT OR REPLACE INTO pilot_verified_item(gen_id,item_model_id,subject,profile,concept_code,"
            "archetype,frame_id,stem,options,answer_text,correct_fact_key,distractor_fact_keys,"
            "distractor_provenance,verifier_verdict,refuter_verdict,verifier_model,created_at) "
            "VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
            (it["gen_id"], it["item_model_id"], it["subject"], it["profile"], it["concept"], it["archetype"],
             it.get("frame_id"), it["stem"], _json.dumps(it["options"]), it["answer_text"],
             it["correct_fact_key"], _json.dumps(it["distractor_fact_keys"]),
             _json.dumps(it["provenance"].get("distractors", [])), v.get("verifier", v.get("verdict")),
             v.get("refuter", v.get("verdict")), verifier_model, now))
        n += 1
    qconn.commit()
    return n


def distractor_check(cand: dict, ev: Evidence) -> Optional[str]:
    """Automatic distractor validity/plausibility check: every distractor must be evidence-backed (a verified
    token of another concept) and not associated with this concept. Returns a reason or None."""
    for d in cand.get("provenance", {}).get("distractors", []):
        tok = d["token"]
        if _norm(tok) not in ev.token_concepts or not ev.token_concepts[_norm(tok)]:
            return "DISTRACTOR_NOT_EVIDENCE_BACKED"
        if cand["concept"] in ev.token_concepts.get(_norm(tok), set()):
            return "DISTRACTOR_IN_CONCEPT"
    return None


def run(concepts: List[str], ev: Evidence, plaus: Plausibility, verify_fn: Callable[[dict], str],
        seed: str = "D1", per_concept: int = 2, n_distractors: int = 3) -> dict:
    """In-loop pipeline (blocker 1): generate → gate → distractor-check → INDEPENDENT verify. Only PASS may
    proceed; REJECT/QUARANTINE never enter a bank. verify_fn(cand) -> 'agree'|'disagree'|'unverifiable'."""
    seen: Set[tuple] = set()
    passed, rejected, quarantined = [], [], []
    for cand in generate_candidates(concepts, ev, plaus, seed, n_distractors, per_concept):
        reason = gate(cand, ev, seen) or distractor_check(cand, ev)
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
            "items": passed + rejected + quarantined,
            "verified_bank": passed}   # ONLY PASS items are eligible for the pilot verified bank
