# Akshara ERP — Legal & Compliance Certification

**Date:** 27 June 2026
**Scope:** Legal & Compliance layer only (no new ERP features, no new engineering
audits). Aligned to India's **DPDP Act 2023** and **DPDP Rules 2025** (notified
14 Nov 2025; substantive obligations enforceable **13 May 2027**), the IT Act 2000,
and Google Play requirements.
**Status:** ✅ Build complete and certified at the code level. ⚠️ Owner inputs
outstanding before public release (placeholders, legal review, hosting, deploy).

> These documents are drafts prepared for the owner to review and complete; they
> are **not legal advice**. Have a qualified lawyer confirm them before release.

---

## 1. Completed

### A. Legal document suite — `docs/legal/`
A complete set tailored to Akshara's **actual functionality**, cross-linked and
versioned, with a single placeholder register and a change log:

| Document | Version |
|---|---|
| [Privacy Policy](legal/PRIVACY_POLICY.md) | 2.0 |
| [Terms & Conditions](legal/TERMS_AND_CONDITIONS.md) | 1.0 |
| [School / Institution Agreement (+ DPA)](legal/INSTITUTION_AGREEMENT.md) | 1.0 |
| [Parent & User Terms](legal/PARENT_USER_TERMS.md) | 1.0 |
| [Acceptable Use Policy](legal/ACCEPTABLE_USE_POLICY.md) | 1.0 |
| [AI Usage & Disclaimer](legal/AI_USAGE_AND_DISCLAIMER.md) | 1.0 |
| [Data Retention & Deletion Policy](legal/DATA_RETENTION_AND_DELETION_POLICY.md) | 1.0 |
| [Data Backup & Recovery Policy](legal/DATA_BACKUP_AND_RECOVERY_POLICY.md) | 1.0 |
| [Security & Responsible Disclosure](legal/SECURITY_AND_RESPONSIBLE_DISCLOSURE.md) | 1.0 |
| [Children's Data & Consent](legal/CHILDREN_DATA_AND_CONSENT.md) | 1.0 |
| [Sub-processors / Third-party Services](legal/SUBPROCESSORS.md) | 1.0 |
| [Placeholders (owner register)](legal/PLACEHOLDERS.md) · [Change Log](legal/CHANGELOG.md) · [Index](legal/README.md) | — |

Key correctness points, verified against the codebase (not assumed):
- **Roles** — Institution = Data Fiduciary; Akshara = Data Processor; Akshara =
  Data Fiduciary only for its own account/device data.
- **Children** — no tracking / behavioural monitoring / targeted ads at children;
  verifiable parental consent is the Institution's responsibility under the
  educational-institution position.
- **Sub-processors disclosed accurately** — Active: **Razorpay** (payments),
  **Fast2SMS** (OTP), **Anthropic/Claude** (optional AI), **Firebase FCM/Google**
  (push); self-hosted storage/DB **in India**. Off-by-default (no data sent unless
  enabled): Meta Graph (FB/IG), Twilio, SendGrid, MSG91, Gupshup, OpenRouter.
  WhatsApp = `wa.me` deep-links only (no Business API). **No** ad/analytics/crash
  SDKs.

### B. In-app legal acceptance gate — implemented & tested
Required acceptance is enforced on first login and on material policy updates, and
the record is durable and auditable.

- **Backend** (`supabase/migrations/20260816000000_legal_policy_acceptance.sql` +
  `supabase/functions/_shared/legal/*` + `routeLegal` in `api/index.ts`):
  - Append-only `legal_acceptances` table (RLS scoped to tenant + user;
    `SELECT, INSERT` to `erp_tenant`).
  - `GET /legal/status` and `POST /legal/accept`, recording **user, role, scope,
    tenant, policy key/version, timestamp, IP, user-agent, device**, plus an audit
    + domain event per acceptance.
- **Client** (`lib/features/legal/*`, `lib/router/*`, `lib/core/legal/legal_links.dart`):
  - A router gate redirects an authenticated user with outstanding mandatory
    policies to the acceptance screen and **prevents navigating elsewhere** until
    they accept; "Decline and log out" is the only alternative.
  - A **Profile → Terms & Policies** entry lets users review the current policies
    later (parent + teacher profiles).
  - **Fail-open by design:** if the backend is unreachable/not yet deployed, users
    are **not** blocked (an outage never locks users out); enforcement activates
    automatically once the backend returns data.

### C. Verification (this batch)
- `flutter analyze` (whole project): **clean — no issues**.
- Flutter tests `test/features/legal/legal_gate_test.dart`: **14/14 passed**, incl.
  the headline proofs:
  - *"FIRST-TIME LOGIN: authenticated user with outstanding policies is sent to the
    acceptance gate."*
  - *"end-to-end through the real app router: the app redirects to the legal gate
    screen."*
  - *"ACCEPTED USER: reaches the dashboard without being asked."*
  - accept → satisfied transition, and fail-open on endpoint error.
- Backend `deno check` clean; `legal_catalog_test.ts`: **8/8 passed** (incl.
  *"a first-time user has everything outstanding"*).
- Regression: `router_smoke_test` (25), `route_guards`, `app_startup`, `widget_test`,
  parent/teacher profile tests — **all passed** (no behavioural change for existing
  flows; the gate is additive and off until the backend reports outstanding items).
- **Full Flutter test suite: 2463 passed, 1 skipped (exit 0)** — no regressions
  from the legal gate across the whole app.

**So, to the practical question "does it ask the first time?" — yes.** A first-time
authenticated user with unaccepted mandatory policies is taken to the acceptance
screen and cannot proceed until they accept; once accepted, they are not asked
again (until a policy version changes).

## 2. Owner input still required (before public release)

1. **Fill all placeholders** in [docs/legal/PLACEHOLDERS.md](legal/PLACEHOLDERS.md)
   (legal entity, address, support/privacy/grievance/security emails, grievance
   officer, governing-law city/state, copyright year) and replace the tokens
   across `docs/legal/`.
2. **Legal review** by a qualified Indian lawyer.
3. **Host the documents** at public HTTPS URLs under
   `LegalLinks.policyHostBaseUrl`, matching the catalog `path`s; the Privacy Policy
   URL must match the Play Console field.
4. **Deploy the backend** (apply the migration + deploy the edge function) so the
   gate begins enforcing. (Owner-gated; intentionally **not** deployed in this batch.)

## 3. Remaining release blockers

- **For the legal layer specifically:** none in the code. The gate, documents and
  recording are complete and tested. The four items in §2 are **owner/business
  actions**, not engineering gaps.
- **Out of scope here (separate, owner-gated):** GA Certification, and any
  Performance / UX / Security / Chaos certifications.

---

*Prepared under the Legal & Compliance batch. No new ERP features were added and no
new engineering audits were performed, per the batch scope. GA Certification has
**not** been started and awaits owner approval.*
