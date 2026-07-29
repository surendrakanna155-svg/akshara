"""Operator framework — every operator must COMPUTE correctly and REFUSE a wrong answer.

The second half is the one that matters. An independent `verify` that cannot fail is not a check, and
`compose.run_pipeline` treats a passing verify as evidence that a step is sound. Each adversarial case
below is a real student error, and one of them (a sign-flipped cross product) was a genuine defect this
suite caught before the operator shipped.
"""
from __future__ import annotations

import unittest

import sympy as sp

from kie.qie import biology, chemistry, genetics, physics  # noqa: F401 — register domain operators
from kie.qie import compose as CO
from kie.qie import operators_ext as OX
from kie.qie.compose import x

M = sp.Matrix([[2, 1], [3, 4]])
A = sp.Matrix([[1, 2], [0, 1]])
V1 = sp.Matrix([1, 2, 3])
V2 = sp.Matrix([0, 1, -1])

# (operator, args, expected-ish, DELIBERATELY WRONG output naming a real student error)
CASES = [
    ("differentiate_expr", [sp.sin(x) * x], sp.cos(x), "forgot the product rule"),
    ("integrate_expr", [sp.cos(x)], -sp.sin(x), "sign error on the antiderivative"),
    ("integrate_def_expr", [sp.sin(x), 0, sp.pi], 0, "wrong definite value"),
    ("evaluate_expr", [sp.exp(x), 1], 2, "e approximated as 2"),
    ("limit_at", [sp.sin(x) / x, 0], 0, "the classic sin(x)/x -> 0 error"),
    ("determinant", [M], 11, "added instead of subtracting the cross terms"),
    ("matrix_inverse", [M], M, "returned the matrix itself"),
    ("matrix_multiply", [M, A], A * M, "multiplied in the wrong order"),
    ("matrix_transpose", [M], M, "forgot to transpose"),
    ("dot_product", [V1, V2], 5, "arithmetic slip"),
    ("cross_product", [V1, V2], sp.Matrix([5, -1, -1]), "computed b x a — wrong handedness"),
    ("vector_magnitude", [V1], 14, "forgot the square root"),
    ("complex_modulus", [3 + 4 * sp.I], 7, "added the parts instead of the hypotenuse"),
    ("complex_conjugate", [3 + 4 * sp.I], 3 + 4 * sp.I, "forgot to conjugate"),
    ("n_choose_r", [10, 3], 720, "gave nPr instead of nCr"),
    ("n_permute_r", [10, 3], 120, "gave nCr instead of nPr"),
    ("ap_sum", [2, 3, 10], 145, "off-by-one on the number of terms"),
    ("gp_sum", [2, 3, 5], 240, "arithmetic slip"),
    ("binomial_probability", [5, 2, sp.Rational(1, 3)], sp.Rational(40, 243),
     "dropped the arrangements factor"),
    ("conditional_probability", [sp.Rational(1, 6), sp.Rational(1, 2)], sp.Rational(1, 12),
     "multiplied instead of dividing"),
    ("mean_of", [[2, 4, 6, 8]], 6, "wrong mean"),
    ("solve_expr", [x ** 2 - 5 * x + 6], [2, 4], "one root wrong"),
    # ── completion pass: the 28 senior-Maths concepts the first pass could not compute ──
    ("set_union", [frozenset({1, 2, 3}), frozenset({3, 4})], frozenset({1, 2, 3}),
     "dropped an element of B"),
    ("set_intersection", [frozenset({1, 2, 3}), frozenset({3, 4})], frozenset({3, 4}),
     "returned B instead of the intersection"),
    ("set_difference", [frozenset({1, 2, 3}), frozenset({3, 4})], frozenset({1, 2, 3}),
     "forgot to remove the common element"),
    ("set_cardinality", [frozenset({1, 2, 3})], 4, "miscounted"),
    ("power_set_size", [frozenset({1, 2, 3})], 6, "used 2n instead of 2^n"),
    ("function_compose", [x ** 2, x + 1], x ** 2 + 1, "composed the wrong way round (fog vs gof)"),
    ("function_inverse", [2 * x + 3], 2 * x - 3, "inverted incorrectly"),
    ("is_injective", [x ** 2], 1, "claimed x^2 is one-one over the reals"),
    ("inverse_trig", ["asin", sp.Rational(1, 2)], sp.pi * sp.Rational(5, 6),
     "gave a value outside the principal branch"),
    ("solve_inequality", [x - 2, "lt"], (sp.Integer(2), sp.oo), "sign of the inequality reversed"),
    ("ode_order", [[1, 2]], 1, "took the lowest order instead of the highest"),
    ("ode_solve_separable", [2 * x], x ** 2 + 5, "ignored the initial condition y(0)=0"),
    ("lp_maximise", [[(0, 0), (4, 0), (0, 3)], [2, 3]], 12, "value not attained at any vertex"),
]


class TestOperatorRegistry(unittest.TestCase):

    def test_extension_registered_without_displacing_the_core(self):
        for core in ("differentiate", "integrate_def", "evaluate", "real_roots", "min_root",
                     "max_root", "unique_root", "subtract_poly", "absval"):
            self.assertIn(core, CO.OPERATORS, "the original 9 operators must survive the extension")
        self.assertGreaterEqual(len(CO.OPERATORS), 44)

    def test_every_operator_declares_types_and_an_independent_verify(self):
        for name, op in CO.OPERATORS.items():
            self.assertTrue(op.in_types, f"{name} declares no input types")
            self.assertTrue(op.out_type, f"{name} declares no output type")
            self.assertTrue(callable(op.verify), f"{name} has no verify")
            self.assertIsNot(op.apply, op.verify, f"{name} verifies with its own forward method")

    def test_every_operator_is_classified_by_exam_level(self):
        """Fixed-vocabulary operators are classified by name; runtime-synthesised ones (chain_step{k},
        whose arity is data-driven) by declared family prefix. Anything matching neither is a real gap."""
        for name in CO.OPERATORS:
            self.assertTrue(OX.levels_for(name), f"{name} has no exam-level classification")

    def test_dynamic_families_resolve_by_prefix(self):
        self.assertTrue(OX.levels_for("chain_step3"))
        self.assertTrue(OX.levels_for("chain_step11"))
        self.assertEqual(OX.levels_for("totally_unknown_operator"), frozenset(),
                         "an unclassified operator must report a gap, never a default")

    def test_operators_for_level_is_non_empty_and_scoped(self):
        for lvl in (OX.BOARD_6_10, OX.BOARD_11_12, OX.JEE_MAIN, OX.JEE_ADVANCED, OX.NEET):
            self.assertTrue(OX.operators_for(lvl), f"no operators admissible at {lvl}")
        # matrices, complex numbers and vector products are not in the NEET syllabus
        neet = set(OX.operators_for(OX.NEET))
        for out_of_scope in ("determinant", "matrix_inverse", "complex_modulus", "cross_product"):
            self.assertNotIn(out_of_scope, neet, f"{out_of_scope} must not be offered for NEET")
        self.assertIn("determinant", set(OX.operators_for(OX.JEE_MAIN)))


class TestOperatorsCompute(unittest.TestCase):
    """Forward correctness: apply() must produce a value its own verify accepts."""

    def test_each_operator_computes_and_self_verifies(self):
        for name, args, _wrong, _why in CASES:
            op = CO.OPERATORS[name]
            out = op.apply(*args)
            self.assertIsNotNone(out, f"{name} returned nothing")
            self.assertTrue(op.verify(list(args), out),
                            f"{name}: verify rejected its own correct output {out!r}")


class TestOperatorsRefuseWrongAnswers(unittest.TestCase):
    """THE test that matters. A verify that cannot fail proves nothing."""

    def test_each_verify_rejects_a_real_student_error(self):
        for name, args, wrong, why in CASES:
            op = CO.OPERATORS[name]
            self.assertFalse(op.verify(list(args), wrong),
                             f"{name}: verify ACCEPTED a wrong answer ({why}) — the check is vacuous")

    def test_cross_product_rejects_a_sign_flip(self):
        """Regression: the first implementation checked orthogonality + magnitude only, and a flipped
        cross product satisfies both. Orientation must be checked too."""
        op = CO.OPERATORS["cross_product"]
        correct = op.apply(V1, V2)
        self.assertTrue(op.verify([V1, V2], correct))
        self.assertFalse(op.verify([V1, V2], -correct), "a sign flip must be refused")
        self.assertFalse(op.verify([V1, V2], op.apply(V2, V1)), "b x a must be refused for (a, b)")


class TestOperatorsInPipelines(unittest.TestCase):
    """The extension must work through the EXISTING executor, unchanged."""

    def test_a_multi_step_pipeline_runs_and_earns_depth(self):
        env0 = {"f": sp.sin(x) * x, "lo": 0, "hi": sp.pi}
        pipeline = [CO.Step("fp", "differentiate_expr", ("f",)),
                    CO.Step("val", "integrate_def_expr", ("fp", "lo", "hi"))]
        env, ok = CO.run_pipeline(env0, pipeline)
        self.assertTrue(ok, "a general-calculus pipeline must execute")
        self.assertIn("val", env)
        self.assertEqual(CO.reasoning_depth(pipeline, env0.keys()), 2)

    def test_pipeline_fails_safe_when_a_step_cannot_verify(self):
        broken = CO.Operator("probe_broken", "PROBE", "test", ("EXPR",), "EXPR",
                             lambda f: f + 1, lambda ins, out: False)
        CO.OPERATORS["probe_broken"] = broken
        try:
            env, ok = CO.run_pipeline({"f": sp.sin(x)}, [CO.Step("g", "probe_broken", ("f",))])
            self.assertFalse(ok, "run_pipeline must fail safe when a verify disagrees")
        finally:
            del CO.OPERATORS["probe_broken"]


if __name__ == "__main__":
    unittest.main()
