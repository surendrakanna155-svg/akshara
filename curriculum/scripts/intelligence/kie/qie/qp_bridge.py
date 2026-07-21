"""QP integration bridge — wire the proven unified compositional engine INTO the existing QP pipeline.

Owner-directed (2026-07-14): integrate qie THROUGH the existing qpgen architecture + governance, not a parallel
paper generator. This module REUSES, unchanged:
  * `scope.resolve_scope`        — the certified in-scope concept universe (the hard syllabus boundary),
  * `blueprint.resolve_blueprint`— the authentic exam paper structure/requirements,
  * `validate.validate_paper`    — the hard governance gate (boundary, subject, dedup, structure),
  * `assemble.assemble`/`render` — paper assembly + the render-honesty (student paper vs authoring worklist),
  * `sanitize`                    — stem/title quality (via validate + assemble).
qie supplies FILLED, independently-verified items (4 valid options + real key) that satisfy `is_student_printable`
and fill the reserved Phase-A5 QuestionSlot seam (item_model_id / lane / gate_verdicts / solution_steps). Each
item is HONESTLY BOUND to a real in-scope certified concept it genuinely belongs to, so the boundary check is
meaningful. qpgen is NOT modified (frozen); `kie.db` is opened read-only.

Discipline: reject invalid / ambiguous / duplicate / weak / difficulty-mismatched items — never fill a quota
with an unsuitable item. Unfilled blueprint positions are reported as honest shortfalls (the render already
states deterministic coverage). Verification hierarchy is preserved: only engine-verified (Tier-1/2) items enter;
LLM is examiner-only, never in this path.
"""
from __future__ import annotations

import hashlib
import re
import sqlite3
from typing import Dict, List, Optional, Tuple

from kie import config
from kie.qie import retired_families
from kie.qpgen import assemble, blueprint as bp_mod, scope as scope_mod, validate
from kie.qpgen.models import (Bloom, Difficulty, GeneratedPaper, PaperRequest, QuestionSlot,
                              QuestionType, RenderMode, SlotStatus)


# #perf-scale-9 (R3-4): the engine pool is a PURE deterministic function of (registry version, subjects,
# seed, per). Memoize it so a paper request never rebuilds the (expensive) engine run per call within a
# process. Keyed on the registry FINGERPRINT so a code change that adds/removes/renames a template can never
# serve a stale cached pool. NOTE (deferred #perf-scale-9): the QDI mining lane's leading-wildcard LIKEs over
# ~57k kie.db chunks want an FTS5 index over chunks; kie.db is frozen v1.5 (chmod a-w), so that index waits
# for the next sanctioned kie.db rebuild under the freeze hatch — see the R3-4 report.
_ENGINE_POOL_CACHE: Dict[tuple, List[dict]] = {}


def _register_generation_surface():
    """Idempotently import the domain modules whose import side-effect registers operators/templates into the
    shared composition registry, and return the compositions module. Safe to call repeatedly."""
    from kie.qie import compositions as K
    from kie.qie import physics, chemistry, genetics, biology  # noqa: F401 — register domain operators/templates
    from kie.qie.convert import kvs_compose  # noqa: F401 — registers governed-KVS templates (verified facts)
    from kie.qie.convert.notation import relation_compose  # noqa: F401 — CERTIFIED recovered relations (numeric)
    # CERTIFIED depth-4/5 chains — the HARD lane. A single relation is one operator application (depth 1) and
    # can only ever be MEDIUM, so every blueprint's hard cells stay empty without these.
    from kie.qie.convert.notation import chain_compose  # noqa: F401
    return K


def _registry_version() -> str:
    """Fingerprint of the registered generation surface (composition TEMPLATE_REGISTRY keys). Changes iff a
    template is added/removed/renamed, so a cached pool is reused ONLY while the generative registry is
    identical — never across a code change that alters what the engine can emit."""
    K = _register_generation_surface()
    return hashlib.sha256("|".join(sorted(K.TEMPLATE_REGISTRY)).encode()).hexdigest()[:16]


def clear_engine_pool_cache() -> None:
    """Drop the memoized engine pools (#perf-scale-9). For tests / after a hot registry change in-process."""
    _ENGINE_POOL_CACHE.clear()


def _engine_pool(subjects, seed: int, per: int = 14) -> List[dict]:
    """Memoized (#perf-scale-9) wrapper over `_build_engine_pool`, keyed by (registry version, subjects, seed,
    per). Returns a fresh list each call (callers filter it in place) that shares the cached items."""
    key = (_registry_version(), tuple(sorted(set(subjects))), int(seed), int(per))
    cached = _ENGINE_POOL_CACHE.get(key)
    if cached is None:
        cached = _build_engine_pool(subjects, seed, per)
        _ENGINE_POOL_CACHE[key] = cached
    return list(cached)


def _build_engine_pool(subjects, seed: int, per: int = 14) -> List[dict]:
    """Run the unified qie engine and collect independently-verified items for the requested subjects.
    Sources: compositional templates (all domains) + single-concept Math generators. Only PASS items."""
    K = _register_generation_surface()
    subs = set(subjects)
    out: List[dict] = []

    for name, tmpl in list(K.TEMPLATE_REGISTRY.items()):
        if tmpl.subject not in subs:
            continue
        for it in K.run({name: tmpl}, per_template=per, seed=str(seed))["verified_bank"]:
            out.append(_norm(it, it.get("reasoning_depth", 2)))

    if "Mathematics" in subs:                      # single-concept Math breadth (more distinct concepts)
        from kie.qie import generate_calculus as GC, generate_jee_math as JM
        # single-concept computation (definite integral, determinant, nCr, …) = standard MEDIUM exam
        # difficulty (depth 3), not "easy" — reasoning-depth ≠ exam-difficulty.
        for it in GC.run(per_family=per, seed=str(seed))["verified_bank"]:
            out.append(_norm(it, 3))
        for it in JM.run(per_family=per, seed=str(seed))["verified_bank"]:
            out.append(_norm(it, 3))
    if subs & {"Physics", "Chemistry"}:            # qie's existing verified single-relation items (V=IR, …)
        from kie.qie import generate_numeric as GN
        for it in GN.run(GN.TEMPLATES, per_template=per, seed=str(seed))["verified_bank"]:
            if it["subject"] in subs:
                out.append(_norm(it, 3))
    return out


def _norm(it: dict, depth: int) -> dict:
    return {"gen_id": it["gen_id"], "item_model_id": it.get("item_model_id"), "subject": it["subject"],
            "frame_id": it["frame_id"], "concept": it.get("concept", ""), "stem": it["stem"],
            "options": list(it["options"].values()) if isinstance(it.get("options"), dict) else it.get("options"),
            "answer": it["answer_text"], "depth": depth, "provenance": it.get("provenance", {})}


def _targets(item: dict) -> List[str]:
    """Ordered, SPECIFIC target concept phrases for honest binding. Ambiguous words that would
    mis-bind (e.g. 'force'→'Nuclear Force', 'energy'→'capacitor energy') are deliberately excluded;
    a frame with no precise in-scope target returns [] and is skipped rather than mis-placed."""
    f = item["frame_id"]
    if f.startswith("kvs_"):
        # governed-KVS items carry their own doc-grounded source chapter ("Subject :: Chapter"); bind to a
        # certified in-scope concept in the same subject by chapter name / significant chapter tokens.
        chapter = (item.get("concept", "").split("::")[-1] or "").strip().lower()
        toks = [chapter] + [w for w in re.split(r"[^a-z0-9]+", chapter) if len(w) > 3]
        return [t for t in toks if t]
    if "integral" in f or f in ("area_between_roots", "area_between_curve_and_line", "ftc_integral_of_derivative"):
        return ["integrals"]
    if "deriv" in f or f in ("min_value_quadratic", "tangent_slope_at_root"):
        return ["derivatives"]
    if f == "limit":
        return ["limits"]
    if f in ("determinant", "matrix_inverse"):
        return ["matrices"]
    if f == "binomial_coeff":
        return ["binomial"]
    if f == "counting":
        return ["permutations"]
    if f in ("phys_force_to_kinetic_energy", "phys_force_to_momentum"):
        return ["newton"]                                    # Newton's laws (F = ma) — the governing concept
    if f in ("phys_power_from_v_r", "phys_series_circuit_power"):
        return ["power", "ohm"]
    # qie single-relation items (generate_numeric) → bind by their certified law/relation concept
    c = item.get("concept", "")
    if c in ("REL_OHMS_LAW",):
        return ["ohm"]
    if c in ("REL_ELECTRIC_POWER",):
        return ["power"]
    if c in ("REL_KINETIC_ENERGY", "REL_KE_MOMENTUM"):
        return ["kinetic energy"]
    if c in ("REL_POTENTIAL_ENERGY",):
        return ["potential energy"]
    if c in ("REL_WEIGHT",):
        return ["weight"]
    if c in ("REL_SERIES_RESISTANCE", "REL_PARALLEL_RESISTANCE"):
        return ["resistance", "resistors"]
    if c in ("REL_KINEMATICS_V", "REL_KINEMATICS_A"):
        return ["equations of motion", "motion", "velocity", "acceleration"]
    if c in ("REL_FREQUENCY",):
        return ["frequency"]
    if c in ("REL_EFFICIENCY",):
        return ["efficiency"]
    if f == "chem_mass_to_molecules":
        return ["mole", "avogadro"]
    if f in ("chem_stoichiometry_mass", "chem_gas_stoichiometry_volume"):
        return ["stoichiometry", "mole"]
    if f in ("chem_dilution_molarity", "chem_molarity_to_mass"):
        return ["concentration", "molarity", "solution"]
    if f in ("gen_monohybrid_recessive", "gen_dihybrid_both_recessive", "gen_conditional_homozygous"):
        return ["mendel"]
    if f == "bio_structure_to_system":                       # bind to the system named in the (correct) answer
        return [w for w in ("excretory", "respiratory", "nervous", "digestive", "circulatory", "skeletal")
                if w in (item["answer"] or "").lower()]
    if f == "bio_gland_hormone_effect":
        return ["endocrine", "hormone", "gland"]
    return []                                                # projectile-PE, vieta, complex, series, process → skip


_TITLE_DROP_LEAD = {"adv", "com", "general", "the"}
_TITLE_DROP_MID = {"their", "its", "the", "an", "a"}


def _clean_title(chapter: str) -> str:
    """Turn a filename-derived chapter into a sanitizer-clean concept title: drop lead noise ('Adv'/'Com'),
    dedupe repeated OCR words, drop trip-word pronouns, cap at 5 words (the qpgen MAX_WORDS)."""
    words = chapter.split()
    while words and words[0].lower() in _TITLE_DROP_LEAD:
        words = words[1:]
    seen, dedup = set(), []
    for w in words:                                    # dedupe repeated words ("Current Current Density")
        if w.lower() not in seen:
            dedup.append(w)
            seen.add(w.lower())
    trimmed = [w for w in dedup if w.lower() not in _TITLE_DROP_MID] or dedup
    return " ".join(trimmed[:5]).strip()


def _governed_concepts(subjects, unified_path=None) -> Tuple[Dict[str, object], Dict[str, Tuple[str, str]], List[str]]:
    """RI-6 re-point (BS-1/BS-6, 2026-07-21): the governed in-scope concepts a paper may use are read from the
    UNIFIED MANIFEST (`unified_inventory.db`) — the single reconciled, deterministically-verified registry —
    NEVER by opening qie.db directly. qie.db is an evidence source, not a product surface (RI-6); routing the
    boundary through the manifest means a governed asset can enter a paper ONLY if it is registered AND holds
    an admitted status: relations must be `promotable` (re-certified by the notation-recovery battery — a
    relation that no longer re-derives is quarantined and thereby excluded); facts are `held_qualitative`
    (model examiner) and define curriculum MEMBERSHIP only, honestly non-deterministic until R4-3.

    Preserves owner decisions A (verified governed chapters are first-class in-scope) and B (topic-granular
    binding) — the manifest stores the SAME `compose_concept` key the generators emit, so binding is identical
    to the pre-manifest read; only the SOURCE changed (manifest, not qie.db). Each admitted concept still
    passes the SAME subject gate + concept sanitizer as every other in-scope concept; an unclean title is an
    honest shortfall, never a boundary breach. Returns (in_scope_concepts, chapter->(code,title), warnings)."""
    from kie.qie.inventory import manifest as MF
    from kie.qpgen import sanitize
    out: Dict[str, object] = {}
    by_chapter: Dict[str, Tuple[str, str]] = {}
    warnings: List[str] = []
    subj_set = set(subjects)

    # (subject, concept_key) governed pairs: relations + facts from the MANIFEST (the one product surface).
    rows: List[Tuple[str, str]] = []
    fr = MF.governed_scope_freshness(unified_path=unified_path)
    if fr.get("fresh") is None and "absent" in (fr.get("reason") or ""):
        warnings.append(f"governed scope: {fr['reason']} — no governed concepts contributed (honest shortfall)")
    elif fr.get("fresh") is False:
        # DRIFT: qie.db changed since the manifest was built. The manifest rows are still verified/registered
        # assets, so we serve them (refusing would strand a whole paper on any drift) but surface it loudly so
        # the registry is rebuilt — a stale boundary is never served silently (the audit's C3 drift class).
        warnings.append("governed scope: unified_inventory.db is STALE vs qie.db "
                        f"({fr['reason']}) — governed concepts served from the last verified build; rebuild it")
    try:
        for g in MF.governed_scope_rows(subj_set, unified_path=unified_path):
            rows.append((g["subject"], g["compose_concept"]))
    except sqlite3.OperationalError:
        if not warnings:
            warnings.append("governed scope: unified_inventory.db unavailable — no governed concepts contributed")

    # CERTIFIED depth-4/5 chains: a code-defined composition over already-certified relations (the HARD lane
    # that alone fills depth>=4 cells). Not a qie.db table read, so outside the RI-6 second-surface concern;
    # kept sourced from the certified chain registry.
    try:
        from kie.qie.convert.notation import chain_compose as chain_mod
        rows += [(ch.subject, f"{ch.subject} :: {ch.name}") for ch in chain_mod.CHAINS]
    except Exception:
        pass

    for subj, cc in rows:
        if subj not in subj_set or not cc:
            continue
        title = _clean_title(cc.split("::")[-1].strip())
        if not sanitize.is_clean_concept(title):            # same gate as every other in-scope concept
            continue
        code = "GOV_" + hashlib.sha256(cc.encode()).hexdigest()[:14]
        out[code] = scope_mod.ConceptRef(concept_code=code, title=title, subject=subj, exam=None,
                                         evidence=2, is_named_law=False, has_definition=True)
        by_chapter[cc] = (code, title)
    return out, by_chapter, warnings


def _bind(item: dict, scope) -> Optional[Tuple[str, str]]:
    """Bind to the first in-scope certified concept matching a target (exact title preferred, then the
    shortest title CONTAINING the target). Returns None if no precise in-scope concept exists (→ skipped)."""
    if item["frame_id"].startswith(("kvs_", "relnum_", "chain_")):
        # governed item (verified KVS fact, a CERTIFIED source-recovered relation, or a CERTIFIED depth-4/5
        # chain over them) -> its own verified concept, now first-class in-scope. Exact and subject-safe.
        gc = getattr(scope, "gov_by_chapter", {}).get(item.get("concept"))
        if gc:
            return gc
    for target in _targets(item):
        exact = contains = None
        for code, cr in scope.concepts.items():
            if cr.subject != item["subject"]:
                continue
            tl = cr.title.lower()
            if tl == target:
                exact = (code, cr.title)
                break
            if target in tl and (contains is None or len(cr.title) < len(contains[1])):
                contains = (code, cr.title)
        if exact:
            return exact
        if contains:
            return contains
    return None


def _difficulty(depth: int) -> str:
    # exam-difficulty, not raw reasoning-depth: every qie item requires genuine computation/reasoning
    # (none is trivially "easy"); multi-concept depth-4/5 chains are HARD, the rest MEDIUM.
    return Difficulty.HARD if depth >= 4 else Difficulty.MEDIUM


def _bloom(depth: int) -> str:
    return Bloom.UNDERSTAND if depth <= 2 else (Bloom.APPLY if depth == 3 else Bloom.ANALYZE)


def _slot(cell, item, code, title, number, exam_profile) -> QuestionSlot:
    is_mcq = cell.question_type in (QuestionType.MCQ, QuestionType.ASSERTION_REASON)
    return QuestionSlot(
        number=number, section=cell.section, concept_code=code, concept_title=title, subject=item["subject"],
        question_type=cell.question_type, marks=cell.marks_each, bloom=_bloom(item["depth"]),
        difficulty=cell.difficulty or _difficulty(item["depth"]), render_mode=RenderMode.DETERMINISTIC,
        status=SlotStatus.FILLED, stem=item["stem"], options=item["options"] if is_mcq else None,
        answer=item["answer"], solution=None,
        # source='template' => machine-verified item, exempt from the free-text grounding check (same rule as
        # solver-verified templates); every other governance check still applies.
        provenance={"source": "template", "exam": exam_profile, "qie_frame": item["frame_id"],
                    "reasoning_depth": item["depth"], "verification": item["provenance"].get("verification", "deterministic")},
        item_model_id=item["item_model_id"], lane=item["provenance"].get("template") or item["frame_id"],
        gate_verdicts=[{"verifier": "qie", "verdict": "agree"}],
        solution_steps=item["provenance"].get("concepts"))


def generate_paper(request: PaperRequest, per: int = 14) -> Tuple[GeneratedPaper, "validate.ValidationReport"]:
    conn = sqlite3.connect(f"file:{config.DB_PATH}?mode=ro", uri=True)
    conn.row_factory = sqlite3.Row
    try:
        scope = scope_mod.resolve_scope(conn, request)              # REUSE — certified boundary
        # Owner decision A: extend the in-scope boundary with governed-fact/relation concepts — RI-6-routed
        # through the unified manifest (the single verified registry), never a direct qie.db read.
        gov_concepts, gov_by_chapter, gov_warnings = _governed_concepts(scope.subjects)
        scope.concepts.update(gov_concepts)
        scope.gov_by_chapter = gov_by_chapter
        blueprint = bp_mod.resolve_blueprint(request, scope.exam_profile)   # REUSE — authentic structure
        errs = bp_mod.validate_blueprint(blueprint)
        if errs:
            raise ValueError(f"invalid blueprint {blueprint.name}: {errs}")

        pool = _engine_pool(scope.subjects, request.seed, per)
        # R3-8 reachability retirement: drop any item belonging to a known-defective retired family
        # (e.g. the qpgen assertion-reason family whose key is hard-coded to option (a)) BEFORE it can
        # enter the reachable pool. The qie lane emits none today, so this is a no-op on real data —
        # a fail-closed guard so no future qie composition/generator can smuggle a retired form in.
        pool = [it for it in pool if not retired_families.is_retired_item(it)]
        # bind to in-scope concepts; drop unbindable (honest — can't place it in-syllabus)
        bound = []
        for it in pool:
            b = _bind(it, scope)
            if b:
                bound.append((it, b[0], b[1]))
        # deterministic order
        bound.sort(key=lambda x: hashlib.sha256((str(request.seed) + x[0]["gen_id"]).encode()).hexdigest())

        slots: List[QuestionSlot] = []
        warnings: List[str] = list(gov_warnings)     # RI-6: surface any governed-registry staleness/absence
        used_gen: set = set()
        used_ct: set = set()          # (concept_code, question_type) — mirror qpgen's dedup so we don't waste picks
        n = 0
        for cell in blueprint.cells:
            if retired_families.is_retired_question_type(cell.question_type):
                # R3-8: the frozen qpgen builder for this type hard-codes the answer (red team
                # 2026-07-11, #red-team-10). The type is RETIRED at the reachability layer — never
                # assembled by the bridge; the slot is an honest shortfall left to authoring.
                warnings.append(f"section {cell.section}: {cell.question_type} is RETIRED (R3-8: "
                                f"known-defective qpgen path — hard-coded answer) — not assembled")
                continue
            if cell.question_type not in (QuestionType.MCQ, QuestionType.NUMERICAL):
                warnings.append(f"section {cell.section}: {cell.question_type} not served by qie (left to authoring)")
                continue
            picked = 0
            for it, code, title in bound:
                if picked >= cell.count:
                    break
                if it["subject"] != cell.subject and cell.subject is not None:
                    continue
                if it["gen_id"] in used_gen or (code, cell.question_type) in used_ct:
                    continue
                if cell.difficulty and _difficulty(it["depth"]) != cell.difficulty:
                    continue                                        # honest depth/difficulty match — no filling
                if cell.question_type in (QuestionType.MCQ,) and (not it["options"] or len(it["options"]) != 4):
                    continue
                if not it["answer"]:
                    continue
                n += 1
                slots.append(_slot(cell, it, code, title, n, scope.exam_profile))
                used_gen.add(it["gen_id"]); used_ct.add((code, cell.question_type)); picked += 1
            if picked < cell.count:
                warnings.append(f"section {cell.section}: qie supplied {picked} of {cell.count} "
                                f"(shortfall {cell.count - picked} — not filled with unsuitable items)")

        report = validate.validate_paper(slots, blueprint, scope)   # REUSE — hard gate
        if report.rejected_slots:
            warnings.append(f"validation rejected {report.rejected_slots} slot(s): " + "; ".join(report.violations[:6]))
        if not report.boundary_ok:
            warnings.append("BOUNDARY BREACH detected and rejected")
        paper = assemble.assemble(request, scope, blueprint, slots, warnings)   # REUSE — assembly + render honesty
        paper.provenance["source_engine"] = "kie.qie unified compositional engine (bridge)"
        paper.provenance["validation"] = {"ok": report.ok, "boundary_ok": report.boundary_ok,
                                          "rejected": report.rejected_slots, "valid": report.valid_slots}
        return paper, report
    finally:
        conn.close()


def render_markdown(paper: GeneratedPaper) -> str:
    return assemble.render_markdown(paper)


def render_json(paper: GeneratedPaper) -> dict:
    return assemble.render_json(paper)
