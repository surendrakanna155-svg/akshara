"""Knowledge Layer Phase 6 — residual concept-quality repair.

Locks the high-precision invariants:
  * verified non-concepts (publication names, glued chapter headings, clause
    extractions, pedagogy scaffolds, bare generic words) are rejected;
  * REAL concepts — including look-alikes ("Introduction to Graphs", "Division of
    Fractions", "Crystallisation", "Resistors in Parallel") — are NEVER rejected;
  * subject mislabels are fixed to the unambiguous home subject;
  * the pass is idempotent (a second run changes nothing).
"""
import json
import unittest

from kie import store
from kie.curate import concept_quality as cq


def _concept(conn, code, title, subject="Physics", status="active", freq=5):
    conn.execute(
        "INSERT INTO concepts(concept_code, title, subject_domain, status, evidence, created_at) "
        "VALUES (?,?,?,?,?,datetime('now'))",
        (code, title, subject, status, json.dumps({"method": "section_title"})),
    )
    conn.execute("INSERT INTO question_patterns(pattern_id, concept_code, frequency) VALUES (?,?,?)",
                 (code + "_P", code, freq))
    conn.commit()


class ConceptQualityTest(unittest.TestCase):
    def setUp(self):
        self.conn = store.open_store(":memory:")

    def tearDown(self):
        self.conn.close()

    def _active(self):
        return {r["concept_code"] for r in self.conn.execute(
            "SELECT concept_code FROM concepts WHERE status='active'").fetchall()}

    def test_rejects_verified_noise(self):
        junk = {
            "J1": "Ganita Prakash", "J2": "Textbook for Class X", "J3": "Subject : Chemistry",
            "J4": "Animal Kingdomchapter 4", "J5": "Coulomb discovered his law",
            "J6": "Verify the distributive law", "J7": "Meet a Scientist", "J8": "Just for FUN",
            "J9": "litres", "J10": "Curiosity", "J11": "Numbers", "J12": "Contents of Physics Part I",
        }
        for code, title in junk.items():
            _concept(self.conn, code, title)
        cq.run(self.conn)
        active = self._active()
        for code in junk:
            self.assertNotIn(code, active, f"{junk[code]!r} should be rejected")

    def test_keeps_real_concepts(self):
        real = {
            "R1": "Introduction to Graphs", "R2": "Division of Fractions", "R3": "Crystallisation",
            "R4": "Resistors in Parallel", "R5": "Comparison of Rational Numbers",
            "R6": "Newton's second law", "R7": "Refraction", "R8": "Double Fertilisation",
            "R9": "Electric Field", "R10": "Photosynthesis",
        }
        for code, title in real.items():
            _concept(self.conn, code, title)
        cq.run(self.conn)
        active = self._active()
        for code in real:
            self.assertIn(code, active, f"{real[code]!r} must NOT be rejected")

    def test_fixes_subject_mislabels(self):
        _concept(self.conn, "M1", "Logarithms", subject="Chemistry")
        _concept(self.conn, "M2", "Baye's theorem", subject="Physics")
        cq.run(self.conn)
        rows = {r["concept_code"]: r["subject_domain"] for r in self.conn.execute(
            "SELECT concept_code, subject_domain FROM concepts").fetchall()}
        self.assertEqual(rows["M1"], "Mathematics")
        self.assertEqual(rows["M2"], "Mathematics")

    def test_idempotent(self):
        _concept(self.conn, "J1", "Ganita Prakash")
        _concept(self.conn, "R1", "Refraction")
        first = cq.run(self.conn)
        second = cq.run(self.conn)
        self.assertEqual(second["rejected"], 0)
        self.assertEqual(second["subjects_fixed"], 0)
        self.assertEqual(first["after"], second["after"])

    def test_dry_run_writes_nothing(self):
        _concept(self.conn, "J1", "Curiosity")
        summary = cq.run(self.conn, dry_run=True)
        self.assertTrue(summary["dry_run"])
        self.assertIn("J1", self._active())


if __name__ == "__main__":
    unittest.main()
