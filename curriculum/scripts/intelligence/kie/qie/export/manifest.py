"""Program D · M2.1 — the export MANIFEST (freeze fingerprints + version tags).

The manifest is the header of the Contract-1 export artifact (§1.1). It carries the two FREEZE
FINGERPRINTS that make an export verifiable and byte-identical for an identical certified bank, plus the
version tags every downstream lane pins against. Nothing here reads wall-clock: both fingerprints are
CONTENT-DERIVED (Contract-1 rule 8), so re-running an export over the same bank reproduces the same manifest.

Two distinct fingerprints, on purpose:
  * ``content_fp``   — sha256 over the EXPORTED rows' content_hashes (sorted). This is the freeze fingerprint
                       (D4): it changes iff the set/identity of shipped rows changes.
  * ``substrate_fp`` — sha256 over the certified-bank SUBSTRATE actually read (every row ``certified_bank``
                       returned, identity-keyed), independent of the export transform. It proves WHAT was
                       read from the bank, even for rows the honest-null admission later excluded (e.g. an
                       unmapped KC). content_fp ⊆ the story substrate_fp tells.
"""
from __future__ import annotations

import hashlib
from typing import Dict, List

from kie.qie.export.embeddings import HASHVEC_MODEL_VERSION, NEAR_DUP_THRESHOLD_VERSION

ARTIFACT_VERSION = "program-d-export/1"   # Contract-1 §1.1 artifact_version
ENUM_MAP_VERSION = "program-d-enum/1"     # Contract-1 §1.4 enum map version


def _sha256(s: str) -> str:
    return hashlib.sha256(s.encode("utf-8")).hexdigest()


def content_fp(content_hashes: List[str]) -> str:
    """Freeze fingerprint (D4): sha256 over the row content_hashes, sorted ascending then newline-joined.
    Deterministic and order-independent of the input; any added / removed / changed row changes it."""
    return _sha256("\n".join(sorted(content_hashes)))


def substrate_fp(substrate_keys: List[str]) -> str:
    """Fingerprint of the certified-bank substrate read: sha256 over the identity keys of EVERY row the
    bank returned (sorted), independent of the export transform — proof of what was read, not just shipped."""
    return _sha256("\n".join(sorted(substrate_keys)))


def build_manifest(*, rows: List[Dict], substrate_keys: List[str], frozen_version: str,
                   generated_from: str = "fixture") -> Dict:
    """Assemble the Contract-1 §1.1 manifest for a completed export.

    ``rows`` are the finished ExportRow dicts (each carries ``content_hash``); ``substrate_keys`` are the
    identity keys of every certified row read (see ``erp_promote``). ``generated_from`` is
    ``"qpl_question_bank"`` for a real bank or ``"fixture"`` for a fixture run.
    """
    return {
        "artifact_version": ARTIFACT_VERSION,
        "generated_from": generated_from,
        "frozen_version": frozen_version,
        "content_fp": content_fp([r["content_hash"] for r in rows]),
        "substrate_fp": substrate_fp(substrate_keys),
        "row_count": len(rows),
        "near_dup_model_version": HASHVEC_MODEL_VERSION,
        "near_dup_threshold_version": NEAR_DUP_THRESHOLD_VERSION,
        "enum_map_version": ENUM_MAP_VERSION,
    }
