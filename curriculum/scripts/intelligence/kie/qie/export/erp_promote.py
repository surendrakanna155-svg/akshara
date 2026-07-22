"""Program D · M1.2 / M2.1 / M2.2 — the OFFLINE, deterministic QIE→ERP certified-bank exporter.

Turns the certified question bank into the frozen Contract-1 export artifact: ``{manifest, rows}``. The
whole module is READ-ONLY on the certified bank — it never writes, commits, or mutates a single row (the
byte-identical-substrate proof in the tests enforces this). It performs no network I/O, calls no model, and
puts no wall-clock into the artifact; two exports of an identical bank are byte-identical.

FAIL-CLOSED EXPORT ADMISSION (Contract-1 §1.2, never widened): a row is exported IFF
  * its source row is ``status='certified' AND certification_class='certified'`` — enforced structurally by
    ``corpus.certified_bank`` (which additionally RI-6-gates the store to the one production bank), AND
  * ``vocab.resolve(kc_id) is not None`` — an unmapped KC is an honest NULL, never a guessed UUID.
Provisional / quarantined / rejected / expired / trial_certified / unmapped-KC rows are EXCLUDED.

BOUNDARY ENUM MAP (Contract-1 §1.4 — a mapping, never a weakened gate): QIE ``MCQ`` → ERP ``mcq``;
QIE difficulty ``easy/moderate/hard`` → ERP ``easy/medium/hard``. An unmapped value fails CLOSED (raises)
rather than silently dropping or fabricating — an incomplete boundary map is a coordination signal that must
surface. M2.2 derivations are documented and honest-null when underivable (see ``_cognitive_level``).
"""
from __future__ import annotations

import json
from typing import Dict, List, Optional

from kie.qie.export.embeddings import hashvec_128
from kie.qie.export.manifest import build_manifest
from kie.qie.factory import corpus

# ── boundary enum maps (Contract-1 §1.4) — normative, applied here, never weakening a QIE gate ──────────
_QIE_TO_ERP_QUESTION_TYPE = {"MCQ": "mcq"}
_QIE_TO_ERP_DIFFICULTY = {"easy": "easy", "moderate": "medium", "hard": "hard"}

# M2.2 derivations (documented). marks: a fixed small table keyed by the ERP question_type. cognitive_level:
# Bloom mapped from the EARNED reasoning depth (or the claimed depth) — honest-null when no depth is present.
_MARKS_BY_QUESTION_TYPE = {"mcq": 1}
_DEPTH_TO_COGNITIVE_LEVEL = {1: "remember", 2: "understand", 3: "apply", 4: "analyze", 5: "hots"}

# M2.1: a certified export is PREDICTED, never measured (R2-5) — the calibration is always this constant.
_DIFFICULTY_CALIBRATION = "predicted_uncalibrated"
# Contract-1 §1.2 default program_track for the fixtures/school lane.
_PROGRAM_TRACK = "board"


def _loads(v) -> dict:
    """Parse a JSON column into a dict; tolerate an already-parsed dict or a NULL/garbage value (→ {})."""
    if v is None:
        return {}
    if isinstance(v, dict):
        return v
    try:
        parsed = json.loads(v)
        return parsed if isinstance(parsed, dict) else {}
    except (TypeError, ValueError):
        return {}


def _as_int(x) -> Optional[int]:
    """Coerce an int-ish depth to int, or None. ``bool`` is rejected (True is not a depth)."""
    if isinstance(x, bool):
        return None
    try:
        return int(x)
    except (TypeError, ValueError):
        return None


def _map_question_type(qie_qt: str) -> str:
    erp = _QIE_TO_ERP_QUESTION_TYPE.get(qie_qt)
    if erp is None:
        raise ValueError(
            f"unmapped QIE question_type {qie_qt!r} at the export boundary (enum map program-d-enum/1 "
            f"covers {sorted(_QIE_TO_ERP_QUESTION_TYPE)}) — refusing to weaken or fabricate the mapping")
    return erp


def _map_difficulty(qie_diff: str) -> str:
    erp = _QIE_TO_ERP_DIFFICULTY.get(qie_diff)
    if erp is None:
        raise ValueError(
            f"unmapped QIE difficulty {qie_diff!r} at the export boundary (enum map program-d-enum/1 "
            f"covers {sorted(_QIE_TO_ERP_DIFFICULTY)}) — refusing to weaken or fabricate the mapping")
    return erp


def _marks_for(erp_question_type: str) -> int:
    marks = _MARKS_BY_QUESTION_TYPE.get(erp_question_type)
    if marks is None:
        raise ValueError(
            f"no marks derivation for question_type {erp_question_type!r} (M2.2 table covers "
            f"{sorted(_MARKS_BY_QUESTION_TYPE)}) — refusing to fabricate a mark")
    return marks


def _cognitive_level(cand) -> Optional[str]:
    """Bloom level derived from the EARNED reasoning depth (``earned_depth``), falling back to the claimed
    depth, then mapped 1→remember … 5→hots. Honest-null (None) when no depth is available or it is out of
    range — never fabricated (Contract-1 §1.2)."""
    depth = cand["earned_depth"]
    if depth is None:
        depth = _loads(cand["claimed"]).get("depth")
    return _DEPTH_TO_COGNITIVE_LEVEL.get(_as_int(depth))


def _options_array(cand) -> List[str]:
    """QIE options dict ``{label: text}`` → array ordered by label A, B, C, D (Contract-1 §1.2)."""
    opts = _loads(cand["options"])
    return [opts[label] for label in sorted(opts)]


def _provenance(cand) -> Dict:
    """The Contract-1 §1.2 provenance object, taken verbatim from the certified row."""
    return {
        "generator_model": cand["generator_model"],
        "generator_family": cand["generator_family"],
        "evidence_class": cand["evidence_class"],
        "certification_class": cand["certification_class"],
        "run_id": cand["run_id"],
        "model_version": cand["model_version"],
        "generator_actor": cand["generator_actor"],
    }


def _export_row(cand, spec, concept_uuid: str, frozen_version: str) -> Dict:
    """Project one certified candidate (+ its generation_spec) into a Contract-1 ExportRow."""
    erp_qtype = _map_question_type(spec["question_type"])
    return {
        "content_hash": cand["item_hash"],
        "stem_norm_hash": cand["stem_norm_hash"],
        "question_text": cand["stem"],
        "answer_text": cand["answer_value"],
        "options": _options_array(cand),
        "answer_label": cand["answer_label"],
        "question_type": erp_qtype,
        "difficulty": _map_difficulty(spec["intended_difficulty"]),
        "difficulty_calibration": _DIFFICULTY_CALIBRATION,
        "cognitive_level": _cognitive_level(cand),
        "marks": _marks_for(erp_qtype),
        "subject_name": spec["subject"],
        "chapter": spec["concept_title"] or "",
        "topic": "",
        "program_track": _PROGRAM_TRACK,
        "kc_id": spec["concept_code"],
        "concept_uuid": concept_uuid,
        "near_dup_embedding": hashvec_128(cand["stem"]),
        "provenance": _provenance(cand),
        "frozen_version": frozen_version,
    }


def _frozen_version(vocab) -> str:
    """The vocabulary's declared frozen index version (mirrored onto the manifest + every row). Falls back to
    the fixture sentinel if the vocabulary is empty."""
    rows = vocab.rows()
    return rows[0]["frozen_version"] if rows else "program-d-fixture"


def export_certified(bank_conn, vocab, *, generated_from: str = "fixture") -> Dict:
    """Export the certified bank behind ``bank_conn`` into the Contract-1 artifact ``{manifest, rows}``.

    READ-ONLY: only SELECTs are issued (``corpus.certified_bank`` + a generation_spec read). Deterministic:
    rows are sorted by ``content_hash`` ascending and every field is content-derived, so two exports of an
    identical bank are byte-identical. Fail-closed admission per the module docstring.
    """
    substrate = corpus.certified_bank(bank_conn)     # RI-6-gated; status='certified' AND cert_class='certified'
    specs = {r["spec_id"]: r for r in bank_conn.execute("SELECT * FROM generation_spec")}
    frozen_version = _frozen_version(vocab)

    substrate_keys: List[str] = []
    rows: List[Dict] = []
    for cand in substrate:
        # substrate fingerprint covers EVERY certified row read, even those the admission below excludes.
        substrate_keys.append(f"{cand['candidate_id']}|{cand['item_hash']}|{cand['stem_norm_hash']}")
        spec = specs.get(cand["spec_id"])
        if spec is None:
            continue                                  # a certified row with no spec cannot be honestly projected
        kc_id = spec["concept_code"]
        concept_uuid = vocab.resolve(kc_id) if kc_id else None
        if concept_uuid is None:
            continue                                  # honest-null: unmapped KC → NOT exported (never guessed)
        rows.append(_export_row(cand, spec, concept_uuid, frozen_version))

    rows.sort(key=lambda r: r["content_hash"])        # determinism: content_hash ascending (Contract-1 rule 7)
    manifest = build_manifest(rows=rows, substrate_keys=substrate_keys,
                              frozen_version=frozen_version, generated_from=generated_from)
    return {"manifest": manifest, "rows": rows}
