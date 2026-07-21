"""Remediation R1-4 — produce knowledge index v1.5 from frozen v1.4 + the live substrate.

WHY: v1.4 was frozen against a kie.db that was RE-CHUNKED on Jul-18 AFTER certification, so it ships 5
dangling evidence refs (chunk gone) and ~garbage OCR-furniture evidence on ~9 more concepts. Evidence refs
were also bare `doc_id#ordinal` with no content hash, so the drift was undetectable. v1.5 fixes this
WITHOUT mutating v1.4 (freeze-as-versioning): it content-addresses every ref (evidence_sha256), records a
substrate fingerprint, and runs a DETERMINISTIC evidence gate the AI cannot waive — QUARANTINING every
certified concept whose cited evidence no longer resolves or is non-substantive. Quarantine is the honest
deterministic outcome; re-certifying those concepts needs the model proposer and is DEFERRED (downstream of
this halt) — do not attempt it here.

⚠ NON-DESTRUCTIVE / NO LIVE MUTATION. This never touches v1.4's bytes: run it against a COPY of the frozen
index (and the live/copied kie.db substrate). It opens the index with the sanctioned unfreeze hatch, so it
is exempt from the R1-5 freeze guard, but the caller is responsible for pointing it at a copy — see main().

Usage (from curriculum/scripts/intelligence/):
    ../../.venv/bin/python -m kie.qie.remediation.rebuild_v15 <index_copy.db> [kie.db] [--version v1.5]
"""
from __future__ import annotations

import sqlite3
import sys

from kie import config
from kie.qie.knowledge import build as B
from kie.qie.knowledge import engineer as E
from kie.qie.knowledge import schema as SC


def rebuild_v15(index_path: str, kie_path: str = None, version: str = "v1.5") -> dict:
    """Backfill content hashes, apply the deterministic evidence gate (quarantine on fail), then freeze.

    Returns a report dict: backfilled rows, the quarantined concept list, the resulting certified count, and
    the recorded content + substrate fingerprints. `index_path` MUST be a writable copy of the frozen index;
    `kie_path` defaults to the live substrate (config.DB_PATH) opened read-only."""
    kie_path = str(kie_path or config.DB_PATH)
    conn = SC.open_index(index_path, unfreeze=True)   # sanctioned bump; migrate adds evidence_sha256
    k = sqlite3.connect(f"file:{kie_path}?mode=ro", uri=True)
    k.row_factory = sqlite3.Row
    quarantined = []
    try:
        before = conn.execute("SELECT COUNT(*) FROM ki_concept WHERE status='certified'").fetchone()[0]

        # 1. content-address every ref to the substrate v1.5 binds to (additive column; tuple untouched)
        backfilled = E.backfill_evidence_sha256(conn, k)

        # 2. deterministic evidence gate over every certified concept; FAIL -> guarded quarantine
        rows = conn.execute(
            "SELECT concept_id, canonical_name, section_heading, evidence_chunks, evidence_sha256 "
            "FROM ki_concept WHERE status='certified'").fetchall()
        for r in rows:
            ok, reason = E.evidence_gate(k, r)
            if ok:
                continue
            cur = conn.execute(
                "UPDATE ki_concept SET status='quarantined', audit_verdict='quarantine', audit_reasons=?, "
                "audit_model='deterministic(evidence-gate v1.5)' "
                "WHERE concept_id=? AND status='certified'",
                (f"evidence gate v1.5: {reason}"[:400], r["concept_id"]))
            if cur.rowcount != 1:                      # guarded transition (money-integrity race pattern)
                raise RuntimeError(f"quarantine of {r['concept_id']} affected {cur.rowcount} rows, expected 1")
            quarantined.append({"concept_id": r["concept_id"], "name": r["canonical_name"], "reason": reason})
        conn.commit()
    finally:
        conn.close()
        k.close()

    # 3. freeze the new version (recompute content fingerprint + record substrate fingerprint + sanitize
    #    the stale index-resident qdi_* tables and the unversioned/legacy meta keys + flip immutability)
    frz = B.freeze_index(version, index_path=index_path, kie_path=kie_path)
    return {"before_certified": before, "backfilled": backfilled,
            "quarantined_count": len(quarantined), "quarantined": quarantined, **frz}


def main(argv) -> int:
    if not argv:
        raise SystemExit(__doc__)
    version = "v1.5"
    args = []
    it = iter(argv)
    for a in it:
        if a == "--version":
            version = next(it)
        else:
            args.append(a)
    if not args:
        raise SystemExit("give the path to a WRITABLE COPY of the frozen index (never the live index)")
    index_path = args[0]
    kie_path = args[1] if len(args) > 1 else None
    rep = rebuild_v15(index_path, kie_path, version)
    print(f"REBUILD {rep['version']}: certified {rep['before_certified']} -> {rep['certified']} "
          f"(quarantined {rep['quarantined_count']}); backfilled_sha={rep['backfilled']}")
    print(f"  content_fp   = {rep['content_fingerprint']}")
    print(f"  substrate_fp = {rep['substrate_fingerprint']}  chunks={rep['chunks']}")
    print(f"  dropped      = {rep['dropped_tables']}  meta_keys_removed={rep['meta_keys_removed']}")
    print("  quarantined concepts:")
    for q in rep["quarantined"]:
        print(f"    {q['concept_id']} | {q['name']} | {q['reason']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
