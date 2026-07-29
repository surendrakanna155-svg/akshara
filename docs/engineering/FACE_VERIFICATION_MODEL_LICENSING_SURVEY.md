# Face Verification — final model market survey

**Date:** 2026-07-29 · **Scope:** all face embedding models, not only MobileFaceNet
**Question:** is there a face embedding model NIKSHA OS can legally ship, on-device, in a product sold to schools?

## Verdict

**No.** After an architecture-agnostic survey, there is **no free, commercially
clean, mobile-viable face embedding model** available today.

Every candidate fails on one of exactly two axes, and none fails on both:

- **Legally clean but not mobile-viable** — one model qualifies (AuraFace-v1),
  and its recognition network is **261 MB**. The entire current app download is
  ~58 MB.
- **Mobile-viable but not legally clean** — everything else. Their weights trace
  to MS-Celeb-1M, VGGFace2, CASIA-WebFace or WebFace260M, all of which are
  research-only.

**Recommendation: defer Face Verification to V2.** Do not ship legally
questionable weights. The alternative is a paid commercial licence — a purchase
decision, priced below.

## Why this gap exists (and why more searching will not close it)

This is structural, not an artefact of a shallow search.

A face recognition model needs millions of *labelled identity* images. The only
datasets at that scale were built by scraping the web without consent —
MS-Celeb-1M, VGGFace2, CASIA-WebFace, WebFace260M, Glint360K — and every one is
licensed for non-commercial research. MS-Celeb-1M was withdrawn by Microsoft
outright in 2019.

So the accuracy leaders are all downstream of data nobody may use commercially.
The one organisation that paid for properly licensed data (fal.ai, AuraFace)
built what it needed for its own server-side product: a **ResNet100**. Nobody
has released a *small, commercially clean* face recognition model, because the
demand for that is met by paid SDKs.

The gap closes only when someone trains a mobile-size model on licensed or
synthetic data and releases it permissively. That has not happened yet.

## Method

Repository licence badges were treated as **evidence of nothing**. For each
candidate the chain checked was:

> code licence → weights licence → **training dataset licence**

The third link is the one that decides it, and it is the one almost never
stated. This is not a hypothetical concern: a survey of 1,000 papers
([arXiv:2108.02922](https://arxiv.org/pdf/2108.02922)) found that of 21 GitHub
repositories hosting models pretrained on MS-Celeb-1M, **only 3** carried the
correct non-commercial designation. The other 18 present as permissive.

## Candidate matrix

| Model | Arch | Dim | Size | Format | Training data | Code licence | **Weights licence** | Commercial | Verdict |
|---|---|---|---|---|---|---|---|---|---|
| **AuraFace-v1** (fal.ai) | ResNet100 | 512 | **261 MB** | ONNX | Commercially + publicly available sources | Apache-2.0 | **Apache-2.0** | ✅ **Yes** | ❌ Too large for mobile |
| **SFace** (OpenCV Zoo) | **MobileFaceNet** | 128 | 38.7 MB / **9.9 MB int8** | ONNX | CASIA-WebFace / VGGFace2 / MS-Celeb-1M | Apache-2.0 | Apache-2.0 *stated* | ⚠️ **Ambiguous** | ❌ Closest miss — see below |
| **CavaFace** (Qualcomm AI Hub) | ResNet-class | n/s | **250 MB** | ONNX/TFLite | Not stated | BSD-3 (wrapper) | "other" — defer to upstream | ⚠️ Unclear | ❌ Too large + unclear |
| MobileFaceNet_TF (sirius-ai) | MobileFaceNet | 192 | ~5.7 MB | TF → TFLite | MS1M-refine-v2 / VGGFace2 | Apache-2.0 | **Not grantable** | ❌ No | ❌ Ruled out |
| `mobilefacenet.tflite` (Flutter tutorials) | MobileFaceNet | 192 | ~5 MB | TFLite | **Unstated** | BSD-3 (repo) | **None — unattributed** | ❌ No | ❌ Ruled out |
| InsightFace buffalo / antelopev2 | ResNet / MBF | 512 | varies | ONNX | MS1M / Glint360K | MIT | **Non-commercial** (explicit) | ❌ No | ❌ Ruled out |
| **EdgeFace** (Idiap) | EdgeNeXt hybrid | n/s | 1.24–1.77M params | PyTorch | WebFace260M | — | **CC BY-NC-SA 4.0** | ❌ No | ❌ Ruled out |
| GhostFaceNets | GhostNetV1/V2 | 512 | small | TF | MS1MV2 / MS1MV3 | — | Inherits MS1M | ❌ No | ❌ Ruled out |
| FaceNet (davidsandberg) | Inception-ResNet | 128/512 | ~90 MB | TF → TFLite | VGGFace2 / CASIA-WebFace | MIT | Inherits datasets | ❌ No | ❌ Ruled out |
| DigiFace-1M–trained | any | — | — | — | **Synthetic**, MS Research | — | Dataset **non-commercial** | ❌ No | ❌ Ruled out |
| DCFace / IDiff-Face | any | — | — | — | Synthetic **via FFHQ** | — | FFHQ **bans face recognition use** | ❌ No | ❌ Ruled out |
| Academic lightweight (FaceLiVT, SqueezeFacePoseNet, …) | various | various | 2.5–4.4 MB | research | MS1M / CASIA / VGGFace2 | varies | Inherits datasets | ❌ No | ❌ Ruled out |
| **MediaPipe** (Google) | — | — | — | TFLite | — | Apache-2.0 | Apache-2.0 | ✅ Yes | ❌ **No identity embedder exists** |

*n/s = not stated on the model card.*

## The three that needed real analysis

### 1. AuraFace-v1 — the only unambiguously clean model

- **Licence (code + weights):** Apache-2.0, single grant covering the model files.
- **Training data:** *"trained on commercially and publicly available data
  sources to enable its usage in commercial setting"* — it exists **because**
  ArcFace's data blocks commercial use. This is the cleanest provenance found.
- **Why it still fails:** `glintr100.onnx` is **261 MB**. ResNet100 is a
  server-side backbone. Our release download is ~58 MB for arm64; this would
  multiply it ~5×, on a product aimed at modest Android phones in Indian
  schools. It is also 512-d ONNX against our 192-d TFLite contract.
- **Migration effort if ever adopted:** high — ONNX→TFLite conversion,
  192→512 contract change, `mobileFaceNetModelTag` bump, and **re-enrolment of
  every enrolled face** (the server 422s `FACE_EMBEDDING_MISMATCH` across model
  tags by design, so this is safe but not free).
- **Risk:** size alone makes it unshippable on this product. Not recommended.

### 2. SFace (OpenCV Zoo) — the closest miss, and the one worth an email

This is the only candidate that is simultaneously the right architecture, the
right size, and carries an explicit permissive grant over the model files:

- **Architecture:** *"Model files encode **MobileFaceNet** instances trained on
  the SFace loss function"* — the same architecture family as our locked contract.
- **Size:** 38.7 MB fp32, **9.9 MB int8** — genuinely mobile-viable.
- **Input/dim:** 112×112 (matches ours), **128-d** (ours is 192-d → contract
  change + tag bump, but not an architecture change).
- **Licence:** OpenCV states plainly, *"All files in this directory are licensed
  under Apache 2.0 License."* Stewarded by a reputable project, ONNX conversion
  credited to Chengrui Wang, model credited to Yaoyao Zhong.

**Why it is still not clean.** The upstream research repo
([`zhongyy/SFace`](https://github.com/zhongyy/SFace)) states **no licence at
all**, and its models were trained on **CASIA-WebFace, VGGFace2 and
MS-Celeb-1M**. So OpenCV's Apache-2.0 grant may exceed what the original author
was in a position to give. That is precisely the defect pattern from the
1,000-paper survey above — a permissive label applied downstream of
research-only data.

**This is the one candidate where the ambiguity is resolvable by asking.** If
the owner wants to pursue it, the question to OpenCV and/or Yaoyao Zhong is
narrow and answerable: *which dataset were the released `2021dec` weights
trained on, and is the Apache-2.0 grant intended to cover commercial
redistribution of those weights?* A written answer either clears it or kills it.
Until then it fails the stated bar of "no licensing ambiguity".

### 3. CavaFace (Qualcomm AI Hub) — fails on both axes

- **249.96 MB** float, 112×112 input, and licence listed as **"other"** with a
  pointer to the upstream repo. Qualcomm's BSD-3 covers their *wrapper*, not the
  weights. Fast on Snapdragon (2–3 ms), but the size and the unresolved weights
  licence both rule it out.

## What was deliberately not evaluated

**Paid commercial SDKs** — InsightFace commercial licensing, Paravision,
Innovatrics, NEC, Luxand, Neurotechnology. These are legally clean by
construction and are the industry's actual answer to this problem. They are a
**procurement decision, not an engineering one**, so they are listed as an
option rather than surveyed. InsightFace advertises commercial model licensing
directly and is the lowest-friction path, since it would keep the MobileFaceNet
architecture and this contract intact.

## Decision

**Face Verification is deferred to V2.** V1 ships without on-device face
matching rather than with weights we cannot defend.

The reasoning is not merely legal caution. NIKSHA OS is **sold** to schools, so
this is commercial use by definition; the payload is **staff biometrics**; the
jurisdiction is **India under the DPDP Act**. A licensing defect in face
recognition weights is the worst place in this product to carry risk, and unlike
most defects it would not surface until someone came looking — by which time the
weights are in every installed copy.

### What V1 ships instead — and it is not a stub

Staff attendance remains functional and audited without face matching:

- GPS geofence (now configurable per school), enforced server-side
- Anti-mock / accuracy floor / anti-stale-fix guards, enforced on both sides
- The audited manual-attendance request flow, with maker–checker approval and
  separation of duties

The embedder stays in place and **fails closed** (`FACE_MODEL_MISSING`, 12/12
tests green), pre-flighted before the capture ceremony so a user is told in the
first second rather than after a blink challenge. Nothing needs rewriting when a
licensed model arrives — dropping the file in and bumping the model tag is the
whole change.

### What would change this answer

1. A commercial licence purchased from InsightFace or an SDK vendor — **the
   realistic path**, keeps the current architecture.
2. Written confirmation from OpenCV / Yaoyao Zhong clearing the SFace weights
   for commercial redistribution.
3. Someone releasing a mobile-size model trained on licensed or synthetic data
   under a permissive licence. This does not exist today; re-check at V2.

## Sources

- [sirius-ai/MobileFaceNet_TF](https://github.com/sirius-ai/MobileFaceNet_TF)
- [MCarlomagno/FaceRecognitionAuth](https://github.com/MCarlomagno/FaceRecognitionAuth)
- [InsightFace licensing](https://www.insightface.ai/)
- [fal/AuraFace-v1](https://huggingface.co/fal/AuraFace-v1) · [file listing](https://huggingface.co/fal/AuraFace-v1/tree/main)
- [OpenCV Zoo — SFace](https://github.com/opencv/opencv_zoo/tree/main/models/face_recognition_sface) · [LICENSE](https://github.com/opencv/opencv_zoo/blob/main/models/face_recognition_sface/LICENSE) · [OpenCV issue #21192](https://github.com/opencv/opencv/issues/21192)
- [zhongyy/SFace](https://github.com/zhongyy/SFace) · [SFace paper](https://arxiv.org/abs/2205.12010)
- [Idiap/EdgeFace-XXS](https://huggingface.co/Idiap/EdgeFace-XXS) · [EdgeFace paper](https://publications.idiap.ch/attachments/papers/2024/George_IEEETBIOM_2024.pdf)
- [HamadYA/GhostFaceNets](https://github.com/HamadYA/GhostFaceNets)
- [microsoft/DigiFace1M](https://github.com/microsoft/DigiFace1M) · [paper](https://arxiv.org/abs/2210.02579)
- [IDiff-Face (ICCV 2023)](https://openaccess.thecvf.com/content/ICCV2023/papers/Boutros_IDiff-Face_Synthetic-based_Face_Recognition_through_Fizzy_Identity-Conditioned_Diffusion_Model_ICCV_2023_paper.pdf)
- [qualcomm/CavaFace](https://huggingface.co/qualcomm/CavaFace)
- [MediaPipe Face Detector](https://ai.google.dev/edge/mediapipe/solutions/vision/face_detector)
- [Mitigating Dataset Harms Requires Stewardship (arXiv:2108.02922)](https://arxiv.org/pdf/2108.02922)
- [VGGFace2 terms](https://www.robots.ox.ac.uk/~vgg/data/vgg_face/licence.txt)
