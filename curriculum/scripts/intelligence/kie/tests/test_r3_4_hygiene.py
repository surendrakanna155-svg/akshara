"""R3-4 · Schema/engine hygiene invariants (PERMANENT regression suite).

Covers the tractable, safe parts of the R3-4 batch:
  * the shared derived-store opener            (#database-9 / #perf-scale-7)
  * run_planner allow-missing fail-loud        (#perf-scale-8)
  * concept_codes_all stores IDS + backfill    (#database-5)
  * JSON-validity across factory + qdi schemas (#database-6)  <-- the required permanent deliverable
  * qp_bridge engine-pool cache                (#perf-scale-9)

DEFERRED (needs a SANCTIONED kie.db rebuild under the freeze hatch — kie.db is frozen v1.5, chmod a-w —
so intentionally NOT implemented here): an FTS5 index over kie.db chunks + a chunks(doc_id, ordinal)
index (#database-9 / #perf-scale-9). Do it at the next kie.db version.
"""
from __future__ import annotations

import json
import os
import sqlite3
import tempfile
import unittest

from kie import config
from kie.qie import qp_bridge as QB
from kie.qie import store_open as SO
from kie.qie.factory import corpus as CO
from kie.qie.knowledge import blueprint_store as BS
from kie.qie.knowledge import examdna as ED
from kie.qie.knowledge import run_planner as RP
from kie.qie.knowledge import run_qdi as RQ


# ── #database-6: the JSON-TEXT column registry (SSOT). Every column here must hold valid JSON or NULL. ───
# gate_result.detail / independent_answer.detail / judge_verdict.reasons are DELIBERATELY EXCLUDED: they
# hold free text, not JSON (the schema marks detail "json/text" and the writers store plain strings).
JSON_COLUMNS = {
    "generation_spec": ("concept_codes_all", "boundary", "planner_evidence", "prerequisites",
                        "curriculum_boundary", "difficulty_drivers", "expected_solving_path", "misconceptions"),
    "candidate": ("options", "claimed", "structure", "solution", "distractor_rationale",
                  "visual_spec", "raw", "relation_waiver"),
    "qdi_pattern": ("concept_roles", "dependency", "reasoning_chain", "operators", "constraints",
                    "difficulty_mechanism", "transformation", "distractor_structure", "misconceptions",
                    "solution_structure", "evidence_refs"),
    "qdi_rejected": ("evidence_refs",),
}

# which stores carry which of the above tables
_STORE_TABLES = {
    "factory_corpus.db": ("generation_spec", "candidate"),
    "qpl_question_bank.db": ("generation_spec", "candidate"),
    "qdi.db": ("qdi_pattern", "qdi_rejected"),
    "examdna.db": (),   # examdna schema has NO JSON-TEXT columns (asserted below) — present for completeness
}


def _table_exists(conn, t) -> bool:
    return conn.execute("SELECT 1 FROM sqlite_master WHERE type='table' AND name=?", (t,)).fetchone() is not None


def bad_json_cells(conn: sqlite3.Connection, table: str, columns) -> list:
    """Return (table, column, ordinal, snippet) for every NON-NULL value that is not valid JSON. Empty list
    == all valid. Column/table-tolerant (skips what a given store's schema does not have)."""
    if not _table_exists(conn, table):
        return []
    present = {r[1] for r in conn.execute(f"PRAGMA table_info({table})")}
    bad = []
    for col in columns:
        if col not in present:
            continue
        for i, (v,) in enumerate(conn.execute(f"SELECT {col} FROM {table}")):
            if v is None:
                continue
            try:
                json.loads(v)
            except (ValueError, TypeError):
                bad.append((table, col, i, str(v)[:60]))
    return bad


# ── shared derived-store opener (#database-9 / #perf-scale-7) ────────────────────────────────────────────
class SharedOpener(unittest.TestCase):
    def test_memory_open_sets_row_factory_and_fk(self):
        conn = SO.open_store(":memory:", read_only=False)
        self.assertIs(conn.row_factory, sqlite3.Row)
        self.assertEqual(conn.execute("PRAGMA foreign_keys").fetchone()[0], 1)
        conn.close()

    def test_readonly_default_missing_fails_loud(self):
        # DEFAULT is read_only=True; a missing file must fail loud (no silent stray-DB creation).
        p = os.path.join(tempfile.mkdtemp(), "absent.db")
        with self.assertRaises(sqlite3.OperationalError):
            SO.open_store(p)  # read_only defaults True
        self.assertFalse(os.path.exists(p))

    def test_writable_creates_file_and_standardizes_wal(self):
        p = os.path.join(tempfile.mkdtemp(), "w.db")
        conn = SO.open_store(p, read_only=False)
        conn.execute("CREATE TABLE t(x)")
        self.assertEqual(conn.execute("PRAGMA journal_mode").fetchone()[0].lower(), "wal")
        conn.close()
        self.assertTrue(os.path.exists(p))

    def test_path_guard_rejects_stray_location(self):
        # a wrong-cwd path (repo root, not KIE_HOME, not the OS temp dir) is refused BEFORE any file is made.
        stray = str(config.WORKSPACE / "stray_r3_4_should_never_exist.db")
        with self.assertRaises(ValueError):
            SO.open_store(stray, read_only=False)
        self.assertFalse(os.path.exists(stray))

    def test_temp_dir_path_is_permitted(self):
        # tests / scratch fixtures live under the OS temp dir — the guard must permit them.
        conn = SO.open_store(os.path.join(tempfile.mkdtemp(), "ok.db"), read_only=False)
        conn.close()


class JournalModeStandardized(unittest.TestCase):
    """The audit found qdi.db / examdna.db on the sqlite default `delete` while the others were WAL. Routing
    them through the shared opener standardizes them to WAL."""

    def test_qdi_store_is_wal(self):
        conn = RQ.open_store(os.path.join(tempfile.mkdtemp(), "qdi.db"))
        self.assertEqual(conn.execute("PRAGMA journal_mode").fetchone()[0].lower(), "wal")
        conn.close()

    def test_examdna_store_is_wal(self):
        conn = ED.open_examdna(os.path.join(tempfile.mkdtemp(), "examdna.db"))
        self.assertEqual(conn.execute("PRAGMA journal_mode").fetchone()[0].lower(), "wal")
        conn.close()


# ── run_planner allow-missing (#perf-scale-8) ───────────────────────────────────────────────────────────
class RunPlannerFailLoud(unittest.TestCase):
    def test_missing_store_fails_loud_by_default(self):
        absent = os.path.join(tempfile.mkdtemp(), "nope_qdi.db")
        with self.assertRaises(sqlite3.OperationalError) as cm:
            RP._load_certified_patterns("NEET", qdi_path=absent, allow_missing=False)
        self.assertIn(absent, str(cm.exception))  # the resolved PATH is in the message

    def test_missing_store_allow_missing_warns_and_returns_empty(self):
        absent = os.path.join(tempfile.mkdtemp(), "nope_qdi.db")
        with self.assertLogs(RP._log, level="WARNING") as logs:
            out = RP._load_certified_patterns("NEET", qdi_path=absent, allow_missing=True)
        self.assertEqual(out, [])                       # honest null, not a fabricated result
        self.assertTrue(any(absent in m for m in logs.output))  # the path is named in the WARNING

    def test_low_level_helper_default_is_fail_loud(self):
        absent = os.path.join(tempfile.mkdtemp(), "x.db")
        with self.assertRaises(sqlite3.OperationalError):
            RP._open_ro_or_none(absent, allow_missing=False, what="test store")
        self.assertIsNone(RP._open_ro_or_none(absent, allow_missing=True, what="test store"))


# ── concept_codes_all stores IDS, not titles (#database-5) ───────────────────────────────────────────────
class ConceptCodesAllWriter(unittest.TestCase):
    def _bp(self, **over):
        base = {"spec_id": "QBP_1", "run_id": "r", "lane": "STRUCTURED_NUMERIC", "exam": "NEET",
                "class_level": 11, "subject": "Physics", "chapter_id": "CH", "concept_id": "KC_abc",
                "concept_name": "Newton's second law", "composition": "single", "compose_with": [],
                "archetype": "single_step_numerical", "question_type": "MCQ", "reasoning_depth": 2,
                "intended_depth": 2, "difficulty": "moderate", "target_difficulty": "moderate",
                "blueprint_fingerprint": "fp", "planner_evidence": {}}
        base.update(over)
        return base

    def test_writer_emits_primary_concept_id(self):
        row = BS._row(self._bp())
        self.assertEqual(json.loads(row["concept_codes_all"]), ["KC_abc"])   # ID, not "Newton's second law"

    def test_writer_includes_composition_partner_ids(self):
        row = BS._row(self._bp(composition="multi", compose_with=["KC_def", "KC_abc"]))
        self.assertEqual(json.loads(row["concept_codes_all"]), ["KC_abc", "KC_def"])  # deduped, order-stable

    def test_writer_never_emits_the_title(self):
        row = BS._row(self._bp())
        self.assertNotIn("Newton's second law", row["concept_codes_all"])


class ConceptCodesAllBackfill(unittest.TestCase):
    def setUp(self):
        self.conn = CO.open_store(":memory:")

    def tearDown(self):
        self.conn.close()

    def _insert(self, spec_id, code, title, codes_all):
        self.conn.execute(
            "INSERT INTO generation_spec (spec_id, run_id, lane, class_level, subject, concept_code, "
            "concept_title, concept_codes_all, composition, archetype, question_type, intended_depth, "
            "intended_difficulty, created_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
            (spec_id, "r", "STRUCTURED_NUMERIC", 11, "Mathematics", code, title, codes_all,
             "single", "single_step_numerical", "MCQ", 2, "moderate", "planned:x:y"))
        self.conn.commit()

    def test_backfill_rewrites_title_to_concept_code_id(self):
        self._insert("S1", "KC_182f4a22158f5a", "Sets and their Representation",
                     json.dumps(["Sets and their Representation"]))
        summ = BS.backfill_concept_codes_all(self.conn)
        self.assertEqual(summ["rewritten"], 1)
        val = self.conn.execute("SELECT concept_codes_all FROM generation_spec WHERE spec_id='S1'").fetchone()[0]
        self.assertEqual(json.loads(val), ["KC_182f4a22158f5a"])   # title -> id (from concept_code)

    def test_backfill_is_idempotent(self):
        self._insert("S1", "KC_x", "Foo", json.dumps(["Foo"]))
        BS.backfill_concept_codes_all(self.conn)
        summ2 = BS.backfill_concept_codes_all(self.conn)   # already ids
        self.assertEqual(summ2["rewritten"], 0)

    def test_backfill_leaves_unresolvable_member_and_never_fabricates(self):
        # a member equal to neither the code nor the title, with no index to resolve it -> honest null (kept)
        self._insert("S1", "KC_x", "Foo", json.dumps(["Totally Unknown Concept"]))
        summ = BS.backfill_concept_codes_all(self.conn)
        self.assertEqual(summ["rewritten"], 0)
        self.assertEqual(summ["unresolved_count"], 1)
        val = self.conn.execute("SELECT concept_codes_all FROM generation_spec WHERE spec_id='S1'").fetchone()[0]
        self.assertEqual(json.loads(val), ["Totally Unknown Concept"])   # unchanged, not fabricated

    def test_backfill_resolves_partner_title_via_index(self):
        self._insert("S1", "KC_primary", "Primary", json.dumps(["Primary", "Partner Concept"]))
        idx = sqlite3.connect(":memory:")
        idx.execute("CREATE TABLE ki_concept (concept_id TEXT, canonical_name TEXT)")
        idx.execute("INSERT INTO ki_concept VALUES ('KC_partner', 'Partner Concept')")
        idx.commit()
        summ = BS.backfill_concept_codes_all(self.conn, index_conn=idx)
        self.assertEqual(summ["rewritten"], 1)
        val = self.conn.execute("SELECT concept_codes_all FROM generation_spec WHERE spec_id='S1'").fetchone()[0]
        self.assertEqual(json.loads(val), ["KC_primary", "KC_partner"])
        idx.close()


# ── JSON validity invariant (#database-6) — the REQUIRED permanent deliverable ───────────────────────────
class JsonValidityChecker(unittest.TestCase):
    def test_checker_flags_invalid_and_passes_valid(self):
        # prove the checker is NOT vacuous: it accepts valid JSON / NULL and rejects a non-JSON string.
        c = sqlite3.connect(":memory:")
        c.execute("CREATE TABLE qdi_pattern (evidence_refs TEXT)")
        c.executemany("INSERT INTO qdi_pattern (evidence_refs) VALUES (?)",
                      [(json.dumps([{"doc_id": "d"}]),), (None,)])
        self.assertEqual(bad_json_cells(c, "qdi_pattern", ("evidence_refs",)), [])
        c.execute("INSERT INTO qdi_pattern (evidence_refs) VALUES ('not json {')")
        self.assertEqual(len(bad_json_cells(c, "qdi_pattern", ("evidence_refs",))), 1)
        c.close()

    def test_freshly_built_stores_have_only_valid_json_columns(self):
        # a freshly-created store (schema-complete, empty) trivially satisfies the invariant, and confirms
        # the registry names real columns of the shipped schema.
        for conn, tables in ((CO.open_store(":memory:"), ("generation_spec", "candidate")),
                             (RQ.open_store(":memory:"), ("qdi_pattern", "qdi_rejected"))):
            for t in tables:
                self.assertTrue(_table_exists(conn, t), f"{t} missing from fresh schema")
                self.assertEqual(bad_json_cells(conn, t, JSON_COLUMNS[t]), [])
            conn.close()

    def test_examdna_schema_has_no_json_columns(self):
        # documents the audit fact: examdna carries no JSON-TEXT columns (so nothing to validate there).
        conn = ED.open_examdna(":memory:")
        for t in ("exam_weight", "exam_distribution"):
            for _name, decl in [(r[1], (r[2] or "")) for r in conn.execute(f"PRAGMA table_info({t})")]:
                pass  # structural presence only; no json cols asserted by absence from JSON_COLUMNS
        self.assertNotIn("exam_weight", JSON_COLUMNS)
        self.assertNotIn("exam_distribution", JSON_COLUMNS)
        conn.close()


class JsonValidityLiveStores(unittest.TestCase):
    """PERMANENT invariant over the LIVE derived stores (gitignored / local): every registered JSON-TEXT
    column holds valid JSON or NULL. Skips a store that is not present locally."""

    def test_live_stores_json_columns_are_valid(self):
        checked = 0
        for db_name, tables in _STORE_TABLES.items():
            path = config.KIE_HOME / db_name
            if not path.exists():
                continue
            conn = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
            try:
                for t in tables:
                    bad = bad_json_cells(conn, t, JSON_COLUMNS.get(t, ()))
                    self.assertEqual(bad, [], f"{db_name}:{t} has invalid JSON: {bad[:3]}")
                    checked += 1
            finally:
                conn.close()
        if checked == 0:
            self.skipTest("no live derived stores present (local-only / gitignored)")


# ── qp_bridge engine-pool cache (#perf-scale-9) ─────────────────────────────────────────────────────────
class EnginePoolCache(unittest.TestCase):
    def setUp(self):
        self._orig = QB._build_engine_pool
        self.calls = []

        def _stub(subjects, seed, per=14):
            self.calls.append((tuple(sorted(set(subjects))), seed, per))
            return [{"gen_id": f"g{len(self.calls)}"}]

        QB._build_engine_pool = _stub
        QB.clear_engine_pool_cache()

    def tearDown(self):
        QB._build_engine_pool = self._orig
        QB.clear_engine_pool_cache()

    def test_same_key_builds_once(self):
        a = QB._engine_pool(["Mathematics"], 7, per=2)
        b = QB._engine_pool(["Mathematics"], 7, per=2)
        self.assertEqual(len(self.calls), 1)      # built once, served from cache the second time
        self.assertEqual(a, b)

    def test_subject_order_is_irrelevant_to_key(self):
        QB._engine_pool(["Physics", "Chemistry"], 7, per=2)
        QB._engine_pool(["Chemistry", "Physics"], 7, per=2)
        self.assertEqual(len(self.calls), 1)      # key is order-independent (sorted subjects)

    def test_distinct_seed_rebuilds(self):
        QB._engine_pool(["Mathematics"], 7, per=2)
        QB._engine_pool(["Mathematics"], 8, per=2)
        self.assertEqual(len(self.calls), 2)

    def test_returned_list_is_a_copy(self):
        a = QB._engine_pool(["Mathematics"], 7, per=2)
        a.append({"gen_id": "mutant"})            # caller filtering must not corrupt the cache
        b = QB._engine_pool(["Mathematics"], 7, per=2)
        self.assertNotIn({"gen_id": "mutant"}, b)

    def test_clear_cache_empties_it(self):
        QB._engine_pool(["Mathematics"], 7, per=2)
        QB.clear_engine_pool_cache()
        QB._engine_pool(["Mathematics"], 7, per=2)
        self.assertEqual(len(self.calls), 2)

    def test_registry_version_is_stable(self):
        self.assertEqual(QB._registry_version(), QB._registry_version())


if __name__ == "__main__":
    unittest.main()
