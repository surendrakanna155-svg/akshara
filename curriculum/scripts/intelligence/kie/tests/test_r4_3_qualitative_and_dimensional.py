"""R4-3 — (Lane A) dimensional-gate yield recovery + (Lane B) the qualitative non-model certification lane.

Lane A: the three false-reject unit classes the audit named (angle, percentage, count) are DIMENSIONLESS, so
the dimensional gate must now PASS them — while a genuinely dimension-wrong item MUST still fail (no weakening).

Lane B: a qualitative governed fact can be certified ONLY by an INDEPENDENT, non-model re-derivation
(>=2-source KVS corroboration). Model agreement never certifies; an unfound claim is HELD (honest-null); a
junk/placeholder concept never certifies through on a coincidental match.
"""
from __future__ import annotations

import json
import os
import sqlite3
import tempfile
import unittest

from kie import config
from kie.qie import store as QIE_STORE
from kie.qie.factory.gates import normalize_unit as NU
from kie.qie.convert.notation.dimensions import check_relation as CR
from kie.qie.verifiers import qualitative as Q
from kie.qie.verifiers.protocol import ModelAgreementIsNotAVerifier


def _chk(lhs, rhs, units):
    return CR(NU(lhs), rhs, {k: NU(v) for k, v in units.items()})


class TestDimensionalRecovery(unittest.TestCase):
    def test_angle_percent_count_normalize_to_dimensionless(self):
        for u in ("rad", "radian", "deg", "degree", "%", "percent", "beats", "rev", "cycles"):
            self.assertEqual(NU(u), "1", f"{u} must normalize to dimensionless")

    def test_must_recover_dimensionless_classes(self):
        self.assertTrue(_chk("rad", "a + b", {"a": "rad", "b": "rad"})["ok"], "angle item false-rejected")
        self.assertTrue(_chk("L", "f*V", {"f": "%", "V": "L"})["ok"], "percentage item false-rejected")
        self.assertTrue(_chk("beat/day", "r*k", {"r": "beat/min", "k": "1"})["ok"], "count-rate false-rejected")

    def test_must_still_reject_dimension_wrong(self):
        # the recovery must NOT weaken the gate: a genuinely wrong relation still fails
        self.assertFalse(_chk("m", "t", {"t": "s"})["ok"], "length==time wrongly passed")
        self.assertFalse(_chk("%", "L*2", {"L": "m"})["ok"], "dimensionless==length wrongly passed")
        self.assertFalse(_chk("J", "m*v", {"m": "kg", "v": "m/s"})["ok"], "energy==momentum wrongly passed")

    def test_compound_units_normalize_each_run(self):
        self.assertEqual(NU("beats/min"), "1/s")            # count/time -> dimensionless/time
        self.assertEqual(NU("rev/s"), "1/s")


# ── Lane B: qualitative non-model certification ────────────────────────────────────────────────────────
def _synth_qie(tmp):
    path = os.path.join(tmp, "qie.db")
    c = QIE_STORE.open_store(path)

    def kvs(obj, cc, docs, subj="Biology"):
        c.execute("INSERT INTO kvs_assertion (subject_term, predicate, object_term, concept_code, evidence, "
                  "evidence_count, created_at) VALUES (?,'correct_answer_is',?,?,?,?,'2026-07-21')",
                  (subj, obj, cc, json.dumps(docs), len(docs)))
    kvs("western ghats", "BIO_BIODIVERSITY", ["docA", "docB"])       # 2 docs, both independent of F_CORROB
    kvs("insulin", "BIO_ENDOCRINE", ["docOWN", "docB"])              # 2 docs but one IS the fact's own source
    kvs("immunoglobulin a", "BIO_IMMUNITY", ["docA", "docB", "docC"])  # Biology concept (for x-subject test)
    kvs("seed only", "BIO_X", ["docA"])                              # 1-source: excluded from the index
    # D1: authoritative subject_term=Chemistry DISAGREES with concept_code BIO_* -> must fail closed
    kvs("catalyst term", "BIO_X", ["docA", "docB"], subj="Chemistry")

    def gf(fid, subj, concept, ans, own_doc):
        prov = {"doc_id": own_doc} if own_doc is not None else {}
        c.execute("INSERT INTO governed_fact (fact_id, subject, concept_candidate, lane, fact_text, "
                  "answer_text, provenance, verification, status, created_at) VALUES (?,?,?,?,?,?,?,?,?,?)",
                  (fid, subj, concept, "CLASSIFICATION_TAXONOMIC", "q", ans,
                   json.dumps(prov), json.dumps({"examiner_verdict": "keep"}), "verified", "2026-07-21"))
    gf("F_CORROB", "Biology", "Biology :: Biodiversity", "Western Ghats", "docX")   # 2 independent docs -> certify
    gf("F_OWNDOC", "Biology", "Biology :: Endocrine", "Insulin", "docOWN")          # own-doc excluded -> 1 -> held
    gf("F_XSUBJ", "Physics", "Physics :: Optics", "immunoglobulin a", "docP")       # subject mismatch -> held
    gf("F_SUBJDIS", "Biology", "Biology :: Enzymes", "catalyst term", "docS")       # subject_term=Chem != Bio -> held
    gf("F_NODOC", "Biology", "Biology :: Cells", "Western Ghats", None)             # no source doc -> held (D4)
    gf("F_NONE", "Biology", "Biology :: Genetics", "Autosome", "docY")              # no KVS -> held
    gf("F_JUNK", "Biology", "Biology :: Test", "Western Ghats", "docZ")             # junk concept -> held
    c.commit()
    c.close()
    return path


class TestQualitativeVerifier(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.qie = _synth_qie(self.tmp.name)
        self.conn = sqlite3.connect(f"file:{self.qie}?mode=ro", uri=True)
        self.conn.row_factory = sqlite3.Row
        self.index = Q.build_corroboration_index(self.conn)

    def tearDown(self):
        self.conn.close()
        self.tmp.cleanup()

    def _fact(self, fid):
        return dict(self.conn.execute("SELECT * FROM governed_fact WHERE fact_id=?", (fid,)).fetchone())

    def test_index_respects_two_source_bar_and_keeps_doc_set(self):
        self.assertIn("western ghats", self.index)                  # ec=2 present
        self.assertNotIn("seed only", self.index)                   # ec=1 excluded
        self.assertEqual(self.index["western ghats"][0]["evidence_docs"], {"docA", "docB"})

    def test_independent_corroboration_certifies(self):
        v = Q.reverify_fact(self._fact("F_CORROB"), self.index)     # 2 docs, both != own source docX
        self.assertIs(v.ok, True)
        self.assertEqual(Q.grounding_label(v), Q.GROUNDING_CORROBORATED)

    def test_own_source_doc_is_excluded_from_independence(self):
        # verifier Finding 1: the fact's OWN source doc must not count toward the >=2 independent bar
        v = Q.reverify_fact(self._fact("F_OWNDOC"), self.index)     # {docOWN,docB} - {docOWN} = {docB} = 1
        self.assertIsNone(v.ok, "the fact's own source document was wrongly counted as independent")

    def test_cross_subject_match_refused(self):
        # verifier Finding 2: an answer-string collision on an unrelated-subject concept must never certify
        v = Q.reverify_fact(self._fact("F_XSUBJ"), self.index)      # Physics fact vs BIO_IMMUNITY assertion
        self.assertIsNone(v.ok, "a concept-blind cross-subject match wrongly certified")

    def test_authoritative_subject_term_governs_not_concept_code(self):
        # re-verifier D1: subject_term (Chemistry) is authoritative; a BIO_* concept_code must not override it
        v = Q.reverify_fact(self._fact("F_SUBJDIS"), self.index)    # Biology fact vs subject_term='Chemistry'
        self.assertIsNone(v.ok, "disagreeing subject signals must fail closed, not certify")

    def test_missing_source_doc_holds(self):
        # re-verifier D4: no fact source doc_id => independence unestablishable => HOLD (fail-closed)
        v = Q.reverify_fact(self._fact("F_NODOC"), self.index)
        self.assertIsNone(v.ok, "a fact with no source doc must never certify")

    def test_no_evidence_is_honest_null(self):
        self.assertIsNone(Q.reverify_fact(self._fact("F_NONE"), self.index).ok)

    def test_junk_concept_never_certifies_on_coincidental_match(self):
        self.assertIsNone(Q.reverify_fact(self._fact("F_JUNK"), self.index).ok)

    def test_model_verdict_alone_never_certifies(self):
        # every synthetic fact carries examiner_verdict='keep'; the model 'keep' must not certify F_NONE
        f = self._fact("F_NONE")
        self.assertEqual(json.loads(f["verification"])["examiner_verdict"], "keep")
        self.assertIsNone(Q.reverify_fact(f, self.index).ok)

    def test_model_agreement_record_is_refused(self):
        fact = self._fact("F_CORROB")
        fact["refuter_verdict"] = "agree"                           # a pilot 'agree' (model-agreement) record
        with self.assertRaises(ModelAgreementIsNotAVerifier):
            Q.reverify_fact(fact, self.index)

    def test_yield_report_is_honest_and_conservative(self):
        from kie.qie import qualitative_lane as QL
        rep = QL.yield_report(self.qie)
        self.assertEqual(rep["verified_facts"], 7)
        self.assertEqual(rep["certifiable_now"], 1)                 # only F_CORROB clears every gate
        self.assertEqual(rep["held_awaiting_independent_evidence"], 6)  # OWNDOC+XSUBJ+SUBJDIS+NODOC+NONE+JUNK
        self.assertEqual(rep["certifiable_now"] + rep["held_awaiting_independent_evidence"]
                         + rep["contradicted"], rep["verified_facts"])


# ── LIVE ─────────────────────────────────────────────────────────────────────────────────────────────
_LIVE = all((config.KIE_HOME / n).exists() for n in ("qie.db", "unified_inventory.db"))


@unittest.skipUnless(_LIVE, "live estate not present")
class TestLiveQualitativeGrounding(unittest.TestCase):
    def test_manifest_records_grounding_without_promoting_nondeterministic(self):
        from kie.qie.inventory import manifest as MF
        conn = MF.open_ro()
        try:
            # every corroborated fact stays held_qualitative (needs the full R2 chain for the product bank) —
            # a model-verified (is_deterministic=0) fact never reaches a promotable state
            bad = conn.execute(
                "SELECT COUNT(*) FROM unified_inventory WHERE asset_class='fact' AND is_deterministic=0 "
                "AND promotion_status IN ('promotable','practice_tier_eligible','eligible','promoted')"
            ).fetchone()[0]
            self.assertEqual(bad, 0)
            corrob = conn.execute(
                "SELECT COUNT(*) FROM unified_inventory WHERE qualitative_grounding='independently_corroborated'"
            ).fetchone()[0]
            held = conn.execute(
                "SELECT COUNT(*) FROM unified_inventory WHERE "
                "qualitative_grounding='held_awaiting_independent_evidence'").fetchone()[0]
            self.assertGreaterEqual(corrob + held, 100)             # all 128 verified facts examined
        finally:
            conn.close()


if __name__ == "__main__":
    unittest.main()
