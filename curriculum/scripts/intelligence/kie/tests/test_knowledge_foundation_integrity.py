"""PERMANENT Knowledge Foundation Integrity Invariants (certification regression suite).

Encodes the deterministic invariants proven by the 6-agent Knowledge Foundation Certification Audit
(2026-07-20). Every invariant must hold on the frozen v1.4 foundation and on any future rebuild/version:
structural hierarchy, class/grade, subject/discipline, curriculum boundary, provenance, immutability, and
exam/board isolation. Each SQL invariant MUST return 0 rows; JSON + runtime invariants assert directly.

These run against the local frozen index (`knowledge_index.db`, gitignored) and skip when it is absent.
"""
from __future__ import annotations

import hashlib
import json
import os
import shutil
import sqlite3
import tempfile
import unittest

from kie import config
from kie.qie.knowledge import engineer as E
from kie.qie.knowledge import schema as SC

_IDX = config.KIE_HOME / "knowledge_index.db"
_QDI = config.KIE_HOME / "qdi.db"
_KIE = config.DB_PATH   # the owned substrate (kie.db); RI-2 / drift diagnostics resolve refs against it


def _has_column(conn, table, column) -> bool:
    return column in {r[1] for r in conn.execute(f"PRAGMA table_info({table})")}


def _gate_over_certified(iconn, kconn):
    """Run the deterministic evidence gate over every certified concept. Column-tolerant: the LIVE frozen
    v1.4 index predates the evidence_sha256 column, so it is only selected when present. Returns
    (passed, dangling, non_substantive) concept counts."""
    have_sha = _has_column(iconn, "ki_concept", "evidence_sha256")
    cols = "concept_id, canonical_name, section_heading, evidence_chunks" + (
        ", evidence_sha256" if have_sha else "")
    passed = dangling = non_sub = 0
    for r in iconn.execute(f"SELECT {cols} FROM ki_concept WHERE status='certified'"):
        ok, _reason = E.evidence_gate(kconn, r)
        if ok:
            passed += 1
            continue
        refs = json.loads(r["evidence_chunks"] or "[]")
        resolves = any(kconn.execute("SELECT 1 FROM chunks WHERE chunk_id=?", (c,)).fetchone() for c in refs)
        if resolves:
            non_sub += 1
        else:
            dangling += 1
    return passed, dangling, non_sub

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

    def test_RI1_certified_content_fingerprint_matches_newest_versioned_key(self):
        """RI-1 (R1-5, C6): recompute the certified-knowledge fingerprint over the live certified rows and
        assert it equals the NEWEST versioned ki_meta key (resolved dynamically from frozen_version — never
        hardcoded, so it keeps holding after a version bump; never the stale UNVERSIONED key). A content
        mutation OR a count-preserving field swap now FAILS — the hole the count-only test could not see.
        On the frozen v1.4 this reproduces e3a146f3…."""
        meta = {r[0]: r[1] for r in self.c.execute("SELECT key, value FROM ki_meta")}
        ver = meta["frozen_version"]
        key = f"certified_knowledge_fingerprint_{ver}"
        self.assertIn(key, meta, f"no versioned fingerprint recorded for {ver}")
        got = SC.certified_content_fingerprint(self.c)
        self.assertEqual(got, meta[key],
                         "certified content fingerprint drifted from the recorded freeze value")


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


def _build_gate_fixture(tmp: str):
    """A minimal, self-contained (index + substrate) fixture the evidence gate PASSES on, plus two known-bad
    concepts it must FAIL. Proves the gate machinery both directions without touching the live estate."""
    kie_path = os.path.join(tmp, "kie_fixture.db")
    idx_path = os.path.join(tmp, "index_fixture.db")
    good = ("Photosynthesis is the biochemical process by which green plants convert light energy into "
            "chemical energy stored as glucose molecules inside chloroplasts.")
    garbage = "Reprint 2026-27\n3answerS"          # boilerplate-only -> fails SUBSTANCE
    good_sha = hashlib.sha256(good.encode()).hexdigest()
    garbage_sha = hashlib.sha256(garbage.encode()).hexdigest()

    k = sqlite3.connect(kie_path)
    k.execute("CREATE TABLE chunks (chunk_id TEXT PRIMARY KEY, doc_id TEXT, ordinal INTEGER, "
              "text TEXT, sha256 TEXT)")
    k.executemany("INSERT INTO chunks (chunk_id, doc_id, ordinal, text, sha256) VALUES (?,?,?,?,?)",
                  [("docX#1", "docX", 1, good, good_sha), ("docX#2", "docX", 2, garbage, garbage_sha)])
    k.commit()
    k.close()

    conn = SC.open_index(idx_path)   # fresh, mutable -> guard passes; migrate adds evidence_sha256
    conn.execute("INSERT INTO ki_source (doc_id, rel_path, subject, taught_at_class, subject_basis, "
                 "created_at) VALUES ('docX','NCERT/x.zip','Science',8,'fixture',?)", (SC.now(),))
    conn.execute("INSERT INTO ki_chapter (chapter_id, subject, taught_at_class, chapter_no, title, doc_id, "
                 "status, created_at) VALUES ('CH_x','Science',8,1,'Life','docX','accepted',?)", (SC.now(),))

    def _concept(cid, name, chunks, shas, status="certified"):
        conn.execute(
            "INSERT INTO ki_concept (concept_id, chapter_id, subject, taught_at_class, canonical_name, "
            "evidence_chunks, evidence_sha256, section_heading, academic_discipline, engineer_model, "
            "audit_verdict, discipline_basis, status, created_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
            (cid, "CH_x", "Science", 8, name, json.dumps(chunks), json.dumps(shas), "1.1 " + name,
             "Biology", "engineer", "accept", "fixture basis", status, SC.now()))

    _concept("KC_good", "Photosynthesis", ["docX#1"], [good_sha])
    _concept("KC_dangling", "Missing", ["docX#404"], [None])       # unresolvable
    _concept("KC_garbage", "Aromaticity", ["docX#2"], [garbage_sha])  # non-substantive
    sub_fp = SC.compute_substrate_fingerprint(k := sqlite3.connect(f"file:{kie_path}?mode=ro", uri=True))
    k.close()
    conn.execute("INSERT OR REPLACE INTO ki_meta (key,value) VALUES ('frozen_version','v-fixture')")
    conn.execute("INSERT OR REPLACE INTO ki_meta (key,value) VALUES (?,?)",
                 ("substrate_fingerprint_v-fixture", sub_fp))
    conn.commit()
    conn.close()
    return idx_path, kie_path


@unittest.skipUnless(_IDX.exists(), "frozen knowledge_index.db not present (gitignored / local only)")
class EvidenceGateAndSubstrate(unittest.TestCase):
    """R1-4 (C3): content-addressed evidence + substrate fingerprint + the deterministic gate."""

    @classmethod
    def setUpClass(cls):
        cls.c = sqlite3.connect(f"file:{_IDX}?mode=ro", uri=True)
        cls.c.row_factory = sqlite3.Row

    @classmethod
    def tearDownClass(cls):
        cls.c.close()

    def test_RI2_gate_passes_on_a_valid_fixture_and_fails_bad_evidence(self):
        """RI-2 in-suite: over a fixture whose evidence resolves + is substantive, the gate reports ZERO
        violations and the recorded substrate fingerprint matches; the two seeded bad concepts (dangling
        ref; boilerplate-only text) are correctly refused. (The live v1.4 legitimately FAILS RI-2 today —
        that drift is asserted read-only below and is fixed only by the v1.5 refreeze.)"""
        tmp = tempfile.mkdtemp()
        try:
            idx_path, kie_path = _build_gate_fixture(tmp)
            iconn = sqlite3.connect(f"file:{idx_path}?mode=ro", uri=True); iconn.row_factory = sqlite3.Row
            kconn = sqlite3.connect(f"file:{kie_path}?mode=ro", uri=True); kconn.row_factory = sqlite3.Row
            try:
                passed, dangling, non_sub = _gate_over_certified(iconn, kconn)
                self.assertEqual((passed, dangling, non_sub), (1, 1, 1),
                                 "fixture gate should pass the 1 good concept and fail the 2 bad ones")
                # both bad concepts refused for the right reason
                good = iconn.execute("SELECT * FROM ki_concept WHERE concept_id='KC_good'").fetchone()
                dang = iconn.execute("SELECT * FROM ki_concept WHERE concept_id='KC_dangling'").fetchone()
                garb = iconn.execute("SELECT * FROM ki_concept WHERE concept_id='KC_garbage'").fetchone()
                self.assertTrue(E.evidence_gate(kconn, good)[0])
                self.assertFalse(E.evidence_gate(kconn, dang)[0])
                self.assertFalse(E.evidence_gate(kconn, garb)[0])
                # substrate fingerprint round-trips (fail-closed refusal machinery, R1-4 (c))
                self.assertEqual(SC.assert_substrate_matches_freeze(iconn, kie_path=kie_path),
                                 SC.compute_substrate_fingerprint(kconn))
            finally:
                iconn.close(); kconn.close()
        finally:
            shutil.rmtree(tmp, ignore_errors=True)

    @unittest.skipUnless(_KIE.exists(), "kie.db substrate not present (gitignored / local only)")
    def test_current_substrate_drift_is_documented_not_hidden(self):
        """Read-only diagnostic (NON-FAILING): document the C3 substrate drift rather than paper over it.
        On the frozen v1.4 the gate must find EXACTLY the known defect set (5 dangling + 9 non-substantive);
        once v1.5 lands and refreezes with the gate applied, both counts must be 0. Either way the suite is
        green — the assertion tracks the recorded reality of whichever version is live."""
        kconn = sqlite3.connect(f"file:{_KIE}?mode=ro", uri=True); kconn.row_factory = sqlite3.Row
        try:
            passed, dangling, non_sub = _gate_over_certified(self.c, kconn)
        finally:
            kconn.close()
        ver = SC.frozen_version(self.c)
        if ver == "v1.4":
            self.assertEqual((dangling, non_sub), (5, 9),
                             "v1.4's documented substrate drift changed unexpectedly (was 5 dangling + 9 "
                             "non-substantive) — investigate before re-freezing")
        else:
            self.assertEqual((dangling, non_sub), (0, 0),
                             f"{ver} was refrozen but still carries dangling/non-substantive evidence — the "
                             f"v1.5 gate did not hold")

    def test_substrate_fingerprint_recorded_matches_live_when_present(self):
        """Once a version records its substrate fingerprint (v1.5+), it MUST match the live kie.db. Skipped
        on v1.4 (no substrate key recorded yet — its absence is itself a refusal at the consumer, RI-4 (c))."""
        meta = {r[0]: r[1] for r in self.c.execute("SELECT key, value FROM ki_meta")}
        key = f"substrate_fingerprint_{meta.get('frozen_version')}"
        if key not in meta:
            self.skipTest("index predates substrate fingerprinting (pre-v1.5) — consumer refuses fail-closed")
        if not _KIE.exists():
            self.skipTest("kie.db substrate not present")
        kconn = sqlite3.connect(f"file:{_KIE}?mode=ro", uri=True)
        try:
            self.assertEqual(SC.compute_substrate_fingerprint(kconn), meta[key], "kie.db drifted since freeze")
        finally:
            kconn.close()


@unittest.skipUnless(_IDX.exists(), "frozen knowledge_index.db not present (gitignored / local only)")
class FreezeEnforcement(unittest.TestCase):
    """RI-10 (R1-5, C6): the freeze is MECHANICAL. RW opens of an immutable index are refused; the RO path
    never writes a byte; a legitimate fresh build is unaffected. All against COPIES — never the live index."""

    def _copy_index(self):
        tmp = tempfile.mkdtemp()
        dst = os.path.join(tmp, "copy.db")
        shutil.copyfile(str(_IDX), dst)
        return tmp, dst

    def test_rw_open_of_frozen_index_is_refused_without_unfreeze(self):
        tmp, dst = self._copy_index()
        try:
            with self.assertRaises(SC.FrozenIndexError):
                SC.open_index(dst)                       # immutable copy -> refused
            conn = SC.open_index(dst, unfreeze=True)      # sanctioned bump path -> allowed
            try:
                self.assertTrue(SC.is_immutable(conn))
            finally:
                conn.close()
            os.environ[SC._UNFREEZE_ENV] = "1"            # env hatch also works
            try:
                conn = SC.open_index(dst)
                conn.close()
            finally:
                os.environ.pop(SC._UNFREEZE_ENV, None)
        finally:
            shutil.rmtree(tmp, ignore_errors=True)

    def test_open_index_ro_does_not_write_a_single_byte(self):
        tmp, dst = self._copy_index()
        try:
            with open(dst, "rb") as fh:
                before = hashlib.sha256(fh.read()).hexdigest()
            conn = E.open_index_ro(dst)
            try:
                conn.execute("SELECT COUNT(*) FROM ki_concept WHERE status='certified'").fetchone()
            finally:
                conn.close()
            with open(dst, "rb") as fh:
                after = hashlib.sha256(fh.read()).hexdigest()
            self.assertEqual(before, after, "open_index_ro mutated the frozen index (schema_migrated_at bump?)")
            self.assertFalse(os.path.exists(dst + "-wal"), "a -wal was created against a read-only open")
        finally:
            shutil.rmtree(tmp, ignore_errors=True)

    def test_fresh_index_rw_open_is_allowed(self):
        # regression: the guard must NOT block a legitimate fresh (non-immutable) build
        conn = SC.open_index(":memory:")
        try:
            self.assertFalse(SC.is_immutable(conn))
            conn.execute("SELECT 1")
        finally:
            conn.close()


if __name__ == "__main__":
    unittest.main()
