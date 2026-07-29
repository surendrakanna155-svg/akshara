"""NIKSHA OS — face embedding service (1:1 verification support).

Derives a 512-d AuraFace embedding from an aligned 112x112 face crop. It does
NOT decide matches: the edge function owns the cosine comparison and the
threshold, so the authority for "is this the enrolled person" stays in one
place (`face_match.ts`).

Deployment shape, per the measured benchmark
(docs/engineering/FACE_VERIFICATION_ARCHITECTURE_REEVALUATION.md §9.3):
N SINGLE-THREADED worker processes, one per vCPU. Four independent
single-threaded workers measured 42.4 faces/s versus 22.9 for one process using
four intra-op threads — 1.85x more throughput from identical cores. Hence
`intra_op_num_threads=1` below and `--workers N` in the container command;
setting either differently silently halves capacity.

Batching is deliberately absent: the workload is compute-bound (80.0 ms/face at
batch 8 versus 81.5 ms at batch 1), so a coalescing layer would add latency and
complexity for no throughput.

SECURITY / DPDP: the crop is processed in memory and never written to disk, and
is never logged. Only the derived embedding leaves this process. The service
binds to the internal network only and is never exposed publicly.
"""
from __future__ import annotations

import base64
import binascii
import io
import os

import numpy as np
import onnxruntime as ort
from fastapi import FastAPI, HTTPException
from PIL import Image
from pydantic import BaseModel, Field

MODEL_PATH = os.environ.get("FACE_MODEL_PATH", "/models/glintr100_int8.onnx")
DETECTOR_PATH = os.environ.get(
    "FACE_DETECTOR_PATH", "/models/blaze_face_short_range.tflite"
)
# Set FACE_REQUIRE_DETECTION=false only to debug; it disables a safety check.
REQUIRE_DETECTION = os.environ.get("FACE_REQUIRE_DETECTION", "true").lower() != "false"

# Deliberately LOW — this is a structural sanity check, not the primary defence.
#
# Measured on this model at 112x112: a real face scores ~0.51-0.59, while smooth
# blob noise scores ~0.53. Those overlap, so the detector CANNOT reliably
# separate a face from a face-shaped blob, and any attempt to tune it to do so
# would start rejecting genuine staff. What it separates reliably is STRUCTURE:
# at 0.2, solid colours, gradients and fine noise are all rejected while a real
# face is detected with wide margin.
#
# The primary defence against a non-face is the MATCH THRESHOLD, and measurement
# supports that: non-face inputs score at most +0.180 against a real enrolled
# face, well below the 0.40 acceptance threshold. This check exists to turn
# obvious garbage into a clear "no face detected — capture again" instead of a
# confusing FACE_NO_MATCH, and to catch a client that has broken entirely.
DETECTION_CONFIDENCE = float(os.environ.get("FACE_DETECTION_CONFIDENCE", "0.2"))
# Must match `mobileFaceNetModelTag`'s successor on the client/server. The
# server refuses to compare embeddings across differing tags, so this string is
# what makes a model swap safe rather than silently wrong.
MODEL_TAG = os.environ.get("FACE_MODEL_TAG", "auraface-v1")
INPUT_SIZE = 112
EMBEDDING_DIMS = 512
# A 112x112 RGB JPEG is ~10-20 KB. This bounds a malicious or buggy client and
# is checked BEFORE any decode work.
MAX_CROP_BYTES = 256 * 1024

_session: ort.InferenceSession | None = None
_detector = None


def _load_detector():
    """MediaPipe BlazeFace (Apache-2.0, Google). Loaded lazily and reused —
    creating a detector per request would dominate the request cost."""
    global _detector
    if _detector is None:
        import mediapipe as mp
        from mediapipe.tasks import python as mp_python
        from mediapipe.tasks.python import vision

        _detector = vision.FaceDetector.create_from_options(
            vision.FaceDetectorOptions(
                base_options=mp_python.BaseOptions(model_asset_path=DETECTOR_PATH),
                min_detection_confidence=DETECTION_CONFIDENCE,
            )
        )
        globals()["_mp"] = mp
    return _detector


def _assert_face_present(rgb: "np.ndarray") -> None:
    """Reject a crop that contains no detectable face.

    Runs BEFORE the embedding, so a client sending non-image data gets a clear,
    actionable error instead of an embedding that later fails to match for
    reasons nobody can diagnose.
    """
    if not REQUIRE_DETECTION:
        return
    try:
        detector = _load_detector()
        mp = globals()["_mp"]
        image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb)
        result = detector.detect(image)
    except HTTPException:
        raise
    except Exception:
        # A broken detector must not silently disable the check, and must not
        # take attendance down either — surface it as unavailable so the caller
        # falls back to the audited manual request.
        raise HTTPException(status_code=503, detail="DETECTOR_UNAVAILABLE")

    if not result.detections:
        raise HTTPException(status_code=422, detail="FACE_NOT_DETECTED")


def _load() -> ort.InferenceSession:
    global _session
    if _session is None:
        opts = ort.SessionOptions()
        opts.intra_op_num_threads = 1
        opts.inter_op_num_threads = 1
        opts.graph_optimization_level = ort.GraphOptimizationLevel.ORT_ENABLE_ALL
        _session = ort.InferenceSession(
            MODEL_PATH, opts, providers=["CPUExecutionProvider"]
        )
    return _session


app = FastAPI(title="niksha-face-inference", docs_url=None, redoc_url=None)


class EmbedRequest(BaseModel):
    # Base64 of an aligned 112x112 face crop (JPEG or PNG).
    crop: str = Field(min_length=1)


class EmbedResponse(BaseModel):
    embedding: list[float]
    modelTag: str
    dims: int


def _decode(crop_b64: str) -> "tuple[np.ndarray, np.ndarray]":
    try:
        raw = base64.b64decode(crop_b64, validate=True)
    except (binascii.Error, ValueError):
        raise HTTPException(status_code=422, detail="CROP_NOT_BASE64")
    if not raw:
        raise HTTPException(status_code=422, detail="CROP_EMPTY")
    if len(raw) > MAX_CROP_BYTES:
        raise HTTPException(status_code=413, detail="CROP_TOO_LARGE")

    try:
        img = Image.open(io.BytesIO(raw))
        img.verify()  # cheap structural check before the real decode
        img = Image.open(io.BytesIO(raw)).convert("RGB")
    except Exception:
        raise HTTPException(status_code=422, detail="CROP_NOT_AN_IMAGE")

    if img.size != (INPUT_SIZE, INPUT_SIZE):
        # The client aligns and crops. Silently resizing here would hide a
        # broken client and change the geometry the model was trained on.
        raise HTTPException(status_code=422, detail="CROP_WRONG_SIZE")

    rgb = np.asarray(img, dtype=np.uint8)
    # ArcFace preprocessing: (x - 127.5) / 128, CHW, batch of one.
    arr = rgb.astype(np.float32)
    arr = (arr - 127.5) / 128.0
    return np.transpose(arr, (2, 0, 1))[np.newaxis, ...], rgb


@app.post("/embed", response_model=EmbedResponse)
def embed(req: EmbedRequest) -> EmbedResponse:
    tensor, rgb = _decode(req.crop)
    # Face-presence check BEFORE the embedding — a crop with no face should
    # never reach the matcher.
    _assert_face_present(rgb)
    sess = _load()
    out = sess.run(None, {sess.get_inputs()[0].name: tensor})[0][0]

    norm = float(np.linalg.norm(out))
    if not np.isfinite(norm) or norm == 0.0:
        # A degenerate embedding would cosine-compare as 0 downstream, but fail
        # here explicitly rather than emit a vector we know is meaningless.
        raise HTTPException(status_code=422, detail="EMBEDDING_DEGENERATE")

    vec = (out / norm).astype(float)
    if not np.all(np.isfinite(vec)):
        raise HTTPException(status_code=422, detail="EMBEDDING_NOT_FINITE")

    return EmbedResponse(
        embedding=[float(x) for x in vec],
        modelTag=MODEL_TAG,
        dims=EMBEDDING_DIMS,
    )


@app.get("/health")
def health() -> dict[str, object]:
    """Readiness. Loads the model on first call so an unreadable or missing
    model file surfaces here rather than on a staff member's first check-in."""
    try:
        sess = _load()
    except Exception:
        raise HTTPException(status_code=503, detail="MODEL_UNAVAILABLE")
    detector_ok = True
    if REQUIRE_DETECTION:
        try:
            _load_detector()
        except Exception:
            detector_ok = False
    if REQUIRE_DETECTION and not detector_ok:
        raise HTTPException(status_code=503, detail="DETECTOR_UNAVAILABLE")
    return {
        "status": "ok",
        "faceDetection": "enabled" if REQUIRE_DETECTION else "DISABLED",
        "modelTag": MODEL_TAG,
        "dims": EMBEDDING_DIMS,
        "inputSize": INPUT_SIZE,
        "provider": sess.get_providers()[0],
    }
