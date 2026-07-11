"""QuestionPaperEngine — the end-to-end facade wiring every stage over the local certified KIE.

  scope → blueprint (+feasibility) → candidate pool → deterministic selection →
  materialize (deterministic; objective = gated-AI spec) → validation gate → assemble.

Opens the KIE store READ-ONLY by default: the certified knowledge base is never mutated.
Deterministic and reproducible for a given (request, seed); AI is never invoked unless the
request opts in AND authorization is set.
"""
from __future__ import annotations

import sqlite3
from dataclasses import replace
from pathlib import Path
from typing import List, Optional

from kie import config
from kie.qpgen import (assemble, blueprint as bp_mod, materialize, pool as pool_mod,
                       presets, scope as scope_mod, select as select_mod, validate)
from kie.qpgen.models import GeneratedPaper, PaperRequest


class QpGenError(RuntimeError):
    pass


# Class-X *board* blueprints. Each must be served ONLY under a certified Class-X board profile
# (grade-10, board-source-isolated); requesting it under any other profile (e.g. FOUNDATION,
# grade 6-12) would mix Class-X board content with Class 11-12 foundation material — board/grade
# corpus misuse. A board blueprint whose matching board profile has no ingested corpus (AP) fails
# closed. (2026-07-11: CBSE_X + TS_X corpus ingested via the Intake Center; AP still absent.)
_CLASS_X_BOARD_BLUEPRINT_PROFILE = {
    "cbse_x_science": "CBSE_X",
    "ts_scert_x_science": "TS_X",
    "ap_scert_x_science": "AP_X",     # no AP_X profile / corpus → always fails closed
}


def _open_ro(db_path) -> sqlite3.Connection:
    conn = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
    conn.row_factory = sqlite3.Row
    return conn


def _fillable_map(conn, pool):
    """candidate.key → deterministic fill-strength rank for fill-aware selection (Phase 2):
      0 solver-verified template · 1 grounded verified definition (descriptive key OR
      definition-match MCQ) · absent ⇒ unfillable (would ship as an authoring spec).
    Mirrors exactly what materialize.materialize() can produce AS-IS with AI OFF, so selection's
    preference never promises fill the materializer cannot deliver."""
    from kie.qpgen import materialize, templates
    from kie.qpgen.models import QuestionType
    descriptive = (QuestionType.SHORT_ANSWER, QuestionType.LONG_ANSWER)
    defs = materialize._definitions(conn, [c.concept_code for c in pool])
    out = {}
    for c in pool:
        if templates.find_template(c.subject, c.concept_title, c.question_type) is not None:
            out[c.key] = 0
        elif materialize.usable_definition(defs.get(c.concept_code, "")) and (
                c.question_type in descriptive or c.question_type == QuestionType.MCQ):
            out[c.key] = 1
    return out


class QuestionPaperEngine:
    def __init__(self, conn: Optional[sqlite3.Connection] = None, db_path: Optional[Path] = None):
        self._conn = conn                         # injected (tests / callers own it)
        self.db_path = str(db_path) if db_path else str(config.DB_PATH)
        self._cache: dict = {}                    # (scope key) -> (SyllabusScope, pool) memo

    def _scope_and_pool(self, conn, request: PaperRequest):
        """Resolve + cache scope and pool by the scope-determining fields, so a batch /
        generate_series (same scope, varying seed/exclude) does not recompute O(corpus) work."""
        key = (request.exam, request.board, request.class_label,
               tuple(request.subjects), tuple(request.chapters))
        if key not in self._cache:
            sc = scope_mod.resolve_scope(conn, request)     # may raise (not cached on failure)
            self._cache[key] = (sc, pool_mod.build_pool(conn, sc))
        return self._cache[key]

    def _connection(self):
        if self._conn is not None:
            return self._conn, False
        return _open_ro(self.db_path), True

    def generate(self, request: PaperRequest) -> GeneratedPaper:
        conn, owned = self._connection()
        try:
            # 1) strict scope + pool (cached by scope key; raises for unsupported/empty scopes)
            scope, pool = self._scope_and_pool(conn, request)

            # 2) blueprint + structural validation + feasibility
            try:
                blueprint = bp_mod.resolve_blueprint(request, scope.exam_profile)
            except KeyError as exc:
                raise QpGenError(
                    f"unknown blueprint preset {request.blueprint_preset!r}; "
                    f"available presets: {sorted(presets.BLUEPRINT_PRESETS)}") from exc
            errs = bp_mod.validate_blueprint(blueprint)
            if errs:
                raise QpGenError(f"invalid blueprint {blueprint.name}: {errs}")

            # HONEST BOARD SUPPORT (P1-4 → Content Density CP3). A Class-X board blueprint is
            # allowed ONLY under its certified Class-X board profile (grade-10, board-source-
            # isolated). Under any other profile — or when the board's corpus was never ingested
            # (AP) — it FAILS CLOSED, so Class-X board content is never mixed with Class 11-12
            # foundation material and no board paper is fabricated from out-of-grade knowledge.
            required = _CLASS_X_BOARD_BLUEPRINT_PROFILE.get(blueprint.name)
            if required and (required not in presets.CERTIFIED_BOARD_PROFILES
                             or scope.exam_profile != required):
                raise scope_mod.ScopeError(
                    f"blueprint {blueprint.name!r} is a Class-X board paper and must be requested "
                    f"under its certified board profile {required!r} (grade-10, board-isolated). "
                    f"Resolved profile was {scope.exam_profile!r}"
                    + ("" if required in presets.CERTIFIED_BOARD_PROFILES else
                       f"; no verified {required} corpus has been ingested (fails closed).")
                    + " Refusing to generate a Class-X board paper from non-board / out-of-grade content.")

            availability = bp_mod.type_availability(conn, scope)
            warnings = list(bp_mod.feasibility(blueprint, availability))

            # 3) select (pool cached above) → 4) materialize
            #    FILL-AWARENESS (Content Density Phase 2): tell selection which candidates can be
            #    materialized deterministically AS-IS (AI OFF), ranked by content strength, so a
            #    paper prefers fillable concepts over authoring specs — without weakening scope,
            #    isolation, diversity, bloom/difficulty, or seed determinism.
            fillable = _fillable_map(conn, pool)
            selection = select_mod.select(blueprint, pool, request, scope, fillable=fillable)
            warnings += selection.shortfalls + selection.notes
            mat = materialize.materialize(selection.slots, conn, request)

            # 6) validation gate (rejected slots are excluded on assembly)
            report = validate.validate_paper(selection.slots, blueprint, scope)
            if report.rejected_slots:
                warnings.append(f"validation rejected {report.rejected_slots} slot(s): "
                                + "; ".join(report.violations[:6]))
            if not report.boundary_ok:
                warnings.append("BOUNDARY BREACH detected and rejected (no out-of-syllabus item shipped)")
            warnings += [f"conformance: {c}" for c in report.conformance]

            # 7) assemble
            paper = assemble.assemble(request, scope, blueprint, selection.slots, warnings)
            paper.provenance["validation"] = {
                "ok": report.ok, "boundary_ok": report.boundary_ok,
                "rejected": report.rejected_slots, "valid": report.valid_slots}
            paper.provenance["materialization"] = mat
            paper.provenance["availability"] = availability
            return paper
        finally:
            if owned:
                conn.close()

    def generate_series(self, request: PaperRequest, count: int) -> List[GeneratedPaper]:
        """Generate `count` papers guaranteed to share NO concepts (Set A/B/…, per-student sets).

        Each paper excludes every concept used by the earlier papers in the series, so
        uniqueness is absolute — while each individual paper still respects scope, blueprint,
        grade isolation, and subject balance. Deterministic + reproducible for a given request;
        if the in-scope pool is exhausted, later papers shrink (reported), never duplicate.
        """
        papers: List[GeneratedPaper] = []
        used: set = set(request.exclude_concepts or ())
        for i in range(count):
            req = replace(request, seed=request.seed + i, exclude_concepts=tuple(sorted(used)))
            paper = self.generate(req)
            papers.append(paper)
            used |= {s.concept_code for s in paper.slots}
        return papers

    # convenience renderers
    def render_markdown(self, paper: GeneratedPaper) -> str:
        return assemble.render_markdown(paper)

    def render_json(self, paper: GeneratedPaper) -> dict:
        return assemble.render_json(paper)
