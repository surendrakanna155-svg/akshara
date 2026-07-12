"""Phase C slices 5-6 — capability matrix + five separate readiness metrics."""
import unittest

from kie.qie import capability_report as CR


def _rec(subject, profile, concept, archetype, n_dna=6, n_res=3, distinct=6, verified=True,
         genuine=True, resolved=True, profile_valid=True, certifiable=True):
    return {"subject": subject, "profile": profile, "concept": concept, "archetype": archetype,
            "lane": "NUMERIC_RELATIONAL" if archetype == "single_step_numerical" else "CONCEPTUAL_CAUSAL",
            "n_dna": n_dna, "n_resources": n_res, "distinct_stems": distinct, "verified": verified,
            "genuine": genuine, "resolved_concept": resolved, "profile_valid": profile_valid,
            "certifiable": certifiable}


class TestMatrix(unittest.TestCase):
    def test_ratings_and_cells(self):
        records = [
            _rec("Physics", "NEET", "PHY_OHM", "single_step_numerical"),
            _rec("Physics", "NEET", "PHY_KE", "single_step_numerical"),
            _rec("Physics", "NEET", "PHY_FIELD", "factual_single_best_answer"),
            _rec("Biology", "NEET", "BIO_ENDO", "factual_single_best_answer", certifiable=False, verified=False),
            _rec("Mathematics", None, "MAT_X", "single_step_numerical", certifiable=False,
                 profile_valid=False),
        ]
        m = CR.build_matrix(records)
        by = {(r["subject"], r["profile"]): r for r in m["subject_profile_ratings"]}
        self.assertEqual(by[("Physics", "NEET")]["rating"], "STRONG")   # 3 cert across 2 archetypes
        self.assertEqual(by[("Biology", "NEET")]["rating"], "THIN")     # genuine but unverified -> not certifiable
        self.assertEqual(by[("Mathematics", None)]["rating"], "UNRESOLVED")
        # cells carry the honest proxy fields
        cell = next(c for c in m["cells"] if c["subject"] == "Physics" and c["archetype"] == "single_step_numerical")
        self.assertEqual(cell["verification_readiness"], "solver")
        self.assertFalse(cell["visual_support"]["measured"])

    def test_absent_when_no_evidence(self):
        m = CR.build_matrix([])
        self.assertEqual(m["subject_profile_ratings"], [])


class TestReadiness(unittest.TestCase):
    def test_five_metrics_present_and_separate(self):
        # a certifiable model on a NEET CORE archetype (factual recall) -> coverage > 0
        records = [_rec("Biology", "NEET", "BIO_ENDO", "factual_single_best_answer")]
        r = CR.readiness_metrics(records)
        for k in ("capability_coverage_per_profile", "evidence_readiness_concepts", "quality_readiness",
                  "scale_readiness", "paper_readiness"):
            self.assertIn(k, r)
        # capability coverage is per-profile and fractional (not one global score)
        self.assertIn("NEET", r["capability_coverage_per_profile"])
        self.assertGreater(r["capability_coverage_per_profile"]["NEET"]["fraction"], 0)
        # a certifiable single_step_numerical is NOT a NEET-core archetype -> does not inflate NEET coverage
        r2 = CR.readiness_metrics([_rec("Physics", "NEET", "PHY_OHM", "single_step_numerical")])
        self.assertEqual(r2["capability_coverage_per_profile"]["NEET"]["fraction"], 0.0)
        # quality/paper readiness honestly flagged as not measured here (separate instruments)
        self.assertFalse(r["quality_readiness"]["measured_here"])
        self.assertFalse(r["paper_readiness"]["measured_here"])

    def test_evidence_readiness_counts_resolved_supported_concepts(self):
        records = [_rec("Biology", "NEET", "BIO_ENDO", "factual_single_best_answer", n_dna=6, n_res=3),
                   _rec("Biology", "NEET", "Biology:cell", "factual_single_best_answer", resolved=False)]
        r = CR.readiness_metrics(records)
        self.assertEqual(r["evidence_readiness_concepts"].get("Biology/NEET"), 1)  # coarse bucket excluded


if __name__ == "__main__":
    unittest.main()
