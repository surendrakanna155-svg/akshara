# B5 — WhatsApp Contact Surfaces · Certification

**Date:** 2026-06-25
**Status:** ✅ DONE (client-side feature; live data verified on the VPS)
**Live edge:** https://akshara.veloraunisexsalon.com
**Branch:** `feature/scope-trim-school-build`
**Migration:** none · **Edge deploy:** none (WhatsApp is a client-side `wa.me` deep-link)

---

## What B5 delivers

Drops the reusable `WhatsAppContactButton` (free `wa.me` deep-links — **no Meta
Business API**, per owner decision) into the five remaining contact surfaces, so
staff can message a contact in one tap with a pre-filled, role-appropriate
message they review before sending. Reuses the affordance + `WhatsAppLauncher`
certified 2026-06-24; the button auto-hides when no dialable number is present.

### Surfaces wired
1. **Admissions lead detail** — "WhatsApp parent" action, prefilled with the
   parent + student name (`lead.phone`).
2. **Transport drivers** — icon button in a new "Contact" column (table) + text
   button on the mobile card; transport-office message (`driver.phone`).
3. **Alumni profile** — "WhatsApp" in the profile action row; alumni-relations
   message (`alumni.phone`).
4. **Inventory vendors** — icon next to the contact person (table) + text button
   on the card; procurement message (`vendor.phone`).
5. **Fee defaulters** — icon button in a new "Contact" column (table) + on the
   mobile card; gentle fee-reminder message. Required a small model addition (see
   below) because `DefaulterRecord` carried no phone.

### Fee-defaulters model addition (the only gap surfacing exposed)
`DefaulterRecord` had no phone and the defaulters dashboard endpoint isn't
live-wired (there is no `/finance/defaulters` route — the screen is mock-backed
today). Added `guardianPhone` to the model, the API mapper (reads `guardianPhone`,
falls back to `phone`), and the mock data. The button degrades gracefully when
empty. **No new backend/endpoint was built** — wiring the defaulters *backend* is
a separate, pre-existing gap outside B5's "drop the button, no backend work" scope.

## Verification

- **Widget tests:** `test/features/whatsapp_b5_contact_surfaces_test.dart` — all
  5 surfaces render `WhatsAppContactButton` over mock data (5/5).
- **Regression:** transport + inventory + alumni + finance + admissions screen
  suites **145/145**; finance contracts **54** green.
- **`flutter analyze`:** 0 errors.

## Live data check (real VPS, real auth + prod DB)

WhatsApp is client-side, so "live-cert" = confirming the live endpoints return the
phone numbers the button consumes. Logged in as the pilot admin and probed:

| Endpoint | Live? | Phone in records |
|---|---|---|
| `GET /admissions/leads` | ✅ | ✅ 1/1 (`9000000001`) |
| `GET /transport/drivers` | ✅ | ✅ 1/1 (`+91 98765 22001`) |
| `GET /alumni/registry` | ✅ | ✅ 1/2 |
| `GET /inventory/vendors` | ✅ (entity store) | reads `phone` from payload; **0 vendor records seeded** in the pilot org yet → nothing to display |
| `GET /finance/defaulters` | ❌ no route (mock-only) | wired in-app via `guardianPhone`; backend = pre-existing gap |

So 3 of the 5 surfaces are verified end-to-end with live phone data today;
vendors is forward-compatible and will show the button once vendor records exist;
defaulters works in-app and is ready for whenever the defaulters backend lands.

## Notes
- No edge deploy / no migration — B5 ships entirely in the Flutter client.
- Honest degradation: every drop-in renders nothing when the number is missing,
  so empty/partial data never produces a dead control.

**Next:** B6 — Marketing Engine MVP (not started this batch).
