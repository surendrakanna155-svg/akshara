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

## Licensing survey — 2026-07-29 (do NOT skip this)

> **A second, architecture-agnostic survey of the whole market followed this
> one. Its conclusion: there is no free, commercially clean, mobile-viable face
> embedding model of ANY architecture, and Face Verification is deferred to V2.
> Full candidate matrix, evidence and owner options:
> [`docs/engineering/FACE_VERIFICATION_MODEL_LICENSING_SURVEY.md`](../../docs/engineering/FACE_VERIFICATION_MODEL_LICENSING_SURVEY.md).**
>
> Read that before considering any model, including non-MobileFaceNet ones.

A search was run for a pre-trained MobileFaceNet `.tflite` matching the contract
above that could be redistributed inside a **commercially sold** app. **None was
found.** Record of what was checked, so this is not re-derived — or worse,
quietly ignored by someone who finds a `.tflite` on GitHub and drops it in:

| Candidate | Code licence | Why it cannot ship |
|---|---|---|
| [`sirius-ai/MobileFaceNet_TF`](https://github.com/sirius-ai/MobileFaceNet_TF) | Apache-2.0 | The **weights** are trained on MS1M-refine-v2 (an MS-Celeb-1M derivative) / VGGFace2. Apache-2.0 covers the repo's *code*; it cannot grant commercial rights to weights the author never held. |
| [`MCarlomagno/FaceRecognitionAuth`](https://github.com/MCarlomagno/FaceRecognitionAuth) (the file most Flutter tutorials copy) | BSD-3-Clause | Ships `assets/mobilefacenet.tflite` as an **unattributed binary** — no source, author or training set stated. Same weights as above with the audit trail removed, which is worse, not better. |
| InsightFace pretrained models (upstream of essentially all ArcFace / MobileFaceNet weights) | code MIT | [insightface.ai](https://www.insightface.ai/) states plainly: *"Pre-trained models are for non-commercial research only — contact us for commercial model licensing."* |

The blocker is the **training data**, not the architecture:

- **MS-Celeb-1M** — non-commercial research only, and *retracted* by Microsoft in
  2019 over privacy and consent concerns. A survey of 1,000 papers
  ([arXiv:2108.02922](https://arxiv.org/pdf/2108.02922)) found only **3 of 21**
  GitHub repositories hosting MS1M-pretrained models carried the correct
  non-commercial designation — so a permissive badge on a face-model repo is
  not evidence of anything.
- **VGGFace2** — CC-BY-NC-SA-4.0. Commercial use prohibited, and the terms
  propagate explicitly to "any modification and/or re-distribution ... in any
  form", which is what a fine-tuned or converted model is.

**Why this matters more here than in a hobby app.** NIKSHA OS is sold to schools,
so this is commercial use by definition. The data is **staff biometrics**, in
India, under the DPDP Act. A licensing defect in face-recognition weights is the
worst possible place in this product to carry legal risk.

### The one commercially-clear model found is NOT a MobileFaceNet

[`fal/AuraFace-v1`](https://huggingface.co/fal/AuraFace-v1) is Apache-2.0 and
was deliberately *"trained on commercially and publicly available data sources
to enable its usage in commercial setting"* — it exists precisely because
ArcFace's training data blocks commercial use. It solves the legal problem and
fails this contract on every technical axis:

- **ResNet100**, not MobileFaceNet — a server-class backbone, orders of
  magnitude larger than MobileFaceNet's ~5.7 MB. On-device inference on a modest
  Android phone is the whole point of this slice.
- **512-d** output, not 192-d.
- **ONNX**, not TFLite.

Adopting it is an architecture change, not a drop-in: ONNX→TFLite conversion, a
192→512 contract change, a `mobileFaceNetModelTag` bump, and **re-enrolment of
every already-enrolled face** (the server 422s `FACE_EMBEDDING_MISMATCH` across
model tags by design, so this is safe but not free). It is recorded here as a
candidate, not a recommendation — it would need on-device benchmarking first.

### Owner options

1. **Buy an InsightFace commercial model licence.** Keeps MobileFaceNet and this
   contract intact; they sell exactly this. Confirm they supply a 112×112 → 192-d
   export — if the dimensions differ, bump `mobileFaceNetModelTag` and the server
   will refuse to compare across spaces rather than silently mis-match.
2. **Licence a commercial face-SDK vendor** (Paravision, Innovatrics, NEC, …).
   Heavier, usually per-device licensing.
3. **AuraFace + architecture change**, with the caveats above. Free and clean
   legally; benchmark on target hardware before committing.
4. **Ship V1 without face check-in — the current state, and the zero-risk one.**
   The embedder fails closed (`FACE_MODEL_MISSING`), and staff attendance still
   works: geofence + anti-mock + the audited manual-request fallback. This needs
   no decision today.
