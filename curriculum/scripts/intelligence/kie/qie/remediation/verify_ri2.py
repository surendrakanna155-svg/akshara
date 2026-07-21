"""Remediation R1-4 — standalone LIVE RI-2 verifier (run AFTER v1.5 is produced + re-pointed live).

RI-2: every certified concept must have at least one cited chunk that resolves in the live substrate, whose
recorded sha256 still matches (no drift), and whose text is substantive. Plus: the recorded substrate
fingerprint must equal the live kie.db. This is the same gate the in-suite fixture exercises, but run over
the REAL live index — kept OUT of the unit suite because on the current frozen v1.4 it legitimately FAILS
(that drift is what v1.5 fixes). Exit code 0 = clean, 1 = violations (use it as an integration gate).

Usage (from curriculum/scripts/intelligence/):
    ../../.venv/bin/python -m kie.qie.remediation.verify_ri2 [index.db] [kie.db]
"""
from __future__ import annotations

import json
import sqlite3
import sys

from kie import config
from kie.qie.knowledge import engineer as E
from kie.qie.knowledge import schema as SC


def verify(index_path: str = None, kie_path: str = None) -> dict:
    ip = str(index_path or (config.KIE_HOME / "knowledge_index.db"))
    kp = str(kie_path or config.DB_PATH)
    iconn = sqlite3.connect(f"file:{ip}?mode=ro", uri=True); iconn.row_factory = sqlite3.Row
    kconn = sqlite3.connect(f"file:{kp}?mode=ro", uri=True); kconn.row_factory = sqlite3.Row
    have_sha = "evidence_sha256" in {r[1] for r in iconn.execute("PRAGMA table_info(ki_concept)")}
    cols = "concept_id, canonical_name, section_heading, evidence_chunks" + (
        ", evidence_sha256" if have_sha else "")
    violations = []
    try:
        for r in iconn.execute(f"SELECT {cols} FROM ki_concept WHERE status='certified'"):
            ok, reason = E.evidence_gate(kconn, r)
            if not ok:
                refs = json.loads(r["evidence_chunks"] or "[]")
                violations.append({"concept_id": r["concept_id"], "name": r["canonical_name"],
                                   "reason": reason, "refs": refs})
        ver = SC.frozen_version(iconn)
        try:
            substrate = SC.assert_substrate_matches_freeze(iconn, kie_path=kp)
            substrate_ok, substrate_msg = True, f"matches ({substrate[:12]}…)"
        except SC.SubstrateDriftError as e:
            substrate_ok, substrate_msg = False, str(e)
        n_cert = iconn.execute("SELECT COUNT(*) FROM ki_concept WHERE status='certified'").fetchone()[0]
    finally:
        iconn.close(); kconn.close()
    return {"version": ver, "certified": n_cert, "violations": violations,
            "substrate_ok": substrate_ok, "substrate_msg": substrate_msg}


def main(argv) -> int:
    rep = verify(argv[0] if argv else None, argv[1] if len(argv) > 1 else None)
    print(f"RI-2 live verify [{rep['version']}]: certified={rep['certified']} "
          f"violations={len(rep['violations'])} substrate_ok={rep['substrate_ok']} ({rep['substrate_msg']})")
    for v in rep["violations"][:50]:
        print(f"  VIOLATION {v['concept_id']} | {v['name']} | {v['reason']} | {v['refs']}")
    return 0 if (not rep["violations"] and rep["substrate_ok"]) else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
