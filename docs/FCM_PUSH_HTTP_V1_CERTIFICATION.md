# Firebase Cloud Messaging (HTTP v1) — Push Notifications Certification

Completes the push-notification layer of the existing notification system using
the **current Google-recommended FCM HTTP v1** architecture. The Communication
Hub (templates, delivery queue, `comm_device_tokens`, in-app inbox, routes) was
**reused, not rebuilt** — only the missing Firebase layer was added and the
retired legacy FCM API was replaced.

## Status — ✅ PRODUCTION CERTIFIED (live), 2026-06-25

Live cert **13/13 PASS** against the real VPS / real DB / real Firebase project
`akshara-erp` via `scripts/qa/live_cert_fcm_push.py`.

## What was built (only the missing Firebase layer)

### App (Flutter, Android)
- `firebase_core` + `firebase_messaging` added; `lib/firebase_options.dart`
  (Android) generated from `android/app/google-services.json`.
- Gradle: `com.google.gms.google-services` plugin wired
  (`android/settings.gradle.kts`, `android/app/build.gradle.kts`).
- `lib/core/notifications/push_messaging_service.dart`:
  - runtime notification permission (Android 13+ `POST_NOTIFICATIONS`, iOS prompt),
  - FCM token fetch + **registration via the existing**
    `/parent|/student/device-tokens/register` route (reuses
    `CommunicationRepository.registerDeviceToken`),
  - **token-refresh** re-registration and re-sync on login,
  - **foreground** message → in-app banner (root `ScaffoldMessenger`) + inbox
    refresh,
  - **background / terminated** tap → deep-link navigation from `data.route`.
- `main.dart` initializes Firebase (guarded) and registers the background handler.

### Backend (Supabase Edge / Deno)
- `supabase/functions/_shared/communication/fcm_v1_client.ts` — **FCM HTTP v1**:
  service-account OAuth2 (JWT-bearer, scope `firebase.messaging`), cached access
  token, `POST /v1/projects/akshara-erp/messages:send`.
- `notification_providers.ts` `sendPush()` now calls the v1 client and forwards
  `data` (notification_id, category, child_context, route). The legacy
  `fcm.googleapis.com/fcm/send` + server-key path is **removed**.
- `notification_provider_config.ts` push config is service-account based
  (`configured` / `stubMode`), driven by `FCM_SERVICE_ACCOUNT_JSON`.

## Certification checks (13/13)

| Check | Result |
|-------|--------|
| health | PASS |
| RBAC — unauth register rejected (401) | PASS |
| RBAC — mobile/school scope required (403) | PASS |
| Parent registers token via existing route (201) | PASS |
| Token row persisted in `comm_device_tokens` | PASS |
| Student registers via student route (201) | PASS |
| Idempotent re-register (ON CONFLICT, single row) | PASS |
| Deployed v1 client configured (project `akshara-erp`) | PASS |
| Push in **v1 mode, not stub** | PASS |
| **Real OAuth + v1 endpoint reached** (FCM `INVALID_ARGUMENT` on bogus token, not `UNAUTHENTICATED`) | PASS |
| Retired legacy server-key API removed | PASS |
| Unregister deactivates token (200) | PASS |
| Clean teardown | PASS |

The decisive proof: with the **real service account**, FCM returns
`400 INVALID_ARGUMENT — "The registration token is not a valid FCM registration
token"` for a dummy token. That response is only reachable **after** Google
accepts the service-account OAuth bearer and the v1 endpoint is hit — an invalid
credential would return `401 UNAUTHENTICATED`.

## Server configuration (VPS)

- `FCM_SERVICE_ACCOUNT_JSON` — the Firebase service-account JSON, stored as a
  **base64 env secret** in `/opt/akshara/.env.akshara`. **Never committed to git.**
- `FCM_STUB_MODE=false` — enables real sending (default is stub).
- Edge recreated to load the new env + code.

## Scope / follow-ups

- **Android-only** this batch — only `google-services.json` was provided. iOS is
  cleanly stubbed in `firebase_options.dart`; to enable iPhone push, add
  `GoogleService-Info.plist`, populate `DefaultFirebaseOptions.ios`, and upload an
  **APNs Auth Key (.p8)** in Firebase Console → Cloud Messaging.
- **Per-event deep links**: the transport carries `data.route` and the app honors
  it; wiring each event type's route (per the catalogue in `docs/Notifications.md`)
  into the enqueue path is an additive future enhancement — no app change needed.
- **Poster/image push**: `notification` text + data routing work now; image
  attachments would need a public image URL (Supabase Storage) on the payload.
