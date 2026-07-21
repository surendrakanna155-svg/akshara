"""Phase 4b tests — governed QDI mining/certification driver: the MANDATORY deterministic floor
(anti-copying + structural + FAIL-CLOSED provenance), audit->certify (now gated on floor marker + evidence
threshold), deterministic scope-linking, exam-scoped certified-pattern reading, and blueprint attach with a
controlled qdi.db. Self-contained (in-memory).

R1-3: the floor is fail-closed on unfetchable evidence and requires the exam+subject provenance invariant, so
these tests supply a real (in-memory) kie.db whose docs' canonical exam + section-resolved subject MATCH the
pattern's declared (exam, subject). A pattern with no fetchable / mis-provenanced evidence can no longer be
certified — that behaviour is proven in test_qdi_provenance_invariants.py."""
from __future__ import annotations

import json
import sqlite3
import unittest

from kie.qie.knowledge import qdi_link as QL
from kie.qie.knowledge import run_qdi as Q


def _insert_proposed(q, pid, exam, subject, archetype, band, summary, refs="[]"):
    reflist = refs if isinstance(refs, list) else json.loads(refs or "[]")
    n_res = len({r.get("doc_id") for r in reflist if r.get("doc_id")}) or None
    q.execute(
        "INSERT OR REPLACE INTO qdi_pattern (pattern_id, exam, subject, archetype, pattern_name, "
        "design_summary, solution_structure, misconceptions, difficulty_band, evidence_refs, evidence_count, "
        "evidence_resource_count, analyst_model, status, created_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
        (pid, exam, subject, archetype, pid + "_name", summary, json.dumps(["step A", "step B"]),
         json.dumps(["mixes up X and Y"]), band, json.dumps(reflist), len(reflist), n_res,
         "test-analyst", "proposed", "t"))
    q.commit()


def _empty_kie():
    k = sqlite3.connect(":memory:")
    k.execute("CREATE TABLE chunks (chunk_id TEXT, text TEXT)")
    return k


def _kie_math(exam="JEE_Main", subject="Mathematics", docs=2, per=3):
    """An in-memory kie.db whose docs are canonically `exam` and whose chunks carry a `subject` section
    marker, so resolve_chunk_subjects yields `subject`. Returns (kconn, evidence_refs) with >=docs*per items
    across `docs` distinct resources (enough to clear the >=5-item/>=2-resource evidence floor)."""
    k = sqlite3.connect(":memory:")
    k.row_factory = sqlite3.Row
    k.executescript(
        "CREATE TABLE source_documents (doc_id TEXT PRIMARY KEY, rel_path TEXT, category TEXT, exam TEXT, "
        "subject TEXT, year INT);"
        "CREATE TABLE chunks (chunk_id TEXT PRIMARY KEY, doc_id TEXT, ordinal INT, text TEXT);")
    refs = []
    for d in range(docs):
        doc = f"D{d}"
        k.execute("INSERT INTO source_documents VALUES (?,?,?,?,?,?)",
                  (doc, f"{exam}/Previous_Papers/2021/{doc}.pdf", exam, exam, subject, 2021))
        for c in range(per):
            cid = f"{doc}#{c}"
            k.execute("INSERT INTO chunks VALUES (?,?,?,?)",
                      (cid, doc, c, f"Section - A ({subject}) {c+1}. An implicitly defined quantity satisfies a "
                       f"given relation; report the requested figure {d*10+c}. (1) p (2) q (3) r (4) s  Ans (2)"))
            refs.append({"chunk_id": cid, "exam": exam, "doc_id": doc})
    k.commit()
    return k, refs


class QdiFloor(unittest.TestCase):
    def test_clean_pattern_passes_floor_and_stamps_marker(self):
        q = Q.open_store(":memory:")
        k, refs = _kie_math()
        _insert_proposed(q, "QDP_ok", "JEE_Main", "Mathematics", "multi_step_numerical", "hard",
                         "Abstract machinery that eliminates an unknown symbolic scale by ratio before "
                         "solving the residual value.", refs=refs)
        self.assertEqual(Q.deterministic_floor(q, k)["passed"], 1)
        # a genuine pass stamps the marker the certification gate requires
        row = q.execute("SELECT floor_passed_at, provenance_verified FROM qdi_pattern "
                        "WHERE pattern_id='QDP_ok'").fetchone()
        self.assertIsNotNone(row["floor_passed_at"])
        self.assertEqual(row["provenance_verified"], 1)
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

    def test_unfetchable_evidence_fails_closed(self):
        # evidence chunk_ids absent from kie.db -> the floor cannot verify anti-copy/provenance -> quarantine
        q = Q.open_store(":memory:")
        _insert_proposed(q, "QDP_ghost", "JEE_Main", "Mathematics", "multi_step_numerical", "hard",
                         "Abstract machinery eliminating an unknown scale by ratio before the residual solve.",
                         refs=json.dumps([{"chunk_id": "missing#1"}]))
        m = Q.deterministic_floor(q, _kie_math()[0])
        self.assertEqual(m["quarantined_unfetchable"], 1)
        self.assertEqual(m["passed"], 0)
        self.assertIsNone(q.execute("SELECT floor_passed_at FROM qdi_pattern WHERE pattern_id='QDP_ghost'")
                          .fetchone()["floor_passed_at"])
        q.close()


class QdiAuditCertifyAndRead(unittest.TestCase):
    def test_audit_certify_scope_link_read_and_attach(self):
        q = Q.open_store(":memory:")
        k, refs = _kie_math()
        _insert_proposed(q, "QDP_a", "JEE_Main", "Mathematics", "multi_step_numerical", "hard",
                         "Abstract machinery for eliminating an unknown scale by ratio then solving the "
                         "residual value.", refs=refs)
        self.assertEqual(Q.deterministic_floor(q, k)["passed"], 1)
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
