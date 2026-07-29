# Bulk Templated Broadcast — implementation plan

**Date:** 2026-07-29 · **Status:** PLANNED — not started · **Type:** independent workstream
**Branch target:** to be decided at kickoff (do **not** land on a Messaging Core branch)

> **This is deliberately NOT part of Messaging Core.** That workstream is frozen and complete.
> Bulk Broadcast requires its own migration, implementation, regression and deployment
> validation. Do not fold it back in — a schema change with a deployment step has a different
> risk profile and a different gate than the pure-client work Messaging Core contained.

---

## 1. The problem in one sentence

Broadcast **targeting** already works; broadcast **language** does not — a broadcast is rendered
once by the sender, so every parent receives the sender's language regardless of their own.

---

## 2. What already exists — do not rebuild any of it

Verified 2026-07-29. This is the reason the plan is small.

| Layer | What exists |
|---|---|
| **Database** | `comm_broadcasts` (`20260614700000_communication_hub.sql`); audience + acknowledgement tables (`20260838000000_communication_audience_and_acknowledge.sql`) |
| **Audience types** | `class_parents`, `all_parents`, `staff` — class-wide and school-wide targeting already implemented |
| **Backend** | Full `_shared/communication/` service: handlers, repository, router, service, escalation, `guardian_recipients` |
| **UI** | `lib/features/communication/broadcast_admin_screen.dart` |
| **Contracts** | `CommunicationBroadcastRequest` (`audience`, `title`, `body`), `BroadcastRequestDto`, `audienceSegments` API path |
| **★ Render path** | `MessageCorpus.render(id, language, placeholders)` — **built, tested, in production use** by the parent inbox. This is the hard part and it is done |

**The only structural gap:** `comm_broadcasts` stores `title TEXT` and `body TEXT` — prose only,
with no JSONB column to carry a Message ID and placeholder values.

---

## 3. Scope

**In scope**
- Language-aware broadcasts: a broadcast carries a corpus Message ID + placeholders, and each
  recipient's device renders in that recipient's own language.
- Backwards compatibility: existing prose broadcasts keep working, unchanged.

**Out of scope**
- Arbitrary multi-student subsets and multi-class selection (a separate targeting feature).
- Flow B / WhatsApp Business API — untouched.
- Any change to Messaging Core.

---

## 4. Implementation

### Step 1 — Migration ⚠️ owner-gated

Next band: **`20260920000210`** (highest current is `20260920000200_tenant_custom_roles.sql`).

```sql
ALTER TABLE comm_broadcasts
  ADD COLUMN IF NOT EXISTS message_id   TEXT,
  ADD COLUMN IF NOT EXISTS placeholders JSONB;
```

**Additive and nullable on purpose.** Every existing row stays valid and every existing broadcast
keeps rendering from `body`. A broadcast is templated when `message_id IS NOT NULL`, prose
otherwise — no backfill, no data migration, no dual-write window.

`apply` is owner-gated in this repository. Writing the migration is engineering; applying it is not.

### Step 2 — Backend

`_shared/communication/` — pass `message_id` and `placeholders` through create and read. Validate
that `placeholders` is a flat `string → string` object; reject nested structures rather than
letting them reach a renderer that cannot use them.

### Step 3 — Client contracts

Add optional `messageId` and `placeholders` to `CommunicationBroadcastRequest` and
`BroadcastRequestDto`. Optional so every existing call site compiles untouched.

### Step 4 — Composer UI

`broadcast_admin_screen.dart` gains a predefined-message picker alongside free text, reusing the
corpus categories. Selecting a message stores the ID; typing free text stores prose. Same
predefined-vs-custom split Messaging Core already uses — do not invent a second model.

### Step 5 — Recipient rendering

Parent notice rendering calls `MessageCorpus.render(...)` with the recipient's language, exactly
as `ParentCommunicationInboxItem.bodyIn` does today. Fall back to stored `body` when `message_id`
is null or unknown to that device's corpus.

---

## 5. ★ The trap to avoid

This bug hid in **three** separate places in Messaging Core and shipped the wrong language to
parents from one of them:

> **Never pass an interpolated string to `TranslationService` or `MessageCorpus`.**
> The catalog is keyed on `"…for {student}."`, so `"…for Rahul."` matches nothing and silently
> falls back to English. **Translate the template; substitute after.**

For broadcasts the equivalent mistake is storing a *filled* body alongside the `message_id`, then
rendering from the body. Store the ID and the placeholder **values** — never pre-filled prose.

---

## 6. Testing

| Level | Coverage |
|---|---|
| **Migration** | Idempotency (`IF NOT EXISTS` re-runs cleanly); existing rows unaffected |
| **Backend** | Templated and prose broadcasts both round-trip; malformed `placeholders` rejected |
| **Corpus bridge** | Every ID a composer can select resolves in en/te/hi |
| **Rendering** | Two parents with different languages receive one broadcast and render different text — the property the feature exists for |
| **Backwards compatibility** | Pre-migration prose broadcasts render identically after |
| **Regression** | Full `flutter test` + `deno test supabase/functions/` green |

---

## 7. Deployment validation

Because this has a schema step, it is not done when tests pass:

1. Apply the migration to staging; confirm existing broadcasts still render.
2. Send one templated broadcast to a class with **mixed** language preferences; confirm each
   parent sees their own language.
3. Send one prose broadcast; confirm unchanged behaviour.
4. Only then apply to production, and re-run checks 2–3 there.

---

## 8. Risks

| Risk | Mitigation |
|---|---|
| Migration applied while older clients are live | Columns are additive and nullable; older clients ignore them and keep reading `body` |
| A composer selects an ID a recipient's corpus lacks | Renderer already returns null on unknown IDs → falls back to stored `body`. Always store a prose `body` as well |
| Corpus still `DRAFT_PENDING_NATIVE_REVIEW` | **Broadcasts reach far more parents than 1:1 messages.** Do not ship templated broadcasts to production before native-language certification completes |
| Scope creep into multi-student targeting | Explicitly out of scope (§3) |

---

## 9. Prerequisites

1. Owner authorisation for the migration apply.
2. Native-language certification of the corpus — see risk 3. A wrong-register message sent to one
   parent is a mistake; sent to every parent in a school it is an incident.
