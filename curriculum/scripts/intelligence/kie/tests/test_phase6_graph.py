"""Phase-6 concept-graph tests (deterministic edges + DAG validation)."""
import unittest

from kie import phase6_graph as p6, store

CONCEPTS = [
    ("PHY_KINEMATICS", "Kinematics"),
    ("PHY_MOTION", "Motion"),
    ("PHY_DISPLACEMENT", "Displacement"),
    ("PHY_VELOCITY", "Velocity"),
]


def _seed(conn):
    # parent source_documents row first (document_sections/chunks FK to it)
    conn.execute("INSERT INTO source_documents(doc_id,corpus,rel_path,sha256,integrity_ok,parser_class,"
                 "parser_strategy,is_duplicate,verify_status,certify_status,certify_reason,created_at) "
                 "VALUES ('d','foundation','d.pdf','h',1,'x','text_extract',0,'verified','certified','ok','now')")
    for code, title in CONCEPTS:
        conn.execute("INSERT INTO concepts(concept_code,title,subject_domain,created_at) VALUES (?,?,?,'now')",
                     (code, title, "Physics"))
    # section hierarchy → parent_child
    for i, path in enumerate(["Kinematics > Motion", "Kinematics > Displacement"], 1):
        conn.execute("INSERT INTO document_sections(section_id,doc_id,ordinal,level,title,page,path) "
                     "VALUES (?,?,?,?,?,1,?)", (f"d#s{i}", "d", i, 2, path.split(" > ")[1], path))
    # chunks with co-occurring mentions (≥2 for a related edge) + contrast + prereq cue
    texts = [
        "Displacement and Velocity are core to Kinematics and Motion.",
        "In Kinematics, Displacement and Velocity describe Motion.",
        "The difference between Displacement and Velocity is direction, in Motion.",
        "Velocity is based on Displacement over time in Kinematics.",
    ]
    for i, t in enumerate(texts, 1):
        conn.execute("INSERT INTO chunks(chunk_id,doc_id,ordinal,block_type,section_path,text,token_est) "
                     "VALUES (?,?,?,?,?,?,?)", (f"d#{i}", "d", i, "paragraph", "", t, 12))
    conn.commit()


class TestGraphUnits(unittest.TestCase):
    def setUp(self):
        self.conn = store.open_store(":memory:")
        _seed(self.conn)

    def tearDown(self):
        self.conn.close()

    def test_index_and_mentions(self):
        by_title, pattern = p6.concept_index(self.conn)
        found = p6.mentions("Displacement relates to Velocity and Kinematics", by_title, pattern)
        self.assertEqual(found, {"PHY_DISPLACEMENT", "PHY_VELOCITY", "PHY_KINEMATICS"})

    def test_dag_rejects_cycle(self):
        self.assertTrue(p6.add_edge(self.conn, "PHY_MOTION", "PHY_VELOCITY", "prerequisite", 1.0))
        self.assertTrue(p6.add_edge(self.conn, "PHY_VELOCITY", "PHY_DISPLACEMENT", "prerequisite", 1.0))
        # Displacement -> Motion would close a cycle Motion->Velocity->Displacement->Motion
        self.assertFalse(p6.add_edge(self.conn, "PHY_DISPLACEMENT", "PHY_MOTION", "prerequisite", 1.0))

    def test_selfloop_rejected(self):
        self.assertFalse(p6.add_edge(self.conn, "PHY_MOTION", "PHY_MOTION", "related", 1.0))


class TestRun(unittest.TestCase):
    def setUp(self):
        self.conn = store.open_store(":memory:")
        _seed(self.conn)
        self.summary = p6.run(self.conn)

    def tearDown(self):
        self.conn.close()

    def _edges(self, rel):
        return {(r["from_concept"], r["to_concept"]) for r in self.conn.execute(
            "SELECT from_concept, to_concept FROM concept_edges WHERE relationship_type=?", (rel,)).fetchall()}

    def test_parent_child(self):
        pc = self._edges("parent_child")
        self.assertIn(("PHY_KINEMATICS", "PHY_MOTION"), pc)
        self.assertIn(("PHY_KINEMATICS", "PHY_DISPLACEMENT"), pc)

    def test_related_from_cooccurrence(self):
        rel = self._edges("related")
        # Displacement & Velocity co-occur in ≥2 chunks
        self.assertTrue(("PHY_DISPLACEMENT", "PHY_VELOCITY") in rel or ("PHY_VELOCITY", "PHY_DISPLACEMENT") in rel)

    def test_confused_with(self):
        cw = self._edges("confused_with")
        self.assertTrue(("PHY_DISPLACEMENT", "PHY_VELOCITY") in cw or ("PHY_VELOCITY", "PHY_DISPLACEMENT") in cw)

    def test_prerequisite(self):
        pre = self._edges("prerequisite")
        self.assertIn(("PHY_DISPLACEMENT", "PHY_VELOCITY"), pre)  # "Velocity is based on Displacement"

    def test_board_mappings(self):
        n = self.conn.execute("SELECT COUNT(*) n FROM concept_board_mappings WHERE board_code='FOUNDATION'").fetchone()["n"]
        self.assertEqual(n, len(CONCEPTS))

    def test_rerun_is_clean(self):
        s2 = p6.run(self.conn)  # rebuild — no duplicate edges
        self.assertEqual(s2["edges_total"], self.summary["edges_total"])


if __name__ == "__main__":
    unittest.main()
