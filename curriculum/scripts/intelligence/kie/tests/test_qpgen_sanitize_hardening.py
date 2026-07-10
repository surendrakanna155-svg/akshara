"""QP engine — Phase 1 sanitizer hardening (deterministic OCR repair + render-time stem gate).

Locks the Phase-1 improvements found by the independent quality audit (2026-07-10):
  * normalize_concept_title() deterministically REPAIRS common OCR/extraction artifacts
    (doubled leading capital, merged possessive, glued caps-run, ALL-CAPS heading, curly
    apostrophe, edge punctuation) so a real concept is cleaned instead of discarded;
  * is_clean_concept() REJECTS genuine sentence fragments / scaffolding that previously leaked
    into student-facing stems (leading discourse adverb, interior finite verb, trailing dangling
    connective, multiword boilerplate);
  * stem_quality_ok() is a render-time gate so no artifact-bearing stem reaches the paper;
  * end-to-end: a KIE seeded with garbage titles ships ZERO garbage stems.

Everything here is deterministic and boundary-preserving (no fabrication, no scope inflation).
"""
import unittest

from kie import store
from kie.qpgen import sanitize
from kie.qpgen.engine import QuestionPaperEngine
from kie.qpgen.models import PaperRequest, SlotStatus, Subject
from kie.intake.store_ext import now_iso


class TestNormalizeConceptTitle(unittest.TestCase):
    def test_repairs_ocr_artifacts(self):
        cases = {
            "FFirst law": "First law",                       # doubled leading capital
            "DDalton's law": "Dalton's law",
            "Newton'sthird law": "Newton's third law",       # merged possessive (straight)
            "Newton’sthird law": "Newton's third law",  # merged possessive (curly)
            "ENERGYConservation": "Energy Conservation",     # glued caps-run split + title-case
            "ACIDS AND BASES": "Acids and Bases",            # ALL-CAPS heading + connective
            "PERMUTATIONS AND COMBINATIONS": "Permutations and Combinations",
            "REFLECTION OF LIGHT": "Reflection of Light",
            "DIVERSITY IN THE LIVING WORLD": "Diversity in the Living World",
            "the Answer sheet.": "the Answer sheet",          # edge punctuation stripped
        }
        for raw, want in cases.items():
            self.assertEqual(sanitize.normalize_concept_title(raw), want, raw)

    def test_normalization_is_idempotent_and_noop_on_clean(self):
        for good in ("Newton's Second Law", "Photosynthesis", "Properties of Rational Numbers",
                     "The Human Eye", "DNA Replication", "IUPAC Nomenclature"):
            self.assertEqual(sanitize.normalize_concept_title(good), good, good)
            once = sanitize.normalize_concept_title(good)
            self.assertEqual(sanitize.normalize_concept_title(once), once, good)

    def test_deterministic(self):
        for t in ("ACIDS AND BASES", "FFirst law", "Newton’sthird law"):
            self.assertEqual(sanitize.normalize_concept_title(t),
                             sanitize.normalize_concept_title(t))


class TestStrengthenedRejection(unittest.TestCase):
    def test_rejects_new_fragment_classes(self):
        # a glued heading+sentence stays junk even after the caps-run split (too many words)
        self.assertFalse(sanitize.is_clean_concept(
            sanitize.normalize_concept_title("LAW OF MOTIONThe first law")))
        for junk in ("Obviously the octet rule",                       # leading discourse adverb
                     "Thisbrings into light the rule",                  # clause preposition
                     "B-Elimination reaction Follows Zaitsev rule",     # interior finite verb
                     "Complex Numbers and", "Some Applications of",     # trailing dangling connective
                     "Miscellaneous Examples", "Solved Exercises",      # trailing scaffold noun
                     "the Answer sheet", "Note to the Teacher",         # multiword boilerplate
                     "Think, Discuss and Write"):
            self.assertFalse(sanitize.is_clean_concept(junk), junk)

    def test_still_accepts_real_concepts_after_normalization(self):
        for raw in ("ACIDS AND BASES", "PERMUTATIONS AND COMBINATIONS", "REFLECTION OF LIGHT",
                    "LAWS OF MOTION", "DIVERSITY IN THE LIVING WORLD", "The Human Eye", "the Atom",
                    "FFirst law", "Newton’sthird law", "Newton's Second Law",
                    "Applications of Derivatives", "Properties of Rational Numbers"):
            self.assertTrue(sanitize.is_clean_concept(sanitize.normalize_concept_title(raw)), raw)

    def test_apostrophe_variants_do_not_change_verdict(self):
        self.assertTrue(sanitize.is_clean_concept("Bernoulli's principle"))
        self.assertTrue(sanitize.is_clean_concept(
            sanitize.normalize_concept_title("Bernoulli’s principle")))


class TestStemQualityGate(unittest.TestCase):
    def test_passes_clean_stems(self):
        for s in ("Explain Electromagnetic Induction in detail with suitable examples.",
                  "A body of mass 12 kg moves with a uniform acceleration of 5 m/s². "
                  "Calculate the net force acting on it.",
                  "Define the pH scale.", "Describe mRNA processing.", "State Ohm's law."):
            self.assertTrue(sanitize.stem_quality_ok(s), s)

    def test_flags_artifact_stems(self):
        for s in ("Explain Newton'sthird law.", "Explain Newton’sthird law.",
                  "Write a short note on FFirst law.", "Describe the Answer sheet..",
                  "Explain LAW OF MOTIONThe first law.", "short"):
            self.assertFalse(sanitize.stem_quality_ok(s), s)


def _seed(conn, code, title, subject):
    conn.execute(
        "INSERT INTO source_documents(doc_id,corpus,rel_path,category,exam,sha256,integrity_ok,"
        "encrypted,is_duplicate,verify_status,certify_status,certify_reason,created_at) "
        "VALUES (?,?,?,?,?,?,1,0,0,'verified','certified','ok',?)",
        (code + "_d", "foundation", "NEET/x.pdf", "NEET", "NEET", code + "s", now_iso()))
    conn.execute(
        "INSERT INTO concepts(concept_code,title,definition,subject_domain,status,evidence,created_at) "
        "VALUES (?,?,?,?, 'active', ?, ?)",
        (code, title, f"the definition of {title}", subject, '{"doc":"%s"}' % (code + "_d"), now_iso()))
    conn.execute(
        "INSERT INTO question_patterns(pattern_id,concept_code,question_type,bloom,difficulty,"
        "frequency,years,evidence) VALUES (?,?,?,?,?,?,?,?)",
        (code + "_p", code, "short_answer", "understand", "medium", 4, "[2022, 2023]", "{}"))


class TestEndToEndNoGarbageStems(unittest.TestCase):
    def test_garbage_titles_never_reach_a_stem(self):
        conn = store.open_store(":memory:")
        # a mix: genuine junk (must be dropped) + OCR-noisy real concepts (must be repaired + kept)
        _seed(conn, "P1", "FFirst law", Subject.PHYSICS)
        _seed(conn, "P2", "Newton’sthird law", Subject.PHYSICS)
        _seed(conn, "P3", "ACIDS AND BASES", Subject.CHEMISTRY)
        _seed(conn, "J1", "Obviously the octet rule", Subject.CHEMISTRY)
        _seed(conn, "J2", "B-Elimination reaction Follows Zaitsev rule", Subject.CHEMISTRY)
        _seed(conn, "J3", "Miscellaneous Examples", Subject.BIOLOGY)
        _seed(conn, "B1", "Photosynthesis", Subject.BIOLOGY)
        conn.commit()

        eng = QuestionPaperEngine(conn=conn)
        paper = eng.generate(PaperRequest(exam="NEET", blueprint_preset="descriptive_40", seed=1))
        titles = {s.concept_title for s in paper.slots}
        # junk never appears
        for junk in ("Obviously the octet rule", "B-Elimination reaction Follows Zaitsev rule",
                     "Miscellaneous Examples"):
            self.assertNotIn(junk, titles)
        # repaired real concepts survive under clean titles
        self.assertIn("First law", titles)
        self.assertIn("Newton's third law", titles)
        self.assertIn("Acids and Bases", titles)
        # every shipped stem passes the render-time quality gate
        for s in paper.slots:
            self.assertTrue(sanitize.stem_quality_ok(s.stem), s.stem)
        self.assertTrue(paper.provenance["validation"]["boundary_ok"])
        conn.close()


if __name__ == "__main__":
    unittest.main()
