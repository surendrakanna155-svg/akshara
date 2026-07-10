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


def _open_ro(db_path) -> sqlite3.Connection:
    conn = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
    conn.row_factory = sqlite3.Row
    return conn


class QuestionPaperEngine:
    def __init__(self, conn: Optional[sqlite3.Connection] = None, db_path: Optional[Path] = None):
        self._conn = conn                         # injected (tests / callers own it)
        self.db_path = str(db_path) if db_path else str(config.DB_PATH)

    def _connection(self):
        if self._conn is not None:
            return self._conn, False
        return _open_ro(self.db_path), True

    def generate(self, request: PaperRequest) -> GeneratedPaper:
        conn, owned = self._connection()
        try:
            # 1) strict scope (raises ScopeError/ScopeEmptyError for unsupported/empty scopes)
            scope = scope_mod.resolve_scope(conn, request)

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
            availability = bp_mod.type_availability(conn, scope)
            warnings = list(bp_mod.feasibility(blueprint, availability))

            # 3) pool → 4) select → 5) materialize
            pool = pool_mod.build_pool(conn, scope)
            selection = select_mod.select(blueprint, pool, request, scope)
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
