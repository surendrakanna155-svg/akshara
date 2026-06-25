# Holiday/Event Calendar + Marketing Publisher — Phase 1 Certification

**Status:** ✅ PRODUCTION CERTIFIED (2026-06-25)
**Live cert:** `scripts/qa/live_cert_holiday_publisher.py` — **18/18** against the VPS pilot (real auth, real DB, real RBAC, real AI captions, real multi-channel fan-out).
**Scope note:** Social channels (Facebook/Instagram) are *selectable but recorded as `pending_connection`* in Phase 1; they are made real in **Phase 2 (Social Media Integration — Meta OAuth/Graph API)**, which the owner authorised to follow this phase.

## What was built (reuse-first, no greenfield publisher)

The certified `achievement_promotions` module already implemented the publisher
lifecycle (create → generate poster assets → approve → publish). Phase 1
**generalised it into a multi-channel School Publisher** and added the
principal-managed holiday/event calendar — reusing the communication hub, the AI
client, the approval gate, and the poster asset service.

**Migration `20260729000000_school_publisher.sql` (additive):**
- `school_calendar_events` — principal/admin holiday/festival/event calendar (date, type, title, description), school-scope RLS.
- `achievement_promotions` += `subject_type`, `calendar_event_id`, `destinations`, `publish_results` (existing rows stay valid).
- `comm_broadcasts.audience` widened with `all_staff`.
- `school_website_posts` — the "School Website" channel sink (ERP→website content).
- New perms `viewSchoolCalendar` / `manageSchoolCalendar` (granted to admins/principal/VP; teacher view).

**Backend:**
- `_shared/school_calendar/` — calendar CRUD (`GET`/`POST` `/school-calendar`, `DELETE /school-calendar/:id`), audited.
- `_shared/promotion/` generalised:
  - `promotion_asset_service.ts` — **subject-aware** captions (a festival reads as a greeting, a holiday as a closure notice — not "achievement" wording).
  - `publisher_ai_captions.ts` — **real AI caption enhancement** via the shared Claude client (`callClaude`), safe fallback to the deterministic captions.
  - `publisher_dispatch.ts` — on publish, fans out to the **selected** destinations: parent/student/teacher/staff apps → in-ERP `comm_broadcasts` + `notification_deliveries` (reusing `resolveBroadcastRecipients`); WhatsApp → deep-link share payload; School Website → `school_website_posts`; Facebook/Instagram → `pending_connection` (Phase 2).
  - Publish now requires an explicit `destinations[]` and stays approval-gated (`approveAchievementPromotion` = principal/marketing).

**Flutter:** `AchievementPromotion` model + mapper carry `subjectType`/`destinations`/`publishResults`; `publishPromotion` takes `destinations`; the Promotion Center screen shows a **destination picker** at publish. Analyze clean; phase5 tests 14/14. *(A dedicated calendar-admin screen is a minor remaining client task — the calendar backend is certified and events can be created via API/publisher.)*

## Live cert — 18/18

Real VPS, real prod DB, edge-minted school JWTs (a `teacher` with view/manage and a `principal` with +approve):

RBAC (unauth 401, read needs `viewSchoolCalendar` 403) · **calendar create** (festival) + list · **publication create** (subjectType=festival, linked to the holiday) · **AI poster + captions** generated, subject-aware (real AI: *"Wishing all our families a very Happy Diwali!"*, not achievement wording) · publish-before-approval blocked **409 PROMOTION_NOT_APPROVED** · **principal-only** (teacher approve 403) · principal approves · publish with no destination **422** · **publish to selected channels** → status published · **in-ERP delivery verified** (5 `notification_deliveries` to parents/students/teachers/staff = the reported recipientCount) · **WhatsApp** deep-link payload ready · **School Website** post created · **Facebook/Instagram** recorded `pending_connection` (Phase 2) · unauth publish 401 · clean teardown.

## Workflow delivered

Principal/Admin creates Holiday/Event → publication → **AI generates poster + captions** → preview (assets) → **principal/marketing approval** → **select publish destinations** → **publish only to the selected channels**. Designed channels live now: Parent/Student/Teacher/Staff apps, WhatsApp, School Website. Facebook/Instagram arrive in Phase 2.
