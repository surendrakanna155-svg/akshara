# Face Verification — architecture re-evaluation under an always-online assumption

**Date:** 2026-07-29 · **Supersedes the offline-first premise for this feature only**
**Inputs:** measured VPS capacity, a read-only audit of Vellora, and the licensing survey in
[`FACE_VERIFICATION_MODEL_LICENSING_SURVEY.md`](FACE_VERIFICATION_MODEL_LICENSING_SURVEY.md)

## Headline

**Move face verification server-side.** Doing so converts a blocked feature into a
shippable one, because it removes the *only* objection to the one commercially
clean model in existence.

> **⚠️ CORRECTED 2026-07-29 after measurement — see [§8](#8-measured-benchmark--corrects-2-and-5).**
> This document originally concluded that the current VPS was too small and a
> resize was required. **That was wrong.** It rested on a FLOP-derived latency
> estimate of 0.5–1.5 s per face. Measured, the model runs in **73.6 ms
> single-threaded**, and the int8 build needs **222 MB RSS**. The existing
> 1 vCPU / 3.8 GB VPS is adequate. No resize, no second host, no purchase.
> §2 and §5 are left as written, with the erroneous claims struck through, so
> the correction is visible rather than quietly edited away.

## 1. Vellora audit — there is no pipeline to adapt

Audited read-only on the shared host. **Vellora has no face recognition
capability of any kind.** The premise is false, so nothing can be reused.

| Check | Result |
|---|---|
| App identity | `ROOT_URLCONF = 'vellore_salon.urls'` — a Django salon/POS app |
| `INSTALLED_APPS` | core, accounts, services, pos, memberships, billing, integrations, inventory, finance, **staffing**, marketing, analytics, smart, admin_dashboard, backup_management, media_manager, utils — **no biometric or face app** |
| Face/ML dependencies in `requirements.txt` (165 lines) | **None.** The only image-related package is `pillow==11.3.0`, for the media manager |
| Source grep for `face_recognition\|facenet\|arcface\|insightface\|deepface\|dlib\|face_encoding\|embedding` | **Zero real hits.** Every match was inside `venv/` and came from `structlog.**stdlib**` matching the substring `dlib` |
| Running containers | akshara-edge, akshara-postgres, chotu-api, akshara-storage, akshara-rest-gateway, akshara-postgrest, root-n8n-1 — **no Vellora container at all** |

Vellora has a `staffing` app, which is probably the origin of the impression
that it does face-based attendance. It does not — there is no model, no
inference library, and no biometric field.

**Conclusion: nothing to adapt. This option is closed.**

## 2. The measured constraint — the VPS is a 1-core box

```
CPU        1 vCPU
RAM        3.8 GB total · 1.9 GB used · 1.9 GB available
Disk       48 GB total · 33 GB free
Shared by  akshara-edge, akshara-postgres, chotu-api, akshara-storage,
           akshara-rest-gateway, akshara-postgrest, n8n
```

~~This single fact governs the recommendation. AuraFace's recognition network is a
ResNet100 at 261 MB fp32 — roughly 24 GFLOPs per face. On one shared x86 core
that is ≈0.5–1.5 s per verification, with ~0.6–1 GB resident.~~

~~Loading that onto this box would consume roughly half the remaining RAM and
block the only core for ~1 s per check-in — starving Postgres and the Deno edge
function during the 08:30–09:00 arrival burst. **Do not deploy inference to the
current VPS.**~~

~~Throughput itself is not the problem. A 100-staff school checking in over 30
minutes is ~3.3 verifications/minute — about an 11% duty cycle even at 2 s each.
The problem is contention on a single core and RAM headroom, not volume.~~

> **The paragraphs above are wrong and are retained only to show the
> correction.** The FLOP-derived latency estimate overstated reality by roughly
> 10×. Measured numbers are in [§8](#8-measured-benchmark--corrects-2-and-5):
> 73.6 ms single-threaded, 222 MB RSS for the int8 build. The duty cycle at a
> 100-staff school is **~1%**, not 11%. The current VPS is adequate.

## 3. What "always online" actually changes — and what it does not

**It changes less than expected, because attendance was never offline.**
`OperationTypes.markStaffAttendance` is already registered
`OperationKind.onlineOnly`
(`lib/core/reliability/policy/operation_policy_registry.dart:59`) — deliberately,
because a queued check-in would be guaranteed stale against the server's
freshness window. So the offline-first premise **had already been abandoned for
this feature specifically**.

That kills the main objection to server-side inference: there is no offline
capability to lose. It also means this is a smaller architectural change than it
appears.

**What it does NOT change: the licence problem for tainted models.**

This is the trap worth stating plainly. Moving inference to a server is not a
laundering step. Non-commercial licences restrict **use**, not merely
redistribution — running MS-Celeb-1M-derived weights on our server to deliver a
paid service is commercial use, and prohibited. Server-side does **not** unlock
EdgeFace, SFace, GhostFaceNets or InsightFace's packs. It removes the
*redistribution* question only.

**What it DOES change: model size stops mattering.**

AuraFace-v1 was rejected in the survey on exactly one ground — 261 MB is
unshippable in a mobile bundle. On a server, 261 MB is nothing. Since AuraFace
is Apache-2.0 with commercially licensed training data, this is the **first and
only architecture that is both legally clean and technically feasible without
buying a licence.** That is the entire case for the change.

## 4. Comparison against our real requirements

| Requirement | On-device (current design) | **Server-side** | Managed API (AWS/Azure) |
|---|---|---|---|
| **Commercial licensing** | ❌ Blocked — no clean mobile-size model exists | ✅ **AuraFace-v1, Apache-2.0, commercially sourced data** | ✅ Clean by contract |
| **DPDP — data minimisation** | ✅ Best: only a template leaves the device | ⚠️ Raw frame transits; mitigated by never persisting it | ❌ Biometrics leave our control entirely |
| **DPDP — processor/consent** | ✅ No third party | ✅ No third party; we remain sole processor | ❌ Needs a processor agreement + notice; residency (Mumbai regions exist) |
| **Security — template forgery** | ❌ **Client computes the embedding** — a tampered client can enrol vector E and replay it forever (recorded P1) | ✅ **Fixed.** Server derives the embedding from the frame it received; the client cannot fabricate a template | ✅ Fixed |
| **Liveness trust** | ❌ Client asserts `livenessPassed` as a boolean | ✅ Server can verify from submitted frames | ✅ Vendor-side (often stronger) |
| **Latency** | ✅ ~20–50 ms, no round trip | ✅ **~150–250 ms inference (measured, §8)** + ~20 KB crop upload | ⚠️ ~1–2 s |
| **Offline** | — (already `onlineOnly`; no capability lost) | — same | — same |
| **VPS cost** | ✅ Zero | ✅ **Zero — fits the existing box (§8)** | ✅ Zero infra; ~$5/mo at our volume |
| **Maintenance** | ❌ Model ships per app version; a model change forces an app release **and** re-enrolment of every staff member | ✅ Swap centrally, no app release, no version skew | ✅ Vendor-managed |
| **Vendor lock-in** | ✅ None | ✅ None | ❌ Core attendance depends on an external service |

## 5. Recommendation

**Adopt server-side face verification using AuraFace-v1 (`glintr100.onnx`), on the
existing VPS — see §8.** Rationale, in priority order:

1. **It is the only legally clean path that does not require a purchase.**
2. **It fixes a real security defect.** Today the client computes the embedding
   and asserts liveness, so a tampered client can replay a stolen template
   indefinitely and the server cannot tell. Moving derivation server-side makes
   template forgery impossible. For a control that feeds payroll, that matters
   more than the latency it costs.
3. **It removes the worst operational property of the current design** — that
   changing the model forces an app release *and* re-enrolment of every staff
   member, because the server refuses to compare across model tags.
4. **It loses nothing on offline**, which was already given up for attendance.

### Infrastructure — ⚠️ superseded by [§8](#8-measured-benchmark--corrects-2-and-5)

~~Do **not** co-locate with Postgres on the 1-core box. Either resize to
≥2 vCPU / 8 GB (~$20–40/mo), or run inference on a separate small host.~~

**Measured position:** deploy the **int8 build on the existing VPS**. 63 MB on
disk, 222 MB resident, ~1% CPU duty cycle at a 100-staff school. No resize, no
second host, no additional spend.

### Keep detection and alignment on-device

Run face **detection, alignment and the blink/liveness challenge on the phone**
as they are today, and send only the cropped, aligned 112×112 face — not a full
camera frame. This:

- cuts upload to ~10–20 KB, holding latency near the bottom of the range;
- keeps the DPDP delta small: a cropped face processed in memory and discarded,
  never persisted;
- avoids a second server-side model.

Use **MediaPipe face detection** for this (Apache-2.0, Google, unambiguous) —
which the app already effectively does via ML Kit.

### ⚠️ Diligence item before committing

The AuraFace repo ships `scrfd_10g_bnkps.onnx`, `2d106det.onnx`, `1k3d68.onnx`
and `genderage.onnx` alongside the recognition model, in a layout mirroring
InsightFace's `antelopev2`. fal states they trained the **recognition** model on
commercially licensed data; it is **not established** that the detection and
landmark models are theirs rather than copied from InsightFace's non-commercial
packs. The repo-wide Apache-2.0 grant does not settle it.

**Mitigation: use only `glintr100.onnx` and do detection/alignment with
MediaPipe.** That sidesteps the question entirely, which is why the split above
is the recommendation rather than adopting the pack wholesale.

### If the owner prefers zero infrastructure work

A **managed face API** (AWS Rekognition `CompareFaces`, ap-south-1 Mumbai) is
legally clean, needs no VPS capacity, and costs roughly **$5/month** at our
volume. The cost is that staff biometrics leave our control, requiring a
processor agreement, DPDP notice, and acceptance that a core attendance flow now
depends on an external service. Viable, but it trades a governance problem for
an infrastructure one.

## 6. Migration effort

Moderate, and mostly deletion on the client:

| Change | Effort |
|---|---|
| Client: stop embedding on-device; send the aligned crop instead | Small — `FaceEmbedder` seam already isolates this; `MobileFaceNetEmbedder` is retired, `FaceCaptureScreen` returns the crop |
| Server: add an inference service (ONNX Runtime) behind the existing `/staff-attendance/check` route | Moderate — new service + container |
| Contract: 192-d → 512-d, bump `mobileFaceNetModelTag` | Small, and **safe by construction** — the server already 422s `FACE_EMBEDDING_MISMATCH` across tags, so nothing silently mis-matches |
| Re-enrolment of already-enrolled staff | **None today** — the bank is empty because the feature has never run |
| Amend the FINAL design decision | Required — see below |

The last row is the one to respect. `docs/ATTENDANCE_AUTH_DESIGN_DECISION.md` is
marked **FINAL** and mandates "live camera face verification". Server-side
inference **satisfies** that requirement — the chain is unchanged
(geofence → anti-mock → live camera face → check-in) and only *where the
embedding is computed* moves. It should still be recorded as an owner-approved
errata to that document, not changed silently.

## 7. Residual risks

- **Single point of failure.** Attendance now depends on the inference service
  being up. Mitigation: the audited manual-attendance request flow already
  exists as the sanctioned fallback, with maker–checker approval.
- **Bandwidth at the gate.** A cropped 112×112 face is ~10–20 KB, so this is
  minor — but attendance is already `onlineOnly`, so connectivity is a
  pre-existing dependency, not a new one.
- **Raw crop in memory server-side.** Must be processed and discarded, never
  written to disk or logs. This needs an explicit test, in the spirit of the
  existing "logs never leak PII" guard.
- **AuraFace accuracy is below ArcFace** by its authors' own statement. For
  1:1 verification against an enrolled reference — not 1:N identification — this
  is very likely sufficient, but the match threshold must be **re-tuned**, since
  the current threshold was set for a different embedding space.

---

## 8. Measured benchmark — corrects §2 and §5

Re-scoped for **1:1 verification against a known enrolled reference**, never 1:N
search. The authenticated staff identity is already established by the JWT, so
the model answers one question: *is this face the enrolled face for this person?*

### Method

`fal/AuraFace-v1` `glintr100.onnx` downloaded and run under ONNX Runtime 1.28.0
on Apple M4, **`intra_op_num_threads=1`** to approximate a single vCPU, batch
size 1 (1:1 never batches), 30 runs after 3 warm-ups. Verified I/O:
input `[None,3,112,112]` float32, output `[1,512]` float32.

### Results

| Build | Disk | Peak RSS | p50 @1 thread | p50 @2 | p95 @1 | Embedding fidelity |
|---|---|---|---|---|---|---|
| `glintr100` fp32 | 249 MB | 454 MB | **73.6 ms** | 52.2 ms | 74.6 ms | reference |
| **`glintr100` int8** | **63 MB** | **222 MB** | 82.2 ms | 55.0 ms | 82.8 ms | **0.9941 cosine vs fp32** |

Three things the measurement changed:

1. **Latency was overstated ~10× by the FLOP estimate.** 73.6 ms on one core,
   not 0.5–1.5 s. Scaling for a cloud vCPU at ~2–3× slower than an M4 core gives
   **~150–250 ms on the VPS** — comfortably inside a check-in interaction.
2. **int8 is not faster here — it is smaller.** 82.2 ms vs 73.6 ms, because
   dynamic quantisation pays quant/dequant overhead that Apple's fp32 NEON
   kernels avoid. On x86 with VNNI it would likely invert. The reason to ship
   int8 is **4× less disk and half the RAM**, not speed.
3. **Quantisation does not move the embedding space.** The int8 build reproduces
   the fp32 embedding at **0.9941 mean cosine** (min 0.9921). The match
   threshold sits far below that, so quantisation noise is negligible against
   the decision boundary — int8 does **not** need its own model tag or its own
   threshold.

### Capacity on the existing VPS

A 100-staff school checking in across a 30-minute arrival window is
~3.3 verifications/minute. At ~200 ms each that is **~0.7 s of CPU per minute —
about a 1% duty cycle**. Memory is 222 MB against 1.9 GB available. Both fit
with wide margin alongside Postgres, the Deno edge function and chotu-api.

**Conclusion: the existing 1 vCPU / 3.8 GB VPS is adequate. §2 and §5 were wrong
to demand a resize.**

### Why 1:1 does not unlock a smaller model — but does settle the accuracy question

The 1:1 reframing is correct and materially reduces the accuracy bar: verifying
against one known reference is far easier than searching thousands of identities,
where false-match probability compounds with gallery size.

But it does **not** produce a smaller model, because **model choice here is
constrained by licensing, not by accuracy**. Every small face model —
MobileFaceNet, EdgeFace, GhostFaceNets, SFace — is trained on MS-Celeb-1M,
VGGFace2, CASIA-WebFace or WebFace260M and is unusable commercially regardless
of how easy the task is. AuraFace is the only commercially clean model, so the
smallest legally compliant option is **AuraFace quantised: 63 MB**. There is
nothing smaller that is also legal.

What 1:1 *does* settle is the one open concern about AuraFace: its authors state
it is less accurate than ArcFace. For 1:N that would matter. For 1:1 against an
enrolled reference, with a geofence and a liveness challenge already gating the
attempt, it is comfortably sufficient. **The accuracy objection is closed by the
use case, and the size objection is closed by quantisation.**

### ⚠️ Integration blocker found while benchmarking

`face_match.ts` defaults to **`DEFAULT_FACE_MATCH_THRESHOLD = 0.82`** and clamps
any override into **`[0.5, 0.99]`** (`MIN_SIMILARITY_THRESHOLD = 0.5`).

That band was chosen for the old 192-d MobileFaceNet space. ArcFace-family 512-d
embeddings — which AuraFace is — operate far lower: OpenCV's SFace uses **0.363**,
and InsightFace verification thresholds typically sit around **0.3–0.4**.

So **0.82 would reject virtually every genuine staff member**, and the clamp
floor of 0.5 means the correct threshold **cannot be configured by environment
variable at all**. This needs a code change alongside the model swap, not just a
config value, and the new threshold must be tuned on real enrolment pairs before
go-live. Failing closed, it degrades to mass false rejection rather than false
acceptance — the safe direction, but it would look like a total outage.

### Commercial SDKs — not needed

Luxand, Innovatrics, Paravision and NEC all license on-prem 1:1 verification,
and all are quote-based rather than publicly priced. They remain a valid
fallback, but there is no longer a reason to buy: a measured, legally clean,
63 MB path that runs on existing hardware is available at zero licence cost.

### Recommendation (final)

**Server-side 1:1 verification using `glintr100` int8 (63 MB) on the existing
VPS**, with detection, alignment and the liveness challenge staying on-device
and only the aligned 112×112 crop transmitted — which is exactly the crop the
client already produces today.

Ordered work: (1) confirm the AuraFace pack-provenance item in §5, (2) widen the
threshold band and re-tune on real pairs, (3) stand up the inference service,
(4) switch the client to send the crop, (5) bump the model tag to `auraface-v1`.
