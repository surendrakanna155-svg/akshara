"""Knowledge Layer Phase 3 — KIE quality (extraction, relationships, graph, taxonomy, evidence).

Locks: residual evidence-bearing junk is rejected; fuzzy duplicates merge with evidence
re-pointed; the rebuilt graph never references a non-active concept; the richer taxonomy is a
strict superset of the engine's; evidence provenance is counts-only (copyright-safe).
"""
import json
import unittest

from kie import store
from kie.curate import quality, taxonomy
from kie.qpgen import chapters as engine_chapters


def _concept(conn, code, title, subject="Physics", definition="", status="active"):
    conn.execute(
        "INSERT INTO concepts(concept_code, title, definition, subject_domain, status, evidence, created_at) "
        "VALUES (?,?,?,?,?,?,datetime('now'))",
        (code, title, definition, subject, status, json.dumps({"method": "section_title"})))
    conn.commit()


def _pattern(conn, pid, code, freq=5):
    conn.execute("INSERT INTO question_patterns(pattern_id, concept_code, frequency) VALUES (?,?,?)",
                 (pid, code, freq))
    conn.commit()


def _chunk(conn, cid, text):
    conn.execute(
        "INSERT OR IGNORE INTO source_documents(doc_id, corpus, rel_path, sha256, integrity_ok, "
        "verify_status, certify_status, created_at) "
        "VALUES ('d','foundation','x.pdf','ds',1,'verified','certified',datetime('now'))")
    conn.execute("INSERT INTO chunks(chunk_id, doc_id, ordinal, text) VALUES (?,?,?,?)",
                 (cid, "d", 0, text))
    conn.execute("INSERT INTO chunks_fts(rowid, text) SELECT rowid, text FROM chunks WHERE chunk_id=?", (cid,))
    conn.commit()


class ExtendRejectionTest(unittest.TestCase):
    def setUp(self):
        self.conn = store.open_store(":memory:")

    def tearDown(self):
        self.conn.close()

    def test_rejects_evidence_bearing_boilerplate_and_fragments(self):
        _concept(self.conn, "PHY_TBC", "Test Booklet Code")
        _pattern(self.conn, "p1", "PHY_TBC", freq=77)
        _concept(self.conn, "PHY_MEM", "Members")
        _concept(self.conn, "PHY_FRAG1", "and Life")
        _concept(self.conn, "PHY_FRAG2", "IN TWO Variables")
        _concept(self.conn, "PHY_FRAG3", "To check the rule")
        _concept(self.conn, "PHY_REAL", "The momentum of an object")   # capital 'The' = real
        _concept(self.conn, "PHY_REAL2", "Force")
        quality.run(self.conn)
        st = {r["concept_code"]: r["status"]
              for r in self.conn.execute("SELECT concept_code, status FROM concepts")}
        for junk in ("PHY_TBC", "PHY_MEM", "PHY_FRAG1", "PHY_FRAG2", "PHY_FRAG3"):
            self.assertEqual(st[junk], "rejected", junk)
        self.assertEqual(st["PHY_REAL"], "active")
        self.assertEqual(st["PHY_REAL2"], "active")

    def test_leading_lowercase_article_is_fragment_but_capital_is_kept(self):
        self.assertTrue(quality._is_fragment("the Atom"))          # lowercase leading article
        self.assertFalse(quality._is_fragment("The momentum of an object"))  # capital = real

    def test_leading_finite_verb_is_fragment_but_noun_homographs_kept(self):
        self.assertTrue(quality._is_fragment("Follows Zaitsev rule"))   # subject-less clause
        self.assertTrue(quality._is_fragment("Occurs at the anode"))
        # "States"/"Uses"/"Find" are nouns/other here — must NOT be treated as fragments
        self.assertFalse(quality._is_fragment("States of Matter"))
        self.assertFalse(quality._is_fragment("Uses of Concave Mirror"))
        self.assertFalse(quality._is_fragment("Find the Unknown"))


class FuzzyMergeTest(unittest.TestCase):
    def setUp(self):
        self.conn = store.open_store(":memory:")

    def tearDown(self):
        self.conn.close()

    def test_merges_case_and_wordorder_variants(self):
        _concept(self.conn, "PHY_HUY1", "Huygens principle")
        _concept(self.conn, "PHY_HUY2", "Huygens Principle")           # case variant
        _pattern(self.conn, "p1", "PHY_HUY2", freq=9)
        quality.run(self.conn)
        st = {r["concept_code"]: (r["status"], r["merged_into"])
              for r in self.conn.execute("SELECT concept_code, status, merged_into FROM concepts")}
        actives = [c for c, (s, _) in st.items() if s == "active"]
        self.assertEqual(len(actives), 1)                              # collapsed to one
        loser = "PHY_HUY1" if actives == ["PHY_HUY2"] else "PHY_HUY2"
        self.assertEqual(st[loser][0], "merged")

    def test_distinct_concepts_not_merged(self):
        _concept(self.conn, "PHY_N1", "Newton's first law")
        _concept(self.conn, "PHY_N2", "Newton's second law")
        quality.run(self.conn)
        active = self.conn.execute("SELECT COUNT(*) n FROM concepts WHERE status='active'").fetchone()["n"]
        self.assertEqual(active, 2)


class ReassignSubjectTest(unittest.TestCase):
    def setUp(self):
        self.conn = store.open_store(":memory:")

    def tearDown(self):
        self.conn.close()

    def test_moves_unambiguous_physics_law_out_of_wrong_subject(self):
        _concept(self.conn, "CHE_OHM", "Ohm's law", subject="Chemistry")
        _concept(self.conn, "BIO_NEWTON2", "Newton's second law", subject="Biology")
        quality.run(self.conn)
        for code in ("CHE_OHM", "BIO_NEWTON2"):
            subj = self.conn.execute(
                "SELECT subject_domain FROM concepts WHERE concept_code=?", (code,)).fetchone()["subject_domain"]
            self.assertEqual(subj, "Physics", code)

    def test_ambiguous_law_names_are_left_alone(self):
        # Faraday's law of electrolysis is legitimately Chemistry — must NOT be moved
        _concept(self.conn, "CHE_FARADAY", "Faraday's law of electrolysis", subject="Chemistry")
        # a bare surname without 'law' is never moved (the biologist Hooke)
        _concept(self.conn, "BIO_HOOKE", "Hooke and the cell", subject="Biology")
        quality.run(self.conn)
        self.assertEqual(self.conn.execute(
            "SELECT subject_domain FROM concepts WHERE concept_code='CHE_FARADAY'").fetchone()["subject_domain"], "Chemistry")
        self.assertEqual(self.conn.execute(
            "SELECT subject_domain FROM concepts WHERE concept_code='BIO_HOOKE'").fetchone()["subject_domain"], "Biology")


class GraphRebuildTest(unittest.TestCase):
    def setUp(self):
        self.conn = store.open_store(":memory:")

    def tearDown(self):
        self.conn.close()

    def test_rebuilt_graph_has_no_edge_to_noise(self):
        _concept(self.conn, "PHY_FORCE", "Force applied")
        _concept(self.conn, "PHY_MASS", "Inertial mass")
        _concept(self.conn, "PHY_JUNK", "Members")           # will be rejected
        # co-occur in >= MIN_COOCCUR chunks so a 'related' edge forms among the real pair
        _chunk(self.conn, "c1", "Force applied changes the Inertial mass response of the body.")
        _chunk(self.conn, "c2", "When Force applied is large the Inertial mass matters greatly.")
        quality.run(self.conn)
        edges = self.conn.execute("SELECT from_concept, to_concept FROM concept_edges").fetchall()
        codes = {c for e in edges for c in (e["from_concept"], e["to_concept"])}
        self.assertNotIn("PHY_JUNK", codes)                  # no edge touches rejected concept
        noise = self.conn.execute(
            "SELECT COUNT(*) n FROM concept_edges e WHERE e.from_concept NOT IN "
            "(SELECT concept_code FROM concepts WHERE status='active') OR e.to_concept NOT IN "
            "(SELECT concept_code FROM concepts WHERE status='active')").fetchone()["n"]
        self.assertEqual(noise, 0)


class TaxonomyAndEvidenceTest(unittest.TestCase):
    def setUp(self):
        self.conn = store.open_store(":memory:")

    def tearDown(self):
        self.conn.close()

    def test_taxonomy_is_superset_of_engine(self):
        # engine mapping preserved exactly
        self.assertEqual(taxonomy.resolve_chapter("Physics", "Newton's Laws of Motion"),
                         engine_chapters.resolve_chapter("Physics", "Newton's Laws of Motion"))
        self.assertEqual(taxonomy.resolve_chapter("Biology", "Characteristics"), "General Biology")
        # rescued from General by richer keywords
        self.assertEqual(taxonomy.resolve_chapter("Physics", "Boyle's law"), "Thermodynamics")
        self.assertEqual(taxonomy.resolve_chapter("Chemistry", "Markovnikov rule"), "Organic Chemistry")

    def test_richer_chapter_written_to_board_mappings(self):
        _concept(self.conn, "PHY_BOYLE", "Boyle's law")
        quality.run(self.conn)
        chap = self.conn.execute(
            "SELECT chapter FROM concept_board_mappings WHERE concept_code='PHY_BOYLE'").fetchone()["chapter"]
        self.assertEqual(chap, "Thermodynamics")

    def test_evidence_provenance_is_counts_only(self):
        _concept(self.conn, "PHY_FORCE", "Force")
        _pattern(self.conn, "p1", "PHY_FORCE", freq=5)
        quality.run(self.conn)
        ev = json.loads(self.conn.execute(
            "SELECT evidence FROM concepts WHERE concept_code='PHY_FORCE'").fetchone()["evidence"])
        prov = ev["provenance"]
        self.assertEqual(prov["pattern_frequency"], 5)
        self.assertEqual(set(prov), {"pattern_rows", "pattern_frequency", "formula_count", "chunk_mentions"})
        # copyright-safe: only integer counts, never text
        self.assertTrue(all(isinstance(v, int) for v in prov.values()))


class QualityLifecycleTest(unittest.TestCase):
    def setUp(self):
        self.conn = store.open_store(":memory:")

    def tearDown(self):
        self.conn.close()

    def test_idempotent(self):
        _concept(self.conn, "PHY_FORCE", "Force")
        _pattern(self.conn, "p1", "PHY_FORCE", freq=5)
        _concept(self.conn, "PHY_MEM", "Members")
        quality.run(self.conn)
        second = quality.run(self.conn)
        self.assertEqual(second["rejected"], 0)
        self.assertEqual(second["concepts_merged"], 0)

    def test_dry_run_writes_nothing(self):
        _concept(self.conn, "PHY_MEM", "Members")
        summary = quality.run(self.conn, dry_run=True)
        self.assertTrue(summary["dry_run"])
        self.assertEqual(summary["rejected"], 1)
        st = self.conn.execute("SELECT status FROM concepts WHERE concept_code='PHY_MEM'").fetchone()["status"]
        self.assertEqual(st, "active")


if __name__ == "__main__":
    unittest.main()
