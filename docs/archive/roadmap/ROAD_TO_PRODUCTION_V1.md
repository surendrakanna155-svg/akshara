# Akshara ERP — Road to Production v1.0 (Play Store)
**Date:** 2026-06-24 · **Goal (owner):** Ship a 100% real app — every feature and button works on the live backend, **no mock, no demo** — and publish on Google Play. Only then do we approach schools.

> This is the execution roadmap. It replaces "pilot with conditions." The bar is: a school downloads it from Play Store and every button does a real thing on the live server.

## Where we actually stand (measured 2026-06-24, not from stale docs)
- Live backend wired & core loops verified: login/OTP, student→attendance→exam→results→parent, fees→receipt→parent, module writes+RBAC, Director, backups, real AI. ✅
- Dead/disabled buttons: **14** `onAction: null` cards (finite list below). 
- Stub writes: ~9 references, mostly the graceful hybrid-fallback machinery, not scattered dead writes.
- TODO/FIXME in `lib`: **0**.
- Play Store packaging: **not started** (debug signing, no icon, no privacy policy).

## The 14 buttons to make real (Batch 2)
student_app/attendance · hostel/attendance · sis/dashboard (×2) · platform/control_center/success · parent/homework · admissions/dashboard · admissions/documents · hr/performance · hr/leave · finance/collection_detail · finance/discounts · finance/defaulters · onboarding/unified_flow

---

## BATCHES (each ends green: `flutter analyze` clean, tests pass, verified on live where applicable)

### Batch P1 — Production config (make live the default, kill mock/demo)
- Release build runs with **API mode ON** and points at the live VPS by default (dart-defines baked into the release flavor).
- **Disable demo OTP** and any mock-login path for production; confirm Fast2SMS OTP is the only login.
- Audit every repository: confirm a real API implementation exists for **every write** (no `ApiNotConnectedException` reachable in a production path); keep hybrid fallback only where intended.
- Provision `ANTHROPIC_API_KEY` on the VPS (turns real AI on).
- Close Batch-7 follow-ups: off-site backups (S3/R2), WAL/PITR, alert sinks (webhook/SMS).
**Done = a release build does real things end-to-end with no mock fallback.**

### Batch P2 — Every button works
- Wire each of the 14 cards to a real destination/action (existing screen, dialog, or live data). Where a card needs a feature that doesn't exist, build the minimal real version or remove the card — **no dead ends**.
- Full sweep for any other no-op control, dead route, or "coming soon" text.
**Done = no button in the app is a no-op.**

### Batch P3 — Real notifications (the paid value)
- Firebase Cloud Messaging push wired to the device (lock-screen alerts).
- SMS/WhatsApp for critical events (extend the existing Fast2SMS integration).
- Poster/image broadcasts + holiday calendar (the delight features).
**Done = a parent's phone actually buzzes when the school posts.**

### Batch P4 — Module write completeness
- Per module, confirm every create/edit/approve persists live + is RBAC-checked. Close the read-only gaps the audit named: HR payroll writes, library catalog/fines, transport roster + route attendance, hostel leave approval, alumni events, inventory stock moves, performance reviews, recruitment.
**Done = every module a school touches supports its real daily writes.**

### Batch P5 — Live-mode E2E (test all corners)
- Re-run the ~10 core journeys **against the live backend** (shard across devices via `scripts/qa/agent_coordinator.py`).
- Add the new feature journeys (onboarding incl. placeholders) in live mode.
- Fix everything that breaks under real data/volume.
**Done = the live backend is proven, not just spot-checked.**

### Batch P6 — Play Store packaging
- Generate a **release keystore**; add `key.properties` + a release `signingConfig`; enable R8/minify + shrinkResources.
- App **launcher icon** + splash (flutter_launcher_icons / native splash).
- **Privacy policy** page (hosted URL) + Play **Data Safety** form answers.
- Permissions audit (add notification permission; justify each).
- Build signed **.aab**; set up Play Console internal testing → closed → production.
**Done = an installable, signed app on the Play internal track.**

### Batch P7 — Final polish & QA gate
- Fix all `flutter analyze` issues (currently 103, all in `test/`).
- Performance + cold-start pass; crash reporting (Sentry/Crashlytics) live.
- Full regression green; version bump; release notes.
**Done = the bar the owner set: 100%, no mock, Play-Store-ready.**

---

## Sequencing & parallelism
P1 and P6-prep (keystore/icon/privacy) can start immediately and in parallel. P2 and P4 are parallel per-module sweeps. P3 needs Firebase project + SMS vendor accounts (owner action). P5 needs P1 done. P7 is last.

**Owner actions that unblock work (only these need you):**
1. Provision `ANTHROPIC_API_KEY` on the VPS.
2. Firebase project (for push) + SMS/WhatsApp vendor confirmation.
3. S3/R2 bucket for off-site backups.
4. A hosting spot for the privacy-policy URL (can be a simple page).
5. Google Play Console account (if not already).

Everything else, I drive.
