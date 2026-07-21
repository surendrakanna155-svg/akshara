"""R3-7 — close latent gate/leak paths (curriculum-boundary vacuity + residual QDI leak paths).

Locks four fixes, all additive over R1/R2:
  (a) the curriculum_boundary gate: a boundary with NO curriculum-evidenced terms ("checked 0") is an ADVISORY
      FAILURE, never a silent pass; sentence-length out-of-scope evidence yields SHORT matchable tokens; a real
      above-class hit stays BLOCKING (QUARANTINE).
  (b) qdi.certified_patterns is EXAM-scoped — a NEET request can never receive a JEE pattern.
  (c) the section-header regex is anchored on real header STRUCTURE (parenthesised / line-anchored) so it no
      longer matches prose, and a chunk spanning >=2 distinct subject sections resolves to None (not the last).
  (d) qdi_link refuses an unknown exam (R1-3 regression — verified still holds).
Self-contained: in-memory sqlite + hand-built candidates. No live-DB mutation.
"""
from __future__ import annotations

import sqlite3
import unittest

from kie.qie.factory import gates as G
from kie.qie.knowledge import qdi as QDI
from kie.qie.knowledge import qdi_link as QL
from kie.qie.knowledge import run_planner as R


def _cand(stem: str) -> dict:
    """A schema-complete candidate so the battery reaches the curriculum_boundary gate (gate #7)."""
    return {"stem": stem,
            "options": {"a": "1", "b": "2", "c": "3", "d": "4"},
            "answer_label": "a",
            "claimed": {"concepts": ["X"], "archetype": "single_step_numerical", "composition": "single"},
            "structure": {}}


def _boundary(stem: str, forbidden) -> dict:
    import json
    spec = {"lane": "QUALITATIVE", "subject": "Mathematics",
            "boundary": json.dumps({"forbidden_terms": forbidden})}
    ctx = {"spec": spec, "seen_norm": {}, "corpus": [], "certified_relations": {}, "certified_relation_eqs": []}
    by = {g["gate"]: g for g in G.run_gates(_cand(stem), ctx)}
    return by["curriculum_boundary"]


# ── (a) curriculum-boundary gate ──────────────────────────────────────────────────────────────────────
class CurriculumBoundaryGate(unittest.TestCase):
    def test_checked_zero_is_an_advisory_failure_not_a_pass(self):
        r = _boundary("A clean class-appropriate stem about numbers and shapes.", [])
        self.assertFalse(r["ok"], "an empty forbidden_terms boundary must NOT read as a pass")
        self.assertEqual(r["severity"], G.ADVISORY, "vacuous boundary is an ADVISORY failure (non-blocking)")

    def test_advisory_boundary_does_not_block_the_lifecycle(self):
        ctx_gates = [r for r in [_boundary("A clean stem.", [])]]
        status, _ = G.verdict(ctx_gates)
        self.assertNotEqual(status, "rejected")
        self.assertNotEqual(status, "quarantined", "an advisory boundary failure must not quarantine on its own")

    def test_sentence_length_out_of_scope_yields_a_matchable_token(self):
        # a SENTENCE the old regex could never match — the derived bigram "polynomial division" now hits.
        r = _boundary("Factor the expression using polynomial division to find the roots.",
                      ["the factor theorem and polynomial division are out of scope at this level"])
        self.assertFalse(r["ok"], "a derived short token from the out-of-scope sentence must hit")
        self.assertEqual(r["severity"], G.QUARANTINE, "a real above-class hit stays BLOCKING")
        self.assertIn("polynomial division", r["detail"])

    def test_lone_forbidden_token_still_blocks(self):
        r = _boundary("Differentiate the function using calculus techniques.", ["calculus"])
        self.assertFalse(r["ok"])
        self.assertEqual(r["severity"], G.QUARANTINE)
        self.assertIn("calculus", r["detail"])

    def _boundary_c(self, stem, forbidden, concept):
        import json
        spec = {"lane": "QUALITATIVE", "subject": "Mathematics", "concept_title": concept,
                "boundary": json.dumps({"forbidden_terms": forbidden})}
        ctx = {"spec": spec, "seen_norm": {}, "corpus": [], "certified_relations": {}, "certified_relation_eqs": []}
        return {g["gate"]: g for g in G.run_gates(_cand(stem), ctx)}["curriculum_boundary"]

    def test_concept_own_name_does_not_cry_wolf(self):
        # adversarial-verifier fix: a concept whose out_of_scope sentence restates its OWN name must not derive
        # a forbidden token that quarantines a legitimate in-scope item (411 concepts were affected).
        r = self._boundary_c(
            "Find the principal value of the inverse trigonometric function arcsin(1/2).",
            ["advanced properties of inverse trigonometric functions are out of scope"],
            "Properties of Inverse Trigonometric Functions")
        self.assertNotEqual(r["severity"], G.QUARANTINE,
                            "a derived token that is the concept's OWN name must not quarantine an in-scope item")

    def test_genuine_above_class_beside_concept_name_still_blocks(self):
        # the concept-self drop must NOT swallow a REAL above-class token that appears in the same sentence.
        r = self._boundary_c(
            "Evaluate the integral of the differential equations shown.",
            ["their integrals and differential equations are out of scope"],
            "Inverse Trigonometric Functions")
        self.assertEqual(r["severity"], G.QUARANTINE)
        self.assertIn("differential equations", r["detail"])

    def test_above_ceiling_technique_caught_even_with_empty_evidence(self):
        # forbidden_terms is empty, but a genuinely undergraduate technique in the stem is caught by the
        # baseline list -> BLOCKING (not the advisory 'checked 0' branch).
        r = _boundary("Find the largest eigenvalue of the given matrix operator.", [])
        self.assertFalse(r["ok"])
        self.assertEqual(r["severity"], G.QUARANTINE)
        self.assertIn("eigenvalue", r["detail"])

    def test_evidenced_no_hit_is_a_genuine_pass(self):
        r = _boundary("A stem about triangles and areas, nothing above class.", ["calculus"])
        self.assertTrue(r["ok"], "an evidenced boundary with no hit is a real pass")
        self.assertEqual(r["severity"], G.QUARANTINE)
        self.assertIn("checked 1 evidenced", r["detail"])

    def test_short_token_derivation_ignores_generic_words(self):
        # a boundary sentence of only generic filler yields no evidenced check -> advisory (never a bigram of
        # common words that would cry wolf on in-scope stems).
        ev, base = G._boundary_checks(["these advanced applications are beyond the general level here"])
        self.assertEqual(ev, [], "generic filler must not become a forbidden token")
        self.assertTrue(base, "the baseline above-ceiling list is always scanned")


# ── (b) certified_patterns is EXAM-scoped ─────────────────────────────────────────────────────────────
def _qdi_mem() -> sqlite3.Connection:
    c = sqlite3.connect(":memory:")
    c.row_factory = sqlite3.Row
    QDI.open_qdi(c)
    return c


def _cert(c, pid, exam, subject):
    c.execute("INSERT INTO qdi_pattern (pattern_id, exam, subject, archetype, pattern_name, design_summary, "
              "difficulty_band, evidence_refs, evidence_count, analyst_model, status, created_at) "
              "VALUES (?,?,?,?,?,?,?,?,?,?,?,?)",
              (pid, exam, subject, "multi_step_numerical", pid + "_name",
               "Abstract machinery for this pattern.", "hard", "[]", 5, "m", "certified", "t"))
    c.commit()


class CertifiedPatternsExamScope(unittest.TestCase):
    def test_neet_request_never_gets_a_jee_pattern(self):
        c = _qdi_mem()
        try:
            _cert(c, "QDP_jee", "JEE_Main", "Mathematics")
            _cert(c, "QDP_neet", "NEET", "Mathematics")
            jee = {p["pattern_id"] for p in QDI.certified_patterns(c, "JEE_Main", "Mathematics")}
            neet = {p["pattern_id"] for p in QDI.certified_patterns(c, "NEET", "Mathematics")}
            self.assertEqual(jee, {"QDP_jee"})
            self.assertEqual(neet, {"QDP_neet"}, "a NEET request must not receive the JEE_Main pattern")
            self.assertNotIn("QDP_jee", neet)
        finally:
            c.close()

    def test_signature_requires_exam(self):
        c = _qdi_mem()
        try:
            with self.assertRaises(TypeError):
                QDI.certified_patterns(c, "Mathematics")   # old subject-only call must no longer type-check
        finally:
            c.close()

    def test_subject_only_planner_path_attaches_no_qdi_pattern(self):
        # run_planner.plan()'s subject-only reader is now an honest null (QDI is exam-scoped, in qdi.db).
        self.assertEqual(R._certified_patterns(sqlite3.connect(":memory:"), "Mathematics"), [])


# ── (c) anchored section-header regex + multi-marker split ────────────────────────────────────────────
def _kie(chunks) -> sqlite3.Connection:
    k = sqlite3.connect(":memory:")
    k.row_factory = sqlite3.Row
    k.executescript("CREATE TABLE chunks (chunk_id TEXT PRIMARY KEY, doc_id TEXT, ordinal INT, text TEXT);")
    for i, (cid, text) in enumerate(chunks):
        k.execute("INSERT INTO chunks VALUES (?,?,?,?)", (cid, "D", i, text))
    k.commit()
    return k


class AnchoredSectionRegex(unittest.TestCase):
    def test_parenthesised_header_resolves_subject(self):
        k = _kie([("c1", "Section - A (Physics) 1. A block slides down an incline. Ans (2)")])
        self.assertEqual(QDI.resolve_chunk_subjects(k, "D")["c1"], "Physics")

    def test_prose_mention_does_not_resolve_a_subject(self):
        # the exact defect: a stray sentence "in this section, physics ..." must NOT tag the chunk Physics.
        k = _kie([("c1", "In this section, physics of the given system and later chemistry ideas are discussed "
                         "as part of the introduction to the overall syllabus of the course.")])
        self.assertIsNone(QDI.resolve_chunk_subjects(k, "D")["c1"],
                          "prose must not satisfy the anchored header regex")

    def test_chunk_spanning_two_subjects_resolves_to_none(self):
        # one chunk carrying BOTH a Physics and a Chemistry section header cannot be one subject -> None,
        # never collapsed onto the LAST marker as the old code did.
        k = _kie([("c1", "Section - A (Physics) 1. Find the acceleration. Ans (2)  "
                         "Section - B (Chemistry) 2. Order the halides. Ans (1)")])
        self.assertIsNone(QDI.resolve_chunk_subjects(k, "D")["c1"])

    def test_line_anchored_bare_header_resolves(self):
        k = _kie([("c1", "SECTION A : PHYSICS\n1. A projectile is launched; find the range. Ans (2)")])
        self.assertEqual(QDI.resolve_chunk_subjects(k, "D")["c1"], "Physics")

    def test_marker_propagates_to_following_unmarked_chunk(self):
        k = _kie([("c1", "Section (Chemistry) 1. Balance the equation. Ans (2)"),
                  ("c2", "2. Another chemistry item with no header of its own. Ans (1)")])
        res = QDI.resolve_chunk_subjects(k, "D")
        self.assertEqual(res["c1"], "Chemistry")
        self.assertEqual(res["c2"], "Chemistry", "an unmarked chunk inherits the most-recent marker")


# ── (d) qdi_link refuses an unknown exam (R1-3 regression) ────────────────────────────────────────────
class UnknownExamRefused(unittest.TestCase):
    def test_unknown_exam_yields_unmapped_profile_and_is_refused(self):
        link = QL.scope_link_for({"pattern_id": "QDP_x", "exam": "Practice_Resources", "subject": "Mathematics"})
        self.assertIsNone(link["exam_profile"], "an unknown exam must NOT silently map to a valid profile")
        self.assertIsNotNone(QL.validate_scope_link(link), "an unmapped exam_profile must be refused")

    def test_known_exam_still_maps_and_validates(self):
        link = QL.scope_link_for({"pattern_id": "QDP_y", "exam": "NEET", "subject": "Biology"})
        self.assertEqual(link["exam_profile"], "NEET")
        self.assertIsNone(QL.validate_scope_link(link))


class SectionHeaderRegexAnchored(unittest.TestCase):
    """R3-7c (adversarial-verifier fix): the section-header regex resolves a real LINE-ANCHORED header but NOT a
    parenthesised subject embedded in running prose."""

    def test_parenthesised_subject_in_prose_does_not_resolve(self):
        from kie.qie.knowledge import qdi as QDI
        for prose in ("In this part (Physics) we analyse the motion of the block.",
                      "as discussed in this section (chemistry) the reaction proceeds to completion"):
            self.assertIsNone(QDI._SECTION_SUBJECT.search(prose),
                              f"prose must not match a section header: {prose!r}")

    def test_real_line_anchored_header_resolves(self):
        from kie.qie.knowledge import qdi as QDI
        for header, subj in (("SECTION A (Physics)\n", "Physics"),
                             ("Section B : Chemistry\n", "Chemistry"),
                             ("prior text ends here.\nPART C (Chemistry)\nnew section", "Chemistry")):
            m = QDI._SECTION_SUBJECT.search(header)
            self.assertIsNotNone(m, f"a real header must resolve: {header!r}")
            self.assertEqual(QDI._marker_subject(m), subj)


if __name__ == "__main__":
    unittest.main()
