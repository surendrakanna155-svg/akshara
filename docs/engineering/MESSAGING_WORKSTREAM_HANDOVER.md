# Messaging & communication — workstream handover

**Date:** 2026-07-29 · **Branch:** `release/v1.0-playstore`

# 🔒 WORKSTREAM FROZEN — owner directive, 2026-07-29

**No further engineering changes to Messaging Core.**

| Component | Status |
|---|---|
| **Messaging Core** | ✅ **COMPLETE** |
| **Localization Pipeline** | ✅ **COMPLETE** |
| **Parent Inbox Rendering** | ✅ **COMPLETE** |
| **Message ID Architecture** | ✅ **COMPLETE** |
| **Regression** | ✅ **GREEN** |

**Verification:** `flutter analyze lib/` clean · **full regression 4,682 passed / 0 failed** ·
end-to-end flow suite **8/8** · corpus suites **20/20** · messaging suites **348** ·
**Flow B: 0 files changed**

**The only remaining Messaging item is native-language content certification, which is
intentionally outside engineering.**

**Bulk Broadcast is no longer part of this workstream.** It is an independent workstream with its
own migration, implementation, regression and deployment validation — see
[`BULK_BROADCAST_IMPLEMENTATION_PLAN.md`](./BULK_BROADCAST_IMPLEMENTATION_PLAN.md). Do not fold it
back in.

---
**Related:** [`WHATSAPP_IMPLEMENTATION_AUDIT.md`](./WHATSAPP_IMPLEMENTATION_AUDIT.md) ·
[`WHATSAPP_TEMPLATE_NAMESPACE_MIGRATION.md`](./WHATSAPP_TEMPLATE_NAMESPACE_MIGRATION.md)

---

## 1. Architecture as it now stands

**Message-ID transport, two render sites, one corpus.**

```
TEACHER selects a predefined message
   └─ request carries { sisStudentId, reason, tone, channels }   ← Message ID, never prose
         │                 └── reason × tone = composite Message ID
         │
         ├─► IN-APP  : recipient device resolves the ID and renders in ITS OWN language
         │
         └─► WHATSAPP: sender device renders, in the RECIPIENT's language, from the same corpus
                       (wa.me?text= carries literal text — there is no resolver on the far side)
```

★ **Recipient-side rendering is impossible on the WhatsApp leg.** `wa.me/<n>?text=` transmits
literal text and WhatsApp has no message-ID concept. That is a property of the channel, not a gap
to close. One corpus, two render sites.

Custom messages take the other branch: `customMessage` + `useAi` send actual text.

---

## 2. What was completed

| Item | Result |
|---|---|
| **Template translation coverage** | **8/22 → 22/22.** Templates carry `{student}`; the sentence is the lookup key and the name is substituted *after* translation. Fixed 9 structurally-untranslatable templates and added 5 missing catalog entries across 6 languages |
| **`wa.me` normalisation** | Routed through `WhatsAppLauncher.buildChatUri`; bare 10-digit numbers no longer produce unresolvable links. `studentName` now actually passed on this path |
| **Communication corpus** | `assets/communication/message_corpus.json` — **50 messages, 15 categories**, en/te/hi, 13 declared placeholders, `DRAFT_PENDING_NATIVE_REVIEW` |
| **Corpus resolver** | `lib/core/communication/corpus/message_corpus.dart` — Message ID → language → local placeholder fill |
| **Teacher → real language source** | `teacherCommunicationRecipientLanguageProvider` resolves `parent_language_preferences` via the existing `parentLanguagePreferenceProvider`, with local-store then English fallback |
| **Guards** | Corpus integrity (language completeness, placeholder parity, used-vs-declared, unique IDs, honest status) + resolver behaviour |

### 2.1 A regression I introduced and caught

Making templates placeholder-based broke `teacherCommunicationTranslationPreviewProvider`: it
passed the **already-interpolated** preview string as the catalog lookup key, which can never match
a key holding `{student}`. It would have silently fallen back to English — the precise failure the
redesign was meant to remove. Fixed by translating `templateFor(...)` and substituting after.

### 2.2 A corpus defect the resolver test caught

`ADMISSION_CONFIRMED` **used** `{school}` but did not **declare** it, so the renderer was never
asked for a value and a parent would have received a literal `{school}`. The integrity guard passed
because it only checked declared-names-exist-in-schema. Added a used-but-not-declared check.

---

## 3. Verified-already-existing (built nothing)

Repeatedly, more existed than the brief assumed. Each was verified before any code was written:

| Assumed missing | Reality |
|---|---|
| Message-ID transport | ✅ Already on the wire — `reason` + `tone` + `sisStudentId`; the server stores the ID, not prose |
| Parent language storage | ✅ Table `parent_language_preferences` + read/upsert functions |
| Language API | ✅ `GET`/`PUT /parent-insights/language-preference` |
| Flutter language client | ✅ `EvolutionRepository.get/saveParentLanguagePreference`, datasource, `parentLanguagePreferenceProvider` |
| **Parent-facing language UI** | ✅ **Already shipped** — language picker in `parent_insights_screen.dart` writing to the real table |
| Bulk / class recipients | ✅ Broadcast subsystem exists: `class_parents`/`all_parents`/`staff`, full `_shared/communication/` service, `broadcast_admin_screen.dart` |

**Only one thing was genuinely missing:** teacher messaging never *read* the preference. That is
now wired.

---

## 4. Flow B — WhatsApp Business API (untouched, as instructed)

Real MSG91 and Gupshup HTTP implementations, delivery ledger with escalation provenance,
per-school channel policies, broadcast subsystem. Dormant: no credentials, no provider account, no
Meta-approved templates, **no inbound delivery-status webhook**. The `stub` provider honestly
returns `success:false` rather than fabricating delivery. **Left exactly as future infrastructure.**

---

## 5. Second pass — closing the remaining engineering gaps

### 5.1 Templates and corpus unified (was: two vocabularies)

The 22 `reason × tone` templates and the 50-message corpus were separate vocabularies — a
duplicate system. Closed:

- **17 template texts merged into the corpus**, reusing the curated translations that already
  existed in `translation_service.dart` / `school_content_translation_catalog.dart` rather than
  re-translating. Corpus now **67 messages, 16 categories** (added `marks`), version `0.2.0-draft`.
- **`TeacherParentTemplates.corpusIdFor(reason, tone)`** maps every combination to a corpus ID.
  That is what turns `reason × tone` from a private enum pair into a real Message ID.
- **Backwards compatibility asserted, not assumed:** a test compares every corpus entry against
  the legacy English template and fails on any drift. Routing through the corpus does not change
  a single word a parent receives.

### 5.2 Parent inbox now renders locally

`ParentCommunicationInboxItem` carries `corpusMessageId` + `placeholders`;
`bodyIn(language, corpus:)` renders on the parent's device in the parent's own language.
`parentMessageBodyProvider` wires both parent screens.

Consequences: a parent who changes language sees **existing** messages re-render, because nothing
is frozen into prose at send time. Custom free-text messages deliberately carry no corpus ID and
show exactly what the teacher wrote. `displayBody` is retained as the fallback, so any caller
without a corpus still works.

### 5.3 The interpolate-before-translate bug — found twice more

Making templates placeholder-based exposed two further call sites still passing the *interpolated*
string as the catalog lookup key, which can never match and silently falls back to English:

- `teacher_parent_communication_provider.dart` (translation preview)
- `parent_communication_store.dart` (the actual send path) ← **this one shipped the wrong language**

Both now translate `templateFor(...)` and substitute after. This is the failure mode the
placeholder design exists to remove, and it hid in three separate places.

### 5.4 Dead code removed

`lib/features/parent/profile/parent_language_provider.dart` deleted — an unused in-memory
`StateProvider<IntelLanguage>` referenced nowhere, which would have become a second, wrong source
of language truth the moment anyone wired it.

---

## 6. Remaining open items

### 6.1 Inside this (frozen) workstream

| # | Item | Type |
|---|---|---|
| 1 | **Corpus is `DRAFT_PENDING_NATIVE_REVIEW`** | ⛔ **CONTENT — the only remaining Messaging item.** 67 messages × te/hi need a native speaker with school-communication context. Fees, discipline and health carry real consequences when the register is wrong. A guard test asserts the status is stated explicitly, so it cannot be flipped silently |
| 2 | Server stores language as a NAME, client keys by ISO code | P2 cosmetic — handled defensively on both sides (`languageFromServerValue` accepts either). **No action needed** |

### 6.2 Moved out of this workstream

| Item | Where it went |
|---|---|
| **Bulk templated broadcast** | → [`BULK_BROADCAST_IMPLEMENTATION_PLAN.md`](./BULK_BROADCAST_IMPLEMENTATION_PLAN.md) — independent workstream |
| `templateNamespace = "AksharaERP"` | Flow B only, off the V1 path → `WHATSAPP_TEMPLATE_NAMESPACE_MIGRATION.md` |
| No delivery-status webhook | Flow B only — future infrastructure |

### 6.3 End-to-end verification performed

`test/communication/click_to_send_end_to_end_test.dart` walks the real chain with no mocks of its
own — teacher picks reason + tone → language resolved → template translated and name substituted
after → record persisted → `wa.me` URI built and normalised → inbox carries the Message ID →
**parent device renders locally in its own language**. Includes a breadth check that every
teacher-selectable `reason × tone` survives the whole chain without an unresolvable ID, a leaked
placeholder, or an empty body. **8/8 passing.**

---

## 6. Files

**Added:** `assets/communication/message_corpus.json` ·
`lib/core/communication/corpus/message_corpus.dart` ·
`test/communication/message_corpus_integrity_test.dart` ·
`test/communication/message_corpus_resolver_test.dart`

**Modified:** `lib/core/communication/teacher_parent_templates.dart` (placeholder templates) ·
`lib/core/i18n/translation_service.dart` (placeholder-aware `pair`, `hasTranslation`, 14 entries) ·
`lib/core/communication/parent_communication_store.dart` (launcher + studentName) ·
`lib/features/teacher/communication/teacher_parent_communication_provider.dart` (real language
source, template-not-prose translation) · `pubspec.yaml` (corpus asset)

**Untouched:** all Flow B / Business API infrastructure.

---

## 7. Continuation prompt

```text
=== BEGIN ===
Continue the NIKSHA OS messaging/communication workstream.

REPO: /Users/surendrakanna/Documents/Akshara_ERP-release   BRANCH: release/v1.0-playstore
READ FIRST: docs/engineering/MESSAGING_WORKSTREAM_HANDOVER.md, then
            docs/engineering/WHATSAPP_IMPLEMENTATION_AUDIT.md

ARCHITECTURE (do not redesign): predefined messages travel as a Message ID (reason × tone) plus
placeholder VALUES — never prose. In-app, the recipient resolves and renders in its own language.
On WhatsApp the SENDER renders in the recipient's language, because wa.me?text= carries literal
text and has no far-side resolver. One corpus, two render sites. Custom messages send actual text.

RULES:
- Do NOT modify Flow B (Meta/Gupshup Business API). Leave it intact as future infrastructure.
- VERIFY BEFORE BUILDING. This workstream repeatedly found the thing assumed missing already
  existed (parent language UI, API routes, bulk broadcast subsystem, message-ID transport).
- The corpus is DRAFT_PENDING_NATIVE_REVIEW. Do not mark it reviewed without native review.
- Translate the TEMPLATE, never the interpolated string — filling first makes the catalog key
  unmatchable and silently falls back to English.

STATE: engineering-complete. Full regression 4,682 passed / 0 failed. Corpus 67 messages,
16 categories, en/te/hi, v0.2.0-draft. Parent inbox renders locally from the corpus in the
parent's own language. Every reason × tone maps to a corpus Message ID (corpusIdFor), asserted
against the legacy English so wording did not drift.

REMAINING — both blocked on someone other than the engineer:
1. CONTENT: the corpus is DRAFT_PENDING_NATIVE_REVIEW. 67 messages x te/hi need a native speaker
   with school-communication context. Do NOT flip the status without that review; a guard test
   asserts the status is stated explicitly.
2. OWNER-GATED: bulk templated broadcast needs an additive migration
   (comm_broadcasts + message_id TEXT, placeholders JSONB — next band 20260920000210) whose apply
   is owner-gated here. Once authorised, steps 2-4 in handover section 6.1 are mechanical: the
   render path already exists and is tested.

IF YOU PICK UP THE MIGRATION WORK, the trap to avoid is the one that hid in THREE places in this
codebase: never pass an interpolated string to TranslationService/MessageCorpus. The catalog is
keyed on "...for {student}.", so "...for Rahul." matches nothing and silently ships English.
Translate the TEMPLATE, substitute after.

VERIFY: flutter test (full suite), plus test/communication/ (integrity, resolver, bridge).
=== END ===
```
