"""Program D · M4.3 — the OFFLINE, deterministic near-dup hashing vectorizer.

`near_dup_embedding` (Contract-1 §1.3) is a DETERMINISTIC text-feature vector, NOT a neural black box:
no model, no network, no wall-clock. WP-A owns the exact recipe; WP-D reads the precomputed vectors at
request time and only does vector math (cosine ≥ threshold) — it never computes an embedding or calls a
model. Freezing the recipe here (version tag ``hashvec-128-v1``) is what makes the two sides compatible.

THE RECIPE (frozen as ``hashvec-128-v1``):
  1. normalise the stem via the ``gates._norm_stem`` SHAPE — lowercase, numbers collapsed to ``#``,
     non-alpha stripped. Numbers→``#`` is deliberate: a template re-fired with fresh numbers ("49 apples"
     vs "91 apples") normalises to the SAME token stream, which is exactly the template-flooding near-dup
     detection must see (mirrors the QIE norm_hash discipline).
  2. tokenise on whitespace and drop the ``gates._STOP`` stopwords (imported, never re-listed — one source
     of truth for both the gate battery and this vectorizer).
  3. hash each DISTINCT token with sha256 into a bucket in ``[0, 128)`` and add PRESENCE weight 1
     (term frequency capped at 1 — i.e. a hashed SET of tokens). Presence, not raw count, because a single
     distinguishing context noun typically repeats several times within one stem; raw counts let that lone
     noun dominate the vector and push two template-paraphrase stems apart (cosine ~0.57 on the fixture),
     whereas presence keeps genuine paraphrases together (~0.90) while distinct templates stay well
     separated (~0.48). The cap is the ONE documented tuning knob; everything else is mechanical.
  4. L2-normalise → ``number[128]``. An empty token set yields the honest zero vector (never NaN).

sha256 (NOT the builtin ``hash()``, which is per-process randomised via PYTHONHASHSEED) is what makes the
bucket assignment reproducible across processes, machines, and runs — the property Contract-1 requires.
"""
from __future__ import annotations

import hashlib
import math
from typing import List

# gates is READ/IMPORT-ONLY here: one source of truth for the normalisation shape + stopword set.
from kie.qie.factory.gates import _STOP, _norm_stem

HASHVEC_MODEL_VERSION = "hashvec-128-v1"       # Contract-1 §1.3 near_dup_model_version
HASHVEC_DIM = 128
NEAR_DUP_THRESHOLD_VERSION = "cosine-0.82-v1"  # Contract-1 §1.3 near_dup_threshold_version
NEAR_DUP_THRESHOLD = 0.82                       # the request-time cosine threshold WP-D applies


def _tokens(stem: str) -> List[str]:
    """Normalised tokens of a stem: the ``gates._norm_stem`` shape, stopwords dropped. Numbers have already
    collapsed to ``#`` inside ``_norm_stem`` so numeric variants of one template tokenise identically."""
    return [t for t in _norm_stem(stem or "").split() if t and t not in _STOP]


def _bucket(token: str) -> int:
    """Deterministic, process-independent hash of a token into ``[0, HASHVEC_DIM)``.

    Uses sha256 rather than the builtin ``hash()`` (which is randomised per process) so the same token maps
    to the same bucket in every environment — the reproducibility Contract-1 §1.3 demands."""
    return int.from_bytes(hashlib.sha256(token.encode("utf-8")).digest()[:8], "big") % HASHVEC_DIM


def hashvec_128(stem: str) -> List[float]:
    """The offline, deterministic, L2-normalised 128-dim near-dup vector for a stem. See the module docstring
    for the frozen recipe. Pure function: same stem → byte-identical vector, always length ``HASHVEC_DIM``."""
    vec = [0.0] * HASHVEC_DIM
    for token in set(_tokens(stem)):           # a hashed SET of tokens (presence weighting)
        vec[_bucket(token)] += 1.0             # collisions naturally accumulate — a feature of hashing
    norm = math.sqrt(sum(x * x for x in vec))
    if norm == 0.0:                            # empty/stopword-only stem → honest zero vector, never NaN
        return vec
    return [x / norm for x in vec]


def cosine(a: List[float], b: List[float]) -> float:
    """Cosine similarity of two vectors — the exact request-time comparison WP-D performs on stored vectors.

    Pure vector math, no model. For L2-normalised inputs this equals their dot product; the norms are still
    divided out defensively so a zero vector (empty stem) yields 0.0 rather than a division error."""
    dot = sum(x * y for x, y in zip(a, b))
    na = math.sqrt(sum(x * x for x in a))
    nb = math.sqrt(sum(x * x for x in b))
    if na == 0.0 or nb == 0.0:
        return 0.0
    return dot / (na * nb)
