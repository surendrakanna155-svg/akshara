# WhatsApp Deep-Link Workflow — Certification

**Date:** 2026-06-24
**Scope:** Free `wa.me` deep-link messaging across roles (no Meta/WhatsApp Business API).

## Decision: deep-link is the permanent approach

Akshara contacts people on WhatsApp via **free `wa.me` deep links**: the app opens the
native WhatsApp app pre-filled with the recipient's number + a draft message, and the
**user reviews and sends it themselves**. No Business API, no template approval, no
per-message cost. The paid **Meta/WhatsApp Business API is intentionally NOT used** (now
or later). Promotional outreach is handled separately via social media.

## Result: **CERTIFIED**

| Role pair | Surface | Status |
|-----------|---------|--------|
| Teacher → Parent | Teacher → Messages → compose → "Open in WhatsApp" | ✅ wired |
| Principal/HR → Staff | HR → Employee profile → "Message on WhatsApp" | ✅ wired (new) |
| Parent → Class teacher | Parent → Attendance → "Contact class teacher via WhatsApp" | ✅ wired |

All three open WhatsApp at `https://wa.me/<international-number>?text=<prefilled>` and launch
it as an external app.

## What was hardened during certification

1. **Country-code bug fixed (correctness).** The launcher previously passed the phone
   through digit-only, so a bare 10-digit Indian number produced `wa.me/9876543210`, which
   WhatsApp **cannot resolve** (it needs the full international number). `WhatsAppLauncher`
   now normalises: 10-digit → prefix `91`; leading trunk `0` dropped; numbers that already
   carry a country code are kept; <10 digits rejected. Default country code is `91` (India),
   overridable.
2. **One reusable widget.** `WhatsAppContactButton` (`lib/core/widgets/`) encapsulates the
   validate → open → SnackBar flow so every role behaves identically, and renders nothing
   when there's no dialable number (no dead buttons). The three surfaces above now use it;
   the previous duplicated inline logic was removed.
3. **Unit tests.** `test/core/utils/whatsapp_launcher_test.dart` — 9 tests (country-code
   normalization incl. trunk-0 and custom code, URL-encoding, and the regression guard
   "a 10-digit number never produces a country-code-less link"). Green. `flutter analyze`
   clean; the 28 existing HR/teacher/parent screen tests still pass.

## Extensibility

Adding WhatsApp contact to any other surface that shows a phone (admissions leads, fee
defaulters, transport drivers, …) is a one-line drop of `WhatsAppContactButton(phone:…,
message:…)`. No backend change needed.

## Notes / limits

- On-device launch uses `url_launcher` external-application mode (standard, package-tested);
  the URI construction — the part that carried the bug — is covered by the unit tests.
- The teacher compose screen takes the parent number in the "To" field. Auto-filling it from
  the class roster is a possible future nicety, not required for the deep link to work.
