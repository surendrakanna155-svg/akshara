"""Knowledge Layer Phase 1 — deterministic concept cleanup.

Proves the four passes on a synthetic KIE and locks the core safety invariants:
  * titles are normalized to the engine's own fixed point (idempotent);
  * a concept the engine can never use is rejected, and it is EXACTLY the set the
    engine's own sanitize.is_clean_concept rejects (zero-regression invariant);
  * OCR-split duplicates merge into one canonical, re-pointing all evidence;
  * canonical chapters are written; a clean concept's code + evidence survive;
  * the whole pass is idempotent (a second run changes nothing).
"""
import json
import unittest

from kie import store
from kie.curate import cleanup
from kie.qpgen import sanitize


# Fixtures commit — cleanup always runs against an already-persisted DB, and its
# dry-run path rolls back, so uncommitted fixtures would be discarded with it.
def _concept(conn, code, title, subject="Physics", definition="", status="active"):
    conn.execute(
        "INSERT INTO concepts(concept_code, title, definition, subject_domain, status, "
        "evidence, created_at) VALUES (?,?,?,?,?,?,datetime('now'))",
        (code, title, definition, subject, status, json.dumps({"method": "section_title"})),
    )
    conn.commit()


def _pattern(conn, pid, code, freq=1):
    conn.execute(
        "INSERT INTO question_patterns(pattern_id, concept_code, frequency) VALUES (?,?,?)",
        (pid, code, freq),
    )
    conn.commit()


def _formula(conn, fid, code):
    conn.execute(
        "INSERT INTO formulas(formula_id, concept_code, kind, expression) VALUES (?,?,?,?)",
        (fid, code, "law", "x"),
    )
    conn.commit()


class KnowledgeCleanupTest(unittest.TestCase):
    def setUp(self):
        self.conn = store.open_store(":memory:")

    def tearDown(self):
        self.conn.close()

    # ── title normalization ────────────────────────────────────────────────────
    def test_titles_are_normalized_and_idempotent(self):
        _concept(self.conn, "PHY_MOTION", "MOTIONThe first law")      # glued caps-run
        _concept(self.conn, "PHY_ACIDS", "ACIDS AND BASES")           # ALL-CAPS heading
        cleanup.run(self.conn)
        rows = {r["concept_code"]: r["title"]
                for r in self.conn.execute("SELECT concept_code, title FROM concepts")}
        # every stored active title is now a fixed point of the engine's normalizer
        for r in self.conn.execute("SELECT title FROM concepts WHERE status='active'"):
            self.assertEqual(sanitize.normalize_concept_title(r["title"]), r["title"])
        self.assertEqual(rows["PHY_ACIDS"], "Acids and Bases")

    # ── noise rejection = engine's own predicate (zero-regression invariant) ────
    def test_rejects_exactly_what_engine_cannot_use(self):
        _concept(self.conn, "PHY_ACK", "ACKNOWLEDGEMENTS")
        _concept(self.conn, "PHY_ACT", "Activity 10.1: Let us explore")
        _concept(self.conn, "PHY_GARBAGE", "ACENTHUSE bqcdfghjk")     # OCR consonant run
        _concept(self.conn, "PHY_REAL", "Newton's second law")
        cleanup.run(self.conn)
        status = {r["concept_code"]: r["status"]
                  for r in self.conn.execute("SELECT concept_code, status FROM concepts")}
        self.assertEqual(status["PHY_REAL"], "active")
        for junk in ("PHY_ACK", "PHY_ACT", "PHY_GARBAGE"):
            self.assertEqual(status[junk], "rejected")
        # the rejected set equals the set the engine's own sanitizer would drop
        for r in self.conn.execute("SELECT title, status FROM concepts"):
            clean = sanitize.is_clean_concept(sanitize.normalize_concept_title(r["title"]))
            self.assertEqual(r["status"] == "active", clean)

    def test_reject_reason_is_recorded(self):
        _concept(self.conn, "PHY_ACK", "Acknowledgements")
        cleanup.run(self.conn)
        ev = json.loads(self.conn.execute(
            "SELECT evidence FROM concepts WHERE concept_code='PHY_ACK'").fetchone()["evidence"])
        self.assertEqual(ev["cleanup"]["action"], "rejected")
        self.assertEqual(ev["cleanup"]["reason"], "boilerplate")

    # ── duplicate merge with evidence re-pointing ───────────────────────────────
    def test_merges_ocr_split_duplicates_and_repoints_evidence(self):
        # two codes, one normalized title; the OCR-split variant carries the evidence
        _concept(self.conn, "PHY_NEWTON_S_SECOND_LAW", "Newton's second law")
        _concept(self.conn, "PHY_NEWTON_SSECOND_LAW", "Newton'ssecond law")
        _formula(self.conn, "F_clean", "PHY_NEWTON_S_SECOND_LAW")
        _pattern(self.conn, "P1", "PHY_NEWTON_SSECOND_LAW", freq=2)
        _pattern(self.conn, "P2", "PHY_NEWTON_SSECOND_LAW", freq=1)
        cleanup.run(self.conn)

        rows = {r["concept_code"]: r["status"]
                for r in self.conn.execute("SELECT concept_code, status FROM concepts")}
        # canonical = strongest evidence (the variant with 3 pattern-freq)
        self.assertEqual(rows["PHY_NEWTON_SSECOND_LAW"], "active")
        self.assertEqual(rows["PHY_NEWTON_S_SECOND_LAW"], "merged")
        merged_into = self.conn.execute(
            "SELECT merged_into FROM concepts WHERE concept_code='PHY_NEWTON_S_SECOND_LAW'"
        ).fetchone()["merged_into"]
        self.assertEqual(merged_into, "PHY_NEWTON_SSECOND_LAW")
        # the loser's formula was re-pointed onto the canonical — evidence not lost
        f = self.conn.execute(
            "SELECT concept_code FROM formulas WHERE formula_id='F_clean'").fetchone()
        self.assertEqual(f["concept_code"], "PHY_NEWTON_SSECOND_LAW")
        # patterns still resolve to the canonical
        pat = self.conn.execute(
            "SELECT COUNT(*) n FROM question_patterns WHERE concept_code='PHY_NEWTON_SSECOND_LAW'"
        ).fetchone()["n"]
        self.assertEqual(pat, 2)

    def test_merge_does_not_touch_distinct_concepts(self):
        _concept(self.conn, "PHY_A", "Ohm's law")
        _concept(self.conn, "PHY_B", "Gauss's law")
        cleanup.run(self.conn)
        active = self.conn.execute(
            "SELECT COUNT(*) n FROM concepts WHERE status='active'").fetchone()["n"]
        self.assertEqual(active, 2)

    # ── chapter mapping ─────────────────────────────────────────────────────────
    def test_maps_canonical_chapter(self):
        _concept(self.conn, "PHY_NEWTON", "Newton's second law")
        _concept(self.conn, "CHE_MOLE", "Mole concept", subject="Chemistry")
        cleanup.run(self.conn)
        chap = {r["concept_code"]: r["chapter"] for r in self.conn.execute(
            "SELECT concept_code, chapter FROM concept_board_mappings WHERE chapter <> ''")}
        self.assertEqual(chap["PHY_NEWTON"], "Mechanics")
        self.assertEqual(chap["CHE_MOLE"], "Physical Chemistry")
        # no lingering blank-chapter row for a mapped concept
        blank = self.conn.execute(
            "SELECT COUNT(*) n FROM concept_board_mappings WHERE concept_code='PHY_NEWTON' AND chapter=''"
        ).fetchone()["n"]
        self.assertEqual(blank, 0)

    def test_maps_chapter_for_null_subject_via_code_prefix(self):
        _concept(self.conn, "BIO_PHOTOSYNTHESIS", "Photosynthesis", subject=None)
        cleanup.run(self.conn)
        chap = self.conn.execute(
            "SELECT chapter FROM concept_board_mappings WHERE concept_code='BIO_PHOTOSYNTHESIS'"
        ).fetchone()["chapter"]
        self.assertEqual(chap, "Plant Physiology")

    # ── idempotency + dry-run ───────────────────────────────────────────────────
    def test_second_run_is_a_noop(self):
        _concept(self.conn, "PHY_MOTION", "MOTIONThe first law")
        _concept(self.conn, "PHY_ACK", "Acknowledgements")
        _concept(self.conn, "PHY_D1", "Newton's third law")
        _concept(self.conn, "PHY_D2", "Newton'sthird law")
        cleanup.run(self.conn)
        second = cleanup.run(self.conn)
        self.assertEqual(second["titles_normalized"], 0)
        self.assertEqual(second["rejected"], 0)
        self.assertEqual(second["concepts_merged"], 0)

    def test_dry_run_writes_nothing(self):
        _concept(self.conn, "PHY_ACK", "Acknowledgements")
        summary = cleanup.run(self.conn, dry_run=True)
        self.assertTrue(summary["dry_run"])
        self.assertEqual(summary["rejected"], 1)
        # nothing persisted
        status = self.conn.execute(
            "SELECT status FROM concepts WHERE concept_code='PHY_ACK'").fetchone()["status"]
        self.assertEqual(status, "active")

    def test_clean_concept_code_and_evidence_preserved(self):
        _concept(self.conn, "PHY_REAL", "Faraday's law",
                 definition="EMF is proportional to rate of change of flux")
        cleanup.run(self.conn)
        row = self.conn.execute(
            "SELECT concept_code, definition FROM concepts WHERE concept_code='PHY_REAL'").fetchone()
        self.assertIsNotNone(row)
        self.assertEqual(row["definition"], "EMF is proportional to rate of change of flux")


if __name__ == "__main__":
    unittest.main()
