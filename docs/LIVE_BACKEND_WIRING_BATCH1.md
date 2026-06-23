# Batch 1 — Live Backend Wiring & Reality Map

Date: 2026-06-23. Branch: `feature/scope-trim-school-build`.
Live edge API: **https://akshara.veloraunisexsalon.com** (public, TLS, auto-renew cert).

## How to connect (no code change needed)
- The app is fully driven by `--dart-define`s (see `lib/core/config/environment.dart`,
  `lib/core/repositories/repository_config.dart`).
- **Base URL must be the ROOT** `https://akshara.veloraunisexsalon.com` — the edge serves
  routes at root (`/auth/login`, `/sis/students`). Do NOT append `/v1` (the committed
  default URLs do; override with `API_BASE_URL`).
- One-command launcher: **`scripts/run_live.sh`**.

## Auth — verified end-to-end against live
- `POST /auth/login {identifier, type:"phone"}` → returns dev OTP in the response body.
- `POST /auth/verify-otp {identifier, otp, type}` → returns `accessToken` (JWT carries
  `tenant_id`/`organization_id`, so reads work without extra tenant headers).
- `GET /auth/me`, `GET /auth/permissions` → 200 (test user = schoolAdmin).
- No token → 401. Wrong-persona route (`/parent/notifications` as admin) → 403. RBAC works.
- Test user: `+919876543210` (staging seed).

## Reads that WORK live today (200 with token)
SIS `/sis/students` · Exams `/academics/exams` · Attendance `/attendance/sessions` ·
Admissions `/admissions/leads`,`/admissions/applications` · Finance `/finance/fee-structures`,`/finance/invoices` ·
HR `/hr/employees`,`/hr/leave` · Transport `/transport/routes` · Hostel `/hostel/rooms` ·
Library `/library/catalog` · Management `/management/dashboard` · Alumni `/alumni/registry` ·
Inventory `/inventory/assets`,`/inventory/procurement`,`/inventory/categories` ·
Communications `/communications/templates` · Copilot `/copilot/sessions`.

This is far healthier than the older audits implied (~35% backend). The **read** layer is
broadly live across all core modules.

## App ↔ backend path mismatches to reconcile (when wiring those modules)
- **Inventory**: app calls `/inventory/items`; backend uses `/inventory/{assets,procurement,
  categories,vendors,allocations,maintenance,reports}`. Reconcile app paths in Batch 5.
- **Copilot**: app calls `/copilot/conversations`,`/copilot/chat`; backend has
  `/copilot/{sessions,assistants,suggestions}`. Reconcile in Batch 8 (copilot is a stub anyway).
- **Communications**: `/communications/broadcasts` is POST (create); GET list path needs
  confirming (templates read works).

## NOT yet tested (deliberately — avoid junk data on live)
- **Writes/mutations** across all modules. Several module API repos throw
  `ApiNotConnectedException` for writes (known stubs). Real write wiring + server RBAC on
  mutations is the substance of Batches 3–5.

## Known hardening gaps confirmed (Batch 2+)
- Dev-OTP returned in response; no real SMS provider; no rate limiting; CORS `*`.
- File storage is a stub; no DB backups; no centralized logging.
