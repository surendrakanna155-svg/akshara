"""R5-1 [C13] — derived prerequisite edge table: subject-scoped resolution, honest-null on unresolved AND
ambiguous (never guessed), cross-subject-unique resolution, versioned + reproducible, frozen index never written.
"""
from __future__ import annotations

import json
import os
import sqlite3
import tempfile
import unittest

from kie import config
from kie.qie.graph import prereq_edges as PE
from kie.qie.graph import store as GST


def _synth_index(tmp):
    """A minimal frozen-index shape with a resolvable edge, an unresolved edge, an ambiguous edge, and a
    cross-subject-unique edge."""
    path = os.path.join(tmp, "knowledge_index.db")
    c = sqlite3.connect(path)
    c.execute("CREATE TABLE ki_concept (concept_id TEXT PRIMARY KEY, subject TEXT, canonical_name TEXT, "
              "aliases TEXT, prerequisites TEXT, status TEXT)")
    c.execute("CREATE TABLE ki_meta (key TEXT, value TEXT)")
    c.execute("INSERT INTO ki_meta VALUES ('certified_knowledge_fingerprint_v1.5','deadbeef1234')")
    rows = [
        # resolvable: KC_A's prereq "Vectors" -> KC_VEC (unique in Physics)
        ("KC_A", "Physics", "Newtons Laws", "[]", json.dumps(["Vectors", "Ghost Topic"]), "certified"),
        ("KC_VEC", "Physics", "Vectors", "[]", "[]", "certified"),
        # a Mathematics "Vectors" too -> subject scoping still resolves KC_A's Physics "Vectors" uniquely
        ("KC_MVEC", "Mathematics", "Vectors", "[]", "[]", "certified"),
        # ambiguous: two "Cell" concepts in Biology -> KC_BIO's prereq "Cell" is multi-target
        ("KC_CELL1", "Biology", "Cell", "[]", "[]", "certified"),
        ("KC_CELL2", "Biology", "Cell", "[]", "[]", "certified"),
        ("KC_BIO", "Biology", "Tissues", "[]", json.dumps(["Cell"]), "certified"),
        # cross-subject-unique: KC_CHEM (Chemistry) prereq "Chlorophyll" exists only in Biology
        ("KC_CHL", "Biology", "Chlorophyll", "[]", "[]", "certified"),
        ("KC_CHEM", "Chemistry", "Photosynthesis Chem", "[]", json.dumps(["Chlorophyll"]), "certified"),
        # self-loop: a concept that (degenerate index revision) names ITSELF as a prereq -> honest-null
        ("KC_SELF", "Physics", "Self Topic", "[]", json.dumps(["Self Topic"]), "certified"),
        # a non-certified concept must be ignored as a resolution target
        ("KC_DRAFT", "Physics", "Draft Concept", "[]", "[]", "proposed"),
    ]
    c.executemany("INSERT INTO ki_concept VALUES (?,?,?,?,?,?)", rows)
    c.commit()
    c.close()
    return path


class TestPrereqEdges(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.idx = _synth_index(self.tmp.name)
        self.graph = os.path.join(self.tmp.name, "graph_edges.db")
        self.summary = PE.build(graph_path=self.graph, index_path=self.idx)

    def tearDown(self):
        self.tmp.cleanup()

    def _edge(self, concept_id, norm):
        conn = GST.open_store(self.graph, writable=False)
        try:
            return conn.execute("SELECT resolved_concept_id, resolution_method, candidate_count FROM prereq_edge "
                                "WHERE concept_id=? AND prereq_norm=?", (concept_id, norm)).fetchone()
        finally:
            conn.close()

    def test_subject_scoped_resolution(self):
        e = self._edge("KC_A", "vectors")
        self.assertEqual(e["resolved_concept_id"], "KC_VEC")     # Physics "Vectors", not the Maths one
        self.assertEqual(e["resolution_method"], "subject_name")

    def test_unresolved_is_honest_null(self):
        e = self._edge("KC_A", "ghost topic")
        self.assertIsNone(e["resolved_concept_id"])
        self.assertEqual(e["resolution_method"], "unresolved")
        self.assertEqual(e["candidate_count"], 0)

    def test_ambiguous_is_honest_null_never_guessed(self):
        e = self._edge("KC_BIO", "cell")
        self.assertIsNone(e["resolved_concept_id"], "an ambiguous multi-target prereq must never be guessed")
        self.assertEqual(e["resolution_method"], "ambiguous")
        self.assertEqual(e["candidate_count"], 2)

    def test_cross_subject_unique_resolution(self):
        e = self._edge("KC_CHEM", "chlorophyll")
        self.assertEqual(e["resolved_concept_id"], "KC_CHL")
        self.assertEqual(e["resolution_method"], "cross_subject_unique")

    def test_self_loop_is_honest_null(self):
        e = self._edge("KC_SELF", "self topic")
        self.assertIsNone(e["resolved_concept_id"], "a concept must never be its own prerequisite")
        self.assertEqual(e["resolution_method"], "self_loop")

    def test_partition_sums_and_rate(self):
        s = self.summary["stats"]
        self.assertEqual(self.summary["total_edges"],
                         s["resolved"] + s["unresolved"] + s["ambiguous"] + s["self_loop"])
        # resolved = subject_name + cross_subject_unique (2 here: Vectors + Chlorophyll)
        self.assertEqual(s["resolved"], 2)
        self.assertEqual(s["ambiguous"], 1)
        self.assertEqual(s["unresolved"], 1)
        self.assertEqual(s["self_loop"], 1)

    def test_versioned_to_frozen_fingerprint(self):
        self.assertIn("deadbeef1234", self.summary["crosswalk_version"])

    def test_prerequisites_of_drops_honest_null(self):
        self.assertEqual(PE.prerequisites_of("KC_A", graph_path=self.graph), ["KC_VEC"])  # Ghost Topic dropped
        allrefs = PE.prerequisites_of("KC_BIO", graph_path=self.graph, resolved_only=False)
        self.assertIn(None, allrefs)                            # ambiguous kept as null when not resolved_only

    def test_frozen_index_never_written(self):
        ro = sqlite3.connect(f"file:{self.idx}?mode=ro", uri=True)
        with self.assertRaises(sqlite3.OperationalError):
            ro.execute("UPDATE ki_concept SET status='x'")
        ro.close()

    def test_rebuild_is_deterministic(self):
        s2 = PE.build(graph_path=self.graph, index_path=self.idx)
        self.assertEqual(self.summary["stats"], s2["stats"])


_LIVE = (config.KIE_HOME / "knowledge_index.db").exists()


@unittest.skipUnless(_LIVE, "frozen index not present")
class TestLivePrereqEdges(unittest.TestCase):
    def test_live_resolution_is_honest(self):
        PE.build()
        rep = PE.resolution_report()
        self.assertGreater(rep["total_edges"], 1000)
        self.assertGreater(rep["by_method"].get("ambiguous", 0), 0)   # ambiguity SURFACED, not hidden
        self.assertGreater(rep["by_method"].get("unresolved", 0), 0)  # unresolved kept honest-null
        self.assertLess(rep["resolution_rate"], 1.0)                  # rate not inflated to 100%


if __name__ == "__main__":
    unittest.main()
