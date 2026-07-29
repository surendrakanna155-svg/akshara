# NIKSHA branding sweep — record

**Date:** 2026-07-29 · **Origin:** owner decision D12 (website redesign workstream)
**Status:** ✅ **SWEEP APPLIED** — owner escalated from "handoff" to "complete sweep before release"
**Enforced by:** `test/branding/niksha_branding_guard_test.dart`

> Superseding note: this document was written as a handoff when the change looked too wide to
> apply safely. The owner then directed a complete sweep with tests kept in sync, which is what
> was done. §6 records what was changed, and §7 what was deliberately **not**.

---

## 1. The literal instruction is already satisfied

> *"Replace every remaining occurrence of 'Akshara Demo School' with 'NIKSHA Demo School'."*

**Done — by a parallel lane, before this handoff was written.** Both occurrences now read
`NIKSHA Demo School`:

| File | Line |
|---|---|
| `lib/core/repositories/mock/mock_school_completion_repository.dart` | 60 |
| `lib/features/evolution/evolution_providers.dart` | 39 |

That lane also left the right note in place, which is worth preserving verbatim:

> *"User-visible: this seed drives `schoolDisplayNameProvider`, i.e. the login screen, the splash
> screen, the app title and the parent shell header in demo/mock mode — and therefore every store
> screenshot. It must carry the NIKSHA brand, not the pre-rename one."*

**Zero occurrences of `Akshara Demo School` remain** anywhere outside historical documents.

---

## 2. The instruction's *intent* is not satisfied — the residue is far larger

The reason D12 was raised is that the old brand renders in product screenshots. That problem is
not confined to one string. A full sweep finds **197 occurrences of user-visible `Akshara …`
naming**, across at least 25 distinct fictional entities:

```
Akshara Analytics · Akshara Care Hospital · Akshara Central Campus · Akshara City Central
Akshara Default · Akshara Director · Akshara East Campus · Akshara Education Trust
Akshara Green Valley · Akshara Horizon Campus · Akshara International Hyderabad
Akshara International School · Akshara International — Hyderabad · Akshara Internship
Akshara Main Campus · Akshara Main Gate · Akshara North Campus · Akshara Public School
Akshara School · Akshara South Campus · Akshara South Franchise · Akshara Stationery Supplies
Akshara Student Import Template · Akshara Support · Akshara Vidyalaya · Akshara Trust Network
```

Plus `senderId: 'AKSHARA'` in `mock_school_completion_repository.dart` — the WhatsApp sender ID,
which is user-visible **in the message itself**, on a real parent's phone.

### Distribution

| Area | Count | Renders to a user? |
|---|---|---|
| `lib/` | **77** | **Yes** — mock repositories feed every demo/screenshot surface |
| `test/`, `patrol_test/` | **63** across **36 files** | No, but they **assert** on these strings |
| `supabase/functions/` | **57** | Backend seeds/fixtures — check per case |

### `lib/` hot spots — where a capture is most likely to expose it

| File | Count |
|---|---|
| `mock_director_repository.dart` | 12 |
| `mock_transport_repository.dart` | 7 |
| `mock_platform_operations_repository.dart` | 7 |
| `mock_multi_school_operations_repository.dart` | 7 |
| `mock_control_center_repository.dart` | 5 |
| `mock_platform_intelligence_repository.dart` | 4 |
| `mock_inventory_finance_repository.dart` | 4 |
| `mock_alumni_repository.dart` | 3 |
| 24 further files | 1–2 each |

Full list reproducible with:

```bash
grep -rn "'Akshara \|\"Akshara " lib/ --include="*.dart" | grep -viE "^\s*//"
```

---

## 3. Why this was not applied in the website workstream

Three reasons, in order of weight:

1. **63 test assertions across 36 files are coupled to these exact strings.** A blanket
   find-and-replace in `lib/` turns green tests red; the assertions must move in the same commit.
   Examples: `test/core/reports/report_card_pdf_test.dart` (3×`Akshara Vidyalaya`),
   `test/core/reports/akshara_report_export_csv_test.dart`,
   `test/core/reports/qa_x_023_board_pack_pdf_test.dart`.
2. **A parallel lane is actively editing this worktree** — it had ~44 uncommitted files mid-session
   and briefly broke the build. A 197-site rename landing on top of that invites a painful merge.
3. **It is product work, and the website must not drive product work** (owner's governing
   principle). The website's correct response to a branded screenshot is to *not use it*, which is
   what the asset-driven architecture already does.

---

## 4. Recommended approach for the engineering session

**Do not blanket-replace.** `Akshara → NIKSHA` across 197 sites is a wide, low-information change
and some hits are legitimately historical.

Suggested order:

1. **Tier 1 — anything that can reach a real user.** `senderId: 'AKSHARA'` first (it goes out in
   WhatsApp messages), then the mock repositories that back shipped demo screens: director,
   transport, control-center, platform-operations, multi-school, parent, SIS, fee store.
2. **Tier 2 — PDF/CSV/document generators.** `sis_certificate_pdf_service.dart`,
   `admissions_offer_letter_pdf_service.dart`, `receipt_models.dart`. These produce artifacts a
   school hands to a parent, so a stale brand there outlives a screenshot.
3. **Tier 3 — tests, in the same commits as their subjects**, so the suite never goes red.
4. **Tier 4 — `supabase/functions/` seeds**, case by case; some are probe fixtures that no one sees.
5. **Leave historical documents alone** — `docs/archive/**`, dated certifications and audit records.
   Rewriting a brand name inside signed-off evidence falsifies the evidence, which is the same rule
   the domain-migration audit applied (§2 Tier 5).

**Add a guard**, or this recurs: a test asserting that no shipped-facing string matches
`/Akshara/i`, with an explicit allow-list for historical fixtures. Every wave in this project is
expected to ship a guard rather than fix instances one at a time.

---

## 5. Effect on the website workstream

Under the asset-driven rule, a capture carrying pre-rename branding is simply **not published**,
and the section that needed it is omitted rather than stubbed. So this handoff does **not** block
the site — it determines how much of the site can be filled.

| Capture | Before | After the D12 fix already landed |
|---|---|---|
| `parent-dashboard` | ⛔ blocked on "Akshara Demo School" | ✅ **brand-clear** — still blocked on the separate `—` vs populated-value contradiction |
| `student-dashboard` | ⛔ blocked | ✅ **unblocked, publishable** |
| `principal-admin-hub`, `teacher-dashboard`, `sign-in` | ✅ | ✅ unaffected |

Screens not yet captured that draw on the Tier-1 repositories above — director, transport,
control-center, multi-school — **will** surface the old brand and should be captured only after
Tier 1 lands.

---

## 6. What the sweep changed

Applied 2026-07-29. **Method:** replace capital-`Akshara` **only when not followed by an
identifier character**, plus all-caps `AKSHARA`. That single rule does nearly all the work safely,
because in this repository every dangerous occurrence is either lowercase
(`package:akshara_erp`, `com.akshara.erp`, `akshara_subscription_v1`, `school_akshara_001`,
`aksharaErrorMessage`) or immediately followed by an uppercase letter (`AksharaSpacing`,
`AksharaLanguage`), while no user-visible string is either.

| Surface | Change |
|---|---|
| **Demo schools, trusts, campuses, orgs** | ~25 entities — `NIKSHA Public School`, `NIKSHA Vidyalaya`, `NIKSHA International`, campuses, franchises, trust network |
| **Support branding** | `Akshara Support` → `NIKSHA Support` across the ASIP reporter, incident detail, and delivery-failure copy |
| **Product self-reference in UI copy** | → **`NIKSHA OS`** (not bare NIKSHA): app-lock "Unlock NIKSHA OS", appearance settings, biometric copy, management setup, face-enrolment hint, parent-app fee reminder, AI-generated PDF footer, Firebase web-unsupported message |
| **Company reference** | left as `NIKSHA` — "NIKSHA operations", "NIKSHA-managed backups", "Hi NIKSHA team" are about the company, not the product |
| **`'AKSHARA SUGGESTS'`** | → `'NIKSHA SUGGESTS'` — the eyebrow on **every AI insight card and suggestion bar** |
| **PDF report header** | `AKSHARA SCHOOL — PARENT ACADEMIC REPORT` → `NIKSHA …` (both the Flutter and edge-function copies) |
| **WhatsApp sender id** | `senderId: 'AKSHARA'` → `'NIKSHA'` — user-visible as the message sender on a parent's phone |
| **WhatsApp closing line** | `— Akshara School` → `— NIKSHA School` in the school-closure template |
| **Copilot refusal message** | *"I'm Akshara's read-only operational…"* → NIKSHA — the assistant's own words to a user |
| **Social hashtag** | `#AksharaPride` → `#NikshaPride` in generated promotion assets |
| **Demo emails / domains / addresses** | `@alumni.akshara.edu`, `@akshara.io`, `12 Akshara Lane`, portal hosts |
| **CSV export template** | `Akshara Student Import Template` → NIKSHA |
| **UPI payee name** | `pn=Akshara` → `pn=NIKSHA` (shown in the payer's UPI app) |
| **AI system prompts** | ASIP triage prompts ("You are an Akshara ERP support engineer") → NIKSHA OS |
| **Stale comments** | 17 further files whose doc comments still said "Akshara ERP" |
| **Tests** | swept in the same pass so assertions moved with their subjects |

## 7. What was deliberately NOT changed — and why

Each of these would break something real. They are encoded in the guard's `_allowed` map with
their reasons, so the exemption is reviewable rather than invisible.

| Kept | Reason |
|---|---|
| `com.akshara.erp` | Play package id — **can never change after first upload**, never shown to a user (already recorded in `app_constants.dart`) |
| `package:akshara_erp/…`, `akshara_*.dart`, `AksharaSpacing` etc. | Dart package, filenames, design-system class names — code identifiers, not branding |
| `akshara_subscription_v1`, `akshara_exam_admin_v1`, `akshara_school_configuration_v1`, `akshara_exam_results_sync_v1` | **Persisted storage keys** — renaming orphans every user's stored value |
| `akshara_reliability.db` | On-device SQLCipher database filename — renaming loses the store |
| `X-Akshara-Offline-Cache` | **HTTP header** — client/server wire contract |
| `school_akshara_001`, `org_akshara_001` | Seeded tenant identifiers matching existing rows |
| `akshara-erp.firebasestorage.app` | Real Firebase bucket |
| `'akshara-edge'`, `'akshara-stub'`, … | AI provider ids persisted in response caches and asserted by backend tests |
| **`templateNamespace ?? "AksharaERP"`** | ⚠ **Registered with the WhatsApp provider.** Renaming unilaterally breaks template resolution until the provider-side registration changes. **Owner action — coordinate with the provider, then update both together.** |
| `docs/archive/**`, dated certifications | Historical evidence. Rewriting a brand name inside signed-off records falsifies them — same rule the domain-migration audit applied |
| The rename note in `app_constants.dart` | The one place the retired name legitimately belongs: the constant that records the rename |

## 7a. Verification

| Suite | Result |
|---|---|
| `flutter analyze lib/ test/` | **No issues found** |
| **Deno** (`supabase/functions/`) | **4188 passed · 0 failed** · 3 ignored |
| **Flutter goldens** | **178 / 178 pass** after regeneration |
| `test/branding/niksha_branding_guard_test.dart` | **green** |

**Two test artifacts needed regenerating, both for the same reason — the rename changed rendered
text — and neither indicated a defect:**

1. **A Deno snapshot** (`education_paper_export_test.ts` — *"buildPaperDocumentV2 is byte-stable"*).
   The stored `.snap` carried `schoolName: "Akshara Vidyalaya"`. Regenerated; the diff is the
   branding line only. While fixing it I also corrected `logoText: "AV"` → `"NV"`, since "AV" was
   the initials of the *old* fixture name and would otherwise have been quietly incoherent.
2. **25 Flutter goldens.** Golden tests render text as Ahem boxes whose widths track string length,
   so `AKSHARA SUGGESTS` → `NIKSHA SUGGESTS` shifts the layout fingerprint. Proven to be
   golden-only: running `test/golden/` alone reproduced exactly 25 failures — the same count as the
   full suite — so no non-golden test regressed. Regenerated; 178/178 now pass.

## 8. The guard

`test/branding/niksha_branding_guard_test.dart` fails if capital-`Akshara` (or all-caps `AKSHARA`)
reappears on a user-visible surface in `lib/`, unless the line matches a documented exemption. It
also canaries `app_constants.dart` so a revert there is caught immediately.

This is the point of the wave: **fixing instances without a guard does not close a class.**

## 9. One open item for the owner

`templateNamespace = "AksharaERP"` is the only user-affecting occurrence left, and it cannot be
changed from inside the repository alone — the WhatsApp provider holds the matching registration.
Coordinate the rename with the provider, then change the default and its tests together.
