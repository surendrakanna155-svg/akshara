"""RI-5 — QDI provenance + evidence-floor invariants (remediation Lane B, closes audit P0 [C2] + BS-4).

These lock the deterministic gates that RECALL/REFUSE the 7 pre-fix certified QDI patterns and prevent any
future mis-provenanced or under-evidenced pattern from reaching `certified`:

  RI-5.1  provenance invariant — pattern.exam+subject must hold for EVERY evidence doc (canonical exam +
          section-resolved subject); a violation quarantines and leaves floor_passed_at NULL.
  RI-5.2  evidence threshold — >=5 items from >=2 resources, computed from refs, enforced AT certification.
  RI-5.3  floor precondition — an auditor `accept` cannot certify a pattern the floor never cleared.
  RI-5.4  fail-closed — unfetchable evidence quarantines (never a silent pass).
  RI-5.5  qdi_source is populated by the ingest path (no longer 0 rows) with canonical exam.
  RI-5.6  regression — the 7 historical live patterns EACH fail the invariant (fixtures + read-only live DB).
  RI-5.7  no contaminated attachment — a recalled physics pattern never enriches a set-theory blueprint.

Self-contained (in-memory kie.db fixtures shaped like the real defect). The live-DB case is read-only.
"""
from __future__ import annotations

import json
import sqlite3
import unittest

from kie import config
from kie.qie.knowledge import qdi as QDI
from kie.qie.knowledge import qdi_link as QL
from kie.qie.knowledge import run_qdi as Q

_ABSTRACT = ("Abstract machinery that names an observable against a symbolic baseline so the unknown scale "
             "must be eliminated by ratio before the residual quantity is solved.")


def _mkkie():
    """A kie.db mirroring the real defect shapes + a clean control doc."""
    k = sqlite3.connect(":memory:")
    k.row_factory = sqlite3.Row
    k.executescript(
        "CREATE TABLE source_documents (doc_id TEXT PRIMARY KEY, rel_path TEXT, category TEXT, exam TEXT, "
        "subject TEXT, year INT);"
        "CREATE TABLE chunks (chunk_id TEXT PRIMARY KEY, doc_id TEXT, ordinal INT, text TEXT);")
    docs = [
        # (doc_id, rel_path, category, exam, doc-level subject, year)
        ("D_adv", "JEE_Advanced/Previous_Papers/2023/P2.pdf", "JEE_Advanced", "JEE_Advanced", "Mathematics", 2023),
        ("D_prac", "Practice_Resources/JEE_Main/Question_Banks/emb.pdf", "Practice_Resources", "Practice_Resources", "Mathematics", 2021),
        ("D_comb", "JEE_Main/Previous_Papers/2020/x.pdf", "JEE_Main", "JEE_Main", None, 2020),
        ("D_m1", "JEE_Main/Previous_Papers/2021/m1.pdf", "JEE_Main", "JEE_Main", "Mathematics", 2021),
        ("D_m2", "JEE_Main/Previous_Papers/2021/m2.pdf", "JEE_Main", "JEE_Main", "Mathematics", 2021),
    ]
    for row in docs:
        k.execute("INSERT INTO source_documents VALUES (?,?,?,?,?,?)", row)
    # D_adv: PHYSICS content, no in-paper section marker -> resolves to None (the real cef4c09 shape)
    k.execute("INSERT INTO chunks VALUES ('D_adv#8','D_adv',8,?)",
              ("Q.1 An electric dipole is formed by two charges; the electric potential at a point along the "
               "axis is required. Q.2 Young's modulus of elasticity of the given wire under load.",))
    # D_prac: JEE Main MATH practice content, no section marker -> resolves to None
    k.execute("INSERT INTO chunks VALUES ('D_prac#13','D_prac',13,?)",
              ("A conic and a line intersect; determine the locus parameter satisfying the stated tangency "
               "condition for the family of curves given in the practice bank.",))
    # D_comb: a JEE_Main combined paper whose referenced chunk is a PHYSICS section
    k.execute("INSERT INTO chunks VALUES ('D_comb#1','D_comb',1,?)",
              ("Section - A (Physics) 1. A block on a frictionless incline; determine the acceleration under "
               "the applied constant force. (1) 2 (2) 4 (3) 6 (4) 8  Ans (2)",))
    # D_m1 / D_m2: clean JEE_Main MATHEMATICS sections (resolve -> Mathematics)
    refs_math = []
    for doc in ("D_m1", "D_m2"):
        for c in range(3):
            cid = f"{doc}#{c}"
            k.execute("INSERT INTO chunks VALUES (?,?,?,?)",
                      (cid, doc, c, f"Section - A (Mathematics) {c+1}. An implicitly defined figure satisfies "
                       f"a relation; report the requested count. (1) p (2) q (3) r (4) s  Ans (2)"))
            refs_math.append({"chunk_id": cid, "exam": "JEE_Main", "doc_id": doc})
    k.commit()
    return k, refs_math


def _proposed(q, pid, exam, subject, refs, archetype="multi_step_numerical", band="hard",
              summary=_ABSTRACT, stamp_floor=False):
    reflist = refs if isinstance(refs, list) else json.loads(refs or "[]")
    n_res = len({r.get("doc_id") for r in reflist if r.get("doc_id")}) or None
    q.execute(
        "INSERT OR REPLACE INTO qdi_pattern (pattern_id, exam, subject, archetype, pattern_name, "
        "design_summary, solution_structure, misconceptions, difficulty_band, evidence_refs, evidence_count, "
        "evidence_resource_count, floor_passed_at, analyst_model, status, created_at) "
        "VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
        (pid, exam, subject, archetype, pid + "_name", summary, json.dumps(["step A", "step B"]),
         json.dumps(["mixes up X and Y"]), band, json.dumps(reflist), len(reflist), n_res,
         ("2026-07-21T00:00:00+00:00" if stamp_floor else None), "test-analyst", "proposed", "t"))
    q.commit()


# ── RI-5.1 provenance invariant ───────────────────────────────────────────────────────────────────────
class ProvenanceInvariant(unittest.TestCase):
    def test_exam_mismatch_fails(self):
        k, _ = _mkkie()
        # a JEE_Advanced physics chunk claimed as JEE_Main Mathematics (mirrors QDP_57333bb83da55b)
        why = QDI.assert_provenance(k, {"exam": "JEE_Main", "subject": "Mathematics",
                                        "evidence_refs": [{"chunk_id": "D_adv#8", "exam": "JEE_Advanced"}]})
        self.assertIsNotNone(why)
        self.assertIn("exam mismatch", why)

    def test_practice_resources_is_not_jee_main(self):
        k, _ = _mkkie()
        why = QDI.assert_provenance(k, {"exam": "JEE_Main", "subject": "Mathematics",
                                        "evidence_refs": [{"chunk_id": "D_prac#13", "exam": "Practice_Resources"}]})
        self.assertIsNotNone(why)
        self.assertIn("exam mismatch", why)

    def test_subject_mismatch_fails_even_when_exam_matches(self):
        k, _ = _mkkie()
        # exam is genuinely JEE_Main, but the chunk's section-resolved subject is Physics, not Mathematics
        why = QDI.assert_provenance(k, {"exam": "JEE_Main", "subject": "Mathematics",
                                        "evidence_refs": [{"chunk_id": "D_comb#1", "exam": "JEE_Main"}]})
        self.assertIsNotNone(why)
        self.assertIn("subject mismatch", why)

    def test_matching_provenance_passes(self):
        k, refs = _mkkie()
        self.assertIsNone(QDI.assert_provenance(
            k, {"exam": "JEE_Main", "subject": "Mathematics", "evidence_refs": refs}))

    def test_floor_quarantines_bad_provenance_and_withholds_marker(self):
        q = Q.open_store(":memory:")
        k, _ = _mkkie()
        _proposed(q, "QDP_phys", "JEE_Main", "Mathematics",
                  [{"chunk_id": "D_adv#8", "exam": "JEE_Advanced", "doc_id": "D_adv"}])
        m = Q.deterministic_floor(q, k)
        self.assertEqual(m["quarantined_provenance"], 1)
        self.assertEqual(m["passed"], 0)
        row = q.execute("SELECT status, floor_passed_at FROM qdi_pattern WHERE pattern_id='QDP_phys'").fetchone()
        self.assertEqual(row["status"], "quarantined")
        self.assertIsNone(row["floor_passed_at"])
        q.close()

    def test_floor_passes_clean_provenance(self):
        q = Q.open_store(":memory:")
        k, refs = _mkkie()
        _proposed(q, "QDP_clean", "JEE_Main", "Mathematics", refs)
        self.assertEqual(Q.deterministic_floor(q, k)["passed"], 1)
        self.assertIsNotNone(q.execute("SELECT floor_passed_at FROM qdi_pattern WHERE pattern_id='QDP_clean'")
                             .fetchone()["floor_passed_at"])
        q.close()


# ── RI-5.2 evidence threshold at certification ─────────────────────────────────────────────────────────
class EvidenceThreshold(unittest.TestCase):
    def test_one_off_pattern_cannot_certify_even_with_accept(self):
        q = Q.open_store(":memory:")
        k, refs = _mkkie()
        # a single-item / single-resource pattern whose provenance is clean (passes the floor) but is under
        # the evidence floor: auditor accept must NOT certify it (mirrors the 2 physics one-offs' violation)
        _proposed(q, "QDP_one", "JEE_Main", "Mathematics", [refs[0]])
        self.assertEqual(Q.deterministic_floor(q, k)["passed"], 1)  # provenance clean, floor marker stamped
        m = Q.ingest_audit(q, [{"pattern_id": "QDP_one", "verdict": "accept", "reasons": "looks fine"}])
        self.assertEqual(m["certified"], 0)
        self.assertEqual(m["refused_low_evidence"], 1)
        self.assertEqual(q.execute("SELECT status FROM qdi_pattern WHERE pattern_id='QDP_one'").fetchone()[0],
                         "quarantined")
        q.close()

    def test_sufficient_evidence_plus_floor_plus_accept_certifies(self):
        q = Q.open_store(":memory:")
        k, refs = _mkkie()   # 6 items across 2 resources
        _proposed(q, "QDP_ok", "JEE_Main", "Mathematics", refs)
        self.assertEqual(Q.deterministic_floor(q, k)["passed"], 1)
        m = Q.ingest_audit(q, [{"pattern_id": "QDP_ok", "verdict": "accept", "reasons": "coherent"}])
        self.assertEqual(m["certified"], 1)
        q.close()


# ── RI-5.3 floor-marker precondition ─────────────────────────────────────────────────────────────────
class FloorPrecondition(unittest.TestCase):
    def test_accept_without_floor_marker_is_refused(self):
        q = Q.open_store(":memory:")
        k, refs = _mkkie()
        _proposed(q, "QDP_nofloor", "JEE_Main", "Mathematics", refs, stamp_floor=False)  # floor never ran
        m = Q.ingest_audit(q, [{"pattern_id": "QDP_nofloor", "verdict": "accept", "reasons": "accept"}])
        self.assertEqual(m["certified"], 0)
        self.assertEqual(m["refused_no_floor"], 1)
        self.assertEqual(q.execute("SELECT status FROM qdi_pattern WHERE pattern_id='QDP_nofloor'").fetchone()[0],
                         "quarantined")
        q.close()


# ── RI-5.4 fail-closed on unfetchable evidence ──────────────────────────────────────────────────────────
class FailClosed(unittest.TestCase):
    def test_unfetchable_evidence_quarantines(self):
        q = Q.open_store(":memory:")
        k, _ = _mkkie()
        _proposed(q, "QDP_ghost", "JEE_Main", "Mathematics", [{"chunk_id": "does_not_exist#1"}])
        m = Q.deterministic_floor(q, k)
        self.assertEqual(m["quarantined_unfetchable"], 1)
        self.assertEqual(m["passed"], 0)
        q.close()

    def test_ingest_refuses_evidence_less_pattern(self):
        q = Q.open_store(":memory:")
        k, _ = _mkkie()
        m = QDI.ingest_patterns(q, k, {"patterns": [{"pattern_name": "no ev", "design_summary": _ABSTRACT}]},
                                "JEE_Main", "Mathematics", "test-analyst")
        self.assertEqual(m["proposed"], 0)
        self.assertEqual(m["malformed"], 1)
        q.close()


# ── RI-5.5 qdi_source populated by the ingest path ──────────────────────────────────────────────────────
class QdiSourcePopulated(unittest.TestCase):
    def test_ingest_populates_qdi_source_with_canonical_exam(self):
        q = Q.open_store(":memory:")
        k, refs = _mkkie()
        payload = {"patterns": [{
            "pattern_name": "ratio elimination", "design_summary": _ABSTRACT,
            "archetype": "multi_step_numerical", "difficulty_band": "hard",
            "solution_structure": ["set the ratio", "solve residual"],
            "evidence_refs": [{"chunk_id": r["chunk_id"], "exam": "JEE_Main"} for r in refs]}]}
        m = QDI.ingest_patterns(q, k, payload, "JEE_Main", "Mathematics", "test-analyst")
        self.assertEqual(m["proposed"], 1)
        n_src = q.execute("SELECT COUNT(*) FROM qdi_source").fetchone()[0]
        self.assertGreater(n_src, 0)
        # every saved source carries the canonical exam identity (not the pattern's asserted one)
        for row in q.execute("SELECT doc_id, exam FROM qdi_source"):
            canon = k.execute("SELECT COALESCE(exam,category) FROM source_documents WHERE doc_id=?",
                              (row[0],)).fetchone()[0]
            self.assertEqual(row[1], canon)
        # doc_id was backfilled onto the stored refs, and resource_count computed
        row = q.execute("SELECT evidence_refs, evidence_count, evidence_resource_count FROM qdi_pattern").fetchone()
        self.assertTrue(all(rr.get("doc_id") for rr in json.loads(row[0])))
        self.assertEqual(row[1], len(refs))
        self.assertEqual(row[2], 2)
        q.close()


# ── RI-5.6 regression — the 7 historical patterns each FAIL the invariant ───────────────────────────────
# The exact evidence refs of the 7 live-certified patterns (read from qdi.db during the R1-3 investigation).
_HISTORICAL_7 = {
    "QDP_57333bb83da55b": [{"chunk_id": "D_adv#8", "exam": "JEE_Advanced"}],                       # physics
    "QDP_e3842c9a9d9c70": [{"chunk_id": "D_adv#8", "exam": "JEE_Advanced"},
                           {"chunk_id": "D_adv#8", "exam": "JEE_Advanced"}],                        # physics
    "QDP_20862d3cedeb3a": [{"chunk_id": "D_prac#13", "exam": "Practice_Resources"}],                # practice
    "QDP_bdf5e36a5361f5": [{"chunk_id": "D_prac#13", "exam": "Practice_Resources"}],                # practice
    "QDP_8fcca3d9685bd1": [{"chunk_id": "D_prac#13", "exam": "Practice_Resources"}],                # practice
    "QDP_739422ee027f88": [{"chunk_id": "D_prac#13", "exam": "Practice_Resources"}],                # practice
    "QDP_b87802f7f09d33": [{"chunk_id": "D_prac#13", "exam": "Practice_Resources"}],                # practice
}


class HistoricalRegression(unittest.TestCase):
    def test_all_seven_fail_the_invariant_fixture(self):
        k, _ = _mkkie()
        for pid, refs in _HISTORICAL_7.items():
            why = QDI.assert_provenance(k, {"exam": "JEE_Main", "subject": "Mathematics",
                                            "evidence_refs": refs})
            self.assertIsNotNone(why, f"{pid} must FAIL the provenance invariant, but passed")

    @unittest.skipUnless((config.KIE_HOME / "qdi.db").exists() and (config.KIE_HOME / "kie.db").exists(),
                         "live qdi.db / kie.db not present (gitignored / local only)")
    def test_live_certified_patterns_all_fail_invariant_read_only(self):
        # READ-ONLY: never route the live qdi.db through open_qdi (no schema migration, no mutation).
        qdb = sqlite3.connect(f"file:{config.KIE_HOME / 'qdi.db'}?mode=ro", uri=True)
        qdb.row_factory = sqlite3.Row
        kdb = sqlite3.connect(f"file:{config.KIE_HOME / 'kie.db'}?mode=ro", uri=True)
        kdb.row_factory = sqlite3.Row
        try:
            rows = qdb.execute("SELECT pattern_id, exam, subject, evidence_refs FROM qdi_pattern "
                               "WHERE status='certified'").fetchall()
            self.assertTrue(rows, "expected the 7 historical certified patterns to still be present")
            for r in rows:
                why = QDI.assert_provenance(kdb, {"exam": r["exam"], "subject": r["subject"],
                                                  "evidence_refs": r["evidence_refs"]})
                self.assertIsNotNone(
                    why, f"live certified pattern {r['pattern_id']} unexpectedly PASSED the provenance "
                         f"invariant — a mis-provenanced pattern must be recalled")
        finally:
            qdb.close()
            kdb.close()


# ── RI-5.7 no contaminated attachment after recall ──────────────────────────────────────────────────────
class NoContaminatedAttachment(unittest.TestCase):
    def test_recalled_physics_pattern_never_enriches_set_theory_blueprint(self):
        q = Q.open_store(":memory:")
        k, _ = _mkkie()
        # a physics pattern FALSELY tagged Mathematics/multi_concept_integration/hard (mirrors the real
        # QDP_57333bb83da55b contamination of the "Empty Set" spec). It fails the floor -> quarantined.
        _proposed(q, "QDP_phys", "JEE_Main", "Mathematics",
                  [{"chunk_id": "D_adv#8", "exam": "JEE_Advanced", "doc_id": "D_adv"}],
                  archetype="multi_concept_integration", band="hard",
                  summary="Physics kinematics solving path masquerading as set-theory design intelligence.")
        Q.deterministic_floor(q, k)
        # certified_patterns must EXCLUDE the recalled pattern
        certified = QDI.certified_patterns(q, "Mathematics")
        self.assertNotIn("QDP_phys", [p["pattern_id"] for p in certified])
        # a set-theory blueprint attaching over ONLY certified patterns keeps honest nulls (no physics DNA)
        bp = QL.attach_pattern(
            {"subject": "Mathematics", "archetype": "multi_concept_integration", "difficulty": "hard",
             "concept_title": "The Empty Set", "pattern_id": None, "expected_solving_path": None,
             "misconceptions_to_evaluate": [], "planner_evidence": {}}, QL.index_by_key(certified))
        self.assertIsNone(bp["pattern_id"])
        self.assertIsNone(bp["expected_solving_path"])
        q.close()


# ── R1-3 unknown-exam scope hardening (qdi_link) ────────────────────────────────────────────────────────
class UnknownExamScope(unittest.TestCase):
    def test_unknown_exam_is_not_silently_mapped_to_school(self):
        link = QL.scope_link_for({"pattern_id": "P", "exam": "Practice_Resources", "subject": "Mathematics"})
        self.assertNotEqual(link["exam_profile"], "SCHOOL")
        self.assertIsNone(link["exam_profile"])
        self.assertIsNotNone(QL.validate_scope_link(link))  # refused

    def test_known_exams_still_map(self):
        self.assertEqual(QL.scope_link_for({"pattern_id": "P", "exam": "JEE_Main"})["exam_profile"], "JEE_MAIN")
        self.assertEqual(QL.scope_link_for({"pattern_id": "P", "exam": "NEET"})["exam_profile"], "NEET")


if __name__ == "__main__":
    unittest.main()
