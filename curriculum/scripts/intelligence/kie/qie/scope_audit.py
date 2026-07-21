"""R4-4 — deferred audit passes (the board's own scope debt) [BS-3][BS-5][BS-6].

Three closures the audit deferred, made concrete + testable here. None of this certifies or promotes anything;
it is governance/interface tooling that turns three "we never looked" gaps into examined, honest artifacts.

 (a) `build_process_audit()`      — BS-5: the KIE build PROCESS (phase 1-7 OCR / parse / chunk correctness) was
     never audited — only its OUTPUTS were, and `ki_run` is empty (0 rows) so there is no per-run build trail.
     This reads the FROZEN index read-only, reconstructs the build provenance that DOES exist (ki_progress
     phases, ki_source, preserved ki_rejected, the ki_meta freeze/fingerprint package), and names the residual
     gap honestly + the forward requirement (future rebuilds MUST populate ki_run per phase). Freeze-safe: never
     writes the frozen index.

 (b) `downstream_surface_contracts()` — BS-3: weakness-intelligence / adaptive-practice / AI-tutor / analytics
     have NO lane code (grep-confirmed). Instead of pretending they exist, declare the READ CONTRACT each will
     need — exactly what it may read and from which SANCTIONED reader (the product bank, the reconciled
     manifest, or the frozen index read-only) — never a raw store. `assert_surface_read` enforces it fail-closed
     so a future surface cannot smuggle a read from an un-reconciled store (the qie.db mistake, RI-6).

 (c) `reconciled_inventory_guard()` — BS-6: a "whole-system" completeness claim must be computed FROM the
     reconciled inventory (R4-1 manifest) across ALL source lanes, never from a single lane (the blind spot that
     let the whole board miss qie.db). Returns the lane coverage a whole-system claim must cite.
"""
from __future__ import annotations

import sqlite3
from typing import Dict, List, Optional

from kie import config

INDEX_DB_PATH = config.KIE_HOME / "knowledge_index.db"


# ── (a) BS-5 — build-process audit ─────────────────────────────────────────────────────────────────────
def build_process_audit(index_path=INDEX_DB_PATH) -> Dict[str, object]:
    """Read-only audit of the frozen index's BUILD provenance. Honest about what was and was NOT audited."""
    try:
        conn = sqlite3.connect(f"file:{index_path}?mode=ro", uri=True)
    except sqlite3.OperationalError:
        return {"available": False, "reason": "frozen index absent"}
    conn.row_factory = sqlite3.Row
    try:
        def count(t):
            try:
                return conn.execute(f"SELECT COUNT(*) FROM {t}").fetchone()[0]
            except sqlite3.OperationalError:
                return None
        meta = {r["key"]: r["value"] for r in conn.execute("SELECT key, value FROM ki_meta")}
        provenance = {t: count(t) for t in
                      ("ki_run", "ki_progress", "ki_source", "ki_chapter", "ki_concept", "ki_rejected", "ki_gap")}
        # OUTPUT audit exists (each certified concept carries audit_verdict/audit_model); the PROCESS audit does not.
        output_audited = count("ki_concept") and next(
            (True for r in conn.execute("SELECT audit_verdict FROM ki_concept WHERE audit_verdict IS NOT NULL "
                                        "LIMIT 1")), False)
        has_run_trail = bool(provenance.get("ki_run"))
        freeze_keys = [k for k in meta if "fingerprint" in k or "audit" in k or "freeze" in k.lower()
                       or "frozen" in k]
        return {
            "available": True,
            "frozen_version": meta.get("frozen_version"),
            "provenance_counts": provenance,
            "output_audit_present": bool(output_audited),   # per-concept engineer+audit verdicts exist
            "process_audit_present": has_run_trail,          # per-run OCR/parse/chunk build trail
            "freeze_provenance_keys": sorted(freeze_keys),
            "gap": (None if has_run_trail else
                    "ki_run is EMPTY (0 rows): the phase 1-7 build process (OCR/parse/chunk correctness) has no "
                    "per-run audit trail. Only build OUTPUTS were audited (per-concept audit_verdict) and the "
                    "freeze was certified (ki_meta package). Preserved: ki_progress phases, ki_rejected "
                    "rejections, ki_source docs — but the extraction PROCESS itself was never independently "
                    "re-audited (BS-5)."),
            "forward_requirement": ("any sanctioned rebuild under the freeze hatch MUST populate ki_run with a "
                                    "per-phase record (phase, inputs sha, outputs sha, model+actor, timings) so "
                                    "the extraction process is auditable, not just its outputs."),
            "freeze_safe": True,                             # opened mode=ro; never writes the frozen index
        }
    finally:
        conn.close()


# ── (b) BS-3 — downstream-surface read contracts ───────────────────────────────────────────────────────
# The ONLY readers a product/downstream surface may use. A raw store (kie.db / qie.db / factory_corpus.db) is
# NEVER a sanctioned reader — that is exactly the un-reconciled second-surface mistake RI-6 closed.
SANCTIONED_READERS = {
    "product_bank": "kie.qie.factory.corpus.product_inventory  (the ONE certified question bank, RI-6)",
    "manifest": "kie.qie.inventory.manifest  (open_ro / governed_scope_rows / promotion_counts — reconciled)",
    "frozen_index_ro": "kie.qie.inventory.crosswalk.open_index_ro  (knowledge_index.db, mode=ro only)",
}

# What each currently-absent downstream surface WILL need, and from where. Designed interfaces (BS-3), not code.
DOWNSTREAM_SURFACES: Dict[str, Dict[str, object]] = {
    "weakness_intelligence": {
        "reads": ["certified item concept_code + difficulty", "per-concept misconception evidence",
                  "student item responses (ERP spine, R5-5)"],
        "readers": ["product_bank", "manifest"],
        "blocked_on": "per-concept difficulty/misconception layer (R5-5); response spine seeded at pilot use",
    },
    "adaptive_practice": {
        "reads": ["certified items by concept + difficulty", "prerequisite edges (R5-1)",
                  "KC_ concept spine (frozen index, ro)"],
        "readers": ["product_bank", "manifest", "frozen_index_ro"],
        "blocked_on": "prerequisite edge table (R5-1) + KC_ namespace convergence (R5-2)",
    },
    "ai_tutor": {
        "reads": ["certified concept definitions + evidence refs (ro)", "certified items for worked examples"],
        "readers": ["frozen_index_ro", "product_bank"],
        "blocked_on": "product bank growth (needs R4-2 actors + a live key); deterministic-first tutoring rules",
    },
    "analytics": {
        "reads": ["coverage/inventory counts across all lanes", "certification provenance"],
        "readers": ["manifest"],
        "blocked_on": "nothing structural — reads the reconciled manifest (this is the guard for BS-6 claims)",
    },
}


class SurfaceContractViolation(Exception):
    """Raised when a downstream surface tries to read from an un-sanctioned source (RI-6 / BS-3)."""


def downstream_surface_contracts() -> Dict[str, object]:
    return {"sanctioned_readers": SANCTIONED_READERS, "surfaces": DOWNSTREAM_SURFACES,
            "rule": ("a downstream surface reads ONLY through a sanctioned reader; a raw store is never one. "
                     "This is the designed-interface closure of BS-3 — the surfaces are absent, but their read "
                     "contracts are fixed so none can repeat the un-reconciled qie.db second-surface mistake.")}


def assert_surface_read(surface: str, reader: str) -> None:
    """Fail CLOSED if `surface` reads through an unknown surface or an un-sanctioned reader."""
    spec = DOWNSTREAM_SURFACES.get(surface)
    if spec is None:
        raise SurfaceContractViolation(f"unknown downstream surface {surface!r}")
    if reader not in SANCTIONED_READERS:
        raise SurfaceContractViolation(
            f"{surface!r} attempted a read via un-sanctioned reader {reader!r}; allowed: "
            f"{sorted(SANCTIONED_READERS)} (a raw store is NEVER sanctioned — RI-6)")
    if reader not in spec["readers"]:
        raise SurfaceContractViolation(
            f"{surface!r} may only read via {spec['readers']}, not {reader!r}")


# ── (c) BS-6 — reconciled-inventory guard ──────────────────────────────────────────────────────────────
def reconciled_inventory_guard(unified_path=None) -> Dict[str, object]:
    """A whole-system completeness claim must be computed FROM the reconciled manifest across ALL lanes. Returns
    the lane coverage such a claim must cite; raises if the manifest is absent (no whole-system claim allowed)."""
    from kie.qie.inventory import manifest as MF
    try:
        conn = MF.open_ro(unified_path)
    except sqlite3.OperationalError as e:
        raise SurfaceContractViolation(
            "no reconciled inventory (unified_inventory.db) — a whole-system claim is forbidden until R4-1 "
            "manifest is built (BS-6)") from e
    try:
        lanes = {f"{r['source_store']}::{r['source_table']}": r["n"] for r in conn.execute(
            "SELECT source_store, source_table, COUNT(*) n FROM unified_inventory "
            "GROUP BY source_store, source_table ORDER BY n DESC")}
        stores = sorted({k.split("::", 1)[0] for k in lanes})
        return {"reconciled": True, "source_stores": stores, "lane_coverage": lanes,
                "rule": ("a 'whole-system' completeness claim is valid ONLY when computed across every "
                         "source_store in this manifest; a claim scoped to one lane is refused (BS-6 — the "
                         "blind spot that hid qie.db from the whole board).")}
    finally:
        conn.close()
