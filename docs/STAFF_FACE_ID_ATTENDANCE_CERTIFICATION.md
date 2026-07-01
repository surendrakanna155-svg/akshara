# Staff Face ID Attendance — COMPLETION CERTIFICATION

**Date:** 2026-06-30 · **Branch:** `feature/data-reliability-platform`
**Roadmap:** Owner decision **O5** (Must-Before-GA) — a **parallel GA-blocker**, NOT one of the 12 QW8
`QA-R` rows. Does not change the QW1–QW8 roadmap. GA (`QA-R-012`) stays **BLOCKED** until this feature's
**live** deploy + on-device cert pass (see "Honest residual").
**Gate:** Engineering Operating System (`/eos`).

> ⚠️ **AUTH MODEL SUPERSEDED — FINAL owner decision 2026-07-01.** This certification's attendance
> authentication (a **device-biometric hard-block** — Face ID / fingerprint via `local_auth` /
> `biometricVerified`, **no GPS, no camera face match**) is **no longer the product design.** Attendance
> auth is now **GPS geofence → anti-mock location validation → live camera face verification →
> check-in/out**, and **MUST NEVER** use fingerprint / Touch ID / PIN / password / device-biometric
> fallback (device OS biometric is allowed for **app login only**). See
> [`ATTENDANCE_AUTH_DESIGN_DECISION.md`](ATTENDANCE_AUTH_DESIGN_DECISION.md). The ledger / RBAC / audit /
> offline scaffolding below is reusable; the **authentication mechanism is superseded** and must be
> **re-implemented** before B4 can certify (tracked P1 gap). The green results below remain historically
> accurate for what was built — they do **not** certify the current design.

---

## Verdict

> **EOS gate: PASS (locally-verifiable scope).** Staff biometric self check-in/out is BUILT end-to-end
> (backend + client + native config) and certified headless. **Zero defects.** The only residual is the
> **live** leg — applying the migration + deploying the edge function to the VPS and a real on-device
> biometric run — which is **Track-B** work (needs the SSH ControlMaster socket + tenant Postgres).
> **This does NOT unblock GA.**

Authoritative sweep on local hardware (2026-06-30):
- **Flutter** `flutter test` → **3176 passed / 0 failed** (1 skipped) — +12 over QW8's 3164, no regression.
- **Deno** staff route-contract **8/0** · audit-completeness **5/0** · QA-B-066 403-envelope **2/0** (now
  covers the new route) · `deno check` clean.
- `flutter analyze` → **0 issues**.

---

## The two owner decisions that shaped it (2026-06-30)

1. **Hard-block, biometric-only.** A check-in proceeds ONLY on a real device biometric (Face ID /
   fingerprint / iris). **No device-credential (PIN) fallback.** Strongest anti-buddy-punching.
2. **Both check-in AND check-out** are recorded (single ledger, `event_type`), no pairing enforcement,
   no late/grace rules in v1.

Settled by prior decisions (NOT re-asked): no computer-vision face matching (Future Vision, Queue 5);
no GPS (Phase 2, O8); student attendance stays teacher-entered (O4); offline-queueable like other
attendance writes.

---

## What was built

### Backend (Supabase / Deno)
- **Migration** `supabase/migrations/20260818000000_staff_face_id_attendance.sql`:
  - RBAC seed — a new `markStaffAttendance` permission granted to **every staff role** (all role
    definitions except `parent`/`student`) so the staff JWT carries it.
  - An **append-only** `staff_check_ins` ledger (no UPDATE/DELETE grant) with `event_type` ∈
    {check_in, check_out} and a DB-level **`biometric_verified = TRUE` CHECK** (hard-block at the row).
  - RLS: SELECT school-scoped; **INSERT pinned to `user_id = app_current_user_id()`** — a staff member
    can only record their OWN check-in (row-level buddy-punching prevention).
- **Repository / handler / router** (`_shared/staff_attendance/*`): `POST /staff-attendance/check`;
  `requirePermission("markStaffAttendance")` + school scope; the acting employee is the **JWT subject**
  (never client-supplied); server-side hard-block (`422` if biometric not asserted); emits a server
  mutation audit (`staffAttendanceAudit`) on success. Registered in `api/app.ts` + the backend RBAC
  route inventory.

### Client (Flutter)
- `Permission.markStaffAttendance` granted to all staff personas via the
  `RolePermissionMatrix` accessor (so a new staff role inherits it; mirrors the server seed).
- `OperationTypes.markStaffAttendance` (`staffAttendance.check`) — queueable / low-risk (offline-safe).
- `AuditEventType.staffCheckInRecorded` / `staffCheckOutRecorded` (+ categorizer → workflow).
- `MutationPermissionRegistry` entries; `ServerRbacRouteInventory` slug + module + count.
- `core/biometric/biometric_authenticator.dart` — `local_auth`-backed, `biometricOnly: true`
  (hard-block); blocks when no biometric is enrolled. Injectable → certifies headless.
- `features/staff_attendance/` — models, controller (biometric → reliable write → audit), reliability-
  backed datasource, Riverpod provider, and a `StaffCheckInCard` (4 states) wired into the **HR Staff
  Attendance** screen via a **deferred** `onRecord` callback (the reliability/biometric stack resolves
  only on tap, never at screen-build time).

### Native
- iOS `NSFaceIDUsageDescription`; Android `USE_BIOMETRIC` + `MainActivity : FlutterFragmentActivity`
  (required by `local_auth`).

---

## What the certification proves (headless)

- **Hard-block:** no enrolled biometric → blocked; biometric cancelled/failed → blocked. In both cases
  **nothing is written and nothing is audited** (no PIN fallback) — asserted client-side (controller)
  AND server-side (`422` before any DB work) AND at the DB CHECK.
- **Both events** record + emit the matching audit through the real categorizer.
- **Offline:** a queued write is still recorded + audited (pending-sync surfaced).
- **RBAC:** every staff persona holds `markStaffAttendance`; `parent`/`student` never; multi-hat union
  grants it when any hat is staff; QA-B-066 confirms the route 403s without it (and does not false-deny).
- **UI:** the card renders the recorded and biometric-blocked states.

---

## Honest residual (Track-B — does NOT unblock GA)

1. **Live deploy:** apply `20260818000000_staff_face_id_attendance.sql` + deploy the edge function to the
   VPS pilot (needs the SSH ControlMaster socket — currently closed).
2. **On-device cert:** a real Face ID / fingerprint run on a device/emulator (`local_auth` cannot run in
   headless `flutter test`).
3. **Live RLS:** the self-insert / school-read isolation executes against `ERP_TENANT_DATABASE_URL`.

**GA (`QA-R-012`) remains BLOCKED** until this live leg is green (alongside the QW8 Track-B run and the
live-regression cron's 7-day green window).

---

## EOS verdict

**EOS gate: PASS** (locally-verifiable scope). 0 defects; 0 locally-open P0/P1; analyze 0; flutter
3176/0; deno 15/0. Additive (no existing behaviour changed — all RBAC/audit/registry guard tests stay
green); the hard-block is enforced in three independent layers. The live deploy + on-device run are
honestly carried to Track B, not faked.
