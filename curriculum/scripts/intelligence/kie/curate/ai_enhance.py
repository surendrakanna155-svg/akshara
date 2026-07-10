"""Knowledge Layer — optional AI-enhanced generation (Phase 5).

Deterministic-first, AI-last. The frozen engine (kie.qpgen) generates a paper whose objective
slots that no certified template can fill become validated SPECS. This runner offers an OPTIONAL
pass that asks a governed provider to author those specs — and it does so through the engine's
OWN seam, changing nothing in the engine:

  * It re-sequences the engine's exact public pipeline (scope → pool → blueprint → select →
    materialize → validate → assemble), differing from engine.generate ONLY by passing the
    provider + persistent cache into materialize (whose signature already accepts them). So AI
    output flows through the SAME validate_paper gate and is rejected if out-of-syllabus,
    ungrounded or malformed — identical safety to a deterministic paper.

  * Hard gate — AI is attempted ONLY when the request opts in AND KIE_AI_AUTHORIZED=1 AND a
    provider is supplied. Otherwise the request is downgraded to fully deterministic; the result
    is byte-identical to engine.generate(). Zero AI calls, ever, unless all three hold.

  * Cache-by-spec-hash — the provider is called at most once per distinct spec; a persistent
    cache (curate.ai_cache) extends that across runs, minimising API usage.

This module NEVER edits the engine and NEVER makes AI mandatory. With the default NullProvider
(or no provider) it is a transparent no-op over the certified deterministic engine.
"""
from __future__ import annotations

from dataclasses import replace
from pathlib import Path
from typing import Optional

from kie import config
from kie.qpgen import (assemble, blueprint as bp_mod, materialize, pool as pool_mod,
                       presets, scope as scope_mod, select as select_mod, validate)
from kie.qpgen.engine import QpGenError, _open_ro
from kie.qpgen.models import GeneratedPaper, PaperRequest
from kie.qpgen.scope import ScopeError


def ai_enabled(request: PaperRequest, provider) -> bool:
    """True iff AI authoring may run: opt-in AND authorized AND a provider is wired."""
    return bool(request.allow_ai_fill) and materialize.ai_authorized() and provider is not None


def generate(request: PaperRequest, *, db_path: Optional[Path] = None, conn=None,
             provider=None, cache=None) -> GeneratedPaper:
    """Generate a paper, optionally AI-filling objective specs (gated/cached/validated).

    Mirrors the frozen engine flow exactly; the only difference is that the (already
    provider-accepting) materialize seam receives the provider + cache when — and ONLY when —
    AI is enabled. With AI disabled the output equals engine.generate()."""
    owned = False
    if conn is None:
        conn = _open_ro(db_path or config.DB_PATH)
        owned = True
    try:
        ai_on = ai_enabled(request, provider)
        # 1) scope + pool
        scope = scope_mod.resolve_scope(conn, request)
        pool = pool_mod.build_pool(conn, scope)
        # 2) blueprint (+validate +feasibility)
        try:
            blueprint = bp_mod.resolve_blueprint(request, scope.exam_profile)
        except KeyError as exc:
            raise QpGenError(f"unknown blueprint preset {request.blueprint_preset!r}; "
                             f"available presets: {sorted(presets.BLUEPRINT_PRESETS)}") from exc
        errs = bp_mod.validate_blueprint(blueprint)
        if errs:
            raise QpGenError(f"invalid blueprint {blueprint.name}: {errs}")
        availability = bp_mod.type_availability(conn, scope)
        warnings = list(bp_mod.feasibility(blueprint, availability))
        # 3) select → 4) materialize (deterministic; AI only if enabled)
        selection = select_mod.select(blueprint, pool, request, scope)
        warnings += selection.shortfalls + selection.notes
        req_mat = replace(request, allow_ai_fill=ai_on)      # never attempt AI unless enabled
        mat = materialize.materialize(selection.slots, conn, req_mat,
                                      provider=provider if ai_on else None,
                                      ai_cache=cache if ai_on else None)
        # 5) SAME validation gate — AI output is validated identically to deterministic output
        report = validate.validate_paper(selection.slots, blueprint, scope)
        if report.rejected_slots:
            warnings.append(f"validation rejected {report.rejected_slots} slot(s): "
                            + "; ".join(report.violations[:6]))
        if not report.boundary_ok:
            warnings.append("BOUNDARY BREACH detected and rejected (no out-of-syllabus item shipped)")
        warnings += [f"conformance: {c}" for c in report.conformance]
        # 6) assemble
        paper = assemble.assemble(request, scope, blueprint, selection.slots, warnings)
        paper.provenance["validation"] = {
            "ok": report.ok, "boundary_ok": report.boundary_ok,
            "rejected": report.rejected_slots, "valid": report.valid_slots}
        paper.provenance["materialization"] = mat
        paper.provenance["availability"] = availability
        paper.provenance["ai"] = {"enabled": ai_on, "detail": mat.get("ai", {})}
        return paper
    finally:
        if owned:
            conn.close()
