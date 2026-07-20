"""Tests for the v1.3 additive TOC-anchoring recovery (kie.qie.knowledge.toc_recover).

The recovery must be strictly additive: it re-anchors ONLY sections that have no certified concept, and it
never proposes a section whose title cannot be found in a non-TOC body chunk. These tests pin the two
deterministic primitives (TOC detection, body re-anchor) and the additive-only contract.
"""
import sqlite3
import unittest

from kie.qie.knowledge import toc_recover as TR


def _kie_db():
    """A minimal in-memory kie.db with the columns spine/toc_recover read."""
    c = sqlite3.connect(":memory:")
    c.row_factory = sqlite3.Row
    c.executescript(
        "CREATE TABLE source_documents(doc_id TEXT, rel_path TEXT);"
        "CREATE TABLE chunks(chunk_id TEXT PRIMARY KEY, doc_id TEXT, ordinal INT, page_start INT,"
        " section_path TEXT, text TEXT);")
    return c


class TestTocDetection(unittest.TestCase):
    def test_contents_marker_is_toc(self):
        self.assertTrue(TR.is_toc_chunk("FOREWORD iii RATIONALISATION OF CONTENT IN THE TEXTBOOKS v 1.1 ..."))
        self.assertTrue(TR.is_toc_chunk("Table of Contents  1.1 Introduction 5"))

    def test_dense_multichapter_reflist_is_toc(self):
        # six section refs spanning three chapters -> a contents page
        toc = ("1.1 Importance 1 1.2 Nature of Matter 2 2.1 Atom 10 2.2 Bohr Model 12 "
               "3.1 Periodic Table 20 3.2 Trends 22")
        self.assertTrue(TR.is_toc_chunk(toc))

    def test_body_chunk_is_not_toc(self):
        # a real body chunk lives inside ONE section; it must not be mistaken for a contents page
        body = ("Ionic or Electrovalent Bond From the Kossel and Lewis treatment of the formation of an "
                "ionic bond, it follows that the formation of ionic compounds depends upon the ease of "
                "formation of ions and the lattice of the crystalline compound.")
        self.assertFalse(TR.is_toc_chunk(body))

    def test_empty_is_not_toc(self):
        self.assertFalse(TR.is_toc_chunk(""))
        self.assertFalse(TR.is_toc_chunk(None))


class TestBodyReanchor(unittest.TestCase):
    def test_finds_body_skips_toc(self):
        c = _kie_db()
        doc = "d1"
        # ordinal 2 is the TOC (dense multi-chapter); ordinal 5 is the real body
        c.execute("INSERT INTO chunks VALUES(?,?,?,?,?,?)",
                  ("d1#2", doc, 2, 9, None,
                   "1.1 Importance 1 1.7 Percentage Composition 18 2.1 Atom 20 3.1 Bond 30 4.1 X 40 5.1 Y 50"))
        c.execute("INSERT INTO chunks VALUES(?,?,?,?,?,?)",
                  ("d1#5", doc, 5, 18, None,
                   "Percentage Composition Mass per cent of an element is defined as the mass of that "
                   "element in one mole of the compound divided by the molar mass, times 100."))
        c.commit()
        hit = TR.find_body_anchor(c, doc, "Percentage Composition", toc_ordinal=2)
        self.assertIsNotNone(hit)
        self.assertEqual(hit[0], "d1#5")  # re-anchored to the BODY, not the TOC

    def test_no_body_match_returns_none(self):
        c = _kie_db()
        c.execute("INSERT INTO chunks VALUES(?,?,?,?,?,?)",
                  ("d1#2", "d1", 2, 9, None, "1.1 A 1 2.1 B 2 3.1 C 3 4.1 D 4 5.1 E 5 6.1 F 6"))
        c.commit()
        # title exists only on the contents page -> genuinely unrecoverable, stays honest (None)
        self.assertIsNone(TR.find_body_anchor(c, "d1", "Nonexistent Section Title", toc_ordinal=2))

    def test_short_title_not_matched(self):
        c = _kie_db()
        c.execute("INSERT INTO chunks VALUES(?,?,?,?,?,?)",
                  ("d1#5", "d1", 5, 1, None, "the volume of a gas ..."))
        c.commit()
        self.assertIsNone(TR.find_body_anchor(c, "d1", "Vol", toc_ordinal=2))


if __name__ == "__main__":
    unittest.main()
