"""Phase 4b tests — governed QDI mining/certification driver: the MANDATORY deterministic floor
(anti-copying + structural), audit->certify, deterministic scope-linking, exam-scoped certified-pattern
reading, and blueprint attach with a controlled qdi.db. Self-contained (in-memory)."""
from __future__ import annotations

import json
import sqlite3
import unittest

from kie.qie.knowledge import qdi_link as QL
from kie.qie.knowledge import run_qdi as Q


def _insert_proposed(q, pid, exam, subject, archetype, band, summary, refs="[]"):
    q.execute(
        "INSERT OR REPLACE INTO qdi_pattern (pattern_id, exam, subject, archetype, pattern_name, "
        "design_summary, solution_structure, misconceptions, difficulty_band, evidence_refs, evidence_count, "
        "analyst_model, status, created_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
        (pid, exam, subject, archetype, pid + "_name", summary, json.dumps(["step A", "step B"]),
         json.dumps(["mixes up X and Y"]), band, refs, 1, "test-analyst", "proposed", "t"))
    q.commit()


def _empty_kie():
    k = sqlite3.connect(":memory:")
    k.execute("CREATE TABLE chunks (chunk_id TEXT, text TEXT)")
    return k


class QdiFloor(unittest.TestCase):
    def test_clean_pattern_passes_floor(self):
        q = Q.open_store(":memory:")
        _insert_proposed(q, "QDP_ok", "JEE_Main", "Mathematics", "multi_step_numerical", "hard",
                         "Abstract machinery that eliminates an unknown symbolic scale by ratio before "
                         "solving the residual value.")
        self.assertEqual(Q.deterministic_floor(q, _empty_kie())["passed"], 1)
        q.close()

    def test_short_summary_is_quarantined(self):
        q = Q.open_store(":memory:")
        _insert_proposed(q, "QDP_short", "JEE_Main", "Mathematics", "comparison", "moderate", "tiny")
        self.assertEqual(Q.deterministic_floor(q, _empty_kie())["quarantined_structural"], 1)
        q.close()

    def test_copying_pattern_is_quarantined(self):
        q = Q.open_store(":memory:")
        k = _empty_kie()
        src = ("find the value of x when the particle moves with speed v at angle theta to the axis and "
               "the constant net force acts along the field direction")
        k.execute("INSERT INTO chunks VALUES ('c1', ?)", (src,))
        k.commit()
        _insert_proposed(q, "QDP_copy", "JEE_Main", "Mathematics", "multi_step_numerical", "hard", src,
                         refs=json.dumps([{"chunk_id": "c1"}]))
        self.assertEqual(Q.deterministic_floor(q, k)["quarantined_copying"], 1)
        q.close()


class QdiAuditCertifyAndRead(unittest.TestCase):
    def test_audit_certify_scope_link_read_and_attach(self):
        q = Q.open_store(":memory:")
        _insert_proposed(q, "QDP_a", "JEE_Main", "Mathematics", "multi_step_numerical", "hard",
                         "Abstract machinery for eliminating an unknown scale by ratio then solving the "
                         "residual value.")
        Q.deterministic_floor(q, _empty_kie())
        m = Q.ingest_audit(q, [{"pattern_id": "QDP_a", "verdict": "accept", "reasons": "coherent"}],
                           model="test-auditor")
        self.assertEqual(m["certified"], 1)
        self.assertEqual(Q.scope_link_certified(q), 1)

        pats = Q.certified_patterns_for_exam(q, "JEE_MAIN", "Mathematics")
        self.assertEqual([p["pattern_id"] for p in pats], ["QDP_a"])
        # exam scoping: a JEE_Main pattern is NOT visible to the NEET profile
        self.assertEqual(Q.certified_patterns_for_exam(q, "NEET", "Mathematics"), [])

        # a quarantined pattern is never certified / never read
        _insert_proposed(q, "QDP_b", "JEE_Main", "Mathematics", "comparison", "moderate", "tiny")
        Q.deterministic_floor(q, _empty_kie())
        self.assertNotIn("QDP_b", [p["pattern_id"] for p in Q.certified_patterns_for_exam(q, "JEE_MAIN", "Mathematics")])

        # attach to a matching blueprint (subject, archetype, difficulty)
        bp = QL.attach_pattern(
            {"subject": "Mathematics", "archetype": "multi_step_numerical", "difficulty": "hard",
             "pattern_id": None, "expected_solving_path": None, "misconceptions_to_evaluate": [],
             "planner_evidence": {}}, QL.index_by_key(pats))
        self.assertEqual(bp["pattern_id"], "QDP_a")
        self.assertEqual(bp["expected_solving_path"], ["step A", "step B"])
        self.assertEqual(bp["misconceptions_to_evaluate"], ["mixes up X and Y"])
        q.close()


if __name__ == "__main__":
    unittest.main()
