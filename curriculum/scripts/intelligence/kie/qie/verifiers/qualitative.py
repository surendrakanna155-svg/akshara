"""R4-3 — the qualitative non-model re-derivation step ([C16] + [BS-2]).

WHY THIS EXISTS (read before changing anything):
`factory/certify.py` states the architecture's own limit: a QUALITATIVE item ("which hormone regulates X")
has NO sympy re-derivation, and its model examiner may REJECT but never solely CERTIFY — certifying on
gates + a same-family judge alone is the C0 self-confirmation the owner ruled out. So the factory parks
qualitative items as `quarantined(awaiting_independent_evidence)`.

This module supplies the ONE thing that can lift that: an INDEPENDENT, NON-MODEL re-derivation. The signal is
INDEPENDENT SOURCE CORROBORATION — the fact's answer is attested by a separately-mined, MULTI-SOURCE-grounded
KVS assertion (`evidence_count >= 2`, the kvs_seed promotion bar). The KVS lane (kvs_build/kvs_seed) is mined
from question_dna across source documents, independently of the governed-fact EXAMINER lane, so an overlap is
genuine cross-substrate corroboration — not the model agreeing with itself.

STANDING LAW encoded here (audit §11):
  * Model agreement is NOT a verifier — `assert_not_model_agreement` refuses it. The governed_fact's
    `verifier_model` (an examiner LLM) can never satisfy this step.
  * Honest-null discipline: NO independent corroboration => ok=None (HELD, never a silent pass). A None can
    never certify anything. Fail-CLOSED on every ambiguity (unknown subject, missing source doc, disagreeing
    subject signals) — uncertainty HOLDS, it never passes.
  * A certification requires a non-model re-derivation; this step is deterministic (string + evidence-count),
    grounded in owned source references, no model in the truth path.

SCOPE HONESTY: consistency here is SUBJECT-level (the assertion's authoritative subject must match the fact's,
cross-checked against the legacy concept_code). True concept-IDENTITY alignment across the three namespaces
awaits R5-2 (KC_ namespace convergence); until then a same-subject answer collision is the ceiling of what
this deterministic step can assert, so the independence bar (>=2 sources excluding the fact's own) carries the
weight.

The honest present-day yield is small (independent corroboration is thin in the current owned estate) — that is
the true state of the substrate, reported rather than papered over. The SAME step certifies more as independent
evidence is acquired (R5-4/R5-6 PYQ corpus) or a cross-family judge is added (R4-2 + a live key).
"""
from __future__ import annotations

import json
import re
import sqlite3
from typing import Any, Dict, List, Optional, Set

from kie.qie.verifiers.protocol import VerdictResult, assert_not_model_agreement

NAME = "qualitative"
METHOD = "independent_kvs_corroboration"
IS_DETERMINISTIC = True

# A corroborating assertion must itself clear the kvs_seed >=2-source reliability bar...
MIN_EVIDENCE = 2
# ...AND attest the answer from at least this many source docs that are INDEPENDENT of the fact's OWN source.
# The governed-fact and KVS lanes both read the same corpus answer keys, so an "overlap" that includes the
# fact's own source document is NOT cross-substrate corroboration — it is one reader agreeing with the fact's
# origin. Excluding the fact's own doc and still requiring >=2 leaves only genuinely-independent attestation.
# (Adversarial-verifier fix, R4-3: without this the sole live "cert" rested on 1 independent doc + the fact's
#  own source, which is below the bar.)
MIN_INDEPENDENT_SOURCES = 2
# junk / placeholder concept candidates a coincidental answer-match must never certify through.
_JUNK_CONCEPT = re.compile(r"::\s*(test|tmp|temp|sample|placeholder|todo)\b", re.IGNORECASE)
# subject encoded in a KVS legacy concept_code (BIO_… / PHY_… / CHE_… / MAT_… / BRD_BIO_…). Used to refuse a
# concept-BLIND match (an answer-string collision on an unrelated-subject assertion must never certify).
_SUBJECT_TOKENS = (("BIO", "Biology"), ("PHY", "Physics"), ("CHEM", "Chemistry"), ("CHE", "Chemistry"),
                   ("MATH", "Mathematics"), ("MAT", "Mathematics"))


def _norm(s: Optional[str]) -> str:
    return re.sub(r"[^a-z0-9 ]", " ", (s or "").lower()).strip()


def _subject_of_concept_code(cc: Optional[str]) -> Optional[str]:
    u = (cc or "").upper()
    for tok, subj in _SUBJECT_TOKENS:
        if tok in u:
            return subj
    return None


def _docs(evidence_json) -> Set[str]:
    try:
        v = json.loads(evidence_json or "[]")
    except (json.JSONDecodeError, TypeError):
        return set()
    return {str(d) for d in v} if isinstance(v, list) else set()


def _norm_subject(s: Optional[str]) -> str:
    return (s or "").strip().lower()


def build_corroboration_index(qie: sqlite3.Connection) -> Dict[str, List[dict]]:
    """{normalized answer -> [ {concept_code, subject_term, cc_subject, evidence_docs, evidence_count}, ... ]}
    over the INDEPENDENTLY-mined KVS `correct_answer_is` assertions that clear the >=2-source bar.

    TWO subject signals are kept: `subject_term` (the authoritative subject kvs_build stores from the source
    question — adversarial-verifier D1) AND `cc_subject` (derived from the legacy concept_code, a cross-check).
    They disagree on ~44% of live rows, so `reverify_fact` fails CLOSED unless BOTH positively agree with the
    fact. The evidence DOC SET is kept (not just a count) so the fact's own source can be excluded. Read-only."""
    idx: Dict[str, List[dict]] = {}
    try:
        rows = qie.execute(
            "SELECT object_term, subject_term, concept_code, evidence, evidence_count FROM kvs_assertion "
            "WHERE predicate='correct_answer_is' AND evidence_count >= ?", (MIN_EVIDENCE,))
    except sqlite3.OperationalError:
        return idx
    for r in rows:
        key = _norm(r["object_term"])
        if not key:
            continue
        idx.setdefault(key, []).append(
            {"concept_code": r["concept_code"], "subject_term": _norm_subject(r["subject_term"]),
             "cc_subject": _norm_subject(_subject_of_concept_code(r["concept_code"])),
             "evidence_docs": _docs(r["evidence"]), "evidence_count": r["evidence_count"]})
    return idx


def _examinable(fact: Dict[str, Any]) -> bool:
    """Refuse to certify through a junk/placeholder concept or an empty claim (a coincidental string match on a
    'Biology :: Test' scratch concept is not evidence)."""
    cc = str(fact.get("concept_candidate") or "")
    if not cc or _JUNK_CONCEPT.search(cc):
        return False
    return bool(_norm(fact.get("answer_text")) or _norm(fact.get("object_term")))


def _claim_answer(fact: Dict[str, Any]) -> str:
    a = _norm(fact.get("answer_text"))
    return a or _norm(fact.get("object_term"))


def _fact_source_doc(fact: Dict[str, Any]) -> str:
    try:
        return str(json.loads(fact.get("provenance") or "{}").get("doc_id") or "")
    except (json.JSONDecodeError, TypeError):
        return ""


def _subject_consistent(h: Dict[str, Any], fact_subject: str) -> bool:
    """FAIL-CLOSED subject consistency (adversarial-verifier D1/D2/D3): certify only when the fact's subject is
    POSITIVELY confirmed by the assertion's authoritative `subject_term` AND is not CONTRADICTED by the subject
    derivable from the legacy concept_code. Any missing/ambiguous/disagreeing signal => refuse (HOLD).
    (This is subject-level consistency; true concept-id alignment awaits R5-2's KC_ namespace convergence.)"""
    if not fact_subject:
        return False                                        # unknown fact subject -> cannot confirm -> HOLD
    if h["subject_term"] != fact_subject:
        return False                                        # authoritative subject missing or mismatched
    if h["cc_subject"] and h["cc_subject"] != fact_subject:
        return False                                        # the concept_code contradicts subject_term -> HOLD
    return True


def reverify_fact(fact: Dict[str, Any], index: Dict[str, List[dict]]) -> VerdictResult:
    """The non-model re-derivation for one governed fact.

      * ok=True  — a subject-consistent KVS assertion attests this exact answer from >= MIN_INDEPENDENT_SOURCES
                   source docs that EXCLUDE the fact's own source: genuine cross-substrate corroboration.
      * ok=None  — no such independent corroboration in the owned substrate: HELD (honest-null), NEVER certified.
    Certification NEVER reads the fact's model examiner verdict; `assert_not_model_agreement` additionally
    refuses any record whose method is model agreement (e.g. a pilot 'agree' row routed through this verifier).
    """
    # defensive: a model-agreement record (pilot lane 'agree') can never be certified through this path.
    assert_not_model_agreement(str(fact.get("refuter_verdict") or "").strip().lower() or "unused")
    if not _examinable(fact):
        return VerdictResult(ok=None, verdict="unavailable", method=METHOD, is_deterministic=True,
                             reason="non-examinable concept/claim (junk or empty) — never certify")
    own_doc = _fact_source_doc(fact)
    if not own_doc:
        # without knowing the fact's own source, independence cannot be established -> HOLD (D4, fail-closed).
        return VerdictResult(ok=None, verdict="unavailable", method=METHOD, is_deterministic=True,
                             reason="fact has no source doc_id — independence unestablishable, HELD")
    claim = _claim_answer(fact)
    fact_subject = _norm_subject(fact.get("subject"))
    for h in index.get(claim, []):
        if not _subject_consistent(h, fact_subject):
            continue                                        # subject not positively confirmed — refuse
        independent = h["evidence_docs"] - {own_doc}
        if len(independent) >= MIN_INDEPENDENT_SOURCES:
            return VerdictResult(
                ok=True, verdict="agree", method=METHOD, is_deterministic=True,
                reason=(f"independently corroborated by >= {MIN_INDEPENDENT_SOURCES} source docs excluding the "
                        f"fact's own source ({h['concept_code']})"),
                evidence={"concept_code": h["concept_code"], "independent_docs": sorted(independent),
                          "answer": claim})
    return VerdictResult(ok=None, verdict="unavailable", method=METHOD, is_deterministic=True,
                         reason=("no >= 2-source KVS corroboration independent of the fact's own source, on a "
                                 "subject-consistent concept — HELD"))


# grounding label used by the manifest (orthogonal to product promotion_status).
GROUNDING_CORROBORATED = "independently_corroborated"
GROUNDING_HELD = "held_awaiting_independent_evidence"
GROUNDING_NA = "not_applicable"


def grounding_label(v: VerdictResult) -> str:
    if v.ok is True:
        return GROUNDING_CORROBORATED
    if v.ok is False:
        return "contradicted"
    return GROUNDING_HELD
