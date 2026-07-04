# Plan: Push Notifications, Poster Broadcasts & Holiday Calendar

> Saved 2026-06-20. Discussed but **not yet built**. Pick up later.

## Why this plan exists
Audit found that the three things the principal actually wants — phone alerts, festival
poster/greeting broadcasts to everyone, and a principal-controlled holiday calendar — are
all missing or only half-built. Backend for messaging exists; the gaps are on the phone
side, image support, and a holiday feature.

---

## Current state (from audit)
| Feature | Status |
|---|---|
| In-app inbox / notices (the bell) | ✅ Working |
| Push notifications (phone lock-screen alerts) | ❌ Backend ready, **phone app not connected to Firebase** |
| Principal broadcast to all parents/teachers/school | ✅ Works, but **text only** |
| Poster / greeting image in a broadcast | ❌ Not supported |
| Holiday announcement notifications | ❌ Not built |
| Principal picks a date as holiday/festival | ❌ No table, no screen |

Key existing files:
- In-app inbox: `lib/features/notifications/`
- Broadcast admin UI: `lib/features/communication/broadcast_admin_screen.dart`
- Broadcast routing: `lib/core/communication/school_broadcast_store.dart`
- Backend push/SMS/email service (ready, stub mode): `supabase/functions/_shared/communication/notification_service.ts`, `notification_providers.ts`
- Tables: `comm_broadcasts`, `comm_recipients`, `comm_device_tokens`, `notification_deliveries`, `notification_templates` (migration `20260614700000_communication_hub.sql`)

---

## Build items (3 pieces)

### Piece 1 — Real push notifications (connect the phone to Firebase)
Goal: parents/staff get a phone banner even when the app is closed.
- Add `firebase_messaging` (+ `flutter_local_notifications` for foreground display) to `pubspec.yaml`.
- Add Firebase project; drop in `google-services.json` (Android) + `GoogleService-Info.plist` (iOS).
- Initialize Firebase on app start; request notification permission.
- On login, get the device token and call existing backend `registerDeviceToken()`
  (`/parent/device-tokens/register`); unregister on logout.
- Turn off stub mode on the backend FCM provider; set `FCM_SERVER_KEY`.
- Test: send a broadcast → confirm lock-screen alert on real Android + iOS device.
- Est: ~0.5–1 day + Firebase account setup.

### Piece 2 — Poster / greeting image in broadcasts
Goal: principal can attach a designed poster (e.g. "Happy Diwali") and send to everyone.
- Add image upload to broadcast compose (`broadcast_admin_screen.dart`) → Supabase Storage bucket.
- Store image URL on `comm_broadcasts` (new `image_url` / attachment column).
- Render poster in the in-app inbox notice and in the push notification (rich/image push).
- Optional: simple greeting templates (festival presets).
- Est: ~1 day.

### Piece 3 — Principal holiday calendar
Goal: principal selects a date, marks it as holiday/festival; it notifies + shows everywhere.
- New table e.g. `school_holidays` (school_id, date, title, type [holiday/festival/exam], note, notify_flag).
- Admin screen: calendar/date picker to add/edit/delete holidays (e.g. mark a Wednesday or a festival).
- On save with notify on → fire a broadcast (reusing Piece 1 + 2) to all parents & staff.
- Surface holidays in attendance calendar (already has a `holiday` status to reuse) and parent/student calendars.
- Optional later: holidays auto-skip timetable/attendance.
- Est: ~1.5–2 days.

---

## Suggested order
1. **Piece 1 (push)** — unlocks the value of everything else; without it nothing reaches the phone.
2. **Piece 2 (posters)** — makes festival wishes possible.
3. **Piece 3 (holiday calendar)** — builds on 1 + 2 for holiday announcements.
