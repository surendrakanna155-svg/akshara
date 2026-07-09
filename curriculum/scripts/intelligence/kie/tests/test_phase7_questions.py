"""Phase-7 question-intelligence tests (deterministic + copyright-safe)."""
import unittest

from kie import phase7_questions as p7, store

MCQ = "Calculate the displacement of the body in kinematics. (A) 5 (B) 10 (C) 15 (D) 20"
DERIVE = "Derive the expression for velocity in kinematics. (1) a (2) b (3) c (4) d"
AR = "Assertion: the body accelerates. Reason: a net force acts. (A) both true (B) false"


class TestClassifiers(unittest.TestCase):
    def test_is_question(self):
        self.assertTrue(p7.is_question(MCQ))
        self.assertTrue(p7.is_question("What is inertia?"))
        self.assertTrue(p7.is_question(AR))
        self.assertFalse(p7.is_question("Newton described three laws of motion in his work."))

    def test_classify_type(self):
        self.assertEqual(p7.classify_type(MCQ), "mcq")
        self.assertEqual(p7.classify_type(AR), "assertion_reason")
        self.assertEqual(p7.classify_type("Match the following. Column I and Column II."), "match")
        self.assertEqual(p7.classify_type("Find the value of the integer x."), "numerical")

    def test_bloom(self):
        self.assertEqual(p7.estimate_bloom("Derive the expression"), "hots")
        self.assertEqual(p7.estimate_bloom("Define force"), "remember")
        self.assertEqual(p7.estimate_bloom("Calculate the value"), "apply")

    def test_difficulty(self):
        self.assertEqual(p7.estimate_difficulty("Derive and prove the theorem"), "hard")
        self.assertEqual(p7.estimate_difficulty("Define force"), "easy")
        self.assertEqual(p7.estimate_difficulty("A body moves with some velocity"), "medium")

    def test_option_count(self):
        self.assertEqual(p7.option_count(MCQ), 4)


class TestRun(unittest.TestCase):
    def setUp(self):
        self.conn = store.open_store(":memory:")
        self.conn.execute("INSERT INTO source_documents(doc_id,corpus,rel_path,category,year,sha256,integrity_ok,"
                          "parser_class,parser_strategy,is_duplicate,verify_status,certify_status,certify_reason,created_at) "
                          "VALUES ('d','foundation','p.pdf','JEE_Main',2020,'h',1,'x','text_extract',0,'verified','certified','ok','now')")
        for code, title in [("PHY_KINEMATICS", "Kinematics"), ("PHY_DISPLACEMENT", "Displacement")]:
            self.conn.execute("INSERT INTO concepts(concept_code,title,created_at) VALUES (?,?,'now')", (code, title))
        for i, t in enumerate([MCQ, DERIVE, AR], 1):
            self.conn.execute("INSERT INTO chunks(chunk_id,doc_id,ordinal,block_type,section_path,text,token_est) "
                              "VALUES (?,?,?,?,?,?,?)", (f"d#{i}", "d", i, "question", "", t, 20))
        self.conn.commit()

    def tearDown(self):
        self.conn.close()

    def test_run_builds_patterns_and_families(self):
        s = p7.run(self.conn)
        self.assertEqual(s["questions_detected"], 3)
        self.assertGreaterEqual(s["patterns"], 2)
        self.assertGreaterEqual(s["families"], 1)
        self.assertGreater(s["mapped_patterns"], 0)      # linked to Kinematics/Displacement
        dist = p7.type_distribution(self.conn)
        self.assertIn("mcq", dist)
        # a family exists for a mapped concept
        fam = self.conn.execute("SELECT COUNT(*) n FROM question_families WHERE concept_code='PHY_KINEMATICS'").fetchone()["n"]
        self.assertGreaterEqual(fam, 1)

    def test_no_verbatim_question_text_stored(self):
        p7.run(self.conn)
        skeletons = [r["stem_skeleton"] for r in self.conn.execute("SELECT stem_skeleton FROM question_patterns").fetchall()]
        blob = " ".join(skeletons)
        # copyright safety: structural skeleton only — never the source stem
        self.assertNotIn("Calculate the displacement", blob)
        self.assertNotIn("Derive the expression", blob)
        self.assertTrue(all("bloom=" in s and "difficulty=" in s for s in skeletons))

    def test_years_recorded(self):
        p7.run(self.conn)
        row = self.conn.execute("SELECT years FROM question_patterns WHERE frequency>0 LIMIT 1").fetchone()
        self.assertIn("2020", row["years"])

    def test_rerun_clean(self):
        p7.run(self.conn)
        n1 = self.conn.execute("SELECT COUNT(*) n FROM question_patterns").fetchone()["n"]
        p7.run(self.conn)
        n2 = self.conn.execute("SELECT COUNT(*) n FROM question_patterns").fetchone()["n"]
        self.assertEqual(n1, n2)


if __name__ == "__main__":
    unittest.main()
