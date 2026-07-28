# NIKSHA OS — Legal & Policy Change Log

This is the **single, authoritative history** of changes to NIKSHA OS's legal and
policy documents. Every material change to any document in `docs/legal/` is recorded
here, newest first. The app reads policy **version** identifiers; bumping a version
here (and in the document header and the in-app policy catalog) is what triggers
re-acceptance in the app.

> How versioning works:
> - Each document has a **Document version** (e.g. `1.0`, `2.0`) in its header.
> - **Minor** changes (typos, clarifications that don't change rights/obligations)
>   bump the decimal (e.g. `1.0 → 1.1`) and do **not** force re-acceptance.
> - **Material** changes (anything affecting users' rights, data use, sub-processors,
>   or obligations) bump the major version (e.g. `1.0 → 2.0`) and **do** force
>   re-acceptance of that policy in the app.
> - The in-app policy catalog
>   (`supabase/functions/_shared/legal/legal_catalog.ts`) holds the version each
>   role must currently accept. Keep it in sync with this changelog.

---

## 2026-06-27 — Initial legal & compliance suite (v1)

**Summary:** First complete legal & compliance layer for NIKSHA OS, tailored to the
product's actual functionality and aligned to the DPDP Act 2023 / DPDP Rules 2025.

| Document | Version | Change |
|---|---|---|
| [Privacy Policy](PRIVACY_POLICY.md) | **2.0** | Expanded from the earlier draft: aligned to DPDP **Rules 2025**, named active sub-processors (Razorpay, Fast2SMS, Anthropic, Firebase/Google), self-hosted-in-India hosting statement, in-app acceptance & breach sections, standardised placeholder tokens, cross-links to the suite. |
| [Terms & Conditions](TERMS_AND_CONDITIONS.md) | **1.0** | New — umbrella terms. |
| [School / Institution Agreement](INSTITUTION_AGREEMENT.md) | **1.0** | New — B2B agreement incl. Data Processing Addendum (DPA). |
| [Parent & User Terms](PARENT_USER_TERMS.md) | **1.0** | New — plain-language end-user terms. |
| [Acceptable Use Policy](ACCEPTABLE_USE_POLICY.md) | **1.0** | New. |
| [AI Usage & Disclaimer](AI_USAGE_AND_DISCLAIMER.md) | **1.0** | New — names Anthropic/Claude, assistive-only disclaimer, no profiling of children. |
| [Data Retention & Deletion Policy](DATA_RETENTION_AND_DELETION_POLICY.md) | **1.0** | New. |
| [Data Backup & Recovery Policy](DATA_BACKUP_AND_RECOVERY_POLICY.md) | **1.0** | New. |
| [Security & Responsible Disclosure](SECURITY_AND_RESPONSIBLE_DISCLOSURE.md) | **1.0** | New — security measures, breach handling, safe-harbour disclosure. |
| [Children's Data & Consent](CHILDREN_DATA_AND_CONSENT.md) | **1.0** | New. |
| [Sub-processors](SUBPROCESSORS.md) | **1.0** | New — active vs. off-by-default integrations, India/outside-India flags. |
| [Placeholders](PLACEHOLDERS.md) | **1.0** | New — owner-action register of every bracketed token. |

**Implementation:** Added an in-app **legal acceptance gate** — a backend table
(`legal_acceptances`) and routes (`GET /legal/status`, `POST /legal/accept`) that
record the accepting user, role, tenant, policy key/version, timestamp and IP/device;
a Flutter gate that blocks continued use until mandatory policies are accepted and a
**Profile → Legal** screen to view policies later. The gate is **fail-open** (if the
backend has not yet been deployed or is unreachable, users are not blocked), so it can
ship ahead of the owner-gated steps.

**Owner action outstanding:** fill placeholders (see [PLACEHOLDERS.md](PLACEHOLDERS.md)),
host the documents publicly, and deploy the backend migration + edge route. See
[`../archive/completed/LEGAL_COMPLIANCE_CERTIFICATION.md`](../archive/completed/LEGAL_COMPLIANCE_CERTIFICATION.md).
