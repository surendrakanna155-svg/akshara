# Face Verification — deployment plan and provenance record

**Status:** implementation in progress · **Architecture:** approved 2026-07-29
**Design:** [`FACE_VERIFICATION_ARCHITECTURE_REEVALUATION.md`](FACE_VERIFICATION_ARCHITECTURE_REEVALUATION.md) ·
**Licensing:** [`FACE_VERIFICATION_MODEL_LICENSING_SURVEY.md`](FACE_VERIFICATION_MODEL_LICENSING_SURVEY.md)

## 1. Licence and provenance record — final

The model NIKSHA OS ships against, and the evidence for using it commercially.

| Field | Value |
|---|---|
| Model | **AuraFace-v1**, file `glintr100.onnx` |
| Source | `https://huggingface.co/fal/AuraFace-v1` (fal.ai) |
| Version | `AuraFace-v1`, repository as at 2026-07-29 |
| Architecture | ResNet100, ArcFace (Additive Angular Margin) objective |
| Input / output | 112×112×3 RGB, `(x−127.5)/128` → 512-d embedding |
| Reported accuracy | **99.65% on LFW** (model card) |
| **Licence** | **Apache-2.0** (`LICENSE.md`, verified: standard text, no additional clause, no named copyright holder) |
| **Training data** | *"trained on commercially and publicly available data sources to enable its usage in commercial setting"* — *"a commercial dataset comprising face images from various sources"* (model card) |
| Deployed form | Dynamic int8 quantisation — 63 MB, 222 MB RSS, **0.9941 mean cosine** against fp32 |
| Model tag | `auraface-v1` |

**Why this is defensible.** AuraFace exists *because* ArcFace's training data
forbids commercial use — that is its stated purpose, not an incidental property.
The licensor makes an explicit representation about commercially licensed
training data and grants Apache-2.0 over the artefact. That combination is the
standard basis on which commercial software adopts open weights.

**Scope of what we use — deliberately narrow.** We use **only
`glintr100.onnx`**, the identity encoder that fal's training claim is about. The
repository also ships `scrfd_10g_bnkps`, `2d106det`, `1k3d68` and `genderage` in
a layout mirroring InsightFace's `antelopev2`, and it is **not established** that
those are fal-trained rather than copied from InsightFace's non-commercial
packs. We do not use, ship, fetch or depend on any of them —
`fetch_model.sh` pulls exactly one file. Detection and alignment are done
on-device with ML Kit / MediaPipe (Apache-2.0, Google).

**Residual, recorded not hidden.** The filename `glintr100` follows InsightFace's
naming convention (Glint360K + ResNet100). Glint360K is a research dataset. The
name is most likely inherited so the file is a drop-in for InsightFace's
`FaceAnalysis` loader — fal's own README documents exactly that usage — and the
model card's explicit training-data statement is the licensor's representation,
which is what we rely on. **Recommended belt-and-braces:** one email to fal
asking them to confirm in writing that `glintr100.onnx` is the model trained on
their commercial dataset. Not a blocker; cheap insurance.

## 2. ⚠️ Security finding — out-of-distribution inputs cluster high

Measured while calibrating: feeding the model **non-face** inputs produces
embeddings that are **not** spread randomly. Unrelated synthetic inputs scored a
mean cosine of **+0.391** against each other, with a **maximum of +0.557** —
above the 0.40 acceptance threshold.

This is expected behaviour for a face embedding model (it is only meaningful on
faces; out-of-distribution inputs collapse into a degenerate region), but it has
a concrete consequence here:

> **A crop that is not a face can score above threshold.** The defence is that
> the crop must *contain a face*, which today is enforced only on-device by ML
> Kit detection — i.e. by the client we just stopped trusting for embeddings.

**Consequences, in order:**

1. **Do not use this measurement to validate the threshold.** It cannot: these
   are not faces, so the numbers say nothing about genuine-versus-impostor
   separation on real faces. Threshold calibration still requires real enrolment
   pairs (§4).
2. **Server-side face-presence validation is a required follow-up** before
   enforcement is relied upon as an anti-fraud control. A detector run on the
   received crop closes the gap. It is deliberately **not** in this change to
   avoid widening scope, and is recorded here as the top follow-up item.
3. What *was* usefully established: the embedding is highly stable to re-capture
   noise (same input + sensor noise scored **0.865–0.913**), so lighting and
   angle jitter will not by themselves push a genuine staff member below
   threshold.

## 3. Deployment

### Components

| Component | Where | Notes |
|---|---|---|
| `akshara-face-inference` | new container | `deploy/akshara-vps/face-inference/` — internal network only, never published |
| Model | `/models` mount | fetched by `fetch_model.sh`, never baked into the image, never committed |
| Edge function | existing `akshara-edge` | calls the service via `FACE_INFERENCE_URL` |

### Steps

```bash
# 1. Fetch + quantise the model on the host (once, ~250 MB download)
cd deploy/akshara-vps/face-inference && ./fetch_model.sh

# 2. Verify the service against the REAL model before wiring anything to it
FACE_MODEL_PATH=./models/glintr100_int8.onnx python3 test_app.py    # expect 17/17

# 3. Build + start, one worker per vCPU (WORKERS=1 on the current 1-vCPU box)
docker compose -f deploy/akshara-vps/docker-compose.akshara.yml up -d \
  --build akshara-face-inference

# 4. Readiness — this loads the model, so a missing/unreadable file surfaces
#    here rather than on a staff member's first check-in
docker exec akshara-edge curl -fsS http://akshara-face-inference:8080/health
```

### Configuration

| Variable | Default | Notes |
|---|---|---|
| `FACE_INFERENCE_URL` | `http://akshara-face-inference:8080` | internal DNS; never public |
| `FACE_INFERENCE_TIMEOUT_MS` | `4000` | bounds a hung service; fails closed to the manual request |
| `FACE_MATCH_MIN_SIMILARITY` | `0.40` | clamped to `[0.25, 0.99]` |
| `WORKERS` | `1` | **one per vCPU** — see §5 |
| `FACE_MODEL_PATH` | `/models/glintr100_int8.onnx` | |
| `FACE_MODEL_TAG` | `auraface-v1` | must match the server's expected tag |

## 4. Threshold calibration — an owner/data gate

`0.40` is a **defensible starting point, not a measured operating point.** It
sits at the top of the published ArcFace-family range (OpenCV's SFace ships
0.363), biasing towards false reject over false accept — the correct direction,
since a false accept is one staff member checking in as another (payroll fraud)
while a false reject routes to the audited manual request with maker–checker
approval.

Before wide rollout it must be tuned on **real enrolment pairs** from the pilot
school: enrol N staff, capture M genuine re-captures each, and score every
genuine and every cross-pair. Set the threshold below the genuine minimum and
above the impostor maximum. If those distributions overlap, the capture pipeline
(lighting, alignment, crop geometry) is the problem, not the threshold.

This cannot be done from the repository — it needs real faces, and is therefore
an owner/data gate exactly like the enrolment bank itself.

## 5. Scaling

Measured (see architecture doc §9.3): **N single-threaded workers, one per
vCPU.** Four independent workers gave 42.4 faces/s against 22.9 for one process
using four intra-op threads — 1.85× more from identical cores. Consolidating
workers into threads halves capacity; the Dockerfile and `app.py` both say so
at the point where someone would change it.

| Schools | Peak (pessimistic) | Shape | Cost/month |
|---|---|---|---|
| 1–10 | ≤1.1 req/s | current VPS, `WORKERS=1` | ₹0 extra |
| ~35 | ~3.9 req/s | 2 vCPU, `WORKERS=2` | ~$12–15 |
| ~100 | ~11 req/s | 4 vCPU, `WORKERS=4` | ~$24–30 |
| ~500 | ~55 req/s | 2 × 8 vCPU behind nginx | ~$96–120 |

The service is **stateless** — no session affinity, no shared cache, no
coordination. Scaling out is adding replicas.

**Add capacity when** sustained morning-peak utilisation exceeds ~70% of replica
capacity, or p95 verification latency drifts above ~1 s end-to-end.

## 6. Rollback

The feature is inert until a staff member has an enrolled reference, and the
enrolment bank is currently **empty** — so there is no migration to reverse and
no re-enrolment cost.

- **Disable:** stop `akshara-face-inference`. Check-in then fails closed with
  `FACE_SERVICE_UNAVAILABLE` and staff use the audited manual request, which is
  the design's sanctioned fallback and is already live.
- **Revert:** the model tag (`auraface-v1`) makes a change of model safe by
  construction — the server 422s `FACE_EMBEDDING_MISMATCH` rather than scoring
  embeddings from two different spaces against one threshold.

## 7. Follow-ups (recorded, not in scope here)

1. **Server-side face-presence validation** (§2) — required before face
   verification is relied on as an anti-fraud control.
2. **Threshold calibration on real pairs** (§4) — owner/data gate.
3. **Written confirmation from fal** on `glintr100` provenance (§1) — cheap
   insurance, not a blocker.
4. **Errata to `docs/ATTENDANCE_AUTH_DESIGN_DECISION.md`** — that document is
   marked FINAL and mandates "live camera face verification". The mandated chain
   (geofence → anti-mock → live camera face → check-in) is **unchanged**; only
   *where the embedding is computed* moves. It should be recorded as an
   owner-approved errata rather than amended silently.
