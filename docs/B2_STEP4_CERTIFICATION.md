# B2 — Entitlement Layer · Step 4 · Certification

**Date:** 2026-06-24 · **Branch:** `feature/scope-trim-school-build`
**Scope (locked):** entitlement layer only — NO billing, payments, renewals,
invoices, MRR, addons, white-label, or subscription-management workflows. Builds
on Step 3 (`39b3c6d`).

Step 4 delivers the **minimal, read-only entitlement UI**. No backend changes, no
VPS deploy. Control Center remains ungated (owner decision).

## What was built (additive, UI-only, read-only)

| Piece | File | Notes |
|---|---|---|
| Plan badge | `lib/features/entitlements/plan_badge.dart` | chip in the admin nav header (rail + drawer); colour by status; taps → Plan & Entitlements. **Renders nothing when the entitlement layer is disabled**, so pre-B2 chrome is unchanged |
| Plan & Entitlements screen | `lib/features/entitlements/plan_entitlements_screen.dart` | current plan + status, **trial days remaining** (Trial only), full entitlement list, **locked module states**, **upgrade messaging**, **WhatsApp upgrade CTA** |
| Route | `lib/router/route_names.dart`, `lib/router/app_router.dart` | `/admin/plan` under the admin `ShellRoute`; added to `adminErpRoutes` |
| Header wiring | `lib/features/admin/admin_navigation_rail.dart` | `PlanBadge` after the brand header (drawer + expanded rail) |
| QA keys | `lib/core/testing/qa_test_keys.dart` | screen, plan-name, trial-remaining, upgrade-WhatsApp keys |

## Approved UX honoured

- **Show locked modules, never hide:** every optional module/feature is listed;
  unavailable ones render with a lock icon, a "Locked" chip and **"Upgrade to
  unlock"**. Core modules show under "Included in every plan".
- **Upgrade messaging:** an upgrade callout appears when ≥1 module is locked,
  stating how many are outside the current plan and that **no payment is taken in
  the app**.
- **WhatsApp upgrade CTA:** reuses `WhatsAppContactButton` (wa.me deep-link only —
  no Meta Business API, no in-app payment); routes the enquiry to sales.

## Read-only posture

Everything is read-only. **No** superAdmin plan-assignment screen was built: it
is not in the Step-4 build list and its `PUT /platform/.../subscription` backend
route does not exist yet (deferred). No billing/payment/renewal/invoice/MRR/addon/
white-label/subscription-management surface was added.

## Definition of Done — Step 4

| Gate | Result |
|---|---|
| Plan badge in admin header | ✅ rail + drawer; hidden when layer disabled |
| Plan & Entitlements screen | ✅ `/admin/plan` |
| Current plan + status | ✅ |
| Trial days remaining (Trial) | ✅ shown only for Trial with a trial-end date |
| Entitlement list | ✅ core (always) + 10 optional modules/features |
| Locked module states (never hidden) | ✅ lock icon + "Locked" chip + "Upgrade to unlock" |
| Upgrade messaging | ✅ callout with locked count |
| WhatsApp upgrade CTA | ✅ `WhatsAppContactButton` (wa.me) |
| `flutter analyze` | ✅ **0 errors** project-wide; no warnings/errors in any B2 file |
| Tests green | ✅ **4/4** new widget tests (Trial locked+days+CTA; Professional unlocked + trust locked + no trial; badge shows when enabled / hidden when disabled); admin shell/nav suite **35/35** incl. no-overflow rail; Step-3 entitlement tests green |
| Backward compatible | ✅ badge hidden + screen reachable only by route; flag default off → no chrome change |
| No UI beyond minimal scope | ✅ no assign/billing/payment/management screens |
| No VPS deploy | ⏭ Step 5 |

## Test commands
```
flutter test test/features/entitlements/   # 4 passed
flutter test test/features/admin/           # 35 passed (no regression)
flutter analyze                             # 0 errors
```

**Status: B2 Step 4 = certified (minimal read-only entitlement UI), local. Not
deployed; flag default off. Next = Step 5 (tests + VPS cert) on owner go.**
