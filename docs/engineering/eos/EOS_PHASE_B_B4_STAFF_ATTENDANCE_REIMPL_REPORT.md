# EOS — Phase B (Track B) · B4 Staff Attendance RE-IMPLEMENTATION

**Date:** 2026-07-01 · **Scope:** B4 (re-scoped) — replace the superseded O5 device-biometric
attendance model with the FINAL owner design: **GPS geofence → anti-mock location → live camera
face (server-authoritative CV match)**. Device biometric is NEVER used for attendance (login-only).

**Standard:** `AKSHARA_ENGINEERING_CONSTITUTION.md` (Part 7B / Part 8). **Decision source:**
[`docs/ATTENDANCE_AUTH_DESIGN_DECISION.md`](../../ATTENDANCE_AUTH_DESIGN_DECISION.md) (FINAL 2026-07-01).

## Owner product decision resolved
§7 (live camera face verification) was OPEN. **Owner chose (a) — automated CV face matching**
against a per-staff **enrolled reference embedding** (server-authoritative; privacy-preserving —
an embedding vector, not a raw image). Recorded as errata in the design doc §7.

## What was built (server-authoritative core — fully verified headless)
- **Migration** `20260820000000_staff_attendance_geofence_face_reimpl.sql`:
  - Drops the device-biometric row hard-block (`staff_check_ins_biometric_check`); adds geofence +
    anti-mock + face-match evidence columns + a new CHECK (`manual` OR location_verified & face_matched
    & not-mock).
  - `school_attendance_geofences` (per-school centre + radius default **100 m** + accuracy/staleness
    policy), `staff_face_enrollments` (one active reference embedding per staff, self-RLS),
    `staff_attendance_requests` (GA-2 audited manual fallback — the ONLY no-bypass path).
  - RBAC: `approveStaffAttendance` + `manageSchoolGeofence` granted to supervisory roles only.
- **Validation module** `staff_attendance_validation.ts` (pure): Haversine geofence, cosine face
  match (threshold 0.82), anti-mock / high-accuracy / anti-stale gates, body parsing. Each failure
  throws a specific code (MOCK_LOCATION / LOW_ACCURACY / STALE_LOCATION / OUTSIDE_GEOFENCE /
  LIVENESS_FAILED / FACE_NO_MATCH / FACE_NOT_ENROLLED / GEOFENCE_NOT_CONFIGURED).
- **Repository + handlers + router**: 6 routes — `check`, `enroll-face`, `geofence` (GET/PUT),
  `manual-request`, `manual-request/decide`. Actor is always the JWT subject (anti-buddy-punching);
  every mutation emits a server audit (5 new catalog specs).

## Verification
- **deno check**: clean (staff_attendance/*, app.ts, audit catalog).
- **deno test**: **20/20 green** — 10 route/RBAC/shape contract + 10 geofence/anti-mock/face-match unit.
  Proves: 401/403/503 RBAC; supervisory perms gate geofence-set + approve; NO device-biometric field is
  accepted as proof; every location/face gate rejects deterministically.
- **Flutter layer** (controller + models + capture seams + datasource + providers + card UI + cert
  test) re-implemented to the new chain; **`dart analyze` clean** across the feature, its hosts, and
  the biometric core. Device biometric removed from the attendance path (kept only as a dormant
  login-convenience seam). No dangling references to the old model.

## Residual (external-dependency gated — NOT autonomous-completable)
1. **`flutter test` execution** — the widget/controller cert suite type-checks (`dart analyze` green)
   but the flutter test *runner* is absent in this environment. Run on a Flutter-enabled machine.
2. **Concrete device adapters** — the geolocator (GPS+mock) and camera+ML (embedding+liveness) impls
   behind `AttendanceLocationSource` / `FaceCaptureSource`. Providers currently wire loud-failing
   `DeviceAdapterPending*` placeholders (never a silent pass).
3. **Live migration apply + edge deploy + on-device run** — geofence config + face enrollment + a real
   camera/GPS check-in on a device with high-accuracy location (mock OFF), per design §8.

## Verdict
**EOS gate: PASS** for the B4 server-authoritative re-implementation (locally-verifiable scope) —
20/20 deno green, dart analyze clean, no P0/P1. The device/tooling/live-deploy items above are the
Track-B remainder, staged like the other infra-gated Track-B gates. **GA `QA-R-012` still BLOCKED**
(B4 live run + B12 7-day cron + B13 GA gate).
