# WhatsApp template namespace — provider coordination brief

**Date:** 2026-07-29 · **Origin:** owner decision D12 (NIKSHA branding sweep)
**Status:** ⏸ **BLOCKED ON PROVIDER COORDINATION — application config deliberately unchanged**

> This is the one user-affecting branding occurrence that could not be fixed from inside the
> repository. Changing it here first would break message delivery. **Provider first, code second.**

---

## 1. What is still branded "Akshara"

`supabase/functions/_shared/school_completion/whatsapp_providers.ts:105`

```ts
"src.name": config.templateNamespace ?? "AksharaERP",
```

`src.name` is the **registered application/namespace name** sent to the WhatsApp provider on every
outbound message. The provider resolves approved message templates against it.

The value is a fallback: `config.templateNamespace` (from `whatsapp_provider_config`) wins when
set. So live behaviour depends on whether the configured value is null in each tenant.

---

## 2. Why it was not changed with the rest of the sweep

Renaming this string **unilaterally breaks message delivery**. The provider holds the matching
registration; if the code sends `NikshaOS` while the provider still knows the app as `AksharaERP`,
template lookups fail and **every WhatsApp message stops** — fee reminders, attendance alerts,
results notifications.

This is a two-sided change. There is no ordering of code-only edits that makes it safe.

---

## 3. What the provider must do (owner action)

The exchange itself cannot be done from this repository — it needs an account holder.

1. **Identify the provider and account.** The stub implementation is Gupshup-shaped (`src.name`,
   `channel=whatsapp`, `source`, `destination`). Confirm against the live
   `whatsapp_provider_config` row before contacting anyone.
2. **Ask for the registered app/namespace name to be changed** from `AksharaERP` to the new value,
   or for a **new namespace to be provisioned alongside** the old one.
   *Prefer provisioning alongside* — it converts a hard cutover into a reversible switch.
3. **Confirm whether approved templates carry over.** Message templates are approved per namespace
   with Meta. If they do not transfer, they must be **re-submitted and re-approved**, which takes
   provider/Meta review time and is the item most likely to delay this.
4. **Get the effective date in writing**, so the code change can be scheduled rather than guessed.

**Recommended new value:** `NikshaOS` — matches the product name, no spaces, alphanumeric.
Confirm the provider's allowed character set before committing to it.

---

## 4. What changes in the repository afterwards

Only after the provider confirms:

| Change | File |
|---|---|
| Fallback default | `supabase/functions/_shared/school_completion/whatsapp_providers.ts:105` |
| Tests asserting the fallback | `whatsapp_providers_test.ts`, `whatsapp_repository_test.ts`, `notification_providers_whatsapp_test.ts` |
| Existing tenant rows | `whatsapp_provider_config.template_namespace` — update any row pinning the old value |
| Branding guard exemption | remove `'AksharaERP'` from `_allowed` in `test/branding/niksha_branding_guard_test.dart` — the guard then enforces the new name permanently |

**Verify after the change:** send one real templated message end to end. A unit test cannot prove
the provider accepted the namespace.

---

## 5. Rollback

If messages fail after the cutover, restore the previous `src.name` value and the tenant config
rows. Keep the old namespace registered with the provider until a real message has been confirmed
delivered under the new one — that is the whole reason to prefer provisioning alongside (§3.2).

---

## 6. Related

- `docs/engineering/NIKSHA_RENAME_RESIDUE_HANDOFF.md` §7, §9 — why this was excluded from the sweep
- `test/branding/niksha_branding_guard_test.dart` — the exemption and its recorded reason
- The sender id (`senderId: 'AKSHARA'` → `'NIKSHA'`) **was** changed in the sweep; it is demo
  configuration, not a provider-side registration. Do not confuse the two.
