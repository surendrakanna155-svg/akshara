"""Tests for the Certified Knowledge Index spine + schema (v2).

These pin the owner's LOCKED architecture decisions as mechanical facts rather than intentions:

  rule 2/3  — a concept id is permanent and stable, and downstream systems reference it. So the id must
              not move when the INFERRED dimension (academic discipline) is re-audited.
  rule 4/5  — the curriculum hierarchy and the academic discipline are independent dimensions and BOTH
              are preserved. 'Science' is a real curriculum subject; it is not a discipline.
  rule 7/8  — every concept traces to owned evidence, and evidence outranks model opinion: the spine
              admits a heading only because the BOOK numbered it, never because it looked plausible.

Plus the two regressions that made v1's index hollow and dirty:
  - reading only `section_path` made every senior book invisible (class 9+ held 1 certified concept)
  - NCERT numbers exercises in the same 'N.M' space as sections, so exercise stems posed as headings
"""
import json
import sqlite3
import unittest

from kie.qie.knowledge import schema as SC
from kie.qie.knowledge import spine as S


def _kie_db() -> sqlite3.Connection:
    """A minimal stand-in for kie.db: source_documents + chunks, the only tables the spine reads."""
    c = sqlite3.connect(":memory:")
    c.row_factory = sqlite3.Row
    c.executescript("""
        CREATE TABLE source_documents (doc_id TEXT PRIMARY KEY, rel_path TEXT, subject TEXT);
        CREATE TABLE chunks (chunk_id TEXT PRIMARY KEY, doc_id TEXT, ordinal INTEGER, page_start INTEGER,
                             section_path TEXT, text TEXT);
    """)
    return c


def _add(c, doc_id, rel_path, chunks, subject="WRONG"):
    c.execute("INSERT INTO source_documents VALUES (?,?,?)", (doc_id, rel_path, subject))
    for i, (path, text) in enumerate(chunks):
        c.execute("INSERT INTO chunks VALUES (?,?,?,?,?,?)", (f"{doc_id}#{i}", doc_id, i, 1, path, text))
    c.commit()


class TestBookClassification(unittest.TestCase):
    def test_subject_comes_from_filename_code_not_the_document_tag(self):
        # hegp1dd is Ganita Prakash (MATHS); source_documents tags it Chemistry. The code wins.
        subj, cls, basis, integrated = S.classify_book("NCERT/Class_08/Textbooks/NCERT_Class8_hegp1dd.zip")
        self.assertEqual((subj, cls, integrated), ("Mathematics", 8, False))
        self.assertIn("hegp1dd"[2:4], basis)

    def test_integrated_science_is_admitted_as_curriculum_subject_science(self):
        """v1 refused these outright, which cost the index every class 6-10 Science concept."""
        for path, cls in (("NCERT/Class_06/Textbooks/NCERT_Class6_fecu1dd.zip", 6),
                          ("NCERT/Class_09/Textbooks/NCERT_Class9_iesc1dd.zip", 9)):
            subj, got, basis, integrated = S.classify_book(path)
            self.assertEqual((subj, got, integrated), ("Science", cls, True), path)
            # and it must say plainly that the discipline is NOT settled by the filename
            self.assertIn("not", basis.lower())

    def test_senior_single_subject_books_are_provable(self):
        for path, want in (("x/NCERT_Class11_keph1dd.zip", ("Physics", 11)),
                           ("x/NCERT_Class12_lech1dd.zip", ("Chemistry", 12)),
                           ("x/NCERT_Class11_kebo1dd.zip", ("Biology", 11)),
                           ("x/NCERT_Class12_lemh2dd.zip", ("Mathematics", 12))):
            subj, cls, _, integrated = S.classify_book(path)
            self.assertEqual((subj, cls), want, path)
            self.assertFalse(integrated)

    def test_non_ncert_is_not_admitted(self):
        subj, cls, _, _ = S.classify_book("NEET/2023/paper.pdf")
        self.assertIsNone(subj)
        self.assertIsNone(cls)


class TestConceptIdentity(unittest.TestCase):
    def test_id_is_stable_and_content_addressed(self):
        a = S.concept_id("Mathematics", 8, "Properties of Rational Numbers")
        b = S.concept_id("Mathematics", 8, "  properties of RATIONAL numbers  ")
        self.assertEqual(a, b)
        self.assertTrue(a.startswith("KC_"))

    def test_id_does_not_depend_on_the_inferred_discipline(self):
        """OWNER RULE 2/3. 'Pressure' from Science-8 keeps its id whether it is later audited Physics,
        Chemistry or Interdisciplinary — otherwise re-auditing silently orphans every question, DPP
        record and analytics row that referenced it."""
        science_8 = S.concept_id("Science", 8, "Pressure")
        self.assertEqual(science_8, S.concept_id("Science", 8, "Pressure"))
        # the discipline is not an input at all — only (curriculum subject, class, name) is
        self.assertNotEqual(science_8, S.concept_id("Physics", 11, "Pressure"))

    def test_id_separates_classes(self):
        self.assertNotEqual(S.concept_id("Science", 8, "Force"), S.concept_id("Science", 9, "Force"))

    def test_chapter_id_includes_the_book(self):
        """Class 7 ships gegp1dd, gegp2dd and gemh1dd — all with a chapter 1."""
        self.assertNotEqual(S.chapter_id("Mathematics", 7, 1, "aaaaaa11"),
                            S.chapter_id("Mathematics", 7, 1, "bbbbbb22"))


class TestHeadingAdmission(unittest.TestCase):
    def test_exercise_stems_are_not_headings(self):
        """NCERT numbers exercises like sections: '3.2 Pick out the two scalar quantities...'."""
        for stem in ("Pick out the two scalar quantities in the following list",
                     "Give the magnitude and direction of the net force acting on",
                     "State with reasons, whether the following algebraic operations",
                     "Fill in the blanks",
                     "A body is moving unidirectionally under the influence of a source"):
            self.assertFalse(S._is_heading_like(stem), stem)

    def test_captions_and_fragments_are_not_headings(self):
        for junk in ("Figure 2", "Table 1", "(ii) he walks the same distance", "of",
                     "3 m6",          # the class-10 answer key, mis-parsed onto a fake heading "5.40"
                     "= x2 + 1"):     # a stray formula fragment
            self.assertFalse(S._is_heading_like(junk), junk)

    def test_real_headings_survive(self):
        for good in ("THE LAW OF INERTIA", "Position and Displacement Vectors", "Types of Relations",
                     "How to group plants?", "Balanced Diet", "Find the Median",
                     "Checking the Dimensional Consistency of Equations"):
            self.assertTrue(S._is_heading_like(good), good)

    def test_clean_title_cuts_allcaps_heading_glued_to_titlecase_body(self):
        # senior-book style: an ALL-CAPS heading OCR-joined to its first sentence. The boundary is
        # uppercase->uppercase (MOTION|The), invisible to the lowercase->uppercase cut.
        self.assertEqual(S._clean_title("NEWTON’S SECOND LAW OF MOTIONThe first law refers to the case"),
                         "NEWTON’S SECOND LAW OF MOTION")
        # a normal Title-Case heading must be left intact
        self.assertEqual(S._clean_title("Types of Relations"), "Types of Relations")

    def test_lowercase_initial_heading_admitted_only_from_allowlist(self):
        c = _kie_db()
        _add(c, "d_lc", "x/NCERT_Class10_jemh1dd.zip", [
            (None, "Consider the pattern.\n5.3 nth Term of an AP\nLet us consider the situation again."),
            (None, "So 1.5 mole Ca2+ ion required = 2 in this calculation of stoichiometry."),
        ])
        sp, _ = S.extract_spine(c, "d_lc")
        self.assertEqual(sp[5]["topics"]["5.3"]["title"], "nth Term of an AP")   # allowlisted 'nth'
        self.assertFalse(any("1.5" in ch["topics"] for ch in sp.values()))       # 'mole ...' is not

    def test_clean_title_splits_glued_words_but_cuts_body_text(self):
        # two heading words glued -> SPLIT (v1 truncated this to 'Checking the Dimensional')
        self.assertEqual(S._clean_title("Checking the DimensionalConsistency of Equations"),
                         "Checking the Dimensional Consistency of Equations")
        # heading ran into body prose -> CUT
        self.assertEqual(S._clean_title("Laws of ExponentsYou know that,102 = 10 x 10"),
                         "Laws of Exponents")


class TestSpineExtraction(unittest.TestCase):
    def test_text_channel_recovers_senior_books_that_have_no_section_path(self):
        """THE v1 REGRESSION: senior books carry no breadcrumb, so v1 saw nothing in class 9-12."""
        c = _kie_db()
        _add(c, "d1", "x/NCERT_Class11_keph1dd.zip", [
            (None, "4.3  THE LAW OF INERTIA\nGalileo studied motion of objects on an inclined plane."),
            (None, "4.4  NEWTON’S FIRST LAW OF MOTION\nGalileo's simple but revolutionary ideas."),
        ])
        sp, _ = S.extract_spine(c, "d1")
        self.assertEqual(sorted(sp[4]["topics"]), ["4.3", "4.4"])
        # recovered from chunk TEXT, not the (absent) section_path breadcrumb. A heading on its own line is
        # legitimately seen by both the line-anchored text channel and the inline channel -> "both".
        self.assertIn(S.extraction_basis(sp[4]), ("text", "inline", "both"))
        self.assertNotEqual(S.extraction_basis(sp[4]), "section_path")

    def test_inline_channel_recovers_headings_glued_to_the_body(self):
        """The NEP Class-9 Science book joins a heading straight onto its first sentence with no line break
        ('6.4 Newton's First Law of MotionNewton's first law...'). Channel B (line-anchored) cannot see it;
        the inline channel + _clean_title recover the real title."""
        c = _kie_db()
        _add(c, "d_in", "x/NCERT_Class9_iesc1dd.zip", [
            (None, "Some intro prose about motion. 6.4 Newton's First Law of MotionNewton's first law of "
                   "motion can be stated as: an object at rest remains at rest."),
        ])
        sp, _ = S.extract_spine(c, "d_in")
        self.assertIn("6.4", sp[6]["topics"])
        self.assertEqual(sp[6]["topics"]["6.4"]["title"], "Newton's First Law of Motion")
        self.assertEqual(S.extraction_basis(sp[6]), "inline")

    def test_heading_with_trailing_period_after_section_number(self):
        """The NCERT Class-12 Maths book prints headings as 'N.M.  Title' — a period AFTER the section
        number ('5.3.  Differentiability', '5.5.  Logarithmic Differentiation'). Without tolerating that
        trailing dot the inline/line channels required whitespace right after the last digit and silently
        dropped every such heading (5.3, 5.5 were absent while 5.3.1 — no trailing dot — survived)."""
        c = _kie_db()
        _add(c, "d_tp", "x/NCERT_Class12_lemh1dd.zip", [
            # inline (glued) channel — trailing dot after 5.3
            (None, "So we conclude the previous section. 5.3.  DifferentiabilityRecall the following facts "
                   "from previous class about the derivative of a real function at a point."),
            # line-anchored channel — heading on its own line, trailing dot after 5.5
            (None, "having discussed products and quotients.\n"
                   "5.5.  Logarithmic Differentiation\n"
                   "In this section we will learn to differentiate a special class of functions."),
        ])
        sp, _ = S.extract_spine(c, "d_tp")
        self.assertIn("5.3", sp[5]["topics"])
        self.assertIn("5.5", sp[5]["topics"])
        self.assertEqual(sp[5]["topics"]["5.3"]["title"], "Differentiability")
        self.assertEqual(sp[5]["topics"]["5.5"]["title"], "Logarithmic Differentiation")

    def test_inline_channel_ignores_figure_refs_and_subnumbers(self):
        """A figure ref ('Fig. 3.21 ...') and a sub-number of a larger number ('5.11.1' -> not '11.1')
        must NOT become sections."""
        c = _kie_db()
        _add(c, "d_fp", "x/NCERT_Class9_iesc1dd.zip", [
            (None, "The result is shown in Fig. 3.21 Tissues in Action across the plate."),
            (None, "As covered in 5.11.1 Elastic and Inelastic Collisions we saw that momentum is conserved."),
        ])
        sp, _ = S.extract_spine(c, "d_fp")
        # neither a spurious chapter 3 section from the figure ref nor an '11.x' from the sub-number
        self.assertNotIn(11, sp)
        self.assertFalse(any("3.21" in ch["topics"] for ch in sp.values()))

    def test_section_path_channel_still_works_and_records_sub_concepts(self):
        c = _kie_db()
        _add(c, "d2", "x/NCERT_Class6_fecu1dd.zip", [
            ("Diversity2 > 2.1\t Diversity in Plants and Animals > 2.2.1\tHow to group plants?", "body"),
        ])
        sp, _ = S.extract_spine(c, "d2")
        self.assertEqual(sorted(sp[2]["topics"]), ["2.1", "2.2.1"])   # 3-level = sub-concept depth
        self.assertEqual(S.extraction_basis(sp[2]), "section_path")

    def test_first_occurrence_wins_so_exercises_cannot_displace_a_section(self):
        c = _kie_db()
        _add(c, "d3", "x/NCERT_Class11_keph1dd.zip", [
            (None, "1.1  INTRODUCTION\nMeasurement of any physical quantity involves comparison."),
            (None, "1.1 Fill in the blanks\nThe volume of a cube of side 1 cm is equal to..."),
        ])
        sp, _ = S.extract_spine(c, "d3")
        self.assertEqual(sp[1]["topics"]["1.1"]["title"], "INTRODUCTION")

    def test_cumulative_breadcrumb_does_not_park_the_whole_book_in_chapter_one(self):
        """REGRESSION. `section_path` is CUMULATIVE — a chunk inside chapter 3 still carries
        '1.1 ... > 2.1 ... > 3.1 ...'. Treating any mentioned segment as the chunk's owner made chapter 1
        swallow 307 of 315 chunks in the class-9 maths book and left chapters 2-8 with ZERO evidence, so
        the engineer received headings with no text and could only fence them off as uncertified.
        Only the LAST numbered segment owns the chunk."""
        c = _kie_db()
        _add(c, "d7", "x/NCERT_Class9_iemh1dd.zip", [
            ("1.1 Number Line", "chapter one body"),
            ("1.1 Number Line > 2.1 Polynomials", "chapter two body"),
            ("1.1 Number Line > 2.1 Polynomials > 3.1 Coordinate Geometry", "chapter three body"),
        ])
        sp, _ = S.extract_spine(c, "d7")
        self.assertEqual(sorted(sp), [1, 2, 3])
        for ch in (1, 2, 3):
            self.assertEqual(len(sp[ch]["chunk_ids"]), 1, f"chapter {ch} must own exactly its own chunk")

    def test_every_section_gets_its_own_evidence_not_the_chapter_opening(self):
        """REGRESSION. Sections 2.1 and 2.2 were handed byte-identical text, because a missing anchor
        fell back to the chapter's first chunk. Distinct sections must yield distinct evidence."""
        c = _kie_db()
        _add(c, "d8", "x/NCERT_Class7_gegp1dd.zip", [
            ("2.1 Arithmetic Expressions", "AAA the first section is about arithmetic expressions"),
            ("2.1 Arithmetic Expressions > 2.2 Terms and Brackets", "BBB the second section is about terms"),
        ])
        sp, _ = S.extract_spine(c, "d8")
        sev = S.section_evidence(c, sp[2])
        self.assertEqual(sorted(sev), ["2.1", "2.2"])
        self.assertNotEqual(sev["2.1"]["text"], sev["2.2"]["text"])
        self.assertNotEqual(sev["2.1"]["chunk_id"], sev["2.2"]["chunk_id"])

    def test_junk_is_rejected_and_kept_as_evidence(self):
        c = _kie_db()
        _add(c, "d4", "x/NCERT_Class7_gesc1dd.zip", [
            ("Chapter > Contributors > Try These > 3.1 Balanced Diet", "body"),
        ])
        sp, rejects = S.extract_spine(c, "d4")
        self.assertEqual(sorted(sp[3]["topics"]), ["3.1"])
        classes = {r["reject_class"] for r in rejects}
        self.assertIn("front_matter", classes)      # Contributors
        self.assertIn("activity_label", classes)    # Try These
        self.assertTrue(all(r["rejected_by"] == "deterministic" for r in rejects))

    def test_unnumbered_book_admits_nothing(self):
        """The real class-9 Science book: every heading is 'Think It Over' / 'Ready to Go Beyond'. It
        carries no numbered section anywhere, so it must yield NO taught-at claims at all — a low
        coverage number here is the honest answer, not something to paper over."""
        c = _kie_db()
        _add(c, "d5", "x/NCERT_Class9_iesc1dd.zip", [("Chapter > Think It Over > Ready to Go Beyond", "b")])
        sp, rejects = S.extract_spine(c, "d5")
        self.assertEqual(sp, {})
        self.assertTrue(any(r["reject_class"] == "activity_label" for r in rejects))

    def test_numbered_chapter_without_any_numbered_topic_is_unsupported(self):
        c = _kie_db()
        _add(c, "d6", "x/NCERT_Class8_hesc1dd.zip", [("CHAPTER 5 > Think It Over", "body text")])
        sp, rejects = S.extract_spine(c, "d6")
        self.assertEqual(sp, {})
        self.assertTrue(any(r["reject_class"] == "unsupported" for r in rejects))


class TestSchema(unittest.TestCase):
    def test_migration_is_idempotent_and_backfills_only_provable_disciplines(self):
        c = SC.open_index(":memory:")
        c.execute("INSERT INTO ki_source VALUES ('d','p','hemh1dd','Mathematics',8,'code',0,10,'t')")
        c.execute("INSERT INTO ki_chapter (chapter_id,subject,taught_at_class,chapter_no,title,doc_id,"
                  "status,created_at) VALUES ('CH','Mathematics',8,1,'T','d','accepted','t')")
        for cid, subj in (("KC_a", "Mathematics"), ("KC_b", "Science")):
            c.execute("INSERT INTO ki_concept (concept_id,chapter_id,subject,taught_at_class,canonical_name,"
                      "evidence_chunks,engineer_model,status,created_at) VALUES (?,'CH',?,8,'N','[]','m',"
                      "'proposed','t')", (cid, subj))
        c.commit()
        first = SC.migrate(c)
        self.assertEqual(SC.migrate(c)["columns_added"], [], "migrate must be idempotent")

        # single-subject Maths: discipline == subject BY PROOF, full confidence
        row = c.execute("SELECT academic_discipline, discipline_confidence FROM ki_concept "
                        "WHERE concept_id='KC_a'").fetchone()
        self.assertEqual((row[0], row[1]), ("Mathematics", 1.0))
        # integrated Science: NOT back-filled — a discipline here must be inferred and audited, never assumed
        self.assertIsNone(c.execute("SELECT academic_discipline FROM ki_concept "
                                    "WHERE concept_id='KC_b'").fetchone()[0])
        self.assertGreaterEqual(first["backfilled"], 1)

    def test_evidence_gap_is_split_out_of_the_curriculum_boundary(self):
        """`out_of_scope` means "the class does not cover X" — a generator refuses X on the strength of it.
        "X is not printed in this evidence" means the opposite (the class DOES teach X; our OCR missed the
        detail). Engineers wrote the latter into the former, which would make a generator refuse real
        syllabus topics (Henry's law, Faraday's laws). They must live in different fields, losing nothing."""
        c = SC.open_index(":memory:")
        c.execute("INSERT INTO ki_source VALUES ('d','p','lech1dd','Chemistry',12,'code',0,10,'t')")
        c.execute("INSERT INTO ki_chapter (chapter_id,subject,taught_at_class,chapter_no,title,doc_id,"
                  "status,created_at) VALUES ('CH','Chemistry',12,1,'Solutions','d','accepted','t')")
        boundary = json.dumps({"in_scope": ["molarity"],
                               "out_of_scope": ["the factor theorem",
                                                "Henry's law constant is not printed in this evidence"]})
        c.execute("INSERT INTO ki_concept (concept_id,chapter_id,subject,taught_at_class,canonical_name,"
                  "boundary,evidence_chunks,engineer_model,status,created_at) VALUES "
                  "('KC_g','CH','Chemistry',12,'Solutions',?,'[\"c1\"]','m','certified','t')", (boundary,))
        c.commit()
        SC.split_evidence_gaps(c)

        row = c.execute("SELECT boundary, evidence_gap FROM ki_concept WHERE concept_id='KC_g'").fetchone()
        oos = json.loads(row[0])["out_of_scope"]
        self.assertEqual(oos, ["the factor theorem"])          # real curriculum boundary survives
        self.assertIn("Henry's law", json.loads(row[1])[0])    # evidence gap preserved, just re-filed
        self.assertEqual(SC.split_evidence_gaps(c), 0)         # idempotent

    def test_progress_ledger_makes_the_build_resumable(self):
        c = SC.open_index(":memory:")
        self.assertFalse(SC.is_done(c, "d1", "engineer"))
        SC.mark(c, "d1", "engineer", "in_progress")
        self.assertFalse(SC.is_done(c, "d1", "engineer"))
        SC.mark(c, "d1", "engineer", "done", "12 chapters")
        self.assertTrue(SC.is_done(c, "d1", "engineer"))

    def test_gaps_are_recorded_permanently(self):
        c = SC.open_index(":memory:")
        SC.record_gap(c, "Chemistry|12|lech2dd", "corrupt_source", "not a zip file", "class 12 organic")
        row = c.execute("SELECT scope, kind, blocks FROM ki_gap").fetchone()
        self.assertEqual(row[0], "Chemistry|12|lech2dd")
        self.assertEqual(row[1], "corrupt_source")


if __name__ == "__main__":
    unittest.main()
