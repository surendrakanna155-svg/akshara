# Face Verification — production readiness report

**Date:** 2026-07-29 · **Architecture:** server-side 1:1, approved and implemented
**Deployed:** `akshara-face-inference` live on the production VPS, benchmarked
**Verdict:** ✅ **Engineering-complete and deployed.** Two gates remain before it
is switched on as an anti-fraud control — both need real faces, neither is code.

## 1. Regression suite — complete

| Suite | Result |
|---|---|
| `flutter analyze --fatal-infos` (repo-wide) | **No issues found** |
| `flutter test` (full, incl. 178 goldens) | **4668 passed, 0 failed** |
| `deno check supabase/functions/api/index.ts` | **clean** |
| `deno test supabase/functions/` | **4211 passed, 0 failed**, 3 ignored |
| Face inference service contract (`test_app.py`, real model) | **17/17** |

## 2. Production benchmark — on the live VPS, not a projection

Measured against the deployed container on the real 1 vCPU / 3.8 GB box, through
the actual HTTP endpoint (base64 decode + PNG decode + preprocessing +
inference), n=40 after warm-up:

| Metric | Measured |
|---|---|
| **p50 latency** | **117.6 ms** |
| p95 latency | 281.6 ms |
| min / max | 108.0 / 296.7 ms |
| **Sustained throughput** | **8.5 verifications/sec on 1 vCPU** |
| Resident memory | **149.3 MiB** |
| Crop payload | 24.6 KB (PNG) |
| Embedding | 512-d, tag `auraface-v1` |

**This beat the projection.** The architecture doc predicted 150–250 ms on the
VPS by derating an Apple M4 measurement; actual is **117.6 ms**, and throughput
is **8.5 req/s** against a conservative planning figure of 4. Memory came in at
149 MiB rather than the 222 MiB measured locally.

Host impact: available RAM went 1966 MB → 1796 MB. Every pre-existing container
(postgres, edge, postgrest, storage, rest-gateway, chotu-api, n8n) remained
healthy throughout.

## 3. Revised capacity — roughly 2× the plan

| Peak model | Per school | **Schools per vCPU** |
|---|---|---|
| Pessimistic — 100 staff, all within 15 min, every school aligned | 0.111 req/s | **~76** |
| Realistic — 60% within the busiest 30 min, staggered start times | 0.033 req/s | **~255** |

| Deployment | Infrastructure | Cost/month |
|---|---|---|
| 1–75 schools | **current VPS, `WORKERS=1`** | **₹0 extra** |
| ~150 schools | 2 vCPU, `WORKERS=2` | ~$12–15 |
| ~300 schools | 4 vCPU, `WORKERS=4` | ~$24–30 |

Scaling is adding replicas: the service is stateless, so no session affinity, no
shared cache, no coordination. **Add capacity when** sustained morning-peak
utilisation exceeds ~70% of replica capacity, or p95 drifts above ~1 s
end-to-end.

## 4. What was built

| Layer | Change |
|---|---|
| Model | AuraFace `glintr100` int8 — 63 MB, Apache-2.0, tag `auraface-v1` |
| Service | `deploy/akshara-vps/face-inference/` — FastAPI + ONNX Runtime, 1 single-threaded worker per vCPU, **no host port**, unprivileged, model mounted read-only |
| Derivation | `attendance_auth/face_embedding_client.ts` — fails closed on every path |
| Threshold | `[0.25, 0.99]`, default **0.40**, space named `auraface-v1` |
| Check-in | `face.crop` in, embedding derived server-side |
| Enrolment | same crop path, same model — so both live in one embedding space |
| Client | `FaceCapture` carries a PNG crop; the on-device embedder is gone from the capture path |

### Security improvements delivered

1. **Template forgery is no longer possible.** The client used to compute the
   embedding and post it, so a tampered build could enrol vector E and replay it
   forever with the server unable to tell. The server now derives from a crop it
   received.
2. **A client-supplied embedding is refused, loudly** (`FACE_EMBEDDING_NOT_ACCEPTED`)
   on both check-in and enrolment — not ignored, so a stale or malicious client
   cannot appear to succeed while its embedding is quietly discarded.
3. **Crops never touch disk or logs**, and travel in the request body, never a
   URL where proxies would log them.
4. **The service is unreachable from the host** — verified, no listening port.

## 5. ⛔ Two gates before this is relied on as an anti-fraud control

Both need real faces. Neither is a code change. **Until they close, face
verification should not be enabled for a live school.**

### Gate 1 — threshold calibration on real enrolment pairs

`0.40` is a defensible starting point from published ArcFace-family practice
(OpenCV's SFace ships 0.363), **not a measured operating point**. Enrol N pilot
staff, capture M genuine re-captures each, score all genuine and all cross
pairs, then set the threshold below the genuine minimum and above the impostor
maximum. If those overlap, the capture pipeline is the problem, not the number.

Failure direction is safe — too high means false rejection, which routes to the
audited manual request — but it would present as an outage.

### Gate 2 — server-side face-presence validation

Measured and recorded during calibration: **out-of-distribution inputs cluster
high.** Unrelated non-face inputs scored a mean cosine of +0.391 against each
other, max **+0.557** — above the 0.40 threshold. This is normal for a face
embedding model, but it means **a crop that is not a face can score above
threshold**, and face-presence is currently enforced only on-device, by the
client we just stopped trusting for embeddings.

A detector run on the received crop closes this. It was deliberately kept out of
this change to avoid widening scope.

## 6. Other follow-ups

- **Written confirmation from fal** that `glintr100.onnx` is the model trained on
  their commercial dataset. Cheap insurance; the model card's explicit statement
  plus the Apache-2.0 grant is the basis relied on today. Not a blocker.
- **Errata to `ATTENDANCE_AUTH_DESIGN_DECISION.md`** (marked FINAL). The mandated
  chain — geofence → anti-mock → live camera face → check-in — is **unchanged**;
  only where the embedding is computed moved. Owner-approved errata, not a silent
  amendment.
- **Payload size.** The crop is 24.6 KB as PNG, slightly above the 10–20 KB
  estimate. Fine at this volume; switching to JPEG q90 would cut it to ~6 KB if
  bandwidth ever matters, at the cost of lossy artefacts on a biometric signal.

## 7. Deployment notes worth keeping

**The VPS compose file has drifted from the repo.** `/opt/akshara/docker-compose.akshara.yml`
lacks the log-rotation config, the Postgres healthcheck fix and the
`akshara-storage` service — yet storage *is* running. Syncing it wholesale could
recreate Postgres from a config that is not what is live.

The face service was therefore deployed via a **separate additive compose file**,
`/opt/akshara/docker-compose.face-inference.yml`, which only adds and joins the
existing external `akshara-net`. Reconciling the main compose file is a separate
piece of work and should not be done casually.

**Rollback:** stop the container. Check-in then fails closed with
`FACE_SERVICE_UNAVAILABLE` (503) and staff use the audited manual request. The
enrolment bank is empty, so there is no migration to reverse and no re-enrolment
cost.
