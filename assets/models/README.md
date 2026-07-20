# assets/models/

## mobilefacenet.tflite — NOT bundled yet

This directory is declared as a Flutter asset (`pubspec.yaml`) and is where the
on-device face-embedding model for staff attendance auth
(`lib/features/staff_attendance/device/face_embedder.dart`,
`MobileFaceNetEmbedder`) expects to find its model file at runtime:

```
assets/models/mobilefacenet.tflite
```

**The model is deliberately NOT checked into this repository.** Until it is
added here, `MobileFaceNetEmbedder` fails loud with
`AttendanceCaptureException(step: face, code: FACE_MODEL_MISSING)` — it never
fabricates an embedding. See
`docs/ATTENDANCE_AUTH_DESIGN_DECISION.md` for the attendance-auth design this
feeds into.

## Required file contract (locked)

- **Format:** TensorFlow Lite (`.tflite`), loadable by `tflite_flutter`'s
  `Interpreter.fromAsset`.
- **Input:** `112 x 112 x 3` RGB, pixel-normalized as `(x - 127.5) / 128`
  (see `normalizePixel` / `imageToInputTensor` in `face_embedder.dart`).
- **Output:** a `192`-dimensional embedding vector. The client L2-normalizes
  it (`l2Normalize`) before sending it to the server, so the server's cosine
  similarity match reduces to a plain dot product.
- **Model tag:** the client always sends this embedder's identity as
  `face.modelTag = "mobilefacenet-v1"` alongside the embedding (see
  `mobileFaceNetModelTag` in `face_embedder.dart`). If a different model is
  ever bundled, bump this tag — the server 422s `FACE_EMBEDDING_MISMATCH`
  when a check-in's `modelTag` differs from the enrolled reference's, so
  swapping models without bumping the tag would silently compare embeddings
  from two incompatible spaces.

## Pending owner decision

Provenance and licensing of the actual `.tflite` weights (which pretrained
MobileFaceNet export to use, and under what license it may be redistributed
inside the app bundle) is **not decided in this slice** — this is a build item
for the owner. Do not fabricate, synthesize, or substitute a placeholder model
file; ship this directory empty (aside from this README) until a real,
license-cleared model is provided.
