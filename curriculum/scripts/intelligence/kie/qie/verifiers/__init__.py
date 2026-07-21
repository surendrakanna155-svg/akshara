"""`kie.qie.verifiers` — the reusable 7-method deterministic verifier battery (QIE remediation R4-1(a)).

Extracts each pilot-lane generator's pure `verify_*` function behind the stateless `Verifier` protocol so the
check is reusable independently of generation (factory lane, reconciliation, re-verification). Deterministic
checks certify; model agreement is NOT a verifier here (audit §11) — see `protocol.assert_not_model_agreement`.

Public surface:
  * `protocol.Verifier` / `VerdictResult`
  * `battery.verify_any(record)` / `battery.reverify_from_record(row)` / `battery.BY_METHOD`
  * `notation_recovery.reverify_relation_row(row)` — re-run the 5-gate governed_relation certifier.
"""
from kie.qie.verifiers.protocol import Verifier, VerdictResult, assert_not_model_agreement  # noqa: F401
