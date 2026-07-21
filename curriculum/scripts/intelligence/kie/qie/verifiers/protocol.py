"""The reusable `Verifier` protocol — R4-1(a), the 7-method battery extracted from the generators.

WHY THIS EXISTS (read before changing anything):
Each of the qie.db pilot lane's verification methods lives EMBEDDED inside a generator's `run()` loop
(`generate_numeric.run`, `compositions.run`, ...). That coupling means the *verifier* — the part that
converts a claim into evidence — cannot be reused by the factory lane, by a reconciliation pass, or by a
re-verification of already-banked items. This package extracts the pure `verify_*` function of each method
behind ONE stateless, deterministic protocol so the check can run independently of generation.

STANDING LAW encoded here (audit §11): *a certification requires a NON-MODEL re-derivation; the judge may
reject but never solely certify.* Therefore every Verifier registered here is DETERMINISTIC
(`is_deterministic = True`). Model agreement (the pilot lane's 8th "method", `refuter_verdict='agree'` on the
62 Biology items) is DELIBERATELY NOT a Verifier — it can reject, never independently certify. A genuine
cross-family model judge is R4-2; a qualitative non-model lane is R4-3. `assert_not_model_agreement` below
makes that boundary a runtime error, not a convention.

A Verifier is a thin WRAPPER over the generator's existing `verify_*` function (imported, never edited): the
generator PROPOSES, sympy / the relation library / the canonical KB DISPOSES. Pure, stateless, no DB writes,
no model calls, no I/O.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Dict, Optional, Protocol, runtime_checkable


@dataclass(frozen=True)
class VerdictResult:
    """The uniform output of every Verifier.

    `ok` is deliberately Optional[bool] to keep the honest-null discipline structural:
      * True   — an independent NON-MODEL re-derivation AGREED (the item is re-verified).
      * False  — the independent re-derivation REFUTED the item (a damaged/wrong item).
      * None   — NOT EVALUABLE here (e.g. the generator's structured payload was never persisted on the
                 stored row, so this method cannot re-run). None is an honest null, NEVER a silent pass —
                 a None can never promote anything.
    """
    ok: Optional[bool]
    verdict: str                       # 'agree' | 'disagree' | 'unavailable' | 'inapplicable'
    method: str                        # canonical method label (matches pilot refuter_verdict labels)
    is_deterministic: bool
    reason: str = ""
    evidence: Dict[str, Any] = field(default_factory=dict)

    @property
    def agreed(self) -> bool:
        return self.ok is True


@runtime_checkable
class Verifier(Protocol):
    """A stateless deterministic re-verifier for one method label.

    name             — module/verifier identity.
    method           — the canonical method label this verifier proves (matches the pilot lane's labels).
    is_deterministic — ALWAYS True for a real Verifier (the protocol refuses to host model agreement).
    applicable(rec)  — cheap predicate: can this verifier run on this record?
    verify(rec)      — run the wrapped `verify_*` and return a VerdictResult.
    """
    name: str
    method: str
    is_deterministic: bool

    def applicable(self, record: Dict[str, Any]) -> bool: ...

    def verify(self, record: Dict[str, Any]) -> VerdictResult: ...


# ── the model-agreement boundary, made structural ────────────────────────────────────────────────────
MODEL_AGREEMENT_METHOD = "agree"      # the pilot lane's label for the 62 Biology model-judge items


class ModelAgreementIsNotAVerifier(Exception):
    """Raised if any code path tries to treat model agreement as an independent certifier (R4-1 / audit §11)."""


def assert_not_model_agreement(method: str) -> None:
    """Fail CLOSED if `method` is model agreement. Called at every promotion decision so a model-agreed item
    can never reach a deterministic-certifies code path. Model agreement belongs to the R4-3 qualitative lane."""
    if str(method).strip().lower() == MODEL_AGREEMENT_METHOD:
        raise ModelAgreementIsNotAVerifier(
            "model agreement ('agree') is NOT an independent verifier — it may reject but never certify "
            "(audit §11). Route model-agreed items to R4-3 (qualitative lane); a cross-family judge is R4-2.")


def unavailable(method: str, reason: str) -> VerdictResult:
    """Honest-null result: this method could not be re-run from the data on hand (ok=None)."""
    return VerdictResult(ok=None, verdict="unavailable", method=method, is_deterministic=True, reason=reason)


def inapplicable(method: str, reason: str) -> VerdictResult:
    return VerdictResult(ok=None, verdict="inapplicable", method=method, is_deterministic=True, reason=reason)


def _from_agree(method: str, verdict: str, reason: str = "", **evidence) -> VerdictResult:
    """Build a VerdictResult from a generator verify_* fn's 'agree'/'disagree' string."""
    ok = True if verdict == "agree" else (False if verdict == "disagree" else None)
    return VerdictResult(ok=ok, verdict=verdict, method=method, is_deterministic=True,
                         reason=reason, evidence=evidence)
