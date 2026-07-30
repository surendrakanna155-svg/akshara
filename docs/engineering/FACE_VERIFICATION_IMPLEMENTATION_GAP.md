# Implementation gap — staff attendance face verification

**Date opened:** 2026-07-29 · **Owner decision:** D9 (website redesign workstream)
**Status:** ✅ **CLOSED 2026-07-29 — implemented, deployed and benchmarked.**
**Enforced by:** `test/release_gate/face_model_release_gate_test.dart`
(`RELEASE_GATE=1 flutter test test/release_gate/`)

> ## ⚠️ This document's original premise turned out to be wrong
>
> It said: *"One artifact is missing. Everything else is built, wired and
> verified. This is a procurement task, not a development task."*
>
> **It was not a procurement task.** No commercially licensed, mobile-size face
> model exists to procure — every free candidate (MobileFaceNet, EdgeFace,
> SFace, GhostFaceNets) is trained on MS-Celeb-1M, VGGFace2, CASIA-WebFace or
> WebFace260M, all research-only, and a repository's permissive badge does not
> change that. The only commercially clean model, AuraFace-v1, is a 261 MB
> ResNet100 that cannot ship in an APK.
>
> The resolution was architectural: **verification moved server-side**, where
> model size stops mattering. That also closed a real security defect — the
> client used to compute the embedding and post it, so a tampered build could
> replay a stolen template forever.
>
> Full reasoning:
> [licensing survey](FACE_VERIFICATION_MODEL_LICENSING_SURVEY.md) ·
> [architecture](FACE_VERIFICATION_ARCHITECTURE_REEVALUATION.md) ·
> [deployment](FACE_VERIFICATION_DEPLOYMENT_PLAN.md) ·
> [readiness](FACE_VERIFICATION_PRODUCTION_READINESS.md)

## 0. Current state (handover)

| | |
|---|---|
| **Model** | AuraFace-v1 `glintr100` int8 — 63 MB, **Apache-2.0**, tag `auraface-v1` |
| **Detector** | MediaPipe BlazeFace short-range — Apache-2.0, Google |
| **Where it runs** | `akshara-face-inference` container, **live on the production VPS**, internal network only |
| **Production latency** | **p50 124.3 ms**, p95 138.0 ms, **8.0 verifications/sec** on 1 vCPU, 183 MiB |
| **Capacity** | ~76 schools per vCPU (pessimistic peak); current VPS covers the pilot at zero extra cost |
| **Regression** | analyze clean · flutter 4682 · deno 4211 · service 22/22 |
| **Client** | sends an aligned 112×112 PNG crop; the on-device embedder is gone |
| **Enrolment** | same crop path, same model — both live in one embedding space |

### The only thing left is operational

**Threshold calibration on real pilot faces.** The shipped default (0.40) comes
from published ArcFace-family practice, not from measurement against your staff,
cameras and lighting. Run `calibrate.py` with the pilot school before enabling
face check-in for real attendance —
[operating procedure](FACE_THRESHOLD_CALIBRATION_PROCEDURE.md).

Nothing else is missing engineering.

### Does the marketing claim still hold?

Yes, and more defensibly than before. The chain the website advertises —
geofence → anti-mock → live camera face → check-in — is unchanged; only *where
the embedding is computed* moved. Note that
`docs/release/screenshots/02-teacher-dashboard.png` is quarantined for a
different reason (it predates the NIKSHA rename), so re-shoot it rather than
publishing it.

---

## 1. Owner decision

> *"Do not remove or weaken the 'Geo + Face Verified' claim. Treat Face Verification as a
> committed product capability. If the current build is missing the model or wiring, record it as
> an implementation gap to be completed in the engineering workstream, not as a reason to change
> the website or marketing assets. The website should continue assuming the intended production
> capability."*

Accepted and recorded. `nikshaos.in` keeps the claim, and
`docs/release/screenshots/02-teacher-dashboard.png` ("Checked in · 9:02 AM · **Geo+Face
verified**") stays eligible for publication. This document is the counterpart obligation: the
capability must actually ship.

---

## 2. What is missing

**The on-device face-embedding model is not in the repository.**

`assets/models/README.md` states it plainly:

> *"The model is deliberately NOT checked into this repository. Until it is added here,
> `MobileFaceNetEmbedder` fails loud with `AttendanceCaptureException(step: face, code:
> FACE_MODEL_MISSING)` — it never fabricates an embedding."*

| Item | State |
|---|---|
| `assets/models/mobilefacenet.tflite` | ❌ **absent** — directory contains only `README.md` |
| Asset declaration in `pubspec.yaml` (`assets/models/`) | ✅ present |
| `MobileFaceNetEmbedder` (`lib/features/staff_attendance/device/face_embedder.dart`) | ✅ implemented, fails loud at line 133 |
| ML Kit face capture (`device/mlkit_face_capture.dart`) | ✅ implemented |
| Enrollment UI (`face_enrollment_screen.dart`) | ✅ implemented |
| Geofence half of the claim | ✅ implemented and working |

**So the wiring is done; the artifact is not.** The failure is deliberate and correct — the
embedder refuses to invent an embedding rather than degrade silently. Nothing here is a bug to be
fixed; a file has to ship.

---

## 3. Consequence today, stated precisely

In any build produced from this tree, staff face verification **cannot succeed**. It fails closed
with `FACE_MODEL_MISSING`. The geofence half works.

The teacher dashboard's "Geo+Face verified" state is reachable in **demo/mock** mode, which is why
it appears in real captures. It is not reachable against a real enrollment until the model ships.

---

## 4. Verified complete — do not re-do this work

Audited 2026-07-29. Everything below is implemented and correct:

| Component | Verified |
|---|---|
| `MobileFaceNetEmbedder` | Lazy interpreter load; construction does no asset I/O (safe in widget tests). Throws `FACE_MODEL_MISSING` rather than ever fabricating an embedding |
| Embedding post-processing | L2-normalised, so a server-side cosine similarity reduces to a dot product |
| **Server-side matching** (`_shared/attendance_auth/face_match.ts`) | **NaN-safe.** `if (!Number.isFinite(raw)) return 0` — a non-finite score fails **CLOSED**. The verdict uses `similarity >= threshold`, never the `score < t` form that lets `NaN` pass. The Staff Face ID lane's recorded lesson is already applied |
| Acceptance threshold | Env-resolvable via `FACE_MATCH_MIN_SIMILARITY`, conservative default, non-finite env value falls back rather than breaking |
| ML Kit face capture, enrolment screen | Implemented |
| Geofence half of the claim | Implemented and working today |

**The threshold work listed as residue in the Staff Face ID lane is done.** No further code is
required for this capability.

## 5. What actually remains — one file

1. **Source `assets/models/mobilefacenet.tflite`.**

   | Requirement | Value |
   |---|---|
   | Architecture | MobileFaceNet |
   | Format | TensorFlow Lite (`.tflite`) |
   | Input | **112 × 112 × 3**, RGB |
   | Output | **192-dimensional** embedding |
   | Model tag recorded with each capture | `mobilefacenet-v1` |
   | Expected size | ~1 MB (the gate rejects anything under 100 KB as a placeholder) |

   **Confirm the licence permits redistribution inside a commercial application.** This is the
   step that makes it a procurement decision rather than a download — it is why the model was
   deliberately kept out of the repository in the first place.

2. **Verify end to end on a real device**: enrol → check in → match, plus a negative case that is
   correctly rejected. The unit-level maths is already covered by `face_match_test.ts`.
3. **Confirm APK size impact** — the model ships in every build.
4. **Re-run the release gate**: `RELEASE_GATE=1 flutter test test/release_gate/` must pass.
5. **Re-confirm the depicted state** in `02-teacher-dashboard.png` is reachable in a shipping
   build, closing the loop with the website's depicted-state rule.

---

## 5. Website coupling — what changes if this slips

The website assumes the production capability per D9, so **no website change is required or
pending**. One dependency is worth stating once, plainly, so it is a tracked date rather than a
surprise:

> If the model has not shipped by public launch, `nikshaos.in` will be advertising a capability
> that the released binary cannot perform. That is a **schedule** dependency, not a truth problem
> today — but it becomes one on launch day.

Recommended: treat "model shipped and verified on device" as a **launch gate** alongside the
existing `APP_ENV=staging → production` gate, so both are hit deliberately rather than discovered.

---

## 6. Cross-references

- `assets/models/README.md` — why the model is absent and what fails without it
- `docs/ATTENDANCE_AUTH_DESIGN_DECISION.md` — the attendance-auth design this feeds
- `docs/website/NIKSHAOS_SITE_REDESIGN_PROPOSAL.md` §10 claim 9, §10.1 — the website-side record
- `docs/release/screenshots/README.md` — capture provenance for the affected screenshot
