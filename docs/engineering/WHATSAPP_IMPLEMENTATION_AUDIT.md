# WhatsApp implementation audit — Flow A vs Flow B

**Date:** 2026-07-29 · **Type:** AUDIT ONLY — no code changed, nothing removed, nothing modified
**Question:** do both flows exist, what is their real state, and which should be V1?

---

## 0. Answer first

**Both flows exist. Neither is a stub in the dismissive sense — but they are at very different
stages, and the codebase has already recorded a decision.**

| | Flow A — Click-to-Send | Flow B — Business API |
|---|---|---|
| **Status** | **PARTIAL** — transport complete and production-ready; translation largely inert | **PARTIAL** — real infrastructure, wired end to end, but **dormant** (never sends) |
| **Ships today?** | ✅ Yes, and it already works | ❌ No — no credentials, no approved templates, no provider account |
| **Cost** | ₹0 per message | Per-message + Meta template approval |
| **Recommendation** | ✅ **V1** | 🔒 **Future infrastructure — keep intact, leave dormant** |

★ **This is not a new decision.** `lib/core/utils/whatsapp_launcher.dart:9-11` already states it:

> *"This free deep-link is the chosen, permanent WhatsApp approach: the paid Meta/WhatsApp
> Business API is intentionally NOT used. (Promotional outreach is handled separately via social
> media.)"*

The audit's real value is therefore not "which flow" — it is **what is actually broken inside
Flow A**, because that is what V1 depends on. See §3.

---

## 1. Flow A — Click-to-Send

### 1.1 End-to-end execution path

```
Teacher opens a student → "Message parent"
  lib/features/teacher/communication/teacher_parent_communication_screen.dart
        ↓ picks reason + tone (no free text unless AI is enabled)
  ParentCommunicationReason × ParentCommunicationTone
        ↓
  teacher_parent_communication_provider.dart:76
        ├─ API mode  → teacherRepositoryProvider.sendParentCommunication()
        │                → api_teacher_repository.dart
        │                → _shared/teacher/teacher_parent_communication_handlers.ts
        │                → teacher_parent_communication_repository.ts  (INSERT/SELECT)
        └─ mock mode → ParentCommunicationStore.instance.send()
        ↓
  preferredLanguageForStudent(sisStudentId)          ← language resolution
        ↓
  TeacherParentTemplates.resolve(reason, tone, studentName)   ← English text
        ↓
  TranslationService.instance.pair(englishText, target)       ← dictionary lookup
        ↓
  wa.me/<digits>?text=<url-encoded translated text>
        ↓
  WhatsAppLauncher.openChat()  → url_launcher → native WhatsApp
        ↓
  ✋ TEACHER REVIEWS AND PRESSES SEND  (no automated delivery, by design)
```

### 1.2 Components and status

| Component | File | Status |
|---|---|---|
| Deep-link builder | `lib/core/utils/whatsapp_launcher.dart` | ✅ **Complete.** Handles bare 10-digit, leading-`0` trunk, already-international (11–15 digits), rejects <10. Web vs native launch modes. Genuinely production-quality |
| Shared UI affordance | `lib/core/widgets/whatsapp_contact_button.dart` | ✅ **Complete** — 13 call sites (teacher→parent, principal/HR→staff, parent→class-teacher) |
| Template catalog | `lib/core/communication/teacher_parent_templates.dart` | ✅ **Complete** — 8 reasons × 19 tones → 22 messages, deterministic, "no AI tokens consumed" |
| Translation service | `lib/core/i18n/translation_service.dart` | ⚠ **Partial** — see §3.1 |
| Language selection | `ParentCommunicationStore._parentLanguageByStudent` | ❌ **Demo-only** — see §3.2 |
| Send screen | `lib/features/teacher/communication/teacher_parent_communication_screen.dart` | ✅ Present |
| Timeline / history | `ParentCommunicationRecord`, `markRead`, delivery status enum | ✅ Present (stores both original and translated text) |
| Backend persistence | `teacher_parent_communication_repository.ts` | ✅ Real INSERT/SELECT — sends **are** recorded server-side |

**Translation languages supported:** English, Telugu, Hindi, Tamil, Kannada, Malayalam, Urdu (7).

### 1.3 What is genuinely working

- The deep link itself, including the international-number normalisation that makes it work at all.
- The reason/tone template catalog — deterministic, zero AI cost, zero per-message cost.
- Server-side recording of what was sent, to whom, in which language.
- Both original **and** translated text are retained on the record, so a teacher can see what the
  parent actually received.
- The human-in-the-loop step: no message leaves without a teacher pressing send. That is a
  compliance property, not a limitation.

---

## 2. Flow B — WhatsApp Business API

### 2.1 What exists

| Layer | Location | Status |
|---|---|---|
| Provider abstraction | `_shared/school_completion/whatsapp_providers.ts` | ✅ `stub \| msg91 \| gupshup` |
| **MSG91 send** | same, `sendViaMsg91` | ✅ **Real HTTP implementation** |
| **Gupshup send** | same, `sendViaGupshup` | ✅ **Real HTTP implementation** |
| Stub behaviour | same, case `"stub"` | ✅ **Honest** — returns `success:false, "not configured"`. GAP-P1-9 fixed a version that reported `success:true` and fabricated 100% delivery on every dashboard |
| Channel dispatch | `_shared/communication/notification_providers.ts:59` | ✅ Wired — the `whatsapp` channel routes here |
| Config repository | `_shared/school_completion/whatsapp_repository.ts` | ✅ Present |
| Config UI | `lib/features/school_completion/whatsapp_provider_screen.dart` | ✅ Present |
| Template channel | migration `20260890000000` | ✅ `notification_templates.channel` accepts `'whatsapp'` |
| Delivery ledger | same migration | ✅ `notification_deliveries.channel` accepts `'whatsapp'`, plus `escalated_from` / `escalation_depth` provenance |
| Escalation policy | `communication_channel_policies` | ✅ Per-school ordered channel chain, RLS enabled |
| Bulk / broadcast | `_shared/communication/` (scheduled broadcasts, audience ack, broadcast report) | ✅ Exists as a channel-agnostic broadcast subsystem |
| Template namespace | `whatsapp_providers.ts:105` | ⚠ `config.templateNamespace ?? "AksharaERP"` — see §4 |

### 2.2 What is missing

| Gap | Detail |
|---|---|
| **Credentials** | `MSG91_API_KEY` / `GUPSHUP_API_KEY` are read from env; **not set in the live environment** |
| **Provider account** | No confirmed MSG91/Gupshup account or Meta Business verification |
| **Approved templates** | Meta requires per-template approval before any business-initiated message. None recorded |
| **Inbound delivery-status callback** | ❌ **No webhook.** Nothing consumes provider status updates, so `notification_deliveries` records only the *send attempt* result, never a later delivered/read transition |
| **Live default** | Demo config is `provider: 'stub', isActive: true` → every send correctly reports "not configured" |

### 2.3 Verdict

**Not a stub — genuinely built, and genuinely dormant.** Two real provider integrations, a
delivery ledger with escalation provenance, per-school policy, and a broadcast subsystem all
exist. What is absent is everything *external*: an account, credentials, and Meta-approved
templates. It cannot send a single message today, and it correctly says so rather than pretending.

---

## 3. ★ What is actually broken — and it is inside Flow A

This is the finding that matters, because V1 depends on Flow A.

### 3.1 Only 8 of 22 templates translate — 36%

`TranslationService` is a **dictionary with exact string matching** and a silent English fallback:

```dart
return _catalog[key]?[target] ?? englishText;
```

Measured against the actual catalog:

| | Count | Why |
|---|---|---|
| Templates total | **22** | |
| ✅ Translated | **8** | present in the catalog |
| ❌ **Interpolated — structurally impossible** | **9** | contain `$studentName`; after interpolation the string is `"…for Rahul…"`, which can never equal a static catalog key |
| ❌ Static but simply absent | **5** | never added to the catalog |

The 9 interpolated templates cover **PTM requests, discipline matters, appreciation, progress
updates and the marks improvement plan** — and are permanently English regardless of the parent's
language.

The 5 missing static ones include both **fee-overdue** messages and the repeat-homework message.

**Verified not caused by the recent branding sweep:** the same 8-of-13 static coverage holds at
`7589e091^`.

**The failure is silent.** A parent set to Telugu receives English, and nothing anywhere reports
that a translation was missed.

### 3.2 Parent language selection is demo-only — with a real table sitting unused next to it

| | |
|---|---|
| Store | `ParentCommunicationStore._parentLanguageByStudent` — a plain in-memory `Map` |
| Persistence | ❌ **None.** No `SharedPreferences`, no database, lost on restart |
| Written by | `mock_parent_repository.dart:184` (demo seed) and 3 tests. **No production or UI caller** |
| Parent-facing UI | ❌ **None found** in `lib/features/parent/` |
| Default | `AksharaLanguage.english` |

**But the database table exists and is in active use — by a different feature.**
`parent_language_preferences` (migration `20260623600000`) is read and upserted by
`_shared/parent_insights/parent_insights_repository.ts`, and `parent_insights_handlers.ts` resolves
a parent's language from it.

So there are **two disconnected language systems**: a real, DB-backed one serving Parent Insights,
and an in-memory demo one serving teacher→parent messaging. Flow A does not read the table that
already holds the answer.

**Consequence:** in a real deployment every parent is `english`, so the translation pipeline —
however well built — is effectively inert for teacher→parent messaging.

### 3.3 A latent deep-link defect

`lib/core/communication/parent_communication_store.dart:99-101` builds the URI by hand:

```dart
final digits = parentPhone.replaceAll(RegExp(r'[^\d]'), '');
whatsAppUri = 'https://wa.me/$digits?text=$encoded';
```

This **bypasses `WhatsAppLauncher.normalizeInternational`** — the function written specifically to
prevent this, whose own doc comment says:

> *"Without this, a 10-digit number produces `wa.me/9876543210`, which WhatsApp cannot resolve
> (it requires the full international number)."*

Any parent phone stored as a bare 10-digit Indian number produces an unresolvable link on this
path. The `WhatsAppContactButton` path is unaffected — it goes through the launcher correctly.

---

## 4. The template-namespace item (unchanged, as instructed)

`whatsapp_providers.ts:105` still reads `config.templateNamespace ?? "AksharaERP"`. It is
registered with the provider, so it cannot be renamed from inside the repository — see
`docs/engineering/WHATSAPP_TEMPLATE_NAMESPACE_MIGRATION.md`. **Untouched by this audit.**

Note this is a **Flow B** concern only. If Flow B stays dormant for V1, this is not on the launch
path at all — which lowers its urgency considerably.

---

## 5. Recommendation

### 5.1 V1 — Flow A (Click-to-Send)

Consistent with the decision already recorded in the code. It is the right call for reasons beyond
cost:

1. **It works today.** No external dependency, no account, no approval queue.
2. **₹0 per message**, versus per-message billing plus Meta approval overhead.
3. **Human-in-the-loop.** A teacher reviews every message before it leaves. For fee reminders and
   discipline matters — where a wrong automated send is a real incident — that is a feature.
4. **No regulatory surface.** No business-initiated messaging rules, no 24-hour session window, no
   template approval to maintain.
5. **It degrades honestly.** If WhatsApp is not installed, `launchUrl` fails visibly rather than
   silently dropping a message.

### 5.2 Flow B — keep intact as future infrastructure

Leave every line in place, exactly as it is. It is well-built, it is honest about being
unconfigured, and it is the correct foundation for automated/bulk messaging when there is a
business case (fee-cycle reminders at scale, attendance alerts without teacher action). Deleting it
would discard real, working work; enabling it would add cost and compliance obligations V1 does not
need.

### 5.3 What V1 actually needs — in priority order

These are the gaps that decide whether Flow A is genuinely production-ready. **None is proposed as
work in this task; this is the audit's finding list.**

| # | Item | Severity | Why |
|---|---|---|---|
| **1** | **Point Flow A at `parent_language_preferences`** instead of the in-memory map | **P0** | Without it every parent is English and the whole translation pipeline is decorative |
| **2** | **Add a parent-facing language setting**, or derive it at admission | **P0** | The table cannot be populated for teacher messaging otherwise |
| **3** | **Fix the 9 interpolated templates** — translate around the placeholder (per-language format strings) rather than matching whole sentences | **P1** | Structural; no amount of catalog additions can fix it |
| **4** | Add the 5 missing static catalog entries | **P1** | Includes both fee-overdue messages |
| **5** | Route `parent_communication_store` through `WhatsAppLauncher.buildChatUri` | **P1** | Latent broken-link defect (§3.3) |
| **6** | Report untranslated sends instead of failing silently | **P2** | Today a missed translation is invisible |

**Assessment: Flow A's transport is production-ready. Its localisation is not.** If V1 ships
English-only messaging that is a coherent product — the app is English-first by decision. But the
translated-message capability should not be described as working until items 1–4 are closed.

---

## 6. Scope note

Face verification was removed from this session's scope by owner directive mid-audit. Nothing
face-related was investigated, modified, or documented here, and the existing release gate and its
documents were left exactly as committed.
