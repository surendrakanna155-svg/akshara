"""R5-5 [#knowledge-ia-8] — cross-class revisits/deepens edges: recurring concept names linked earlier->later
by class order; undirected co-occurrence when order is unknown (never guessed); frozen index never written.
"""
from __future__ import annotations

import os
import sqlite3
import tempfile
import unittest

from kie import config
from kie.qie.graph import revisits as RV
from kie.qie.graph import store as GST


def _synth_index(tmp):
    path = os.path.join(tmp, "knowledge_index.db")
    c = sqlite3.connect(path)
    c.execute("CREATE TABLE ki_concept (concept_id TEXT PRIMARY KEY, subject TEXT, canonical_name TEXT, "
              "aliases TEXT, taught_at_class TEXT, status TEXT)")
    c.execute("CREATE TABLE ki_meta (key TEXT, value TEXT)")
    c.execute("INSERT INTO ki_meta VALUES ('certified_knowledge_fingerprint_v1.5','beadfeed')")
    c.executemany("INSERT INTO ki_concept VALUES (?,?,?,?,?,?)", [
        ("KC_A6", "Mathematics", "Area of a rectangle", "[]", "6", "certified"),
        ("KC_A8", "Mathematics", "Area of a rectangle", "[]", "8", "certified"),   # 6 -> 8 directed
        ("KC_ONE", "Mathematics", "Fractions", "[]", "7", "certified"),            # single class -> no edge
        ("KC_Fx", "Physics", "Force", "[]", "Foundation", "certified"),            # non-numeric class
        ("KC_Fy", "Physics", "Force", "[]", "Bridge", "certified"),                # -> co-occurrence directed=0
        ("KC_DRAFT", "Mathematics", "Area of a rectangle", "[]", "9", "proposed"), # not certified -> ignored
    ])
    c.commit(); c.close()
    return path


class TestRevisits(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.idx = _synth_index(self.tmp.name)
        self.graph = os.path.join(self.tmp.name, "graph_edges.db")
        self.summary = RV.build(graph_path=self.graph, index_path=self.idx)

    def tearDown(self):
        self.tmp.cleanup()

    def _edges(self):
        conn = GST.open_store(self.graph, writable=False)
        try:
            return [dict(r) for r in conn.execute("SELECT * FROM revisits_edge")]
        finally:
            conn.close()

    def test_directed_edge_earlier_to_later(self):
        e = [x for x in self._edges() if x["concept_norm"] == "area rectangle"]
        self.assertEqual(len(e), 1)
        self.assertEqual((e[0]["earlier_kc"], e[0]["later_kc"]), ("KC_A6", "KC_A8"))
        self.assertEqual(e[0]["directed"], 1)

    def test_non_certified_not_linked(self):
        # KC_DRAFT (proposed, class 9) must not appear as a revisit target
        kcs = {e["earlier_kc"] for e in self._edges()} | {e["later_kc"] for e in self._edges()}
        self.assertNotIn("KC_DRAFT", kcs)

    def test_single_class_concept_has_no_edge(self):
        self.assertNotIn("KC_ONE", {e["earlier_kc"] for e in self._edges()})

    def test_unknown_order_is_co_occurrence_not_guessed(self):
        e = [x for x in self._edges() if x["concept_norm"] == "force"]
        self.assertEqual(len(e), 1)
        self.assertEqual(e[0]["directed"], 0, "unparseable class order must be undirected, not a guessed order")

    def test_summary(self):
        self.assertEqual(self.summary["edges"], 2)             # area(directed) + force(co-occurrence)
        self.assertEqual(self.summary["directed"], 1)
        self.assertEqual(self.summary["co_occurrence"], 1)
        self.assertEqual(self.summary["recurring_concepts"], 2)

    def test_deepens_query(self):
        self.assertEqual(RV.deepens("KC_A8", self.graph), ["KC_A6"])
        self.assertEqual(RV.deepens("KC_A6", self.graph), [])  # Class-6 node deepens nothing

    def test_frozen_index_never_written(self):
        ro = sqlite3.connect(f"file:{self.idx}?mode=ro", uri=True)
        with self.assertRaises(sqlite3.OperationalError):
            ro.execute("UPDATE ki_concept SET status='x'")
        ro.close()

    def test_deterministic(self):
        s2 = RV.build(graph_path=self.graph, index_path=self.idx)
        self.assertEqual(self.summary, s2)


_LIVE = (config.KIE_HOME / "knowledge_index.db").exists()


@unittest.skipUnless(_LIVE, "frozen index not present")
class TestLiveRevisits(unittest.TestCase):
    def test_live_recurrences_linked(self):
        summ = RV.build()
        self.assertGreaterEqual(summ["recurring_concepts"], 10)   # ~18 certified names recur across classes
        self.assertEqual(summ["edges"], summ["directed"] + summ["co_occurrence"])


if __name__ == "__main__":
    unittest.main()
