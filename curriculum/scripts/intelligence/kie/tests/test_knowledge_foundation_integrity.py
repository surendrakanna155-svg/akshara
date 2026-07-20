"""PERMANENT Knowledge Foundation Integrity Invariants (certification regression suite).

Encodes the deterministic invariants proven by the 6-agent Knowledge Foundation Certification Audit
(2026-07-20). Every invariant must hold on the frozen v1.4 foundation and on any future rebuild/version:
structural hierarchy, class/grade, subject/discipline, curriculum boundary, provenance, immutability, and
exam/board isolation. Each SQL invariant MUST return 0 rows; JSON + runtime invariants assert directly.

These run against the local frozen index (`knowledge_index.db`, gitignored) and skip when it is absent.
"""
from __future__ import annotations

import json
import os
import shutil
import sqlite3
import tempfile
import unittest

from kie import config

_IDX = config.KIE_HOME / "knowledge_index.db"
_QDI = config.KIE_HOME / "qdi.db"

VALID_SUBJECTS = ("Science", "Physics", "Chemistry", "Biology", "Mathematics")
VALID_DISCIPLINES = ("Physics", "Chemistry", "Biology", "Mathematics", "Interdisciplinary")

# (name, SQL that MUST return 0 rows). Certified scope only.
_ZERO_ROW_INVARIANTS = [
    # ── hierarchy tree ──────────────────────────────────────────────────────────────────────────────
    ("H1_class_in_range",
     "SELECT concept_id FROM ki_concept WHERE status='certified' "
     "AND (taught_at_class IS NULL OR taught_at_class NOT BETWEEN 6 AND 12)"),
    ("H2_chapter_fk_resolves",
     "SELECT c.concept_id FROM ki_concept c WHERE c.status='certified' "
     "AND NOT EXISTS (SELECT 1 FROM ki_chapter ch WHERE ch.chapter_id=c.chapter_id)"),
    ("H3_chapter_accepted",
     "SELECT c.concept_id FROM ki_concept c JOIN ki_chapter ch ON ch.chapter_id=c.chapter_id "
     "WHERE c.status='certified' AND ch.status<>'accepted'"),
    ("H4_concept_subject_eq_chapter",
     "SELECT c.concept_id FROM ki_concept c JOIN ki_chapter ch ON ch.chapter_id=c.chapter_id "
     "WHERE c.status='certified' AND c.subject<>ch.subject"),
    ("H5_concept_class_eq_chapter",
     "SELECT c.concept_id FROM ki_concept c JOIN ki_chapter ch ON ch.chapter_id=c.chapter_id "
     "WHERE c.status='certified' AND c.taught_at_class<>ch.taught_at_class"),
    ("H6_chapter_one_subject_class",
     "SELECT chapter_id FROM ki_chapter GROUP BY chapter_id "
     "HAVING COUNT(DISTINCT subject||'|'||taught_at_class)>1"),
    ("H7_no_concept_leaked_across_chapters",
     "SELECT subject FROM ki_concept WHERE status='certified' "
     "GROUP BY subject, taught_at_class, lower(canonical_name) HAVING COUNT(DISTINCT chapter_id)>1"),
    ("H8_section_heading_present",
     "SELECT concept_id FROM ki_concept WHERE status='certified' "
     "AND (section_heading IS NULL OR TRIM(section_heading)='')"),
    # ── subject / discipline ────────────────────────────────────────────────────────────────────────
    ("S1_valid_subject_and_discipline",
     "SELECT concept_id FROM ki_concept WHERE status='certified' AND ("
     "subject IS NULL OR subject NOT IN ('Science','Physics','Chemistry','Biology','Mathematics') "
     "OR academic_discipline IS NULL OR academic_discipline NOT IN "
     "('Physics','Chemistry','Biology','Mathematics','Interdisciplinary'))"),
    ("S2_split_subject_discipline_lock",
     "SELECT concept_id FROM ki_concept WHERE status='certified' "
     "AND subject<>'Science' AND subject<>academic_discipline"),
    ("S3_interdisciplinary_only_in_science",
     "SELECT concept_id FROM ki_concept WHERE status='certified' "
     "AND academic_discipline='Interdisciplinary' AND subject<>'Science'"),
    ("S4_subject_class_partition",
     "SELECT concept_id FROM ki_concept WHERE status='certified' AND ("
     "(subject='Science' AND taught_at_class NOT BETWEEN 6 AND 10) OR "
     "(subject IN ('Physics','Chemistry','Biology') AND taught_at_class NOT BETWEEN 11 AND 12) OR "
     "(subject='Mathematics' AND taught_at_class NOT BETWEEN 6 AND 12))"),
    # ── provenance ──────────────────────────────────────────────────────────────────────────────────
    ("P1_evidence_present",
     "SELECT concept_id FROM ki_concept WHERE status='certified' "
     "AND (evidence_chunks IS NULL OR evidence_chunks IN ('','[]'))"),
    ("P2_engineer_model_present",
     "SELECT concept_id FROM ki_concept WHERE status='certified' "
     "AND (engineer_model IS NULL OR TRIM(engineer_model)='')"),
    ("P3_independent_audit_accept",
     "SELECT concept_id FROM ki_concept WHERE status='certified' "
     "AND (audit_verdict<>'accept' OR discipline_basis IS NULL OR TRIM(discipline_basis)='')"),
    ("P4_ncert_only_source",
     "SELECT s.doc_id FROM ki_source s WHERE s.rel_path NOT LIKE 'NCERT/%'"),
    ("P5_lineage_resolves_to_ncert",
     "SELECT c.concept_id FROM ki_concept c JOIN ki_chapter ch ON ch.chapter_id=c.chapter_id "
     "LEFT JOIN ki_source s ON s.doc_id=ch.doc_id "
     "WHERE c.status='certified' AND (s.doc_id IS NULL OR s.rel_path NOT LIKE 'NCERT/%')"),
]


@unittest.skipUnless(_IDX.exists(), "frozen knowledge_index.db not present (gitignored / local only)")
class FoundationInvariants(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.c = sqlite3.connect(f"file:{_IDX}?mode=ro", uri=True)
        cls.c.row_factory = sqlite3.Row

    @classmethod
    def tearDownClass(cls):
        cls.c.close()

    def test_zero_row_invariants(self):
        for name, sql in _ZERO_ROW_INVARIANTS:
            rows = self.c.execute(sql).fetchall()
            self.assertEqual(rows, [], f"INVARIANT {name} violated: {len(rows)} row(s), e.g. {rows[:3]}")

    def test_every_grade_6_12_is_populated(self):
        present = {r[0] for r in self.c.execute(
            "SELECT DISTINCT taught_at_class FROM ki_concept WHERE status='certified'")}
        self.assertTrue(set(range(6, 13)).issubset(present), f"missing grades: {set(range(6,13)) - present}")

    def test_json_columns_are_well_formed(self):
        # sub_concepts / prerequisites are JSON string-lists; boundary is a dict of two lists
        for r in self.c.execute("SELECT concept_id, sub_concepts, prerequisites, boundary "
                                "FROM ki_concept WHERE status='certified'"):
            for col in ("sub_concepts", "prerequisites"):
                v = json.loads(r[col] or "[]")
                self.assertIsInstance(v, list, f"{r['concept_id']} {col} not a list")
                self.assertTrue(all(isinstance(x, str) for x in v), f"{r['concept_id']} {col} non-string element")
            b = json.loads(r["boundary"] or "{}")
            self.assertIsInstance(b, dict, f"{r['concept_id']} boundary not a dict")
            for k in ("in_scope", "out_of_scope"):
                self.assertIsInstance(b.get(k, []), list, f"{r['concept_id']} boundary.{k} not a list")

    def test_immutability_metadata_matches_live_count(self):
        meta = {r[0]: r[1] for r in self.c.execute("SELECT key, value FROM ki_meta")}
        self.assertEqual(meta.get("immutable"), "true")
        self.assertTrue(meta.get("frozen_version"))
        live = self.c.execute("SELECT COUNT(*) FROM ki_concept WHERE status='certified'").fetchone()[0]
        self.assertEqual(int(meta.get("certified_count_at_freeze")), live,
                         "frozen certified count no longer matches the live certified count")


@unittest.skipUnless(_IDX.exists(), "frozen knowledge_index.db not present (gitignored / local only)")
class ExamAndPatternBoundary(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        from kie.qie.knowledge import examdna as ED
        cls.tmp = tempfile.mkdtemp()
        cls.edb = os.path.join(cls.tmp, "examdna.db")
        idx, out = ED.open_frozen_index(), ED.open_examdna(cls.edb)
        try:
            ED.build(idx, out)
        finally:
            idx.close()
            out.close()

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.tmp, ignore_errors=True)

    def test_exam_subject_isolation(self):
        from kie.qie.knowledge import examdna as ED
        from kie.qie.knowledge import run_planner as R
        for exam in ("NEET", "JEE_MAIN", "JEE_ADVANCED"):
            out = R.plan_blueprints(exam, 240, examdna_path=self.edb)
            subs = {b["subject"] for b in out["issued"]}
            self.assertEqual(subs, set(ED.EXAM_SUBJECTS[exam]), f"{exam} subject set drifted: {subs}")
        # the hard cross-exam guarantees
        neet = {b["subject"] for b in R.plan_blueprints("NEET", 240, examdna_path=self.edb)["issued"]}
        self.assertNotIn("Mathematics", neet, "NEET must contain no Mathematics")
        jee = {b["subject"] for b in R.plan_blueprints("JEE_MAIN", 240, examdna_path=self.edb)["issued"]}
        self.assertNotIn("Biology", jee, "JEE must contain no Biology")

    def test_no_cross_exam_pattern_attachment(self):
        # every attached design pattern must be legal for that exam profile (planner reads exam-scoped)
        from kie.qie.knowledge import run_planner as R
        for exam in ("NEET", "JEE_MAIN", "JEE_ADVANCED"):
            legal = {p["pattern_id"] for p in R._load_certified_patterns(exam)}
            out = R.plan_blueprints(exam, 300, examdna_path=self.edb)
            attached = {b["pattern_id"] for b in out["issued"] if b["pattern_id"]}
            self.assertTrue(attached.issubset(legal),
                            f"{exam}: attached patterns not scoped to this exam: {attached - legal}")

    @unittest.skipUnless(_QDI.exists(), "qdi.db not present")
    def test_certified_patterns_have_valid_scope_links(self):
        q = sqlite3.connect(f"file:{_QDI}?mode=ro", uri=True)
        q.row_factory = sqlite3.Row
        try:
            # every certified pattern has a scope link with a valid exam profile
            orphan = q.execute(
                "SELECT p.pattern_id FROM qdi_pattern p WHERE p.status='certified' "
                "AND NOT EXISTS (SELECT 1 FROM qdi_scope_link s WHERE s.pattern_id=p.pattern_id)").fetchall()
            self.assertEqual(orphan, [], f"certified patterns without a scope link: {[r[0] for r in orphan]}")
            bad = q.execute("SELECT pattern_id FROM qdi_scope_link WHERE exam_profile NOT IN "
                            "('SCHOOL','JEE_MAIN','JEE_ADVANCED','NEET')").fetchall()
            self.assertEqual(bad, [], f"scope links with invalid exam_profile: {[r[0] for r in bad]}")
        finally:
            q.close()


if __name__ == "__main__":
    unittest.main()
