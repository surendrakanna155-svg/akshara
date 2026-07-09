"""Phase-5 concept-extraction tests (deterministic + gated AI hook)."""
import os
import unittest

from kie import phase5_concept as p5, store


class TestHelpers(unittest.TestCase):
    def test_concept_code_deterministic(self):
        self.assertEqual(p5.concept_code("Physics", "Newton's Second Law"), "PHY_NEWTON_S_SECOND_LAW")
        self.assertEqual(p5.concept_code("Physics", "Newton's Second Law"),
                         p5.concept_code("Physics", "Newton's Second Law"))
        self.assertTrue(p5.concept_code(None, "Vectors").startswith("GEN_"))

    def test_is_concept_title(self):
        self.assertTrue(p5.is_concept_title("Real Numbers"))
        self.assertTrue(p5.is_concept_title("Laws of Motion"))
        self.assertFalse(p5.is_concept_title("08th April 2024 Shift-2"))
        self.assertFalse(p5.is_concept_title("CAREERS360"))
        self.assertFalse(p5.is_concept_title("12345"))
        self.assertFalse(p5.is_concept_title("a b c d e f g h i j"))  # too many words

    def test_extract_definitions(self):
        defs = p5.extract_definitions("Momentum is defined as the product of mass and velocity. Noise.")
        self.assertEqual(defs, [("Momentum", "the product of mass and velocity")])

    def test_extract_named_laws(self):
        laws = p5.extract_named_laws(
            "By Newton's second law and Ohm's law and the Pythagoras theorem we proceed."
        )
        names = {n for n, _ in laws}
        self.assertIn("Newton's second law", names)
        self.assertIn("Ohm's law", names)
        self.assertTrue(any(k == "theorem" for _, k in laws))

    def test_ai_hook_gated(self):
        os.environ.pop("KIE_AI_AUTHORIZED", None)
        self.assertFalse(p5.ai_available())
        with self.assertRaises(p5.AiGatedError):
            p5.ai_enrich_concept("some small chunk")


class TestRun(unittest.TestCase):
    def setUp(self):
        self.conn = store.open_store(":memory:")
        self.did = "aaaa0000bbbb1111"
        self.conn.execute(
            """INSERT INTO source_documents
                 (doc_id,corpus,rel_path,category,subject,sha256,integrity_ok,encrypted,parser_class,parser_strategy,
                  is_duplicate,verify_status,certify_status,certify_reason,created_at)
               VALUES (?,?,?,?,?,?,1,0,'born_digital_text','text_extract',0,'verified','certified','ok','now')""",
            (self.did, "foundation", "phys.pdf", "NCERT", "Physics", "q" * 64),
        )
        for i, title in enumerate(["Laws of Motion", "08th April 2024 Shift-2"], 1):
            self.conn.execute("INSERT INTO document_sections(section_id,doc_id,ordinal,level,title,page,path) "
                              "VALUES (?,?,?,1,?,1,?)", (f"{self.did}#s{i}", self.did, i, title, title))
        for i, txt in enumerate([
            "Force is defined as the product of mass and acceleration.",
            "This follows from Newton's second law of motion in mechanics.",
        ], 1):
            self.conn.execute("INSERT INTO chunks(chunk_id,doc_id,ordinal,block_type,section_path,text,token_est) "
                              "VALUES (?,?,?,?,?,?,?)", (f"{self.did}#{i}", self.did, i, "paragraph", "", txt, 10))
        self.conn.commit()

    def tearDown(self):
        self.conn.close()

    def test_run_extracts_concepts_and_formula(self):
        s = p5.run(self.conn)
        self.assertEqual(s["processed"], 1)
        titles = {r["title"] for r in self.conn.execute("SELECT title FROM concepts").fetchall()}
        self.assertIn("Laws of Motion", titles)       # section concept
        self.assertIn("Force", titles)                # definition concept
        self.assertNotIn("08th April 2024 Shift-2", titles)  # noise filtered
        force = self.conn.execute("SELECT definition FROM concepts WHERE title='Force'").fetchone()
        self.assertIn("mass and acceleration", force["definition"])
        laws = self.conn.execute("SELECT COUNT(*) n FROM formulas WHERE kind='law'").fetchone()["n"]
        self.assertGreaterEqual(laws, 1)

    def test_merge_and_idempotent(self):
        p5.run(self.conn)
        n1 = self.conn.execute("SELECT COUNT(*) n FROM concepts").fetchone()["n"]
        s2 = p5.run(self.conn)                         # ledger skip
        self.assertEqual(s2["skipped"], 1)
        n2 = self.conn.execute("SELECT COUNT(*) n FROM concepts").fetchone()["n"]
        self.assertEqual(n1, n2)


if __name__ == "__main__":
    unittest.main()
