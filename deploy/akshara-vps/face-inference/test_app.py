"""Contract tests for the face embedding service.

Run against a real model (no mocks — a mocked embedder cannot tell you the
preprocessing is right):

    ./fetch_model.sh
    FACE_MODEL_PATH=./models/glintr100_int8.onnx python3 test_app.py

Deliberately dependency-light (no pytest) so it can run on the deploy host
during a rollout, not only in CI.

Every rejection case asserts a specific status rather than "not 200": this
service sits in front of an attendance decision, and the failure mode that
matters is one where a malformed input quietly produces an embedding anyway.
"""
from __future__ import annotations

import base64
import io
import os
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
os.environ.setdefault("FACE_MODEL_PATH", os.path.join(_HERE, "models", "glintr100_int8.onnx"))
os.environ.setdefault("FACE_DETECTOR_PATH", os.path.join(_HERE, "models", "blaze_face_short_range.tflite"))

import numpy as np  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402
from PIL import Image  # noqa: E402

import app as service  # noqa: E402

client = TestClient(service.app)
_passed = 0
_failed = 0


def check(name: str, cond: bool, extra: str = "") -> None:
    global _passed, _failed
    if cond:
        _passed += 1
        print(f"  PASS  {name} {extra}")
    else:
        _failed += 1
        print(f"  FAIL  {name} {extra}")


def crop_b64(size=(112, 112), fmt="JPEG", seed=0) -> str:
    """A synthetic aligned crop. Not a face — these tests cover the CONTRACT
    (shape, normalisation, rejection), not recognition accuracy, which needs
    real enrolment pairs and is an owner/data gate."""
    rng = np.random.default_rng(seed)
    small = (rng.random((14, 14, 3)) * 255).astype(np.uint8)
    img = Image.fromarray(small).resize(size, Image.BILINEAR)
    buf = io.BytesIO()
    img.save(buf, format=fmt)
    return base64.b64encode(buf.getvalue()).decode()


print("health")
r = client.get("/health")
check("returns 200", r.status_code == 200, str(r.json()))
check("declares the model tag", r.json().get("modelTag") == "auraface-v1")
check("declares 512 dims", r.json().get("dims") == 512)

print("embedding contract")
r = client.post("/embed", json={"crop": crop_b64(seed=1)})
check("accepts a well-formed crop", r.status_code == 200)
if r.status_code == 200:
    vec = r.json()["embedding"]
    check("512 dimensions", len(vec) == 512, f"got {len(vec)}")
    check("L2-normalised", abs(float(np.linalg.norm(vec)) - 1.0) < 1e-5)
    check("all values finite", bool(np.all(np.isfinite(vec))))
    check("echoes the model tag", r.json()["modelTag"] == "auraface-v1")

print("determinism")
# Non-deterministic embeddings would make enrolment meaningless: the same face
# must score against itself identically every time.
a = client.post("/embed", json={"crop": crop_b64(seed=2)}).json()["embedding"]
b = client.post("/embed", json={"crop": crop_b64(seed=2)}).json()["embedding"]
check("same crop -> same embedding", float(np.dot(a, b)) > 0.9999, f"cos={np.dot(a, b):.6f}")

print("rejections — each must fail CLOSED, never emit an embedding")
check("not base64 -> 422", client.post("/embed", json={"crop": "!!!not base64!!!"}).status_code == 422)
check("empty crop -> 422", client.post("/embed", json={"crop": ""}).status_code == 422)
check(
    "not an image -> 422",
    client.post("/embed", json={"crop": base64.b64encode(b"hello world" * 20).decode()}).status_code == 422,
)
check("64x64 -> 422", client.post("/embed", json={"crop": crop_b64(size=(64, 64))}).status_code == 422)
check("224x224 -> 422", client.post("/embed", json={"crop": crop_b64(size=(224, 224))}).status_code == 422)
check(
    "oversize payload -> 413",
    client.post("/embed", json={"crop": base64.b64encode(b"\xff" * (300 * 1024)).decode()}).status_code == 413,
)
check("missing field -> 422", client.post("/embed", json={}).status_code == 422)
check("PNG is accepted", client.post("/embed", json={"crop": crop_b64(fmt="PNG", seed=3)}).status_code == 200)

print("face-presence validation")
# What the detector reliably rejects is STRUCTURE, not face-vs-blob. These are
# the cases it separates with margin; see the DETECTION_CONFIDENCE comment in
# app.py for why it is not tuned tighter.
import numpy as _np


def solid(v: int) -> str:
    buf = io.BytesIO()
    Image.fromarray(_np.full((112, 112, 3), v, _np.uint8)).save(buf, format="PNG")
    return base64.b64encode(buf.getvalue()).decode()


def gradient() -> str:
    row = _np.linspace(0, 255, 112, dtype=_np.uint8)
    buf = io.BytesIO()
    Image.fromarray(_np.tile(row[:, None, None], (1, 112, 3))).save(buf, format="PNG")
    return base64.b64encode(buf.getvalue()).decode()


def fine_noise() -> str:
    rng = _np.random.default_rng(4)
    buf = io.BytesIO()
    Image.fromarray((rng.random((112, 112, 3)) * 255).astype(_np.uint8)).save(buf, format="PNG")
    return base64.b64encode(buf.getvalue()).decode()


for label, payload in [("solid white", solid(255)), ("solid black", solid(0)),
                       ("gradient", gradient()), ("fine noise", fine_noise())]:
    r = client.post("/embed", json={"crop": payload})
    check(
        f"{label} -> 422 FACE_NOT_DETECTED",
        r.status_code == 422 and r.json().get("detail") == "FACE_NOT_DETECTED",
        f"got {r.status_code} {r.json().get('detail')}",
    )

# The positive path needs a REAL face. Supply one via FACE_TEST_FIXTURE (a
# 112x112 aligned crop) to assert it. Skipped rather than faked, because a
# synthetic "face" would prove nothing about a detector trained on real ones —
# and the failure this guards against (rejecting genuine staff) is exactly the
# one a fake fixture would hide.
fixture = os.environ.get("FACE_TEST_FIXTURE")
if fixture and os.path.exists(fixture):
    with open(fixture, "rb") as fh:
        real = base64.b64encode(fh.read()).decode()
    r = client.post("/embed", json={"crop": real})
    check("a REAL face is accepted", r.status_code == 200, f"got {r.status_code} {r.json()}")
else:
    print("  SKIP  a REAL face is accepted — set FACE_TEST_FIXTURE to a 112x112 crop")

print(f"\n{_passed} passed, {_failed} failed")
sys.exit(1 if _failed else 0)
