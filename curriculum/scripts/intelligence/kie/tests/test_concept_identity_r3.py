"""R3-5 — concept-identity ingest safety + alias/name/prerequisite collision audit.

concept_id = sha(subject|class|canonical_name) EXCLUDES the chapter, so a plain INSERT OR REPLACE could
silently (a) collapse two same-named concepts from different chapters/parallel books, and (b) demote a
certified/quarantined row back to proposed. These tests lock the fix: a concept_id collision is REFUSED +
logged (never silent, never a demotion), a same-name-same-chapter merge is an INTENTIONAL recorded
operation, and the read-only alias audit reports the known name/alias/prereq collisions deterministically.

Fixtures only (in-memory index + a tiny stand-in kie.db) — no live DB, no rebuild, nothing frozen opened RW.
"""
from __future__ import annotations

import json
import sqlite3
import unittest

from kie.qie.knowledge import engineer as E
from kie.qie.knowledge import schema as SC
from kie.qie.knowledge import spine as S
from kie.qie.remediation import alias_audit as AA


def _fresh_index():
    """An in-memory index at current schema. FK off so ki_concept fixtures need no ki_source/ki_chapter."""
    conn = SC.open_index(":memory:")
    conn.execute("PRAGMA foreign_keys = OFF")
    return conn


def _values(concept_id, chapter_id, name, *, subject="Physics", cls=8, status="proposed",
            aliases=None, sub=None, prereqs=None):
    return {
        "concept_id": concept_id, "chapter_id": chapter_id, "subject": subject, "taught_at_class": cls,
        "canonical_name": name, "aliases": json.dumps(aliases or []),
        "sub_concepts": json.dumps(sub or []), "prerequisites": json.dumps(prereqs or []),
        "boundary": json.dumps({}), "evidence_chunks": json.dumps(["CH1"]),
        "evidence_sha256": json.dumps(["sha1"]), "evidence_pages": json.dumps([1]),
        "section_heading": "1.1 X", "extraction_basis": "text", "academic_discipline": subject,
        "discipline_basis": "b", "discipline_confidence": 1.0, "engineer_model": "m",
        "status": status, "created_at": E._now()}


def _status(conn, cid):
    return conn.execute("SELECT status FROM ki_concept WHERE concept_id=?", (cid,)).fetchone()[0]


def _gap_kinds(conn):
    return dict(conn.execute("SELECT kind, COUNT(*) FROM ki_gap GROUP BY kind").fetchall())


class TestIngestConceptSafe(unittest.TestCase):
    def test_fresh_insert(self):
        conn = _fresh_index()
        cid = S.concept_id("Physics", 8, "Refraction")
        self.assertEqual(E.ingest_concept_safe(conn, _values(cid, "CH_A", "Refraction")), "inserted")
        self.assertEqual(conn.execute("SELECT COUNT(*) FROM ki_concept").fetchone()[0], 1)
        self.assertEqual(_gap_kinds(conn), {})

    def test_cross_chapter_collision_is_refused_and_logged_not_collapsed(self):
        conn = _fresh_index()
        cid = S.concept_id("Physics", 8, "Refraction")
        E.ingest_concept_safe(conn, _values(cid, "CH_A", "Refraction"))
        # same id, DIFFERENT chapter -> must refuse and keep the first, not overwrite it
        act = E.ingest_concept_safe(conn, _values(cid, "CH_B", "Refraction"))
        self.assertEqual(act, "refused_cross_chapter")
        self.assertEqual(conn.execute("SELECT COUNT(*) FROM ki_concept").fetchone()[0], 1)
        self.assertEqual(conn.execute("SELECT chapter_id FROM ki_concept WHERE concept_id=?",
                                      (cid,)).fetchone()[0], "CH_A")   # first row untouched
        self.assertEqual(_gap_kinds(conn), {E.GAP_CROSS_CHAPTER: 1})

    def test_certified_row_is_never_demoted(self):
        conn = _fresh_index()
        cid = S.concept_id("Physics", 8, "Refraction")
        E.ingest_concept_safe(conn, _values(cid, "CH_A", "Refraction"))
        conn.execute("UPDATE ki_concept SET status='certified' WHERE concept_id=?", (cid,))
        # re-ingest of stale content (even same chapter) must NOT reset certified -> proposed
        act = E.ingest_concept_safe(conn, _values(cid, "CH_A", "Refraction", aliases=["X"]))
        self.assertEqual(act, "refused_would_demote")
        self.assertEqual(_status(conn, cid), "certified")
        self.assertEqual(_gap_kinds(conn), {E.GAP_WOULD_DEMOTE: 1})

    def test_quarantined_row_is_never_demoted(self):
        conn = _fresh_index()
        cid = S.concept_id("Physics", 8, "Refraction")
        E.ingest_concept_safe(conn, _values(cid, "CH_A", "Refraction"))
        conn.execute("UPDATE ki_concept SET status='quarantined' WHERE concept_id=?", (cid,))
        act = E.ingest_concept_safe(conn, _values(cid, "CH_B", "Refraction"))
        self.assertEqual(act, "refused_would_demote")
        self.assertEqual(_status(conn, cid), "quarantined")

    def test_same_name_same_chapter_is_an_explicit_recorded_merge(self):
        conn = _fresh_index()
        cid = S.concept_id("Physics", 8, "Refraction")
        E.ingest_concept_safe(conn, _values(cid, "CH_A", "Refraction", aliases=["a1"], sub=["s1"]))
        act = E.ingest_concept_safe(conn, _values(cid, "CH_A", "Refraction", aliases=["a2"], sub=["s1", "s2"]))
        self.assertEqual(act, "merged")
        self.assertEqual(conn.execute("SELECT COUNT(*) FROM ki_concept").fetchone()[0], 1)
        row = conn.execute("SELECT aliases, sub_concepts FROM ki_concept WHERE concept_id=?", (cid,)).fetchone()
        self.assertEqual(json.loads(row[0]), ["a1", "a2"])          # aliases unioned, nothing lost
        self.assertEqual(json.loads(row[1]), ["s1", "s2"])          # sub_concepts unioned, de-duplicated
        self.assertEqual(_gap_kinds(conn), {E.GAP_MERGE: 1})        # the merge is recorded, not silent

    def test_distinct_collisions_get_distinct_rows_but_reruns_are_idempotent(self):
        conn = _fresh_index()
        a = S.concept_id("Physics", 8, "Refraction")
        b = S.concept_id("Physics", 8, "Reflection")
        for cid in (a, b):
            E.ingest_concept_safe(conn, _values(cid, "CH_A", "n"))
        # two DISTINCT cross-chapter collisions -> two gap rows
        E.ingest_concept_safe(conn, _values(a, "CH_B", "n"))
        E.ingest_concept_safe(conn, _values(b, "CH_B", "n"))
        self.assertEqual(_gap_kinds(conn).get(E.GAP_CROSS_CHAPTER), 2)
        # re-running the SAME collision is idempotent (event-keyed gap_id) -> still 2, not 4
        E.ingest_concept_safe(conn, _values(a, "CH_B", "n"))
        E.ingest_concept_safe(conn, _values(b, "CH_B", "n"))
        self.assertEqual(_gap_kinds(conn).get(E.GAP_CROSS_CHAPTER), 2)


# ── kie.db stand-in for the end-to-end ingest_engineer path ─────────────────────────────────────────
def _kie_db():
    k = sqlite3.connect(":memory:")
    k.row_factory = sqlite3.Row
    k.execute("CREATE TABLE chunks (chunk_id TEXT PRIMARY KEY, doc_id TEXT, ordinal INTEGER, "
              "sha256 TEXT, text TEXT)")
    for i, cid in enumerate(("D1#0", "D1#1", "D1#5", "D1#6")):
        k.execute("INSERT INTO chunks VALUES (?,?,?,?,?)", (cid, "D1", i, f"sha{i}", "a body of real text"))
    k.commit()
    return k


class TestIngestEngineerEndToEnd(unittest.TestCase):
    def test_same_name_across_two_chapters_refuses_the_second_without_dying_midbatch(self):
        conn = SC.open_index(":memory:")
        k = _kie_db()
        book = {"doc_id": "D1", "rel_path": "x", "book_code": "keph1dd", "subject": "Physics",
                "subject_basis": "the filename code proves it", "is_integrated": False,
                "taught_at_class": 8, "chunks": 10}
        E.save_book(conn, book)   # satisfies the ki_chapter -> ki_source FK
        spine = {
            1: {"raw": ["1.1 Refraction"],
                "topics": {"1.1": {"chunk_id": "D1#0", "page": 1, "title": "Refraction",
                                   "channels": {"text"}}},
                "chunk_ids": ["D1#0", "D1#1"], "pages": [1, 2]},
            2: {"raw": ["2.1 Refraction"],
                "topics": {"2.1": {"chunk_id": "D1#5", "page": 6, "title": "Refraction",
                                   "channels": {"text"}}},
                "chunk_ids": ["D1#5", "D1#6"], "pages": [6, 7]}}
        payload = [
            {"chapter_no": 1, "canonical_title": "Light I",
             "concepts": [{"canonical_name": "Refraction", "section_heading": "1.1 Refraction"}],
             "rejects": []},
            {"chapter_no": 2, "canonical_title": "Light II",
             "concepts": [{"canonical_name": "Refraction", "section_heading": "2.1 Refraction"}],
             "rejects": []}]
        m = E.ingest_engineer(conn, k, payload, book, spine, model="opus-4.8(engineer)")
        self.assertEqual(m["concepts"], 1)                 # only the first chapter's row was stored
        self.assertEqual(m["refused_cross_chapter"], 1)    # the second was refused, not collapsed
        self.assertEqual(m["chapters"], 2)                 # the batch completed — no raise mid-batch
        cid = S.concept_id("Physics", 8, "Refraction")
        self.assertEqual(conn.execute("SELECT COUNT(*) FROM ki_concept").fetchone()[0], 1)
        ch1 = S.chapter_id("Physics", 8, 1, "D1")
        self.assertEqual(conn.execute("SELECT chapter_id FROM ki_concept WHERE concept_id=?",
                                      (cid,)).fetchone()[0], ch1)
        self.assertEqual(conn.execute("SELECT COUNT(*) FROM ki_gap WHERE kind=?",
                                      (E.GAP_CROSS_CHAPTER,)).fetchone()[0], 1)

    def test_collision_free_payload_counts_every_concept_as_before(self):
        """Backward-compat: with no collisions, every concept still lands and m['concepts'] is unchanged."""
        conn = SC.open_index(":memory:")
        k = _kie_db()
        book = {"doc_id": "D1", "rel_path": "x", "book_code": "keph1dd", "subject": "Physics",
                "subject_basis": "the filename code proves it", "is_integrated": False,
                "taught_at_class": 8, "chunks": 10}
        E.save_book(conn, book)
        spine = {1: {"raw": ["1.1 Refraction"],
                     "topics": {"1.1": {"chunk_id": "D1#0", "page": 1, "title": "Refraction",
                                        "channels": {"text"}}},
                     "chunk_ids": ["D1#0", "D1#1"], "pages": [1, 2]}}
        payload = [{"chapter_no": 1, "canonical_title": "Light I",
                    "concepts": [{"canonical_name": "Refraction", "section_heading": "1.1 Refraction"},
                                 {"canonical_name": "Dispersion", "section_heading": "1.1 Refraction"}],
                    "rejects": []}]
        m = E.ingest_engineer(conn, k, payload, book, spine, model="m")
        self.assertEqual(m["concepts"], 2)
        self.assertEqual(m["refused_cross_chapter"], 0)
        self.assertEqual(m["concepts_merged"], 0)


# ── alias / name / prerequisite audit ───────────────────────────────────────────────────────────────
def _ins(conn, subject, cls, name, aliases=None, prereqs=None, status="certified"):
    cid = S.concept_id(subject, cls, name)
    conn.execute(
        "INSERT INTO ki_concept (concept_id, chapter_id, subject, taught_at_class, canonical_name, "
        "aliases, prerequisites, evidence_chunks, engineer_model, status, created_at) "
        "VALUES (?,?,?,?,?,?,?,?,?,?,?)",
        (cid, "CH", subject, cls, name, json.dumps(aliases or []), json.dumps(prereqs or []),
         json.dumps(["CH1"]), "m", status, E._now()))
    return cid


class TestAliasAudit(unittest.TestCase):
    def _index(self):
        conn = _fresh_index()
        self.refraction = _ins(conn, "Physics", 8, "Refraction", aliases=["Bending of Light"])
        self.bending = _ins(conn, "Physics", 8, "Bending of Light")
        self.reflection = _ins(conn, "Physics", 8, "Reflection", prereqs=["Refraction"])
        # 'Bending of Light' now resolves to BOTH the canonical (self.bending) and an alias (self.refraction)
        self.lens = _ins(conn, "Physics", 9, "Lens", prereqs=["Bending of Light", "Nonexistent Concept"])
        return conn

    def test_alias_collides_with_another_canonical_name(self):
        rep = AA.audit_aliases(self._index())
        hits = [x for x in rep["alias_name_collisions"] if x["concept_id"] == self.refraction]
        self.assertEqual(len(hits), 1)
        self.assertEqual(hits[0]["alias"], "Bending of Light")
        self.assertIn(self.bending, hits[0]["collides_same_subject"])

    def test_canonical_name_appears_as_an_alias_elsewhere(self):
        rep = AA.audit_aliases(self._index())
        hits = [x for x in rep["canonical_as_alias"] if x["concept_id"] == self.bending]
        self.assertEqual(len(hits), 1)
        self.assertIn(self.refraction, hits[0]["aliased_by"])

    def test_prereq_resolution_reports_resolved_ambiguous_and_unresolved(self):
        rep = AA.audit_aliases(self._index())
        self.assertGreaterEqual(rep["prereq_resolved"], 1)                       # 'Refraction' -> exactly 1
        amb = [x for x in rep["prereq_ambiguous"] if x["prerequisite"] == "Bending of Light"]
        self.assertEqual(len(amb), 1)
        self.assertEqual(set(amb[0]["targets"]), {self.refraction, self.bending})  # 2 targets => ambiguous
        unres = [x for x in rep["prereq_unresolved"] if x["prerequisite"] == "Nonexistent Concept"]
        self.assertEqual(len(unres), 1)

    def test_resolver_is_id_based_and_subject_scoped(self):
        conn = self._index()
        concepts = AA._load_concepts(conn, "certified")
        self.assertEqual(AA.resolve_name_to_concept_ids(concepts, "Physics", "Refraction", 8),
                         [self.refraction])
        self.assertEqual(AA.resolve_name_to_concept_ids(concepts, "Chemistry", "Refraction", 8), [])
        # a prerequisite must be at/below the referencing class
        self.assertEqual(AA.resolve_name_to_concept_ids(concepts, "Physics", "Lens", 8), [])


if __name__ == "__main__":
    unittest.main()
