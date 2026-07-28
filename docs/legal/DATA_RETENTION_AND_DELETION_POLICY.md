# NIKSHA OS — Data Retention & Deletion Policy

**Document version:** 1.0
**Status:** Draft for owner sign-off (see [PLACEHOLDERS.md](PLACEHOLDERS.md))
**Operator:** **NIKSHA Technologies Pvt. Ltd.** ("NIKSHA OS", "we", "us").

> This policy explains how long NIKSHA OS keeps personal data and how it is deleted.
> Because the **Institution (school) is usually the Data Fiduciary**, the school
> decides retention for its records; NIKSHA OS retains data **on the school's behalf**
> and to the extent needed to run the service. Read together with the
> [Privacy Policy](PRIVACY_POLICY.md).

---

## 1. Principles

- **Keep only what is needed, for only as long as needed.** We retain personal data
  while the school's account is active and the data is needed to provide the
  service, then delete or anonymise it within a reasonable period — unless the law
  requires us to keep it longer.
- **The school decides.** Retention of academic, financial and operational records
  follows the school's instructions and its own legal obligations.
- **Some records must be kept by law.** For example, financial/accounting records
  in India are generally retained for several years to meet tax and audit
  obligations.

## 2. Indicative retention periods

These are defaults; an Institution may instruct a different period in its agreement,
subject to law.

| Data category | Default retention | Notes |
|---|---|---|
| **Active account & profile** (name, role, phone) | While the account is active | Deleted/anonymised after account closure (see §4). |
| **Academic records** (attendance, marks, results, homework) | While the student is enrolled + the school's stated archival period | Schools commonly keep academic history for the student's lifecycle and beyond; follows school instruction. |
| **Financial records** (invoices, receipts, payments) | Typically up to **8 years** | To meet Indian tax/audit obligations; the longer of school policy or statutory requirement. |
| **Communication & notification logs** | Up to **24 months** | Service/audit purpose; then deleted or aggregated. |
| **Audit & security logs** (including legal-acceptance records) | Up to **3 years** (acceptance records kept as long as needed to evidence consent) | Supports security investigation and the school's accountability. |
| **Authentication artefacts** (OTP, session tokens) | OTP: minutes; sessions: short-lived | OTPs expire quickly; sessions are revocable and time-limited. |
| **Uploaded media** (photos, documents) | While relevant to the school + school instruction | Stored in managed storage; deleted on request/closure. |
| **AI request content** | Not stored by the AI provider for training; processed transiently | We do not retain a separate AI transcript store for profiling. |
| **Diagnostic/device data** | Up to **12 months** | For stability and security. |
| **Backups** | Rolling, per the [Backup Policy](DATA_BACKUP_AND_RECOVERY_POLICY.md) | Deleted records age out of backups within the backup cycle. |

## 3. Deletion & correction requests

- **Individuals** (parents, staff) should direct requests to **their school**, which
  is the Data Fiduciary. The school can correct or remove records, and can instruct
  NIKSHA OS to do so.
- **Schools** can request deletion or return of their data at any time, subject to
  records the law requires to be retained.
- NIKSHA OS will assist the school in fulfilling valid access, correction and erasure
  requests, and will action them within a reasonable period (and within statutory
  timelines where they apply).
- To raise a request directly with NIKSHA OS: **[PRIVACY EMAIL]**.

## 4. Account closure (off-boarding a school)

When an Institution leaves the service:

1. Access is disabled.
2. The school may request an **export** of its data within an agreed window.
3. After that window, NIKSHA OS **deletes or anonymises** the school's personal data
   from active systems within a reasonable period, except records that must be
   retained by law (e.g. certain financial records) or that are already
   de-identified.
4. Residual copies in **encrypted backups** are deleted as those backups age out of
   the rolling backup cycle.

## 5. Anonymisation

Where we keep data for analytics, product improvement or statistics, we
**aggregate or anonymise** it so it no longer identifies an individual. Anonymised
data is not subject to this policy's deletion timelines.

## 6. How deletion is performed

- Deletions respect database integrity (related records are handled consistently)
  and are **audit-logged**.
- Destructive operations on the backend are performed through controlled,
  permissioned routines — not ad-hoc — to prevent accidental or unauthorised loss.

## 7. Changes

Material changes to this policy are recorded in the [CHANGELOG](CHANGELOG.md).
