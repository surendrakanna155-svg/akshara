"""Lane C — certified-knowledge-bound deterministic generation (W1/W2/W4).

These tests protect the properties that make Lane C output certifiable rather than merely correct-looking.
Each one corresponds to a defect that was actually found and fixed while building the lane, so a regression
here is a return to a known-bad state, not a hypothetical.
"""
from __future__ import annotations

import re
import sqlite3
import unittest

from kie import config
from kie.qie.certgen import assertion_reason as AR
from kie.qie.certgen import binding as B
from kie.qie.certgen import composition as COMP
from kie.qie.certgen import engine as E
from kie.qie.certgen import match_columns as MTC
from kie.qie.certgen import solution as SOL
from kie.qie.factory import gates as G
from kie.qie.knowledge import planner as P

INDEX = config.KIE_HOME / "knowledge_index.db"


def _index():
    c = sqlite3.connect(f"file:{INDEX}?mode=ro", uri=True)
    c.row_factory = sqlite3.Row
    return c


@unittest.skipUnless(INDEX.exists(), f"certified knowledge index not found at {INDEX}")
class TestPlannerDisciplineAxis(unittest.TestCase):
    """W4 — classes 6-10 Physics/Chemistry/Biology were unreachable to every planner call."""

    @classmethod
    def setUpClass(cls):
        cls.c = _index()

    @classmethod
    def tearDownClass(cls):
        cls.c.close()

    def test_subject_keyed_read_still_finds_nothing_for_junior_physics(self):
        # NOT a bug to fix — `subject` is the curriculum SOURCE subject and classes 6-10 print an
        # integrated 'Science' book. This test pins the behaviour so the discipline reader stays necessary.
        self.assertEqual(P.certified_universe(self.c, "Physics", [6, 7, 8, 9, 10]), [])

    def test_discipline_keyed_read_reaches_junior_physics(self):
        u = P.certified_universe_by_discipline(self.c, "Physics", [6, 7, 8, 9, 10])
        self.assertGreater(len(u), 0, "junior Physics concepts must be reachable by discipline")
        self.assertTrue(all(r["academic_discipline"] == "Physics" for r in u))
        self.assertTrue(all(6 <= r["taught_at_class"] <= 10 for r in u))

    def test_discipline_read_spans_six_to_twelve_for_every_requested_subject(self):
        for disc in ("Mathematics", "Physics", "Chemistry", "Biology"):
            u = P.certified_universe_by_discipline(self.c, disc, list(range(6, 13)))
            self.assertGreater(len(u), 0, f"{disc} must be reachable")
            classes = {r["taught_at_class"] for r in u}
            self.assertTrue(classes & {6, 7, 8, 9, 10}, f"{disc} must reach junior classes")
            self.assertTrue(classes & {11, 12}, f"{disc} must reach senior classes")

    def test_discipline_read_never_widens_the_certified_universe(self):
        # it must select on an audited column, NOT relax the certified/accepted predicate
        u = P.certified_universe_by_discipline(self.c, "Mathematics", None)
        rows = self.c.execute(
            "SELECT COUNT(*) FROM ki_concept c JOIN ki_chapter ch ON ch.chapter_id=c.chapter_id "
            "WHERE c.academic_discipline='Mathematics' AND c.status='certified' AND ch.status='accepted'"
        ).fetchone()[0]
        self.assertEqual(len(u), rows)

    def test_discipline_mismatch_is_refused_by_check_plan(self):
        u = P.certified_universe_by_discipline(self.c, "Physics", [8])
        kc = u[0]
        spec = {"concept_id": kc["concept_id"], "concept_name": kc["canonical_name"],
                "subject": kc["subject"], "discipline": "Biology", "class_level": 8,
                "chapter_id": kc["chapter_id"], "archetype": "single_step_numerical",
                "intended_depth": 1, "composition": "single"}
        v = P.check_plan(spec, {kc["concept_id"]: kc})
        self.assertTrue(any("discipline_mismatch" in x for x in v),
                        f"a Physics concept must not fill a Biology spec; got {v}")

    def test_absent_discipline_declaration_is_backwards_compatible(self):
        u = P.certified_universe_by_discipline(self.c, "Physics", [8])
        kc = u[0]
        spec = {"concept_id": kc["concept_id"], "concept_name": kc["canonical_name"],
                "subject": kc["subject"], "class_level": 8, "chapter_id": kc["chapter_id"],
                "archetype": "single_step_numerical", "intended_depth": 1, "composition": "single"}
        self.assertFalse([x for x in P.check_plan(spec, {kc["concept_id"]: kc}) if "discipline" in x])


@unittest.skipUnless(INDEX.exists(), f"certified knowledge index not found at {INDEX}")
class TestBindingGrounding(unittest.TestCase):
    """W1 — a generator template may only fire against a concept whose evidence attests its relation."""

    @classmethod
    def setUpClass(cls):
        cls.c = _index()
        cls.resolved, cls.refusals = B.resolve(cls.c)

    @classmethod
    def tearDownClass(cls):
        cls.c.close()

    def test_every_shipped_binding_resolves_and_grounds(self):
        self.assertEqual(self.refusals, {}, f"shipped bindings must all ground: {self.refusals}")
        self.assertEqual(len(self.resolved), len(B.BINDINGS))

    def test_every_binding_resolves_to_a_real_certified_concept_id(self):
        for rb in self.resolved:
            self.assertTrue(rb.concept_id.startswith("KC_"))
            row = self.c.execute(
                "SELECT status, taught_at_class, academic_discipline FROM ki_concept WHERE concept_id=?",
                (rb.concept_id,)).fetchone()
            self.assertIsNotNone(row)
            self.assertEqual(row["status"], "certified")
            self.assertEqual(row["taught_at_class"], rb.binding.taught_at_class)
            self.assertEqual(row["academic_discipline"], rb.binding.discipline)

    def test_ungrounded_relation_is_refused(self):
        bad = B.BINDINGS[0].__class__(**{**B.BINDINGS[0].__dict__,
                                         "binding_id": "PROBE_UNGROUNDED",
                                         "grounding": ("this string is not in any certified evidence",)})
        r, why = B.resolve_one(self.c, bad)
        self.assertIsNone(r)
        self.assertTrue(any("ungrounded_relation" in w for w in why), why)

    def test_grounding_cannot_be_satisfied_by_the_concept_name_alone(self):
        """The loophole that would let a binding certify itself: 'Kinetic Energy' is a TITLE, and a title
        says nothing about whether K = (1/2)mv^2 is taught at that class."""
        kc = {"canonical_name": "Kinetic Energy", "section_heading": "5.4 Kinetic Energy",
              "sub_concepts": ["something else entirely"], "boundary": {"in_scope": []}}
        self.assertNotIn("kinetic energy", B.evidence_blob(kc))

    def test_unknown_concept_name_is_refused(self):
        bad = B.BINDINGS[0].__class__(**{**B.BINDINGS[0].__dict__,
                                         "binding_id": "PROBE_UNKNOWN",
                                         "concept_name": "A Concept That Does Not Exist"})
        r, why = B.resolve_one(self.c, bad)
        self.assertIsNone(r)
        self.assertTrue(any("unresolved_concept" in w for w in why), why)

    def test_identical_scenarios_are_refused(self):
        b0 = B.BINDINGS[0]
        bad = b0.__class__(**{**b0.__dict__, "binding_id": "PROBE_DUP",
                              "stems": (b0.stems[0], b0.stems[0])})
        r, why = B.resolve_one(self.c, bad)
        self.assertIsNone(r)
        self.assertTrue(any("duplicate_scenarios" in w for w in why), why)


@unittest.skipUnless(INDEX.exists(), f"certified knowledge index not found at {INDEX}")
class TestLaneCGeneration(unittest.TestCase):
    """W2 + the battery — what Lane C emits must survive the SAME gates the factory lane faces."""

    @classmethod
    def setUpClass(cls):
        cls.c = _index()
        cls.resolved, _ = B.resolve(cls.c)
        cls.items = E.generate(cls.resolved, per_binding=3, seed="TEST1")
        cls.gated = E.gate_items(cls.items, resolved=cls.resolved)
        cls.passed = [r for r in cls.gated if r["passed"]]

    @classmethod
    def tearDownClass(cls):
        cls.c.close()

    def test_generation_is_deterministic(self):
        again = E.generate(self.resolved, per_binding=3, seed="TEST1")
        self.assertEqual([i["gen_id"] for i in self.items], [i["gen_id"] for i in again])
        self.assertEqual([i["stem"] for i in self.items], [i["stem"] for i in again])

    def test_no_item_ever_fails_a_fatal_gate(self):
        fatal = {r["gen_id"]: r["fatal"] for r in self.gated if r["fatal"]}
        self.assertEqual(fatal, {}, f"Lane C must never emit a FATAL-failing item: {fatal}")

    def test_items_pass_the_battery(self):
        self.assertGreater(len(self.passed), 0)

    def test_every_item_binds_a_real_certified_concept(self):
        for r in self.gated:
            self.assertTrue(r["concept_id"].startswith("KC_"))
            self.assertEqual(r["claimed"]["concept_ids"], [r["concept_id"]])
            self.assertIn(r["class_level"], range(6, 13))

    def test_every_item_carries_a_complete_solution_terminating_on_the_key(self):
        for r in self.gated:
            steps = r["solution"]["steps"]
            self.assertGreaterEqual(len(steps), 4, "a solution must actually work the problem")
            self.assertEqual(r["solution"]["final"], r["answer_value"])

    def test_the_independent_solver_reproduces_every_key(self):
        for r in self.gated:
            self.assertEqual(r["independent_solve"]["verdict"], "solved", r["gen_id"])
            self.assertTrue(r["independent_solve"]["agree"], r["gen_id"])

    def test_exactly_one_option_is_correct(self):
        for r in self.gated:
            self.assertEqual(len(r["options"]), 4)
            self.assertEqual(len(set(r["options"].values())), 4, "options must be distinct")
            self.assertIn(r["answer_label"], r["options"])

    def test_every_wrong_option_is_proven_by_a_named_misconception(self):
        for r in self.gated:
            res = G.verify_distractors(r["structure"], r["options"], r["answer_label"],
                                       r["distractor_rationale"], uncertifiable=[])
            self.assertTrue(res["ok"], f"{r['gen_id']}: {res['detail']}")

    def test_printed_options_equal_the_values_they_claim(self):
        """The rounding defect: a distractor printed as 0.12 when its misconception computes 0.125 is not
        the option the misconception produces, and the item is no longer honest."""
        for r in self.gated:
            for label, spec in r["distractor_rationale"].items():
                probe = {"givens": {s: v for s, v in r["structure"]["givens"].items()},
                         "relation": spec["mis_relation"], "solve_for": r["structure"]["solve_for"]}
                got = G.independent_solve(probe)
                self.assertEqual(got.get("verdict"), "solved", f"{r['gen_id']} {label}")
                agree, why = G.answers_agree(got["solver_answer"], r["options"][label])
                self.assertTrue(agree, f"{r['gen_id']} option {label}: {why}")

    def test_no_two_passing_items_share_a_normalized_stem(self):
        """`norm_hash` masks numerals, so template flooding must be impossible: variety has to come from
        distinct SCENARIOS, not from fresh numbers."""
        hashes = [G.norm_hash(r["stem"]) for r in self.passed]
        self.assertEqual(len(hashes), len(set(hashes)), "passing items must not be one template repeated")

    def test_key_is_not_identifiable_by_magnitude_alone(self):
        """A key that is always the largest (or smallest) option is guessable without doing the work."""
        extreme = 0
        for r in self.passed:
            vals = sorted(float(v) for v in r["options"].values())
            key = float(r["options"][r["answer_label"]])
            if key in (vals[0], vals[-1]):
                extreme += 1
        self.assertLess(extreme / max(len(self.passed), 1), 0.75,
                        "most keys must sit inside the option range, not at an extreme")

    def test_key_is_never_a_number_already_printed_in_the_stem(self):
        for r in self.gated:
            self.assertFalse(E.key_collides_with_a_given(float(r["answer_value"]), r["_params"]),
                             f"{r['gen_id']}: the answer must not equal one of the givens")

    def test_difficulty_is_recomputable_not_stamped(self):
        for r in self.gated:
            again = E.DIFF.predict(r["reasoning_depth"], 1, misconception_pressure=0.0,
                                   calculation_load=E.DIFF.LANE_CALC_LOAD["STRUCTURED_NUMERIC"])
            self.assertEqual(again["band"], r["difficulty"]["band"])
            self.assertEqual(again["score"], r["difficulty"]["score"])

    def test_provenance_records_the_grounding_and_the_certified_concept(self):
        for r in self.gated:
            prov = r["provenance"]
            self.assertEqual(prov["certified_concept_id"], r["concept_id"])
            self.assertTrue(prov["grounding"])
            self.assertEqual(prov["evidence_class"], E.EVIDENCE_CLASS)
            self.assertEqual(prov["verification"]["roundtrip_substitution"], "agree")

    def test_stem_declares_every_given_and_no_other_number(self):
        for r in self.gated:
            for sym, spec in r["structure"]["givens"].items():
                self.assertIn(SOL.fmt_number(spec["value"]), r["stem"],
                              f"{r['gen_id']}: given {sym} missing from the stem")


@unittest.skipUnless(INDEX.exists(), f"certified knowledge index not found at {INDEX}")
class TestDepthTier(unittest.TestCase):
    """The depth tier — multi-concept chains. Depth must be EARNED by execution, never claimed."""

    @classmethod
    def setUpClass(cls):
        cls.c = _index()
        cls.rb, _ = B.resolve(cls.c)
        cls.rc, cls.chain_refusals = COMP.resolve(cls.c)
        cls.items = E.generate_chains(cls.rc, per_chain=3, seed="TESTK")
        cls.gated = E.gate_items(cls.items, resolved=cls.rb, resolved_chains=cls.rc)
        cls.passed = [r for r in cls.gated if r["passed"]]

    @classmethod
    def tearDownClass(cls):
        cls.c.close()

    def test_every_chain_resolves_and_grounds_every_step(self):
        self.assertEqual(self.chain_refusals, {}, f"chains must all ground: {self.chain_refusals}")

    def test_every_step_binds_a_distinct_certified_concept(self):
        for rc in self.rc:
            self.assertGreaterEqual(len(rc.concept_ids), 2)
            self.assertGreaterEqual(len(set(rc.concept_ids)), 2, "a chain must span >=2 certified concepts")
            for cid in rc.concept_ids:
                row = self.c.execute("SELECT status FROM ki_concept WHERE concept_id=?", (cid,)).fetchone()
                self.assertEqual(row["status"], "certified")

    def test_no_step_is_taught_above_the_questions_class(self):
        for rc in self.rc:
            for st in rc.chain.steps:
                self.assertLessEqual(st.taught_at_class, rc.chain.taught_at_class)

    def test_depth_is_at_least_two_and_earned_by_replay(self):
        for r in self.gated:
            self.assertGreaterEqual(r["reasoning_depth"], 2, "the depth tier must not emit depth-1 items")
            rep = G.replay_steps(r["structure"])
            self.assertTrue(rep["ok"], r["gen_id"])
            self.assertEqual(rep["depth"], r["reasoning_depth"],
                             "claimed depth must equal the depth the DAG actually earned")

    def test_padding_the_step_list_cannot_inflate_depth(self):
        """A flat DAG whose steps all read the givens earns depth 1 no matter how many steps are listed."""
        flat = {"givens": {"a": {"value": 3.0}, "b": {"value": 4.0}},
                "relation": "z = a * b", "solve_for": "z",
                "steps": [{"out": "p", "inputs": ["a", "b"], "relation": "p = a * b"},
                          {"out": "q", "inputs": ["a", "b"], "relation": "q = a + b"},
                          {"out": "z", "inputs": ["a", "b"], "relation": "z = a * b"}]}
        self.assertEqual(G.replay_steps(flat)["depth"], 1)

    def test_the_two_routes_agree_on_every_item(self):
        """Route A (execute the DAG) and route B (solve the composed relation) are derived differently and
        must produce the same key — the core guarantee of the depth tier."""
        for r in self.gated:
            route_a = G.replay_steps(r["structure"])
            self.assertTrue(route_a["ok"])
            route_b = G.independent_solve(
                {"givens": r["structure"]["givens"], "relation": r["structure"]["relation"],
                 "solve_for": r["structure"]["solve_for"]})
            self.assertEqual(route_b.get("verdict"), "solved", r["gen_id"])
            key = float(r["answer_value"])
            self.assertAlmostEqual(float(route_a["final"]), key, delta=0.02 * max(abs(key), 1.0))
            self.assertAlmostEqual(float(route_b["solver_answer"]), key, delta=0.02 * max(abs(key), 1.0))

    def test_a_composed_relation_that_is_not_the_chain_is_refused(self):
        rc0 = self.rc[0]
        broken = COMP.Chain(**{**rc0.chain.__dict__, "composed": rc0.chain.composed + " * 2"})
        rc_broken = COMP.ResolvedChain(**{**rc0.__dict__, "chain": broken})
        self.assertEqual(E.generate_chains([rc_broken], per_chain=3, seed="TESTK"), [])

    def test_multi_composition_claim_is_structurally_backed(self):
        for r in self.gated:
            self.assertEqual(r["claimed"]["composition"], "multi")
            self.assertGreaterEqual(len(r["claimed"]["concept_ids"]), 2)
            gate = [g for g in r["gates"] if g["gate"] == "composition_backed"]
            self.assertTrue(gate and gate[0]["ok"], f"{r['gen_id']}: {gate}")

    def test_depth_tier_items_are_harder_than_easy(self):
        for r in self.gated:
            self.assertIn(r["difficulty"]["band"], ("moderate", "hard"))

    def test_solution_prints_every_intermediate(self):
        for r in self.gated:
            body = " ".join(r["solution"]["steps"])
            for out_sym, val in r["provenance"]["intermediates"].items():
                if out_sym == r["structure"]["solve_for"]:
                    continue
                self.assertIn(SOL.fmt_number(val), body,
                              f"{r['gen_id']}: intermediate {out_sym} must appear in the worked solution")

    def test_no_fatal_or_quarantine_in_the_depth_tier(self):
        bad = {r["gen_id"]: r["fatal"] + r["quarantine"] for r in self.gated if r["fatal"] or r["quarantine"]}
        self.assertEqual(bad, {}, f"depth tier must be clean: {bad}")

    def test_boundary_filter_keeps_genuine_exclusions(self):
        """The chain filter must remove only self-referential records, never a real above-class exclusion.

        It passes records through WHOLE — extracting the claim is `gates._claim_clause`'s job now (W7), so
        there is exactly one implementation of that rule and every caller gets it.
        """
        kept = COMP.chain_boundary_terms(
            ["complex numbers - not introduced until a later class",
             "kinetic energy as a vector - it is a scalar"],
            ["Kinetic Energy"], ["computing the kinetic energy of a moving object"])
        self.assertTrue(any("complex numbers" in k for k in kept),
                        f"a genuine above-class exclusion must survive: {kept}")
        self.assertFalse(any("kinetic energy as a vector" in k for k in kept),
                         f"a record naming the chain's own concept must be dropped: {kept}")

    def test_exclusion_claim_drops_only_the_rationale(self):
        s = ("non-uniform (variable) acceleration - these equations are derived for uniformly accelerated "
             "motion only, and the average-velocity form is flagged as holding for constant acceleration only")
        self.assertEqual(COMP.exclusion_claim(s), "non-uniform (variable) acceleration")
        self.assertEqual(COMP.exclusion_claim("motion in two or three dimensions"),
                         "motion in two or three dimensions")


@unittest.skipUnless(INDEX.exists(), f"certified knowledge index not found at {INDEX}")
class TestAssertionReason(unittest.TestCase):
    """W3 — the key must be COMPUTED. R3-8 retired this family precisely because the frozen builder
    hard-coded it to option (a)."""

    @classmethod
    def setUpClass(cls):
        cls.c = _index()
        cls.rb, _ = B.resolve(cls.c)
        cls.rc, _ = COMP.resolve(cls.c)
        cls.ra, cls.refusals = AR.resolve(cls.c)
        cls.items = AR.generate(cls.ra)
        cls.gated = E.gate_items(cls.items, resolved=cls.rb, resolved_chains=cls.rc)

    @classmethod
    def tearDownClass(cls):
        cls.c.close()

    def test_every_ar_binding_resolves_and_grounds(self):
        self.assertEqual(self.refusals, {}, f"AR bindings must all ground: {self.refusals}")

    def test_the_key_is_not_always_option_a(self):
        """The R3-8 defect, stated as a test: `_ar_family.build` returned option (a) every time."""
        keys = {i["answer_label"] for i in self.items}
        self.assertEqual(keys, {"a", "b", "c", "d"}, f"every key must be reachable; got {keys}")

    def test_the_key_follows_from_the_computed_truth_table(self):
        expected = {(True, True, True): "a", (True, True, False): "b"}
        for it in self.items:
            tt = it["provenance"]["truth_table"]
            trip = (tt["assertion_true"], tt["reason_true"], tt["reason_explains"])
            if trip in expected:
                self.assertEqual(it["answer_label"], expected[trip], it["gen_id"])
            elif tt["assertion_true"] and not tt["reason_true"]:
                self.assertEqual(it["answer_label"], "c", it["gen_id"])
            elif not tt["assertion_true"] and tt["reason_true"]:
                self.assertEqual(it["answer_label"], "d", it["gen_id"])
            else:
                self.fail(f"{it['gen_id']}: unreachable truth table {trip}")

    def test_assertion_truth_is_computed_not_declared(self):
        """Re-run the probe from scratch and require it to reproduce the recorded truth value."""
        for it in self.items:
            probe = it["provenance"]["probe"]
            b = next(x.binding for x in self.ra if x.binding.binding_id == it["binding_id"])
            claim = AR.ScalingClaim("", probe["var"], probe["factor"], probe["claimed_ratio"])
            got = AR.claim_is_true(b.relation, probe["base_params"], b.solve_for, claim)
            self.assertEqual(got, it["provenance"]["truth_table"]["assertion_true"], it["gen_id"])

    def test_a_false_reason_is_provably_not_the_certified_relation(self):
        for ra in self.ra:
            b = ra.binding
            self.assertFalse(AR.relations_equivalent(b.relation, b.reason_false_relation, b.solve_for),
                             f"{b.binding_id}: the 'false' reason is a rearrangement of the certified one")

    def test_option_b_reason_genuinely_cannot_explain_the_assertion(self):
        for ra in self.ra:
            b = ra.binding
            for tc in b.true_claims:
                self.assertFalse(
                    AR.reason_can_express_claim(b.unrelated_relation, tc.var, b.solve_for),
                    f"{b.binding_id}: the option-(b) reason mentions both {tc.var} and {b.solve_for}, "
                    f"so it might explain the assertion")

    def test_every_wrong_option_is_contradicted_by_a_computed_value(self):
        for it in self.items:
            res = AR.verify_options(it)
            self.assertTrue(res["ok"], f"{it['gen_id']}: {res['detail']}")
            self.assertEqual(res["unrefuted"], [], "an unrefuted option is a second correct answer")

    def test_ar_items_clear_the_battery(self):
        bad = {r["gen_id"]: r["fatal"] + r["quarantine"] for r in self.gated if r["fatal"] or r["quarantine"]}
        self.assertEqual(bad, {}, f"AR must be clean: {bad}")

    def test_ar_carries_a_solution_that_tests_all_three_facts(self):
        for r in self.gated:
            body = " ".join(r["solution"]["steps"]).lower()
            self.assertIn("assertion", body)
            self.assertIn("reason", body)
            self.assertIn("explanation link", body)
            self.assertEqual(r["solution"]["final"], r["answer_value"])

    def test_computed_key_items_are_reachable_but_the_frozen_family_is_not(self):
        """The R3-8 lift, exactly as R3-8 worded it: a COMPUTED key is admissible; the frozen builder
        (which cannot have one) stays banned."""
        from kie.qie import retired_families as RF

        # Lane C AR items carry the evidence, so a sanctioned caller may select them
        for it in self.items:
            self.assertTrue(RF.has_computed_key(it), it["gen_id"])
            self.assertFalse(RF.is_retired_item(it),
                             "an AR item with a computed key must be reachable")

        # the frozen families stay unreachable even if they claim a computed key
        for fam in RF.RETIRED_QPGEN_FAMILIES:
            forged = {"frame_id": fam, "archetype": "assertion_reason",
                      "provenance": {"key_derivation": "claimed",
                                     "truth_table": {"assertion_true": True, "reason_true": True,
                                                     "reason_explains": True}}}
            self.assertTrue(RF.is_retired_item(forged),
                            f"{fam} is a defective frozen builder and is never exempt")

        # a bare AR item with NO evidence of a computed key is still retired
        self.assertTrue(RF.is_retired_item({"archetype": "assertion_reason", "provenance": {}}))
        self.assertIn("assertion_reason", RF.RETIRED_ARCHETYPES,
                      "the archetype-level retirement must remain in force for un-evidenced items")


@unittest.skipUnless(INDEX.exists(), f"certified knowledge index not found at {INDEX}")
class TestMatchColumns(unittest.TestCase):
    """The form the measured PYQ corpus uses heavily (11.0% of NEET) and Lane C produced none of."""

    @classmethod
    def setUpClass(cls):
        cls.c = _index()
        cls.rb, _ = B.resolve(cls.c)
        cls.rc, _ = COMP.resolve(cls.c)
        cls.rm, cls.refusals = MTC.resolve(cls.c)
        cls.items = MTC.generate(cls.rm, per_binding=3, seed="TESTM")
        cls.gated = E.gate_items(cls.items, resolved=cls.rb, resolved_chains=cls.rc)

    @classmethod
    def tearDownClass(cls):
        cls.c.close()

    def test_every_match_binding_resolves_and_grounds(self):
        self.assertEqual(self.refusals, {}, f"match bindings must all ground: {self.refusals}")

    def test_every_pair_is_grounded_in_its_own_certified_concept(self):
        for rm in self.rm:
            self.assertEqual(len(rm.concept_ids), 4)
            for cid in rm.concept_ids:
                row = self.c.execute("SELECT status FROM ki_concept WHERE concept_id=?", (cid,)).fetchone()
                self.assertEqual(row["status"], "certified")

    def test_no_pair_is_taught_above_the_questions_class(self):
        for rm in self.rm:
            for pr in rm.binding.pairs:
                self.assertLessEqual(pr.taught_at_class, rm.binding.taught_at_class)

    def test_exactly_one_option_reproduces_the_certified_pairing(self):
        for it in self.items:
            res = MTC.verify_key(it)
            self.assertTrue(res["ok"], f"{it['gen_id']}: {res['detail']}")
            self.assertEqual(len(res["matching"]), 1, "a second matching option is a second correct answer")

    def test_every_wrong_option_names_a_pair_it_contradicts(self):
        for it in self.items:
            self.assertEqual(len(it["distractor_rationale"]), 3)
            for lab, r in it["distractor_rationale"].items():
                self.assertTrue(r["misconception"], f"{it['gen_id']} option {lab} has no stated contradiction")
                self.assertIn("certified relation", r["misconception"])

    def test_the_key_is_never_the_identity_permutation(self):
        """A-I, B-II, C-III, D-IV is guessable without reading either column."""
        for it in self.items:
            m = it["provenance"]["correct_mapping"]
            self.assertFalse(all(m[L] == R for L, R in zip(MTC.LEFT_LABELS, MTC.RIGHT_LABELS)), it["gen_id"])

    def test_distractors_differ_from_the_key_by_one_transposition(self):
        """Partial knowledge must not be enough — every option agrees with the key on two of four."""
        for it in self.items:
            key_map = it["provenance"]["correct_mapping"]
            for lab, text in it["options"].items():
                if lab == it["answer_label"]:
                    continue
                pairs = dict(p.split("-") for p in text.split(", "))
                differing = [L for L in MTC.LEFT_LABELS if pairs[L] != key_map[L]]
                self.assertEqual(len(differing), 2,
                                 f"{it['gen_id']} option {lab}: a transposition changes exactly two pairings")

    def test_list_entries_are_distinct(self):
        """A repeated List-II entry would make more than one permutation correct."""
        for it in self.items:
            rights = re.findall(r"\(I{1,3}V?\)\s([^;\n]+)", it["stem"].split("List-II")[1])
            self.assertEqual(len(rights), len(set(r.strip() for r in rights)), it["gen_id"])

    def test_match_items_clear_the_battery(self):
        bad = {r["gen_id"]: r["fatal"] + r["quarantine"] for r in self.gated if r["fatal"] or r["quarantine"]}
        self.assertEqual(bad, {}, f"match must be clean: {bad}")

    def test_multi_concept_claim_is_structurally_backed_without_arithmetic(self):
        for r in self.gated:
            gate = [g for g in r["gates"] if g["gate"] == "composition_backed"]
            if gate:
                self.assertTrue(gate[0]["ok"], f"{r['gen_id']}: {gate[0]['detail']}")
            self.assertGreaterEqual(len(set(r["claimed"]["composition_components"])), 2)

    def test_nonnumeric_composition_backing_cannot_be_asserted_without_the_concepts(self):
        """The backing is CHECKED: declared components must be real concept ids of this item."""
        forged = {"stem": "x" * 40, "options": {"a": "1", "b": "2", "c": "3", "d": "4"},
                  "answer_label": "a", "structure": {},
                  "claimed": {"composition": "multi", "concepts": ["A", "B"],
                              "concept_ids": ["KC_real1"],
                              "composition_components": ["KC_bogus1", "KC_bogus2"],
                              "archetype": "comparison", "depth": 2}}
        gr = G.run_gates(forged, {"spec": {"lane": "MATCH_COLUMNS", "subject": "Physics"}})
        cb = [g for g in gr if g["gate"] == "composition_backed"]
        self.assertTrue(cb and not cb[0]["ok"],
                        "components not present in the item's own concept_ids must not back a multi claim")


class TestValidatorRepairs(unittest.TestCase):
    """W7 and W10 repaired IN `factory/gates.py`. Each test proves the repair STRENGTHENS the gate: the
    true positive still fires, and a check that was previously impossible now runs."""

    # ── W7: bigram extraction over sentence-length boundary prose ──
    def test_w7_genuine_above_class_exclusion_still_fires(self):
        ev, _base = G._boundary_checks(["integration by parts - not introduced before class 12"],
                                       "Area of a Rectangle")
        labels = [l for _r, l in ev]
        self.assertIn("integration by parts", labels)
        self.assertTrue(any(r.search("Use integration by parts to find the area.") for r, _l in ev))

    def test_w7_rationale_prose_no_longer_generates_tokens(self):
        sent = ("non-uniform (variable) acceleration - these equations are derived for uniformly "
                "accelerated motion only, and the average-velocity form is flagged in the evidence as "
                "holding for constant acceleration only")
        ev, _ = G._boundary_checks([sent], "Kinematic Equations for Uniformly Accelerated Motion")
        labels = [l for _r, l in ev]
        for noise in ("flagged evidence", "evidence holding", "holding constant", "constant acceleration"):
            self.assertNotIn(noise, labels, f"{noise!r} is prose ABOUT the exclusion, not an exclusion")
        self.assertFalse(any(r.search("a constant acceleration of 4 m/s^2") for r, _l in ev),
                         "an in-scope constant-acceleration stem must not be flagged")

    def test_w7_the_exclusion_itself_is_still_checked(self):
        sent = ("non-uniform (variable) acceleration - these equations are derived for uniformly "
                "accelerated motion only")
        ev, _ = G._boundary_checks([sent], "Kinematic Equations for Uniformly Accelerated Motion")
        self.assertTrue(any(r.search("a body under variable acceleration") for r, _l in ev),
                        "a genuinely out-of-scope stem must still be caught")

    def test_w7_claim_clause_leaves_a_separatorless_record_intact(self):
        self.assertEqual(G._claim_clause("motion in two or three dimensions"),
                         "motion in two or three dimensions")

    def test_w7_every_concept_of_a_multi_concept_item_is_protected(self):
        """Passing one title protected only that concept; a chain names several."""
        banned = ["kinetic energy as a vector - it is a scalar"]
        one = [l for _r, l in G._boundary_checks(banned, "Kinematic Equations")[0]]
        many = [l for _r, l in G._boundary_checks(banned, ["Kinematic Equations", "Kinetic Energy"])[0]]
        self.assertIn("kinetic energy", one, "with only the other title, the topic word leaks through")
        self.assertNotIn("kinetic energy", many, "naming both concepts must protect both")

    # ── W10: currency had no dimension, so money relations could not be checked at all ──
    def test_w10_currency_relation_is_now_checkable(self):
        got = G.check_relation(G.normalize_unit("Rs"), "P * (1 + R / 100) ** n",
                               {"P": G.normalize_unit("Rs"), "R": G.normalize_unit("%"),
                                "n": G.normalize_unit("1")})
        self.assertTrue(got["ok"], got)

    def test_w10_a_real_dimensional_mismatch_in_a_money_relation_now_fails(self):
        """Previously unparseable => never compared => silently unchecked. Now it is caught."""
        got = G.check_relation(G.normalize_unit("Rs"), "P * s",
                               {"P": G.normalize_unit("Rs"), "s": G.normalize_unit("m")})
        self.assertFalse(got["ok"])
        self.assertIn("differ", got["reason"])

    def test_w10_does_not_make_unrelated_units_dimensionless(self):
        for u, base in (("cm", "m"), ("kg", "kg"), ("N", "N"), ("ohm", "ohm"), ("J", "J")):
            self.assertEqual(G.normalize_unit(u), base)
            self.assertNotEqual(G.normalize_unit(u), "1")


class TestIndependentChecks(unittest.TestCase):
    """The re-derivations must actually be able to FAIL — a check that cannot fail proves nothing."""

    def test_roundtrip_rejects_a_wrong_key(self):
        params = {"l": 6.0, "w": 5.0}
        self.assertTrue(E.roundtrip_agrees("A = l * w", params, "A", 30.0))
        self.assertFalse(E.roundtrip_agrees("A = l * w", params, "A", 31.0))

    def test_roundtrip_rejects_an_off_by_rounding_key(self):
        params = {"m": 80.0, "V": 10.0}
        self.assertTrue(E.roundtrip_agrees("D = m / V", params, "D", 8.0))
        self.assertFalse(E.roundtrip_agrees("D = m / V", params, "D", 8.5))

    def test_ambiguous_root_is_refused(self):
        # x**2 = 16 has two real roots of equal magnitude and opposite sign; only the positive one is a
        # physical magnitude, but a relation with two DISTINCT positive roots must never guess.
        self.assertIsNone(E.solve_for_key("y = (x - 2) * (x - 8)", {"y": 0.0}, "x"))

    def test_fmt_exact_refuses_to_print_a_value_it_cannot_represent(self):
        self.assertEqual(SOL.fmt_exact(8.0, 2), "8")
        self.assertEqual(SOL.fmt_exact(0.125, 2), "0.125")     # NOT '0.12'
        self.assertIsNone(SOL.fmt_exact(1e-12, 2, max_dp=3))

    def test_pretty_equation_does_not_change_the_stored_relation(self):
        eq = "K = m * v ** 2 / 2"
        self.assertEqual(SOL.pretty_equation(eq), "K = m x v ^ 2 / 2")
        self.assertEqual(G.independent_solve(
            {"givens": {"m": {"value": 2}, "v": {"value": 3}}, "relation": eq,
             "solve_for": "K"})["solver_answer"], 9.0)


if __name__ == "__main__":
    unittest.main()


class TestCorpusStemDNA(unittest.TestCase):
    """The corpus miner. It must recover stems WITHOUT ever inventing a key or a concept link."""

    def test_segmentation_splits_on_question_markers_only(self):
        from kie.qie.pyq import stem_dna as SD
        txt = ("1. A body of mass 2.5 kg moves at 4 m/s. Find its kinetic energy.\n"
               "2. Two cars start from the same point. At what time are their speeds equal?")
        segs = SD.segment_chunk(txt)
        self.assertEqual(sorted(segs), [1, 2])
        # "2.5 kg" inside question 1 must NOT be read as the start of question 5
        self.assertIn("2.5 kg", segs[1])
        self.assertNotIn(5, segs)

    def test_boilerplate_is_flagged_not_mined(self):
        from kie.qie.pyq import stem_dna as SD
        row = {"item_id": "x", "exam": "NEET", "year": 2016, "question_number": 15,
               "question_type": "mcq", "chunk_ids": '["d#0"]'}
        text = "15. The candidates will write the correct Test Booklet Code in the Attendance Sheet."
        ms = SD.mine_stem(row, {"d#0": text})
        self.assertIsNotNone(ms)
        self.assertTrue(ms.is_boilerplate, "exam instructions must never be mined as a question")

    def test_concept_matching_refuses_single_word_names(self):
        """'Ray' would fire on every stem containing the word ray; 'Series' on any series."""
        from kie.qie.pyq import stem_dna as SD
        matchers = SD.build_concept_matchers([
            {"concept_id": "KC_a", "canonical_name": "Ray", "taught_at_class": 6},
            {"concept_id": "KC_b", "canonical_name": "Series", "taught_at_class": 11},
            {"concept_id": "KC_c", "canonical_name": "Kinetic Energy", "taught_at_class": 11}])
        names = {n for _p, _c, n, _cl in matchers}
        self.assertNotIn("Ray", names)
        self.assertNotIn("Series", names)
        self.assertIn("Kinetic Energy", names)

    def test_concept_link_requires_the_full_name_on_word_boundaries(self):
        from kie.qie.pyq import stem_dna as SD
        matchers = SD.build_concept_matchers(
            [{"concept_id": "KC_c", "canonical_name": "Kinetic Energy", "taught_at_class": 11}])
        self.assertEqual(SD.link_concepts("Find the kinetic energy of the body.", matchers), ["KC_c"])
        self.assertEqual(SD.link_concepts("Find the potential energy of the body.", matchers), [])

    def test_the_miner_never_produces_an_answer_key(self):
        """Keys are treated as permanently unavailable (owner decision 2026-07-29)."""
        from kie.qie.pyq import stem_dna as SD
        row = {"item_id": "x", "exam": "NEET", "year": 2016, "question_number": 1,
               "question_type": "mcq", "chunk_ids": '["d#0"]'}
        ms = SD.mine_stem(row, {"d#0": "1. What is the SI unit of force?\n(1) newton\n(2) joule"})
        self.assertIsNotNone(ms)
        for field in ("answer", "answer_label", "key", "options"):
            self.assertFalse(hasattr(ms, field), f"the miner must not expose {field}")
        self.assertNotIn("newton", ms.stem, "options are cut: they are OCR-damaged and are not mined")


@unittest.skipUnless(INDEX.exists(), f"certified knowledge index not found at {INDEX}")
class TestConceptualMCQ(unittest.TestCase):
    """Priority 1 — the dominant real form, built by falsification, with the uncertifiable half excluded."""

    @classmethod
    def setUpClass(cls):
        from kie.qie.certgen import conceptual_mcq as CMC
        cls.CMC = CMC
        cls.c = _index()
        cls.rb, _ = B.resolve(cls.c)
        cls.rc, _ = COMP.resolve(cls.c)
        cls.rq, cls.refusals = CMC.resolve(cls.c)
        cls.items = CMC.generate(cls.rq, per_binding=3, seed="TESTQ")
        cls.gated = E.gate_items(cls.items, resolved=cls.rb, resolved_chains=cls.rc)

    @classmethod
    def tearDownClass(cls):
        cls.c.close()

    def test_bindings_resolve_and_ground(self):
        self.assertEqual(self.refusals, {}, f"conceptual bindings must all ground: {self.refusals}")

    def test_items_clear_the_battery(self):
        bad = {r["gen_id"]: r["fatal"] + r["quarantine"] for r in self.gated if r["fatal"] or r["quarantine"]}
        self.assertEqual(bad, {}, f"conceptual MCQ must be clean: {bad}")

    def test_every_wrong_option_survives_neither_falsification_check(self):
        """Not equivalent to the certified relation AND computes a different value at the probe."""
        for rq in self.rq:
            b = rq.binding
            for f in b.falsifications:
                ok, why = self.CMC.falsification_holds(b.relation, f.relation, b.solve_for, b.probe_params)
                self.assertTrue(ok, f"{b.binding_id}: {f.text!r} is not provably false — {why}")

    def test_a_rearrangement_of_the_certified_relation_is_refused(self):
        """V = I*R written as I = V/R is the SAME claim; it must never be offered as a wrong option."""
        ok, why = self.CMC.falsification_holds("V = I * R", "V = I * R", "V", {"I": 3.0, "R": 8.0})
        self.assertFalse(ok, why)

    def test_the_key_is_the_certified_expression(self):
        for it in self.items:
            if it["provenance"]["variant"] != "relation_identification":
                continue
            b = next(x.binding for x in self.rq if x.binding.binding_id == it["binding_id"])
            self.assertEqual(it["options"][it["answer_label"]], b.correct_text)

    def test_no_numbers_are_supplied_for_relation_identification(self):
        """The form tests whether the relation is held, not whether arithmetic can be done."""
        for it in self.items:
            if it["provenance"]["variant"] != "relation_identification":
                continue
            self.assertEqual(it["structure"], {}, "no givens may be declared")

    def test_reachability_separation_excludes_factual_recall(self):
        """A concept whose evidence states no relation must never back a conceptual MCQ."""
        kc_factual = {"concept_id": "KC_x", "canonical_name": "Class Chondrichthyes",
                      "sub_concepts": ["cartilaginous endoskeleton", "placoid scales"],
                      "boundary": {"in_scope": ["recognising the class"]}}
        kc_relation = {"concept_id": "KC_y", "canonical_name": "Ohm's Law",
                       "sub_concepts": ["V = IR and resistance R"], "boundary": {"in_scope": []}}
        self.assertFalse(self.CMC.concept_states_a_relation(kc_factual))
        self.assertTrue(self.CMC.concept_states_a_relation(kc_relation))
        r = self.CMC.classify_reachability([kc_factual, kc_relation])
        self.assertIn("KC_y", r.relation_reachable)
        self.assertIn("KC_x", r.factual_only)

    def test_proportionality_key_is_computed_from_the_relation(self):
        for it in self.items:
            if it["provenance"]["variant"] != "proportionality":
                continue
            b = next(x.binding for x in self.rq if x.binding.binding_id == it["binding_id"])
            phrase, factor, ratio = b.scaling_true
            got = AR.claim_is_true(b.relation, b.probe_params, b.solve_for,
                                   AR.ScalingClaim(phrase, b.scaling_var, factor, ratio))
            self.assertTrue(got)
            self.assertEqual(it["options"][it["answer_label"]], phrase)


class TestStemEnrichment(unittest.TestCase):
    """Priority 2 — the measured 0.47x information-density gap."""

    def test_setup_condition_ask_order(self):
        out = SOL.enrich_stem("A resistor carries 4 A. What is the potential difference?",
                              elaboration="A student sets up a simple circuit.",
                              condition="The temperature stays constant.")
        self.assertTrue(out.startswith("A student sets up a simple circuit."))
        self.assertTrue(out.endswith("What is the potential difference?"))
        self.assertLess(out.index("The temperature stays constant."),
                        out.index("What is the potential difference?"),
                        "a stated condition belongs before the ask, where a setter puts it")

    def test_enrichment_never_drops_the_question(self):
        base = "A body of mass 4 kg moves at 5 m/s. What is its kinetic energy, in joule?"
        for el, cond in (("", ""), ("Context.", ""), ("", "Condition."), ("Context.", "Condition.")):
            out = SOL.enrich_stem(base, el, cond)
            self.assertTrue(out.endswith("What is its kinetic energy, in joule?"))
            self.assertIn("4 kg", out)
            self.assertIn("5 m/s", out)

    def test_enrichment_is_a_no_op_without_parts(self):
        base = "A body moves. What is its speed?"
        self.assertEqual(SOL.enrich_stem(base), base)


@unittest.skipUnless(INDEX.exists(), f"certified knowledge index not found at {INDEX}")
class TestPrereqGraphIntegration(unittest.TestCase):
    """The prerequisite-graph bridge — the first repository integration."""

    @classmethod
    def setUpClass(cls):
        from kie.qie.knowledge import prereq_bridge as PB
        cls.PB = PB
        cls.c = _index()
        cls.uni = []
        for d in ("Physics", "Chemistry", "Mathematics", "Biology"):
            cls.uni += P.certified_universe_by_discipline(cls.c, d, list(range(6, 13)))
        cls.by = {x["concept_id"]: x for x in cls.uni}
        cls.g = PB.load(certified_ids=set(cls.by))

    @classmethod
    def tearDownClass(cls):
        cls.c.close()

    def test_graph_loads_and_is_kc_native(self):
        self.assertTrue(self.g.loaded)
        self.assertGreater(self.g.n_edges, 0)
        for src, dsts in self.g.edges.items():
            self.assertIn(src, self.by, "every edge source must be a CERTIFIED concept")
            for d in dsts:
                self.assertIn(d, self.by, "every edge target must be a CERTIFIED concept")

    def test_absent_graph_reproduces_prior_behaviour(self):
        """The reversibility guarantee: no graph file -> empty graph -> planner unchanged."""
        empty = self.PB.load(db_path="/nonexistent/graph.db")
        self.assertFalse(empty.loaded)
        self.assertEqual(empty.n_edges, 0)
        self.assertEqual(empty.prerequisites("KC_anything"), frozenset())
        self.assertEqual(empty.depth("KC_anything"), 0)
        self.assertFalse(empty.related("KC_a", "KC_b"))

    def test_ambiguous_and_unresolved_edges_are_excluded(self):
        """The graph builder refused to guess; this bridge must not guess on its behalf."""
        self.assertEqual(self.PB._TRUSTED_METHODS, ("subject_name", "cross_subject_unique"))

    def test_universe_records_carry_resolved_prereqs_and_depth(self):
        withp = [x for x in self.uni if x["prereq_ids"]]
        self.assertGreater(len(withp), 500, "the graph must actually attach to the universe")
        for x in self.uni:
            self.assertIsInstance(x["prereq_ids"], list)
            self.assertIsInstance(x["prereq_depth"], int)
            self.assertGreaterEqual(x["prereq_depth"], 0)

    def test_traversal_is_cycle_safe(self):
        """`prereq_edge` is not guaranteed acyclic; every traversal must terminate."""
        cyc = self.PB.PrereqGraph(edges={"A": frozenset({"B"}), "B": frozenset({"A"})},
                                  loaded=True, n_edges=2, n_concepts=2)
        self.assertLessEqual(cyc.depth("A"), self.PB._MAX_CHAIN)
        self.assertEqual(cyc.transitive_prerequisites("A"), {"A", "B"})
        self.assertTrue(cyc.related("A", "B"))

    def test_a_concept_is_not_its_own_prerequisite(self):
        for src, dsts in self.g.edges.items():
            self.assertNotIn(src, dsts)

    def test_backing_check_never_fires_when_the_graph_cannot_speak_about_both(self):
        """The corrected fail-open rule. An earlier version used OR and wrongly refused two legitimate
        chains because ONE side had no recorded prerequisites."""
        known = [c for c in self.uni if c["prereq_ids"]]
        unknown = [c for c in self.uni if not c["prereq_ids"] and c["subject"] == known[0]["subject"]]
        self.assertTrue(known and unknown, "fixture needs one known and one unknown same-subject concept")
        a, b = known[0], unknown[0]
        spec = {"concept_id": a["concept_id"], "concept_name": a["canonical_name"],
                "subject": a["subject"], "class_level": max(a["taught_at_class"], b["taught_at_class"]),
                "chapter_id": a["chapter_id"], "archetype": "multi_concept_integration",
                "intended_depth": 2, "composition": "multi", "compose_with": [b["concept_id"]]}
        v = [x for x in P.check_plan(spec, self.by) if "prerequisite_backed" in x]
        self.assertEqual(v, [], "a gap in the graph must never refuse a composition")

    def test_every_shipped_chain_survives_the_backing_check(self):
        rc, _ = COMP.resolve(self.c)
        for r in rc:
            ids = list(dict.fromkeys(r.concept_ids))
            if len(ids) < 2:
                continue
            kc = self.by[ids[0]]
            spec = {"concept_id": ids[0], "concept_name": kc["canonical_name"],
                    "subject": kc["subject"], "class_level": r.chain.taught_at_class,
                    "chapter_id": kc["chapter_id"], "archetype": "multi_concept_integration",
                    "intended_depth": 2, "composition": "multi", "compose_with": ids[1:]}
            v = [x for x in P.check_plan(spec, self.by) if "prerequisite_backed" in x]
            self.assertEqual(v, [], f"{r.chain.binding_id} must remain legal: {v}")


@unittest.skipUnless(INDEX.exists(), f"certified knowledge index not found at {INDEX}")
class TestAnswerFormats(unittest.TestCase):
    """Integer-entry and multi-correct — the two highest-value missing examined formats."""

    @classmethod
    def setUpClass(cls):
        from kie.qie.certgen import answer_formats as AF
        cls.AF = AF
        cls.c = _index()
        cls.rb, _ = B.resolve(cls.c)
        cls.rc, _ = COMP.resolve(cls.c)
        cls.ints = AF.generate_integer(cls.rb, 2, "TESTI")
        cls.msqs = AF.generate_multi_correct(cls.rb, 1, "TESTS")
        cls.gi = E.gate_items(cls.ints, resolved=cls.rb, resolved_chains=cls.rc)
        cls.gm = E.gate_items(cls.msqs, resolved=cls.rb, resolved_chains=cls.rc)

    @classmethod
    def tearDownClass(cls):
        cls.c.close()

    # ── integer entry ──
    def test_integer_items_clear_the_battery(self):
        bad = {r["gen_id"]: r["fatal"] + r["quarantine"] for r in self.gi if r["fatal"] or r["quarantine"]}
        self.assertEqual(bad, {}, f"integer items must be clean: {bad}")

    def test_integer_items_offer_no_options(self):
        for r in self.gi:
            self.assertEqual(r["options"], {}, "a numerical-entry item must not print options")
            self.assertIsNone(r["answer_label"])

    def test_integer_items_declare_a_sane_tolerance(self):
        for r in self.gi:
            tol = float(r["answer_tolerance"])
            key = abs(float(r["answer_value"]))
            self.assertGreater(tol, 0)
            self.assertLessEqual(tol, max(0.02 * key, 1e-6),
                                 "a tolerance wide enough to admit a different answer is not a tolerance")

    def test_integer_key_is_reproducible_from_the_structure(self):
        for r in self.gi:
            res = self.AF.verify_integer_key(r)
            self.assertTrue(res["ok"], f"{r['gen_id']}: {res['detail']}")

    def test_integer_gate_refuses_an_item_that_prints_options(self):
        cand = {"answer_format": G.INTEGER_ENTRY, "stem": "x" * 40, "claimed": {"archetype": "x"},
                "answer_value": "12", "answer_tolerance": 0.05, "options": {"a": "1", "b": "2"}}
        gr = G.run_gates(cand, {"spec": {"subject": "Physics"}})
        os_gate = [g for g in gr if g["gate"] == "option_structure"]
        self.assertTrue(os_gate and not os_gate[0]["ok"])

    def test_integer_gate_refuses_a_missing_tolerance(self):
        cand = {"answer_format": G.INTEGER_ENTRY, "stem": "x" * 40, "claimed": {"archetype": "x"},
                "answer_value": "12", "options": {}}
        gr = G.run_gates(cand, {"spec": {"subject": "Physics"}})
        os_gate = [g for g in gr if g["gate"] == "option_structure"]
        self.assertTrue(os_gate and not os_gate[0]["ok"], "an undeclared tolerance must be refused")

    # ── multi-correct ──
    def test_multi_correct_items_clear_the_battery(self):
        bad = {r["gen_id"]: r["fatal"] + r["quarantine"] for r in self.gm if r["fatal"] or r["quarantine"]}
        self.assertEqual(bad, {}, f"multi-correct items must be clean: {bad}")

    def test_multi_correct_has_four_options_and_two_or_three_keys(self):
        for r in self.gm:
            self.assertEqual(len(r["options"]), 4)
            self.assertTrue(2 <= len(r["answer_labels"]) <= 3)
            self.assertTrue(set(r["answer_labels"]) <= set(r["options"]))

    def test_no_option_is_both_correct_and_refuted(self):
        for r in self.gm:
            self.assertFalse(set(r["answer_labels"]) & set(r["distractor_rationale"]))

    def test_multi_correct_key_truth_is_recomputable(self):
        """Every correct option must survive re-derivation from the certified relation."""
        for r in self.gm:
            res = self.AF.verify_multi_correct_key(r)
            self.assertTrue(res["ok"], f"{r['gen_id']}: {res['detail']}")

    def test_multi_correct_gate_refuses_a_single_key(self):
        cand = {"answer_format": G.MULTI_CORRECT, "stem": "x" * 40, "claimed": {"archetype": "x"},
                "options": {"a": "1", "b": "2", "c": "3", "d": "4"}, "answer_labels": ["a"]}
        gr = G.run_gates(cand, {"spec": {"subject": "Physics"}})
        os_gate = [g for g in gr if g["gate"] == "option_structure"]
        self.assertTrue(os_gate and not os_gate[0]["ok"],
                        "one correct option is a single-correct item, not a multi-correct one")

    def test_multi_correct_gate_refuses_all_four_correct(self):
        cand = {"answer_format": G.MULTI_CORRECT, "stem": "x" * 40, "claimed": {"archetype": "x"},
                "options": {"a": "1", "b": "2", "c": "3", "d": "4"},
                "answer_labels": ["a", "b", "c", "d"]}
        gr = G.run_gates(cand, {"spec": {"subject": "Physics"}})
        os_gate = [g for g in gr if g["gate"] == "option_structure"]
        self.assertTrue(os_gate and not os_gate[0]["ok"], "all-correct tests nothing and must be refused")

    # ── the default must be untouched ──
    def test_absent_answer_format_behaves_exactly_as_single_correct(self):
        self.assertEqual(G.answer_format_of({}), G.SINGLE_CORRECT)
        self.assertEqual(G.answer_format_of({"answer_format": "nonsense"}), G.SINGLE_CORRECT)
        self.assertEqual(G._REQUIRED, ("stem", "options", "answer_label", "claimed"))

    def test_a_scaling_probe_outside_a_relation_domain_returns_none_not_a_crash(self):
        """Scaling the r of n!/(n-r)! drives mpmath to a gamma pole; the honest answer is 'unverifiable'."""
        self.assertIsNone(AR._solve("P = factorial(n) / factorial(n - r)", {"n": 5.0, "r": 20.0}, "P"))


@unittest.skipUnless(INDEX.exists(), f"certified knowledge index not found at {INDEX}")
class TestStatementBased(unittest.TestCase):
    """JEE Main's staple. The AR truth table with the explanation link removed."""

    @classmethod
    def setUpClass(cls):
        from kie.qie.certgen import statement_based as SB
        cls.SB = SB
        cls.c = _index()
        cls.rb, _ = B.resolve(cls.c)
        cls.rc, _ = COMP.resolve(cls.c)
        cls.ra, _ = AR.resolve(cls.c)
        cls.items = SB.generate(cls.ra)
        cls.gated = E.gate_items(cls.items, resolved=cls.rb, resolved_chains=cls.rc)

    @classmethod
    def tearDownClass(cls):
        cls.c.close()

    def test_items_clear_the_battery(self):
        bad = {r["gen_id"]: r["fatal"] + r["quarantine"] for r in self.gated if r["fatal"] or r["quarantine"]}
        self.assertEqual(bad, {}, f"statement items must be clean: {bad}")

    def test_key_follows_from_two_computed_truths(self):
        for it in self.items:
            tt = it["provenance"]["truth_table"]
            expect = self.SB._KEY_FOR[(tt["statement_1_true"], tt["statement_2_true"])]
            self.assertEqual(it["answer_label"], expect, it["gen_id"])

    def test_truths_are_recomputable(self):
        for it in self.items:
            b = next(x.binding for x in self.ra if x.binding.binding_id == it["binding_id"])
            tt = it["provenance"]["truth_table"]
            lines = it["stem"].split("\n")
            s1 = lines[0].replace("Statement I: ", "")
            match = [c for c in list(b.true_claims) + [b.false_claim] if c.text == s1]
            self.assertTrue(match, f"{it['gen_id']}: statement I not traceable to a declared claim")
            got = AR.claim_is_true(b.relation, b.base_params, b.solve_for, match[0])
            self.assertEqual(bool(got), tt["statement_1_true"])

    def test_every_wrong_option_is_refuted(self):
        for it in self.items:
            res = self.SB.verify_options(it)
            self.assertTrue(res["ok"], f"{it['gen_id']}: {res['detail']}")
            self.assertEqual(res["unrefuted"], [])

    def test_two_identical_statements_are_refused(self):
        """A key requiring both statements false would reuse one sentence twice — not a two-statement item."""
        for it in self.items:
            lines = it["stem"].split("\n")
            self.assertNotEqual(lines[0].replace("Statement I: ", ""),
                                lines[1].replace("Statement II: ", ""))


@unittest.skipUnless(INDEX.exists(), f"certified knowledge index not found at {INDEX}")
class TestCaseStudy(unittest.TestCase):
    """Shared stimulus with dependent sub-questions — CBSE case-based, JEE Advanced paragraph."""

    @classmethod
    def setUpClass(cls):
        from kie.qie.certgen import case_study as CS
        cls.CS = CS
        cls.c = _index()
        cls.rb, _ = B.resolve(cls.c)
        cls.rc, _ = COMP.resolve(cls.c)
        cls.items = CS.generate(cls.rc, 1, "TESTCS")
        cls.gated = E.gate_items(cls.items, resolved=cls.rb, resolved_chains=cls.rc)

    @classmethod
    def tearDownClass(cls):
        cls.c.close()

    def test_items_clear_the_battery(self):
        bad = {r["gen_id"]: r["fatal"] + r["quarantine"] for r in self.gated if r["fatal"] or r["quarantine"]}
        self.assertEqual(bad, {}, f"case items must be clean: {bad}")

    def test_cases_are_structurally_sound(self):
        res = self.CS.verify_case(self.items)
        self.assertTrue(res["ok"], res["detail"])
        self.assertGreater(res["cases"], 0)

    def test_parts_share_one_passage_and_are_contiguous(self):
        by_case = {}
        for it in self.items:
            by_case.setdefault(it["case_id"], []).append(it)
        for cid, group in by_case.items():
            group.sort(key=lambda r: r["sub_index"])
            self.assertEqual([r["sub_index"] for r in group], list(range(1, len(group) + 1)))
            passages = {r["stem"].split("\nQuestion ")[0] for r in group}
            self.assertEqual(len(passages), 1, f"{cid}: parts must share one passage")

    def test_each_part_has_a_distinct_answer(self):
        """A case whose parts share an answer is not progressive."""
        by_case = {}
        for it in self.items:
            by_case.setdefault(it["case_id"], []).append(it)
        for cid, group in by_case.items():
            vals = [r["answer_value"] for r in group]
            self.assertEqual(len(set(vals)), len(vals), f"{cid}: repeated answer across parts")

    def test_sub_answers_match_the_parent_chain_execution(self):
        """Every sub-answer must be a value the chain actually produced — not recomputed here."""
        for it in self.items:
            inter = it["provenance"]["intermediates"]
            self.assertIn(it["answer_value"], [SOL.fmt_exact(v, 2) for v in inter.values()],
                          f"{it['gen_id']}: answer is not one of the chain's intermediates")

    def test_a_duplicated_case_is_skipped_whole(self):
        """Two chains sharing a leading prefix must not emit a case with a missing part."""
        res = self.CS.verify_case(self.items)
        self.assertTrue(res["ok"], "no partial case may be emitted")
