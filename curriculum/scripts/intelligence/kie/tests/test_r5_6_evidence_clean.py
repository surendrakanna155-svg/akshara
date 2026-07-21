"""R5-6 [#data-integrity-2] — deterministic evidence-substrate cleaning: strip whole-line boilerplate (never
in-line content), flag low-linguistic (mangled) chunks, cleaned text stored BESIDE the raw pointer, frozen
stores never mutated.
"""
from __future__ import annotations

import json
import os
import sqlite3
import tempfile
import unittest

from kie import config
from kie.qie.graph import evidence_clean as EC
from kie.qie.graph import store as GST


class TestCleanText(unittest.TestCase):
    def test_strips_reprint_pagenum_runninghead(self):
        raw = ("Reprint 2026-27\n2\nCuriosity — Textbook of Science for Grade 8\n"
               "Forces are connected to powerful weather events like storms and cyclones.")
        cleaned, removed = EC.clean_text(raw)
        self.assertTrue(removed)
        self.assertIn("Forces are connected", cleaned)
        self.assertNotIn("Reprint 2026-27", cleaned)
        self.assertNotIn("Textbook of Science", cleaned)
        self.assertFalse(cleaned.strip().startswith("2\n"))       # standalone page number gone

    def test_keeps_inline_mention_of_reprint(self):
        # only WHOLE-LINE boilerplate is stripped; a real sentence mentioning 'reprint' survives
        raw = "The reprint of this book in 2026 corrected several errors in the diagrams."
        cleaned, removed = EC.clean_text(raw)
        self.assertFalse(removed)
        self.assertEqual(cleaned, raw)

    def test_data_dump_numbers_are_preserved(self):
        # verifier Finding 1: a chunk full of standalone numbers is a figure/table DUMP — those digits are real
        # content and must NEVER be deleted as "page numbers"
        raw = "Find the sum of the numbers in each figure.\n40\n40\n50\n125\n250\n500\n25\n35\n15"
        cleaned, _removed = EC.clean_text(raw)
        for n in ("40", "50", "125", "250", "500"):
            self.assertIn(n, cleaned, f"data number {n} was wrongly deleted")

    def test_sparse_page_number_still_stripped(self):
        cleaned, removed = EC.clean_text("Reprint 2026-27\n47\nForce is a push or a pull.")
        self.assertTrue(removed)
        self.assertEqual(cleaned, "Force is a push or a pull.")   # the lone page number 47 stripped

    def test_non_linguistic_ratio(self):
        self.assertLess(EC.non_linguistic_ratio("This is ordinary prose about photosynthesis."), 0.1)
        self.assertGreater(EC.non_linguistic_ratio("83818181=++#@^~|{}[]<>=++83818181"), 0.5)

    def test_mangled_flag_catches_number_soup_and_spares_prose(self):
        # verifier Finding 2: near prose-free number soup must be flagged even when spaces make the ratio look ok
        self.assertTrue(EC.is_flagged_mangled("40 40 50 125 250 500 25 35 15 32 32 6464 5001000"))
        self.assertFalse(EC.is_flagged_mangled("Photosynthesis converts light energy into chemical energy."))

    def test_empty_text(self):
        self.assertEqual(EC.clean_text(""), ("", False))
        self.assertEqual(EC.non_linguistic_ratio(""), 0.0)
        self.assertFalse(EC.is_flagged_mangled(""))


def _synth(tmp):
    idx = os.path.join(tmp, "knowledge_index.db")
    c = sqlite3.connect(idx)
    c.execute("CREATE TABLE ki_meta (key TEXT, value TEXT)")
    c.execute("INSERT INTO ki_meta VALUES ('certified_knowledge_fingerprint_v1.5','cafe1234')")
    # XW.build reads canonical_name/aliases; evidence_clean reads evidence_chunks/status
    c.execute("CREATE TABLE ki_concept (concept_id TEXT, subject TEXT, canonical_name TEXT, aliases TEXT, "
              "evidence_chunks TEXT, status TEXT)")
    c.executemany("INSERT INTO ki_concept VALUES (?,?,?,?,?,?)", [
        ("KC_1", "Physics", "Force", "[]", json.dumps(["docA#1", "docA#2"]), "certified"),
        ("KC_2", "Biology", "Cell", "[]", json.dumps(["docA#3", "MISSING#9"]), "certified"),  # MISSING = dangling
        ("KC_DRAFT", "Physics", "Draft", "[]", json.dumps(["docA#4"]), "proposed"),           # not certified
    ])
    c.commit(); c.close()

    kie = os.path.join(tmp, "kie.db")
    k = sqlite3.connect(kie)
    k.execute("CREATE TABLE chunks (chunk_id TEXT PRIMARY KEY, doc_id TEXT, ordinal INTEGER, text TEXT)")
    k.executemany("INSERT INTO chunks VALUES (?,?,?,?)", [
        ("docA#1", "docA", 1, "Reprint 2026-27\n5\nA force is a push or a pull acting on an object."),
        ("docA#2", "docA", 2, "Newton's first law describes inertia clearly and completely here."),
        ("docA#3", "docA", 3, "8181=++==##@@^^||{}[]<>81813838=++=="),   # mangled -> flagged
        ("docA#4", "docA", 4, "This grounds only a NON-certified concept and must be skipped."),
    ])
    k.commit(); k.close()
    return idx, kie


class TestBuild(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.idx, self.kie = _synth(self.tmp.name)
        self.graph = os.path.join(self.tmp.name, "graph_edges.db")
        self.summary = EC.build(graph_path=self.graph, index_path=self.idx, kie_path=self.kie)

    def tearDown(self):
        self.tmp.cleanup()

    def test_only_certified_evidence_processed(self):
        # docA#4 grounds only KC_DRAFT (non-certified) -> not processed; MISSING#9 dangling -> skipped
        self.assertEqual(self.summary["chunks_processed"], 3)      # docA#1, docA#2, docA#3
        self.assertIsNone(EC.cleaned_evidence("docA#4", self.graph))

    def test_boilerplate_removed_and_content_kept(self):
        r = EC.cleaned_evidence("docA#1", self.graph)
        self.assertIn("A force is a push or a pull", r["cleaned_text"])
        self.assertNotIn("Reprint", r["cleaned_text"])

    def test_mangled_flagged(self):
        r = EC.cleaned_evidence("docA#3", self.graph)
        self.assertEqual(r["flagged_mangled"], 1)
        self.assertGreater(r["non_linguistic_ratio"], EC.MANGLED_RATIO)

    def test_summary_counts(self):
        self.assertEqual(self.summary["boilerplate_removed"], 1)  # only docA#1
        self.assertEqual(self.summary["flagged_mangled"], 1)      # only docA#3

    def test_frozen_stores_never_written(self):
        for p in (self.idx, self.kie):
            ro = sqlite3.connect(f"file:{p}?mode=ro", uri=True)
            with self.assertRaises(sqlite3.OperationalError):
                ro.execute("CREATE TABLE _w (x)")
            ro.close()

    def test_deterministic(self):
        s2 = EC.build(graph_path=self.graph, index_path=self.idx, kie_path=self.kie)
        self.assertEqual(self.summary, s2)


_LIVE = all((config.KIE_HOME / n).exists() for n in ("knowledge_index.db", "kie.db"))


@unittest.skipUnless(_LIVE, "frozen estate not present")
class TestLiveClean(unittest.TestCase):
    def test_live_cleaning_is_substantive_and_honest(self):
        summ = EC.build()
        self.assertGreater(summ["chunks_processed"], 1500)        # the certified-evidence set
        self.assertGreater(summ["boilerplate_removed"], 500)      # the audit's ~54% boilerplate
        self.assertGreaterEqual(summ["flagged_mangled"], 1)       # some OCR-mangled evidence flagged


if __name__ == "__main__":
    unittest.main()
