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


# Class-X *board* blueprints with no certified board/grade corpus (see the P1-4 guard in
# generate()). The corpus is JEE/NEET Class 11-12 only, so these must fail closed rather than
# be served from out-of-grade content. Class-XII board blueprints are in-band and NOT listed.
_CLASS_X_BOARD_NO_CORPUS = frozenset({"cbse_x_science", "ts_scert_x_science", "ap_scert_x_science"})


def _open_ro(db_path) -> sqlite3.Connection:
    conn = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
    conn.row_factory = sqlite3.Row
    return conn


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

            # P1-4 HONEST BOARD SUPPORT (2026-07-11 QP Content Readiness remediation).
            # The certified corpus is JEE/NEET Class 11-12 (concept_board_mappings is 100%
            # FOUNDATION; no CBSE/AP/TS board mapping and no Class-X grade evidence exists).
            # A Class-X *board* paper drawn from Class 11-12 knowledge is board/grade corpus
            # misuse — so we FAIL CLOSED with an honest message rather than fabricate a
            # Class-X board paper. (A Class-XII board scope, e.g. cbse_xii_physics, IS in the
            # 11-12 band and remains supported.) Documented exception; reversible the moment a
            # real board/grade corpus is ingested (remove the name from the set below).
            if blueprint.name in _CLASS_X_BOARD_NO_CORPUS:
                raise scope_mod.ScopeError(
                    f"blueprint {blueprint.name!r} is a Class-X board paper, but the certified "
                    f"corpus holds only JEE/NEET Class 11-12 knowledge (no CBSE/AP/Telangana "
                    f"Class-X board/grade corpus). Refusing to generate a Class-X board paper "
                    f"from Class 11-12 content. Ingest a certified Class-X board corpus to enable it.")

            availability = bp_mod.type_availability(conn, scope)
            warnings = list(bp_mod.feasibility(blueprint, availability))

            # 3) select (pool cached above) → 4) materialize
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
