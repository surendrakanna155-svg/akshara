"""R4-1 reconciliation — classification, crosswalk honest-null, per-asset promotion class. Fixture-only tests
build tiny synthetic source stores (no live estate); DB-dependent tests self-skip when qie.db is absent.
"""
from __future__ import annotations

import json
import os
import sqlite3
import tempfile
import unittest

from kie import config
from kie.qie import store as QIE_STORE
from kie.qie.inventory import crosswalk as XW
from kie.qie.inventory import reconcile as RC


def _synth_qie(path):
    """A minimal but real qie.db (full schema) seeded with a handful of assets of each class."""
    conn = QIE_STORE.open_store(path)
    # pilot items: numeric-agree, numeric-wrong(refuted), model-agreement, symbolic-inverse(no payload)
    pilot = [
        ("G1", "IM1", "Physics", "NEET", "REL_OHMS_LAW", "single_step_numerical", "T_VIR",
         "A resistor of 20 ohm carries a steady current of 5 A. The potential difference across it "
         "(in volt) is:", json.dumps({"1": "100", "2": "200", "3": "50", "4": "25"}), "100",
         "fk_ohm", "[]", None, "agree", "deterministic_solver", "det", "2026"),
        ("G2", "IM1", "Physics", "NEET", "REL_OHMS_LAW", "single_step_numerical", "T_VIR",
         "A resistor of 20 ohm carries a steady current of 5 A. The potential difference across it "
         "(in volt) is:", json.dumps({"1": "7", "2": "200", "3": "50", "4": "25"}), "7",
         "fk_bad", "[]", None, "agree", "deterministic_solver", "det", "2026"),
        ("G3", "IM2", "Biology", "NEET", "BIO_X", "assertion_reason", "F_bio",
         "Which one of the following is most closely associated with insulin?",
         json.dumps({"1": "pancreas", "2": "liver", "3": "kidney", "4": "lung"}), "pancreas",
         "fk_bio", "[]", None, "agree", "agree", "gen-tier2-2judge", "2026"),
        ("G4", "IM3", "Mathematics", "JEE_MAIN", "CALC_DERIV", "single_step_numerical", "deriv",
         "Differentiate x^2.", json.dumps({"1": "2x", "2": "x", "3": "2", "4": "x^2"}), "2x",
         "fk_calc", "[]", None, "agree", "symbolic_inverse", "sympy", "2026"),
    ]
    conn.executemany(
        "INSERT INTO pilot_verified_item (gen_id,item_model_id,subject,profile,concept_code,archetype,"
        "frame_id,stem,options,answer_text,correct_fact_key,distractor_fact_keys,distractor_provenance,"
        "verifier_verdict,refuter_verdict,verifier_model,created_at) "
        "VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)", pilot)
    # relations: valid(certified), broken(certified-but-fails), rejected
    valid_prov = json.dumps({"store_path": "resources/x.zip", "page": 3})
    rels = [
        ("R1", "Ohm's law", "Physics", "Physics :: Current Electricity", "NEET", "V = I*R", "V=IR", "V",
         json.dumps({"V": "V", "I": "A", "R": "ohm"}), "{}", "[]", "[]", valid_prov, "{}", "certified", None,
         "vt", "2026", "{}"),
        ("R2", "Broken", "Physics", "Physics :: X", "NEET", "V = I", "V=I", "V",
         json.dumps({"V": "V", "I": "A"}), "{}", "[]", "[]", valid_prov, "{}", "certified", None, "vt",
         "2026", "{}"),
        ("R3", "Rejected rel", "Physics", "Physics :: Y", "NEET", "V = I*R", "V=IR", "V",
         json.dumps({"V": "V", "I": "A", "R": "ohm"}), "{}", "[]", "[]", "{}", "{}", "rejected",
         "bad prov", "vt", "2026", "{}"),
    ]
    conn.executemany(
        "INSERT INTO governed_relation (relation_id,name,subject,concept_candidate,exam,equation,display,"
        "lhs_unit,symbols,meanings,constants,constraints,provenance,verification,status,reject_reason,"
        "extractor,created_at,value_ranges) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)", rels)
    # facts: verified(model examiner) + rejected
    conn.executemany(
        "INSERT INTO governed_fact (fact_id,subject,exam,concept_candidate,certified_concept_code,lane,"
        "fact_text,structured,answer_text,distractors,provenance,verification,verifier_model,status,"
        "reject_reason,item_hash,created_at,topic,topic_evidence) "
        "VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
        [("F1", "Biology", "NEET", "Biology :: Endocrine", None, "qual", "insulin lowers glucose", "{}",
          "insulin", "[]", "{}", "{}", "examiner-x", "verified", None, "IHF1", "2026", "Endocrine", "{}"),
         ("F2", "Biology", "NEET", "Biology :: Z", None, "qual", "bad", "{}", "x", "[]", "{}", "{}",
          "examiner-x", "rejected", "bad", "IHF2", "2026", "Z", "{}")])
    # kvs: >=2 refs (eligible) + 0 refs (honest-null)
    conn.executemany(
        "INSERT INTO kvs_assertion (assertion_id,subject_term,predicate,object_term,concept_code,evidence,"
        "evidence_count,created_at) VALUES (?,?,?,?,?,?,?,?)",
        [("K1", "insulin", "lowers", "glucose", "BIO_X", "[]", 2, "2026"),
         ("K2", "x", "rel", "y", "BIO_Y", "[]", 0, "2026")])
    conn.commit()
    conn.close()


class TestCrosswalkHonestNull(unittest.TestCase):
    def test_resolve_and_honest_null(self):
        xw = XW.Crosswalk(version="test", by_name={("Physics", "ohms law"): "KC_test",
                                                   ("Physics", "current electricity"): "KC_ce"})
        self.assertEqual(xw.resolve("Physics", "Physics :: Current Electricity"), "KC_ce")
        self.assertEqual(xw.resolve("Physics", "REL_OHMS_LAW"), "KC_test")     # legacy tail "ohms law"
        self.assertIsNone(xw.resolve("Physics", "UNKNOWN_CODE_XYZ"))           # honest-null, never guessed
        self.assertGreater(xw.resolution_rate, 0.0)


class TestReconcileClassification(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.qie_path = os.path.join(self.tmp, "qie.db")
        _synth_qie(self.qie_path)
        self.qie = sqlite3.connect(f"file:{self.qie_path}?mode=ro", uri=True)
        self.qie.row_factory = sqlite3.Row
        self.xw = XW.Crosswalk(version="test", by_name={("Physics", "current electricity"): "KC_ce"})

    def tearDown(self):
        self.qie.close()

    def _by_id(self, it):
        return {r["source_id"]: r for r in it}

    def test_pilot_classification(self):
        rows = self._by_id(RC.iter_pilot_items(self.qie, self.xw))
        self.assertEqual(rows["G1"]["promotion_status"], "practice_tier_eligible")
        self.assertEqual(rows["G1"]["reverify_ok"], 1)                # numeric agree from rendered content
        self.assertEqual(rows["G1"]["is_deterministic"], 1)
        self.assertEqual(rows["G2"]["promotion_status"], "quarantined")   # wrong answer -> refuted
        self.assertEqual(rows["G2"]["reverify_ok"], 0)
        self.assertEqual(rows["G3"]["promotion_status"], "held_qualitative")  # model agreement -> R4-3
        self.assertEqual(rows["G3"]["is_deterministic"], 0)
        self.assertIsNone(rows["G3"]["reverify_ok"])
        self.assertEqual(rows["G4"]["promotion_status"], "practice_tier_eligible")
        self.assertIsNone(rows["G4"]["reverify_ok"])                  # payload not persisted -> honest-null

    def test_relation_classification(self):
        rows = self._by_id(RC.iter_relations(self.qie, self.xw))
        self.assertEqual(rows["R1"]["promotion_status"], "promotable")
        self.assertEqual(rows["R1"]["evidence_class"], "source_proven")
        self.assertEqual(rows["R1"]["concept_kc"], "KC_ce")          # crosswalk resolved
        self.assertEqual(rows["R2"]["promotion_status"], "quarantined")   # certified-but-no-longer-certifies
        self.assertEqual(rows["R3"]["promotion_status"], "rejected_source")  # rejected evidence preserved

    def test_fact_and_kvs_classification(self):
        facts = self._by_id(RC.iter_facts(self.qie, self.xw))
        self.assertEqual(facts["F1"]["promotion_status"], "held_qualitative")
        self.assertEqual(facts["F1"]["evidence_class"], "model_agreed_on_owned_evidence")
        self.assertEqual(facts["F1"]["is_deterministic"], 0)         # model examiner, never certified here
        self.assertEqual(facts["F2"]["promotion_status"], "rejected_source")
        kvs = self._by_id(RC.iter_kvs(self.qie, self.xw))
        self.assertEqual(kvs["K1"]["promotion_status"], "eligible")  # >=2 source refs
        self.assertEqual(kvs["K2"]["promotion_status"], "held_low_quality")  # 0 refs -> honest-null


@unittest.skipUnless((config.KIE_HOME / "knowledge_index.db").exists(),
                     "frozen knowledge_index.db not present (gitignored / local only)")
class TestLiveCrosswalk(unittest.TestCase):
    def test_live_index_resolves_some_and_reports_rate(self):
        xw = XW.build()
        s = xw.stats()
        self.assertGreater(s["index_concepts"], 0)
        xw.resolve("Physics", "Physics :: Current Electricity")
        self.assertGreaterEqual(xw.resolution_rate, 0.0)


if __name__ == "__main__":
    unittest.main()
