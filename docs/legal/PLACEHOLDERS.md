# NIKSHA OS — Legal Placeholders (Owner Action Required)

> This file is the **single source of truth** for every owner-supplied value still
> missing from the documents in `docs/legal/`. Each one appears in the policies as a
> bracketed token such as `[REGISTERED ADDRESS]`. The legal pack cannot be published,
> and the app cannot be submitted to Google Play, until every row in the table below
> is filled in and the matching token replaced in the policy files.

> **Repair note (2026-07-28):** the product rename swept this file by accident and
> replaced the *token* column with the *values* — so rows read "the token
> `NIKSHA Technologies Pvt. Ltd.` is TODO", the grep recipe pointed at a token that no
> longer exists, and three already-decided values were still listed as outstanding.
> The table below has been rebuilt from what is actually present in `docs/legal/*.md`
> today, verified by scanning the sources rather than by editing prose.

## How to check the current state

The legal site generator is the authority — it renders the pack and refuses to
publish while any token is unfilled:

```
node scripts/legal/build_legal_site.js
```

It exits non-zero and lists every blocking token per page, and writes the same
result to `deploy/akshara-vps/public/_PUBLISH_GATE.json`. To find a specific token
by hand:

```
grep -rn "\[REGISTERED ADDRESS\]" docs/legal/
```

---

## Already decided — not placeholders, do not re-open

| Item | Value |
|---|---|
| Product name | **NIKSHA OS** |
| Legal entity name | **NIKSHA Technologies Pvt. Ltd.** |
| Entity type | Private Limited Company |
| Copyright year | 2026 |

The brand name **NIKSHA OS** and the entity name **NIKSHA Technologies Pvt. Ltd.**
are fixed and already written into every policy. Only the values below are missing.

---

## Outstanding — 9 tokens, all blocked on owner action

Counts are occurrences across `docs/legal/*.md` as of 2026-07-28.

| Token | Occurrences | Meaning | Example | Value (owner to fill) |
|---|---|---|---|---|
| `[REGISTERED ADDRESS]` | 5 | Full registered office address, as on the incorporation certificate | "Plot 1, Hitech City, Hyderabad, Telangana 500081, India" | `TODO` |
| `[SUPPORT EMAIL]` | 3 | General product / customer support inbox | "support@nikshaos.com" | `TODO` |
| `[PRIVACY EMAIL]` | 10 | Privacy / data-protection contact (DPDP) | "privacy@nikshaos.com" | `TODO` |
| `[GRIEVANCE OFFICER NAME]` | 6 | Named Grievance Officer (IT Rules 2021 / DPDP) | "Ms. A. Sharma" | `TODO` |
| `[GRIEVANCE OFFICER DESIGNATION]` | 2 | Their designation | "Grievance Officer" | `TODO` |
| `[GRIEVANCE EMAIL]` | 10 | Grievance Officer contact inbox | "grievance@nikshaos.com" | `TODO` |
| `[SECURITY EMAIL]` | 5 | Security / responsible-disclosure inbox | "security@nikshaos.com" | `TODO` |
| `[GOVERNING LAW CITY]` | 2 | City whose courts have jurisdiction | "Hyderabad" | `TODO` |
| `[GOVERNING LAW STATE]` | 2 | State for governing law | "Telangana" | `TODO` |

⚠️ **Governing law city/state are deliberately blank.** They must match the
registered office on the incorporation certificate. Guessing "Hyderabad / Telangana"
from the demo data would put an unverified jurisdiction into a binding contract.

**Every one of these nine is downstream of exactly two owner actions:**

1. **Buy the domain** → unblocks the four email addresses.
2. **Complete company registration** → unblocks the registered address and the
   governing-law city/state.

The Grievance Officer additionally needs a **real named person**, not just an inbox.
Nothing in this list is waiting on engineering.

---

## Related values that are NOT placeholders (but still need owner attention)

These are configured in code rather than in the policy text, so they will not show
up in the publish gate. They still have to be right before submission.

| Where | Current value | Owner action |
|---|---|---|
| `lib/core/legal/legal_links.dart` → `policyHostBaseUrl` | `https://nikshaos.in` | Point at the real domain. Today the policies are served from an unrelated business's host — a parent tapping "Privacy Policy" in a school app lands on `veloraunisexsalon.com`, which reads as a phishing redirect to anyone paying attention. |
| Play Console → "Privacy Policy" field | not yet set | Must be **byte-identical** to `policyHostBaseUrl` + `/privacy`. A mismatch between the listing and the policy is a documented rejection trigger. |
| Play Console → contact email, website | not yet set | Owner-supplied. |

---

## Notes for the owner

1. **Hosting.** The Privacy Policy at minimum must be reachable at a public HTTPS
   URL. `deploy/akshara-vps/legal-site.conf` serves the generated pack; the paths it
   exposes (`/privacy`, `/terms/user`, `/terms/acceptable-use`, `/terms/institution`)
   are contractual — they must match `supabase/functions/_shared/legal/legal_catalog.ts`,
   which the app joins to the policy host to build its in-app links.
2. **Grievance Officer** is a legal requirement for an intermediary / data fiduciary
   operating in India. Name a real person and a monitored inbox — not a role alias.
3. **Data Protection Officer (DPO).** Only a *Significant* Data Fiduciary must appoint
   one. NIKSHA OS is unlikely to be classified as an SDF initially, so a Grievance /
   Privacy contact is sufficient — but revisit if the Data Protection Board notifies
   NIKSHA OS as an SDF.
4. **After filling anything in**, re-run the generator and redeploy. The gate is the
   check that the live pages and the source agree; the previous hand-maintained HTML
   drifted a full version and a rename behind its own source without anyone noticing.
