# Akshara ERP — Legal & Compliance

This folder holds Akshara ERP's legal and compliance documents. They are written for
Akshara's **actual functionality** and aligned to India's **Digital Personal Data
Protection Act, 2023** and the **DPDP Rules, 2025**, the **IT Act, 2000**, and Google
Play requirements. They are **drafts for the owner to review, complete and (ideally)
have a lawyer confirm** before public release — they are not legal advice.

## Documents

| # | Document | Audience | Version |
|---|---|---|---|
| 1 | [Privacy Policy](PRIVACY_POLICY.md) | Everyone (the public/Play Store policy) | 2.0 |
| 2 | [Terms & Conditions](TERMS_AND_CONDITIONS.md) | Everyone (umbrella terms) | 1.0 |
| 3 | [School / Institution Agreement (+ DPA)](INSTITUTION_AGREEMENT.md) | Schools (B2B) | 1.0 |
| 4 | [Parent & User Terms](PARENT_USER_TERMS.md) | Parents, teachers, staff, students | 1.0 |
| 5 | [Acceptable Use Policy](ACCEPTABLE_USE_POLICY.md) | Everyone | 1.0 |
| 6 | [AI Usage & Disclaimer](AI_USAGE_AND_DISCLAIMER.md) | Everyone | 1.0 |
| 7 | [Data Retention & Deletion Policy](DATA_RETENTION_AND_DELETION_POLICY.md) | Schools / privacy | 1.0 |
| 8 | [Data Backup & Recovery Policy](DATA_BACKUP_AND_RECOVERY_POLICY.md) | Schools / ops | 1.0 |
| 9 | [Security & Responsible Disclosure](SECURITY_AND_RESPONSIBLE_DISCLOSURE.md) | Everyone / researchers | 1.0 |
| 10 | [Children's Data & Consent](CHILDREN_DATA_AND_CONSENT.md) | Parents / schools | 1.0 |
| 11 | [Sub-processors / Third-party Services](SUBPROCESSORS.md) | Everyone | 1.0 |
| — | [Placeholders (owner action)](PLACEHOLDERS.md) | Owner | 1.0 |
| — | [Change Log](CHANGELOG.md) | Everyone | — |

## How these documents relate

```
Terms & Conditions  (umbrella)
├── Institution Agreement  ── for schools  (includes the Data Processing Addendum / DPA)
├── Parent & User Terms    ── for individual users
├── Acceptable Use Policy
├── AI Usage & Disclaimer
└── Privacy Policy
    ├── Children's Data & Consent
    ├── Sub-processors / Third-party Services
    ├── Data Retention & Deletion Policy
    ├── Data Backup & Recovery Policy
    └── Security & Responsible Disclosure
```

## Who is responsible for data (in one line)

The **school (Institution) is the Data Fiduciary** for student/parent/staff data;
**Akshara is the Data Processor** acting on the school's instructions; Akshara is the
**Data Fiduciary** only for the minimal account/device data it needs to run the app.

## In-app acceptance

The app enforces acceptance of the mandatory policies on first login (and on material
updates) and records who accepted which version, when, and from which device. See the
[Change Log](CHANGELOG.md) and
[`../LEGAL_COMPLIANCE_CERTIFICATION.md`](../LEGAL_COMPLIANCE_CERTIFICATION.md).

## Before going public (owner)

1. Fill in every value in [PLACEHOLDERS.md](PLACEHOLDERS.md) and replace the matching
   tokens across these files.
2. Have a qualified lawyer review the set.
3. Host the documents at public HTTPS URLs and wire them in
   [`lib/core/legal/legal_links.dart`](../../lib/core/legal/legal_links.dart) and the
   Play Console.
4. Deploy the backend acceptance migration + edge route.
