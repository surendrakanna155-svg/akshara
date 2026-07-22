"""Program D — deterministic synthetic certified-bank fixtures (TEST-ONLY).

Emits N rows in the qpl_question_bank *certified* shape (status='certified',
certification_class='certified') into a THROWAWAY production-stamped bank, so the
Program-D promotion → import → retrieval pipeline is fully buildable and testable
BEFORE a real certified bank exists. (Readiness report §0: the empty certified
bank is the *operational* blocker, not an *engineering* one — the fixture lane is
the first-class deliverable that decouples construction from data supply.)

NON-NEGOTIABLE INVARIANTS (why this is not a certification bypass):
  * TEST-ONLY. This module NEVER opens or writes the real production bank
    (`corpus.PRODUCTION_BANK_DB_PATH`). It builds an isolated `:memory:` (or a
    caller-supplied temp) bank via `corpus.open_store(path, role=ROLE_PRODUCTION)`.
  * It promotes rows through the SAME guarded write path the factory uses
    (`save_specs` → `ingest` → `mark_certified`), so a fixture row is structurally
    identical to a real certified row and exercises the real integrity guards
    (append-only ingest, RI-9 bank-dedup UNIQUE on item_hash + stem_norm_hash,
    guarded status transition). It does NOT re-run the AI/gate certification
    pipeline — it synthesises already-certified *test data*, clearly labelled and
    unreachable from any prod code path. It weakens NO gate and touches NO real
    store.

Content realism: each item is a distinct, real arithmetic word problem. Because
`norm_hash` collapses numbers → '#' (a template re-fired with fresh numbers is a
near-duplicate by construction), every item carries a UNIQUE context noun so its
NORMALISED stem is unique — which is exactly why the RI-9 bank-dedup UNIQUE lets
all N promote. Two items sharing a skill template (different noun) form a natural
near-dup pair, useful for the M4.3 semantic-near-dup tests.

Determinism contract:
  * `make_certified_fixture(n, seed)` returns pure content — no DB, no wall-clock,
    no randomness beyond a seed-derived hash. Same (n, seed, kwargs) → byte-
    identical rows (candidate_id / item_hash / stem_norm_hash included). This is
    what the exporter's byte-identical-artifact test rests on.
  * `build_fixture_bank(...)` materialises those rows into a real production bank.
    The only non-deterministic field is `created_at` (wall-clock) — deliberately
    NOT part of content identity, so it never perturbs the export artifact.
"""
from __future__ import annotations

import hashlib
import json
import sqlite3
from typing import Callable, Dict, List, Optional, Tuple

from kie.qie.factory import corpus
from kie.qie.factory.gates import item_hash, norm_hash

# ── fixed, non-placeholder provenance for the synthetic factory ──────────────────────────────────────
# Deliberately NOT any of corpus.BANNED_PROVENANCE_IDS: a fixture row must carry honest, distinct
# provenance so the exporter can round-trip it (and so it can never be mistaken for anonymous 'agent'
# output). The model/actor names announce themselves as the Program-D fixture harness.
_FIXTURE_GENERATOR_MODEL = "fixture-structured-numeric-v1"
_FIXTURE_GENERATOR_FAMILY = "program-d-fixture-family"
_FIXTURE_ACTOR = "program-d-fixture-harness"
_FIXTURE_CONTRACT = "program-d-fixture-contract-1"

# One distinct context noun per item guarantees a unique NORMALISED stem (nouns survive normalisation;
# numbers do not). 64 nouns ⇒ fixtures of up to 64 fully-distinct certified items — ample for tests.
_NOUNS: Tuple[str, ...] = (
    "apple", "pencil", "book", "marble", "coin", "ribbon", "stamp", "brick", "candle", "ticket",
    "bead", "tile", "seed", "lemon", "button", "balloon", "crayon", "eraser", "magnet", "cube",
    "ring", "spoon", "cup", "plate", "flag", "kite", "drum", "bell", "clip", "card",
    "token", "gem", "shell", "leaf", "feather", "nail", "screw", "bolt", "washer", "gear",
    "bottle", "jar", "carton", "sack", "basket", "crate", "tray", "rack", "pouch", "packet",
    "cable", "wire", "rod", "bar", "sheet", "slab", "block", "panel", "frame", "hook",
    "lens", "disk", "chip", "reel",
)


def _h(seed: int, i: int, tag: str) -> bytes:
    return hashlib.sha256(f"pd-fixture|{seed}|{i}|{tag}".encode()).digest()


def _rint(seed: int, i: int, tag: str, lo: int, hi: int) -> int:
    return lo + (int.from_bytes(_h(seed, i, tag)[:4], "big") % (hi - lo + 1))


def _kc_id(subject: str, class_level: int, concept_name: str) -> str:
    """A KC_<sha14> concept id byte-identical to the QIE spine's `concept_id`
    (kie.qie.knowledge.spine.concept_id): KC_ + sha256(subject|class|lower(name))[:14]."""
    h = hashlib.sha256(f"{subject}|{class_level}|{concept_name.strip().lower()}".encode()).hexdigest()[:14]
    return "KC_" + h


def _distractors(ans: int, seed: int, i: int) -> List[int]:
    """Three DISTINCT wrong integers, deterministic, never equal to the answer. Off-by-one and
    off-by-magnitude are the classic arithmetic misconceptions, so the distractors are plausible."""
    candidates = [ans + 1, ans - 1, ans + 10, ans - 10, ans * 2, ans + _rint(seed, i, "d", 2, 9)]
    out: List[int] = []
    for c in candidates:
        if c != ans and c not in out:
            out.append(c)
        if len(out) == 3:
            break
    # Guarantee three distinct wrongs even in pathological cases (e.g. ans == 0).
    pad = ans + 3
    while len(out) < 3:
        if pad != ans and pad not in out:
            out.append(pad)
        pad += 1
    return out


# ── skill templates: each returns (stem, answer, solve_for, relation, steps, (concept, bloom, depth)) ──
# `noun` is unique per item, so the normalised stem is unique. bloom values are drawn from the ERP
# `cognitive_level` axis (remember|understand|apply|analyze|hots) so M2.2's Bloom mapping has a target.
_TemplateFn = Callable[[str, int, int], Dict]


def _t_sum(noun: str, seed: int, i: int) -> Dict:
    a = 12 + _rint(seed, i, "a", 0, 80)
    b = 5 + _rint(seed, i, "b", 0, 40)
    ans = a + b
    return dict(stem=f"A crate holds {a} {noun}s, and {b} more {noun}s are packed in. "
                     f"How many {noun}s are there in total?",
                ans=ans, solve_for="total", relation="total = start + added",
                steps=[f"{a} + {b} = {ans}"], concept=("Addition of whole numbers", "understand", 1))


def _t_diff(noun: str, seed: int, i: int) -> Dict:
    a = 45 + _rint(seed, i, "a", 0, 50)
    b = 6 + _rint(seed, i, "b", 0, 30)
    ans = a - b
    return dict(stem=f"A vendor started the day with {a} {noun}s and sold {b} of them. "
                     f"How many {noun}s are left unsold?",
                ans=ans, solve_for="remaining", relation="remaining = start - sold",
                steps=[f"{a} - {b} = {ans}"], concept=("Subtraction of whole numbers", "understand", 2))


def _t_product(noun: str, seed: int, i: int) -> Dict:
    a = 2 + _rint(seed, i, "a", 0, 10)
    b = 2 + _rint(seed, i, "b", 0, 10)
    ans = a * b
    return dict(stem=f"Each carton contains {b} {noun}s. If a warehouse has {a} such cartons, "
                     f"how many {noun}s are stored in all?",
                ans=ans, solve_for="total", relation="total = cartons x per_carton",
                steps=[f"{a} x {b} = {ans}"], concept=("Multiplication as repeated addition", "apply", 2))


def _t_division(noun: str, seed: int, i: int) -> Dict:
    q = 2 + _rint(seed, i, "q", 0, 10)
    d = 2 + _rint(seed, i, "d", 0, 6)
    total = q * d
    ans = q
    return dict(stem=f"{total} {noun}s are shared equally among {d} groups. "
                     f"How many {noun}s does each group receive?",
                ans=ans, solve_for="per_group", relation="per_group = total / groups",
                steps=[f"{total} / {d} = {ans}"], concept=("Division as equal sharing", "apply", 3))


def _t_linear(noun: str, seed: int, i: int) -> Dict:
    b = 5 + _rint(seed, i, "b", 0, 25)
    now = 30 + _rint(seed, i, "a", 0, 40)
    ans = now - b
    return dict(stem=f"After {b} more {noun}s were added to a box, it held {now} {noun}s in all. "
                     f"How many {noun}s were in the box to begin with?",
                ans=ans, solve_for="start", relation="start = final - added",
                steps=[f"{now} - {b} = {ans}"], concept=("Linear equations in one variable", "analyze", 3))


def _t_compare(noun: str, seed: int, i: int) -> Dict:
    a = 20 + _rint(seed, i, "a", 0, 60)
    b = 5 + _rint(seed, i, "b", 0, 40)
    hi, lo = (a, b) if a >= b else (b, a)
    ans = hi - lo
    return dict(stem=f"Shelf P has {a} {noun}s and shelf Q has {b} {noun}s. "
                     f"How many more {noun}s does the fuller shelf hold?",
                ans=ans, solve_for="difference", relation="difference = larger - smaller",
                steps=[f"max({a}, {b}) - min({a}, {b}) = {ans}"],
                concept=("Comparing and ordering numbers", "analyze", 2))


_TEMPLATES: Tuple[_TemplateFn, ...] = (_t_sum, _t_diff, _t_product, _t_division, _t_linear, _t_compare)
_DIFFICULTIES = ("easy", "moderate", "hard")   # the QIE `intended_difficulty` vocabulary (NOT the ERP one)
_ARCHETYPE_BY_TEMPLATE = ("numeric_sum", "numeric_diff", "numeric_product", "numeric_division",
                          "linear_solve", "numeric_compare")


def _one_item(seed: int, i: int, *, subject: str, class_level: int, board: str, exam_profile: str) -> Dict:
    """Build ONE deterministic certified-shape row for index i (0-based)."""
    if i >= len(_NOUNS):
        raise ValueError(f"fixture index {i} exceeds distinct-noun pool ({len(_NOUNS)}); "
                         f"extend _NOUNS to build larger fixtures")
    t_idx = i % len(_TEMPLATES)
    noun = _NOUNS[i]                       # unique per item ⇒ unique normalised stem
    built = _TEMPLATES[t_idx](noun, seed, i)
    concept_name, bloom, depth = built["concept"]
    archetype = _ARCHETYPE_BY_TEMPLATE[t_idx]
    ans = built["ans"]

    # Deterministic option placement: correct label rotates by i; distractors fill the rest in order.
    labels = ["A", "B", "C", "D"]
    correct_pos = i % 4
    wrong = _distractors(ans, seed, i)
    options: Dict[str, str] = {}
    wi = 0
    for pos, label in enumerate(labels):
        if pos == correct_pos:
            options[label] = str(ans)
        else:
            options[label] = str(wrong[wi])
            wi += 1
    answer_label = labels[correct_pos]

    stem = built["stem"]
    difficulty = _DIFFICULTIES[i % len(_DIFFICULTIES)]
    concept_code = _kc_id(subject, class_level, concept_name)
    run_id = f"pd_fixture_run_{seed}"
    spec_id = f"pd_fixture_spec_{seed}_{i}"

    claimed = {"concepts": [concept_name], "archetype": archetype, "depth": depth,
               "difficulty": difficulty, "composition": "single"}
    structure = {"givens": {"noun": noun}, "relation": built["relation"],
                 "solve_for": built["solve_for"], "steps": built["steps"]}
    solution = {"steps": built["steps"], "final": ans}
    distractor_rationale = {
        lab: ("correct answer" if lab == answer_label else "classic arithmetic slip (off-by-one / magnitude)")
        for lab in labels
    }

    return {
        "candidate_id": corpus._cid(run_id, spec_id),
        "run_id": run_id,
        "spec_id": spec_id,
        "lane": "STRUCTURED_NUMERIC",
        "board": board,
        "exam_profile": exam_profile,
        "class_level": class_level,
        "subject": subject,
        "concept_code": concept_code,
        "concept_title": concept_name,
        "concept_codes_all": json.dumps([concept_code]),
        "composition": "single",
        "archetype": archetype,
        "question_type": "MCQ",              # QIE-native; the exporter maps 'MCQ' → ERP 'mcq'
        "intended_depth": depth,
        "intended_difficulty": difficulty,   # QIE-native; exporter maps 'moderate' → ERP 'medium'
        "visual_required": 0,
        "stem": stem,
        "options": options,
        "answer_label": answer_label,
        "answer_value": str(ans),
        "claimed": claimed,
        "structure": structure,
        "solution": solution,
        "distractor_rationale": distractor_rationale,
        "visual_spec": None,
        "item_hash": item_hash(stem, options, str(answer_label)),
        "stem_norm_hash": norm_hash(stem),
        "evidence_class": corpus.EVIDENCE_SYMPY,
        "certification_class": corpus.CERT_CERTIFIED,
        "earned_depth": depth,
        "computed_archetype": archetype,
        "bloom": bloom,                      # ERP cognitive_level axis (M2.2 target)
        "marks": 1,                          # single-answer numeric MCQ → 1 mark (M2.2 marks-mapping input)
        "generator_model": _FIXTURE_GENERATOR_MODEL,
        "generator_family": _FIXTURE_GENERATOR_FAMILY,
        "provenance": {
            "model": _FIXTURE_GENERATOR_MODEL,
            "model_version": "fixture-1.0.0",
            "prompt_sha256": hashlib.sha256(f"pd-fixture-prompt|{spec_id}".encode()).hexdigest(),
            "actor": _FIXTURE_ACTOR,
            "contract_version": _FIXTURE_CONTRACT,
        },
    }


def make_certified_fixture(n: int, seed: int = 0, *, subject: str = "Mathematics", class_level: int = 8,
                           board: str = "CBSE", exam_profile: str = "SCHOOL") -> List[Dict]:
    """Return N deterministic certified-shape rows. Pure function: no DB, no wall-clock, no randomness
    beyond the seed-derived hash. Same (n, seed, kwargs) → byte-identical list."""
    if n < 0:
        raise ValueError("n must be >= 0")
    return [_one_item(seed, i, subject=subject, class_level=class_level, board=board,
                      exam_profile=exam_profile) for i in range(n)]


def build_fixture_bank(rows: Optional[List[Dict]] = None, *, n: Optional[int] = None, seed: int = 0,
                       conn: Optional[sqlite3.Connection] = None, **kw) -> sqlite3.Connection:
    """Materialise fixture rows into a THROWAWAY production-stamped bank and return the open connection.

    The rows are written through the REAL corpus write path (save_specs → ingest → mark_certified), so
    the resulting bank is byte-for-byte the same shape the factory produces and `certified_bank(conn)`
    returns exactly these rows. `conn` defaults to a fresh in-memory production bank; pass your own only
    if it is already stamped role=production_bank (never the real bank).
    """
    if rows is None:
        if n is None:
            raise ValueError("pass either `rows` or `n`")
        rows = make_certified_fixture(n, seed, **kw)
    if conn is None:
        conn = corpus.open_store(":memory:", role=corpus.ROLE_PRODUCTION)

    # 1) specs (one per row)
    now = corpus._now()
    specs = [{
        "spec_id": r["spec_id"], "run_id": r["run_id"], "lane": r["lane"], "board": r["board"],
        "exam_profile": r["exam_profile"], "class_level": r["class_level"], "subject": r["subject"],
        "concept_code": r["concept_code"], "concept_title": r["concept_title"],
        "concept_codes_all": r["concept_codes_all"], "composition": r["composition"],
        "archetype": r["archetype"], "question_type": r["question_type"],
        "intended_depth": r["intended_depth"], "intended_difficulty": r["intended_difficulty"],
        "visual_required": r["visual_required"], "boundary": None,
        "planner_evidence": json.dumps({"source": "program-d-fixture", "method": "synthetic-deterministic"}),
        "created_at": now,
    } for r in rows]
    corpus.save_specs(conn, specs)

    # 2) ingest raw candidates (grouped by the single fixture run_id). Provenance is real (non-placeholder).
    by_run: Dict[str, List[Dict]] = {}
    for r in rows:
        by_run.setdefault(r["run_id"], []).append({
            "spec_id": r["spec_id"], "stem": r["stem"], "options": r["options"],
            "answer_label": r["answer_label"], "answer_value": r["answer_value"],
            "claimed": r["claimed"], "structure": r["structure"], "solution": r["solution"],
            "distractor_rationale": r["distractor_rationale"], "visual_spec": r["visual_spec"],
        })
    for run_id, raw_items in by_run.items():
        # All rows in a run share the same fixture provenance; the harness is the single accountable actor.
        prov = rows[0]["provenance"]
        corpus.ingest(conn, run_id, raw_items, _FIXTURE_GENERATOR_MODEL, "pd-fixture-batch",
                      generator_family=_FIXTURE_GENERATOR_FAMILY, provenance=prov)

    # 3) promote each candidate through the guarded certification write path.
    for r in rows:
        corpus.mark_certified(conn, r["candidate_id"], corpus.EVIDENCE_SYMPY, corpus.CERT_CERTIFIED,
                              reason="program-d-fixture", earned_depth=r["earned_depth"],
                              computed_archetype=r["computed_archetype"], expected=corpus.CANDIDATE)
    conn.commit()
    return conn
