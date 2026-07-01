# Attendance Authentication — Design Decision (FINAL)

**Owner decision · 2026-07-01 · FINAL.** This document is the single source of truth for how
**staff/teacher attendance** is authenticated. It **supersedes** the device-biometric model that was
built and certified in [`STAFF_FACE_ID_ATTENDANCE_CERTIFICATION.md`](STAFF_FACE_ID_ATTENDANCE_CERTIFICATION.md)
and the "OS Face ID / device biometric" step in the enhancement backlog's GA-1.

> **Governance:** English-first, hide-first, and the "STOP & ask on ambiguous product behaviour" rule
> still apply. This is a product-behaviour correction from the owner — it amends the frozen backlogs by
> errata (see below), it does not silently rewrite them.

---

## 1. Two authentication flows — completely separate

App login and attendance are **different flows** and must never share a mechanism.

| Flow | Who | Mechanism allowed |
|---|---|---|
| **App login** (convenience) | any user | The mobile **OS** fingerprint / Touch ID / Face Unlock **may** be used purely to unlock the app. This is a device-convenience login only. |
| **Attendance auth** (check-in / check-out) | **Teachers & Staff only** | **GPS geofence → anti-mock location validation → live camera face verification → check-in/out.** Nothing else. |

**Login biometric never affects attendance. Attendance never uses the login/device biometric.**

## 2. Attendance flow (Teachers & Staff only) — the required chain

```
GPS Geofence
  → Anti-Mock Location Validation
    → Camera Face Verification (live)
      → Attendance Check-In / Check-Out
```

Every attendance event **must** require **live camera face verification together with a verified GPS
position inside the school geofence**. No step may be skipped or bypassed.

## 3. Attendance MUST NEVER use

- Fingerprint
- Touch ID
- PIN
- Password
- **Device biometric fallback** (OS Face Unlock / Face ID / fingerprint / iris as the attendance proof)

There is **no PIN/password/device-biometric fallback** for attendance. When the geofence or camera-face
step cannot complete, the **only** path is the audited **Manual Attendance Request** (Principal/HR
approval) — never a silent bypass.

## 4. Location security requirements (strengthened)

The location component must:

- **Detect mock locations** (mock-location providers / developer-mode fake GPS).
- **Reject spoofed GPS.**
- **Require high-accuracy location** (GPS/fused high-accuracy; reject low-accuracy fixes).
- **Reject stale / cached locations** (a fresh fix per attendance event; reject old timestamps).
- **Configurable school geofence radius** (per school; default 100 m, e.g. 50 / 100 / 150 / 200 / 300 m).

## 5. What this supersedes

- **`STAFF_FACE_ID_ATTENDANCE_CERTIFICATION.md` (O5, as-built).** That feature authenticates attendance
  with a **device biometric hard-block** (`biometricVerified`, backend
  `supabase/functions/_shared/staff_attendance/staff_check_in_repository.ts`) and explicitly **no GPS,
  no camera face match**. That mechanism is now **forbidden for attendance** — the certification's
  auth model is **superseded**. (The ledger/RBAC/audit/offline scaffolding it built is reusable; the
  **authentication mechanism** is not.)
- **Enhancement backlog GA-1** flow "geofence → **OS Face ID / device biometric** → check-in": the
  **OS-biometric step is replaced** by **anti-mock GPS validation + live camera face verification**.

## 6. Implementation gap (must be tracked — not just docs)

The **as-built O5 feature does not match this decision.** Re-implementation is required:

- **Remove** the device-biometric (`local_auth` / `biometricVerified`) hard-block as the attendance proof.
- **Add** a GPS-geofence check (with the §4 anti-mock / high-accuracy / anti-stale hardening) and a
  **live camera face verification** step; record both on the `staff_check_ins` ledger.
- **Keep** device OS biometric only on the **app-login** path.

This is a **build item** (owner-gated, non-trivial: camera-face + location-hardening), **not** part of
the current documentation update. It is a **P1 gap** against the shipped O5 cert.

## 7. Open clarification for the build phase (not blocking this doc)

"**Live camera face verification**" — confirm at build time whether this means (a) **automated
computer-vision face matching** against an enrolled reference face, or (b) a **live liveness selfie
capture** recorded as audited proof (no automated match). Either satisfies "camera, not device
biometric"; the choice affects the build (CV pipeline vs capture+audit). The prior "no CV face matching"
note in the O5 cert was tied to the superseded device-biometric model and should be re-decided here.

## 8. Impact on Track B

- **B4** is re-scoped: it is **no longer** "apply migration + on-device biometric run." It cannot certify
  until the feature is **re-implemented** per this decision (geofence + anti-mock + live camera face).
- **Phase B entry gate #3** changes: not "a biometric-enrolled device" but **a device/emulator with a
  camera and high-accuracy location services (mock-location OFF)** — and it is now **gated on the
  re-implementation**, not merely a device.
- **Phase C C3** (staff-attendance dashboard/muster, GA-2/GA-3/TCH-9/HR-6) rides on the corrected
  `staff_check_ins` ledger — its metrics are unchanged, but its data source is the corrected flow.
