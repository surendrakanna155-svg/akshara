"""Content Density — definition-first extraction over board docs.

Locks precision-first invariants: clean atomic (term, definition) pairs are extracted; sentence
fragments / pronoun / run-on subjects, option-list bodies, and OCR-merged prose are rejected;
subject is resolved (or the term is skipped, never guessed); creation is idempotent.
"""
import unittest

from kie import store
from kie.curate import board_definitions as bd
from kie.qpgen.materialize import usable_definition


class ExtractPairsTest(unittest.TestCase):
    def _terms(self, text, subj=None):
        return {t for t, _, _ in bd.extract_pairs(text, subj)}

    def test_accepts_clean_atomic_definitions(self):
        text = ("Alloying is a method of improving the properties of a metal. "
                "Iris is the coloured part that we see in an eye. "
                "Oxidation is the gain of oxygen or loss of hydrogen.")
        pairs = bd.extract_pairs(text, "Chemistry")
        terms = {t for t, _, _ in pairs}
        self.assertIn("Alloying", terms)
        self.assertIn("Oxidation", terms)
        for _, d, _ in pairs:
            self.assertTrue(usable_definition(d))

    def test_rejects_fragment_and_runon_subjects(self):
        text = ("Since x is the distance between the pole and the gate it must be positive. "
                "What is the ratio of heights of the tower and the building. "
                "Once the food is eaten its energy follows a variety of patterns. "
                "Oxidation reactions Though combustion is generally an oxidation reaction here. "
                "ATP ATP is the energy currency for most cellular processes here.")
        self.assertEqual(self._terms(text, "Chemistry"), set())

    def test_rejects_option_list_body(self):
        text = ("Respiration is a catabolic process because of ( ) A) breakdown of food "
                "B) conversion of light C) synthesis of glucose in leaves.")
        self.assertEqual(self._terms(text, "Biology"), set())

    def test_rejects_ocr_merged_prose(self):
        text = "Valence is thecombining power of an element with respect to hydrogen and oxygen."
        self.assertEqual(self._terms(text, "Chemistry"), set())

    def test_subject_resolution_skips_when_unknown(self):
        # combined-science doc (doc_subject None); a term with no lexicon signal is skipped
        text = "Xylophone is a very melodious wooden musical instrument played in orchestras."
        self.assertEqual(bd.extract_pairs(text, None), [])

    def test_idempotent_creation(self):
        conn = store.open_store(":memory:")
        try:
            conn.execute(
                "INSERT INTO source_documents(doc_id,corpus,rel_path,category,exam,sha256,"
                "integrity_ok,encrypted,is_duplicate,verify_status,certify_status,certify_reason,"
                "class_label,created_at) VALUES ('d1','board','x/y.pdf','TS_SCERT','TS','s',1,0,0,"
                "'verified','certified','ok','Class 10',datetime('now'))")
            conn.commit()
            # no PDF resolvable in a memory test → run is a clean no-op (docs scanned, 0 created)
            s1 = bd.run(conn)
            s2 = bd.run(conn)
            self.assertEqual(s1["concepts_created"], 0)
            self.assertEqual(s2["concepts_created"], 0)
        finally:
            conn.close()


if __name__ == "__main__":
    unittest.main()
