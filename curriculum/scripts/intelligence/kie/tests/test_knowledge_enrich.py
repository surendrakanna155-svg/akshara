"""Knowledge Layer Phase 2 — deterministic concept enrichment.

Proves each grounded pass and locks the precision invariant on the ONE field the
engine consumes (definition): a definition is backfilled only when a clean,
complete, factual sentence exists in the corpus — truncated / OCR-merged /
option-list prose is rejected (a wrong model answer is worse than the honest
marking-guideline fallback). Metadata passes are grounded in linked evidence and
never fabricated.
"""
import json
import unittest

from kie import store
from kie.curate import enrich
from kie.qpgen import materialize


def _concept(conn, code, title, subject="Physics", definition="", doc=None):
    ev = {"method": "section_title"}
    if doc:
        ev["doc"] = doc
    conn.execute(
        "INSERT INTO concepts(concept_code, title, definition, subject_domain, status, "
        "evidence, created_at) VALUES (?,?,?,?, 'active', ?, datetime('now'))",
        (code, title, definition, subject, json.dumps(ev)),
    )
    conn.commit()


def _pattern(conn, pid, code, bloom=None, difficulty=None, freq=1):
    conn.execute(
        "INSERT INTO question_patterns(pattern_id, concept_code, bloom, difficulty, frequency) "
        "VALUES (?,?,?,?,?)", (pid, code, bloom, difficulty, freq))
    conn.commit()


def _formula(conn, fid, code, kind="law", expr="E=mc^2"):
    conn.execute(
        "INSERT INTO formulas(formula_id, concept_code, kind, expression) VALUES (?,?,?,?)",
        (fid, code, kind, expr))
    conn.commit()


def _doc(conn, doc_id, class_label=None, exam=None):
    conn.execute(
        "INSERT INTO source_documents(doc_id, corpus, rel_path, class_label, exam, sha256, "
        "integrity_ok, verify_status, certify_status, created_at) "
        "VALUES (?,?,?,?,?,?,1,'verified','certified',datetime('now'))",
        (doc_id, "foundation", "x.pdf", class_label, exam, doc_id + "s"))
    conn.commit()


def _chunk(conn, cid, doc_id, text):
    conn.execute(
        "INSERT INTO chunks(chunk_id, doc_id, ordinal, text) VALUES (?,?,?,?)",
        (cid, doc_id, 0, text))
    conn.execute("INSERT INTO chunks_fts(rowid, text) SELECT rowid, text FROM chunks WHERE chunk_id=?",
                 (cid,))
    conn.commit()


class EnrichMetadataTest(unittest.TestCase):
    def setUp(self):
        self.conn = store.open_store(":memory:")

    def tearDown(self):
        self.conn.close()

    def test_backfills_subject_from_code_prefix(self):
        self.conn.execute(
            "INSERT INTO concepts(concept_code, title, subject_domain, status, created_at) "
            "VALUES ('CHE_MOLE','Mole concept', NULL, 'active', datetime('now'))")
        self.conn.commit()
        enrich.run(self.conn)
        subj = self.conn.execute(
            "SELECT subject_domain FROM concepts WHERE concept_code='CHE_MOLE'").fetchone()["subject_domain"]
        self.assertEqual(subj, "Chemistry")

    def test_bloom_and_difficulty_from_linked_patterns(self):
        _concept(self.conn, "PHY_FORCE", "Force")
        _pattern(self.conn, "P1", "PHY_FORCE", bloom="apply", difficulty="hard")
        _pattern(self.conn, "P2", "PHY_FORCE", bloom="remember", difficulty="easy")
        enrich.run(self.conn)
        r = self.conn.execute(
            "SELECT bloom_levels, difficulty_min, difficulty_max FROM concepts "
            "WHERE concept_code='PHY_FORCE'").fetchone()
        # blooms sorted by canonical taxonomy order
        self.assertEqual(json.loads(r["bloom_levels"]), ["remember", "apply"])
        self.assertEqual(r["difficulty_min"], "easy")
        self.assertEqual(r["difficulty_max"], "hard")

    def test_grade_band_from_evidencing_doc(self):
        _doc(self.conn, "d_ncert11", class_label="Class 11")
        _doc(self.conn, "d_neet", exam="NEET")
        _concept(self.conn, "PHY_A", "Alpha", doc="d_ncert11")
        _concept(self.conn, "PHY_B", "Beta", doc="d_neet")
        enrich.run(self.conn)
        a = self.conn.execute("SELECT typical_grade_low, typical_grade_high FROM concepts WHERE concept_code='PHY_A'").fetchone()
        b = self.conn.execute("SELECT typical_grade_low, typical_grade_high FROM concepts WHERE concept_code='PHY_B'").fetchone()
        self.assertEqual((a["typical_grade_low"], a["typical_grade_high"]), (11, 11))
        self.assertEqual((b["typical_grade_low"], b["typical_grade_high"]), (11, 12))

    def test_reference_facts_from_formulas(self):
        _concept(self.conn, "PHY_NEWTON", "Newton's second law")
        _formula(self.conn, "F1", "PHY_NEWTON", kind="law", expr="F = ma")
        enrich.run(self.conn)
        rf = json.loads(self.conn.execute(
            "SELECT reference_facts FROM concepts WHERE concept_code='PHY_NEWTON'").fetchone()["reference_facts"])
        self.assertEqual(rf, [{"kind": "law", "expression": "F = ma"}])

    def test_misconceptions_from_confused_with_edges(self):
        _concept(self.conn, "PHY_SPEED", "Speed")
        _concept(self.conn, "PHY_VELOCITY", "Velocity")
        self.conn.execute(
            "INSERT INTO concept_edges(from_concept, to_concept, relationship_type, strength) "
            "VALUES ('PHY_SPEED','PHY_VELOCITY','confused_with',1.0)")
        self.conn.commit()
        enrich.run(self.conn)
        misc = json.loads(self.conn.execute(
            "SELECT common_misconceptions FROM concepts WHERE concept_code='PHY_SPEED'").fetchone()["common_misconceptions"])
        self.assertIn("Velocity", misc)


class DefinitionMiningTest(unittest.TestCase):
    def setUp(self):
        self.conn = store.open_store(":memory:")

    def tearDown(self):
        self.conn.close()

    def test_backfills_clean_definition_from_corpus(self):
        _doc(self.conn, "d1", class_label="Class 11")
        _concept(self.conn, "PHY_PHOTO", "Photosynthesis", subject="Biology", doc="d1")
        _chunk(self.conn, "c1", "d1",
               "Photosynthesis is the process of converting light energy into chemical "
               "energy stored in glucose by green plants.")
        enrich.run(self.conn)
        d = self.conn.execute(
            "SELECT definition FROM concepts WHERE concept_code='PHY_PHOTO'").fetchone()["definition"]
        self.assertTrue(materialize.usable_definition(d))
        self.assertIn("process of converting light energy", d)

    def test_rejects_truncated_or_optionlist_prose(self):
        _doc(self.conn, "d1")
        _concept(self.conn, "PHY_MOM", "Momentum", doc="d1")
        _chunk(self.conn, "c1", "d1", "Momentum is Jy, then: (1) In x An (3) An oc J2 (2) An i.")
        _concept(self.conn, "PHY_BMR", "Basal metabolic rate", doc="d1")
        _chunk(self.conn, "c2", "d1", "Basal metabolic rate is defined as the energy.")  # truncated
        enrich.run(self.conn)
        for code in ("PHY_MOM", "PHY_BMR"):
            d = self.conn.execute(
                "SELECT definition FROM concepts WHERE concept_code=?", (code,)).fetchone()["definition"]
            self.assertFalse(materialize.usable_definition(d or ""),
                             f"{code} should NOT have gained a usable definition")

    def test_rejects_relative_clause_fragment(self):
        _doc(self.conn, "d1")
        _concept(self.conn, "PHY_RAD", "Radioactivity", doc="d1")
        _chunk(self.conn, "c1", "d1",
               "Radioactivity is the phenomenon in which nuclei of a given species.")
        enrich.run(self.conn)
        d = self.conn.execute(
            "SELECT definition FROM concepts WHERE concept_code='PHY_RAD'").fetchone()["definition"]
        self.assertFalse(materialize.usable_definition(d or ""))

    def test_does_not_overwrite_existing_usable_definition(self):
        _doc(self.conn, "d1")
        _concept(self.conn, "PHY_V", "Velocity", definition="Velocity is the rate of change of displacement with time.", doc="d1")
        _chunk(self.conn, "c1", "d1", "Velocity is defined as the ratio of something else entirely wrong here.")
        enrich.run(self.conn)
        d = self.conn.execute(
            "SELECT definition FROM concepts WHERE concept_code='PHY_V'").fetchone()["definition"]
        self.assertEqual(d, "Velocity is the rate of change of displacement with time.")

    def test_demotes_garbled_definition_to_safe_fallback(self):
        _doc(self.conn, "d1")
        _concept(self.conn, "BIO_PRO", "Probiotics",
                 definition="Probiotics are livemicroorganisms including Lactobacillusspecies present in food.",
                 doc="d1")
        enrich.run(self.conn)
        d = self.conn.execute(
            "SELECT definition FROM concepts WHERE concept_code='BIO_PRO'").fetchone()["definition"]
        self.assertFalse(materialize.usable_definition(d or ""))  # garbled def removed → safe fallback

    def test_keeps_clean_existing_definition(self):
        _doc(self.conn, "d1")
        _concept(self.conn, "PHY_PWR", "Power",
                 definition="Power is the rate at which work is done.", doc="d1")
        enrich.run(self.conn)
        d = self.conn.execute(
            "SELECT definition FROM concepts WHERE concept_code='PHY_PWR'").fetchone()["definition"]
        self.assertEqual(d, "Power is the rate at which work is done.")

    def test_looks_merged_precision(self):
        # real long science terms are never flagged; OCR merges are
        for w in ("electromagnetic", "characteristics", "photosynthesis", "office", "often"):
            self.assertFalse(enrich._looks_merged(w), w)
        for w in ("ofreproduction", "speciestransformby"):
            self.assertTrue(enrich._looks_merged(w), w)


class EnrichLifecycleTest(unittest.TestCase):
    def setUp(self):
        self.conn = store.open_store(":memory:")

    def tearDown(self):
        self.conn.close()

    def test_idempotent(self):
        _concept(self.conn, "PHY_FORCE", "Force")
        _pattern(self.conn, "P1", "PHY_FORCE", bloom="apply", difficulty="hard")
        enrich.run(self.conn)
        second = enrich.run(self.conn)
        self.assertEqual(second["definitions_mined"], 0)
        # metadata is stable (re-deriving the same values)
        self.assertEqual(second["after"], second["before"])

    def test_dry_run_writes_nothing(self):
        _concept(self.conn, "PHY_FORCE", "Force")
        _pattern(self.conn, "P1", "PHY_FORCE", bloom="apply", difficulty="hard")
        summary = enrich.run(self.conn, dry_run=True)
        self.assertTrue(summary["dry_run"])
        bloom = self.conn.execute(
            "SELECT bloom_levels FROM concepts WHERE concept_code='PHY_FORCE'").fetchone()["bloom_levels"]
        self.assertIn(bloom, (None, ""))


if __name__ == "__main__":
    unittest.main()
