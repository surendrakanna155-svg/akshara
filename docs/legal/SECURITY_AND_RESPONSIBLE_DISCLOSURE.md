# Akshara ERP — Security & Responsible Disclosure Policy

**Document version:** 1.0
**Status:** Draft for owner sign-off (see [PLACEHOLDERS.md](PLACEHOLDERS.md))
**Operator:** **[LEGAL ENTITY NAME]** ("Akshara", "we", "us").

> This document describes the security measures protecting Akshara ERP, how we
> handle data breaches, and how security researchers can report vulnerabilities
> safely. It supports the [Privacy Policy](PRIVACY_POLICY.md).

---

## Part A — Our security measures

We apply technical and organisational measures appropriate to the sensitivity of
the data (which includes children's data). These include:

- **Encryption in transit.** All app↔server traffic uses HTTPS/TLS.
- **Authentication.** Login is by mobile number + one-time password (OTP), with
  rate limiting and a pilot allow-list. Access tokens are short-lived; sessions can
  be revoked centrally and are validated on each request.
- **Secure token storage.** Authentication tokens are stored in the device's secure
  keystore, not in plain text.
- **Role-based access control (RBAC).** Every action is checked against the user's
  role and permissions.
- **Row-level security (RLS).** The database enforces tenant and user scoping, so a
  user can only read or write rows belonging to their own school and, where
  relevant, their own records — even if an application bug tried to over-fetch.
- **Tenant isolation.** Each school's data is scoped to its organisation/school
  context on every request.
- **Audit logging.** Key actions (logins, record changes, acceptances) are recorded
  with actor, role, timestamp, IP and device, to support investigation and the
  school's accountability obligations.
- **Encrypted, restore-tested backups.** See the
  [Data Backup & Recovery Policy](DATA_BACKUP_AND_RECOVERY_POLICY.md).
- **Secrets management.** Provider keys (SMS, AI, payments, push) and token
  encryption keys are stored as server-side secrets, never in the app.
- **Encryption of sensitive stored values.** Where third-party access tokens are
  stored (e.g. social-publishing tokens), they are encrypted at rest.
- **Least-privilege infrastructure.** The production database is not exposed
  publicly; the application connects through a constrained database role.
- **Monitoring.** The production service is monitored, with alerting on outages.

No system is perfectly secure, but we work to reduce risk and respond quickly.

## Part B — Data-breach handling

If we become aware of a **personal-data breach**:

1. We **contain** it and begin investigation immediately.
2. As a **Data Processor**, we **notify the affected Institution(s) without undue
   delay** so the Institution (as Data Fiduciary) can meet its obligations.
3. We **assist** the Institution in notifying the **Data Protection Board of India**
   and affected individuals within the timelines set by the DPDP Rules, 2025
   (notification to the Board without delay, with a fuller report and notification
   to affected data principals within **72 hours**).
4. Where we are the Data Fiduciary (for our own operational data), we notify the
   Board and affected individuals directly within the same timelines.
5. We record the breach, root cause and remediation, and take steps to prevent
   recurrence.

We also remain mindful of the separate **CERT-In** incident-reporting expectations
under the Information Technology Act for certain cyber incidents, and will report
where applicable.

## Part C — Responsible Disclosure (Vulnerability Reporting)

We welcome reports from security researchers acting in good faith.

### How to report
Email **[SECURITY EMAIL]** with:
- a clear description of the issue and its potential impact,
- step-by-step reproduction details, and
- any proof-of-concept (please keep it minimal and non-destructive).

We aim to **acknowledge within 5 working days** and to keep you updated as we
investigate and fix.

### Safe-harbour — what we ask of you
If you follow these rules, we will treat your research as authorised and will not
pursue legal action against you for it:

- **Do** test only against accounts and data you own or have explicit permission to
  use. **Never** access, modify, or retain another person's data — especially
  children's data.
- **Do** stop as soon as you find a vulnerability and report it; do not pivot deeper.
- **Don't** run denial-of-service attacks, spam, social-engineer our staff or users,
  or degrade the service for others.
- **Don't** publicly disclose the issue until we have fixed it and agreed timing
  with you.
- **Don't** access, download, or exfiltrate personal data; if you inadvertently
  encounter it, stop and tell us.

### Out of scope
Reports without a realistic security impact (e.g. missing security headers with no
exploit, theoretical issues, best-practice suggestions, automated-scanner output
without a working proof of concept) may be acknowledged but not actioned.

### Recognition
We currently run a **goodwill** disclosure programme (no cash bounty by default).
With your permission we are happy to credit you once an issue is resolved. Any paid
reward is at our discretion.

## Part D — Contacts

- Security / vulnerability reports: **[SECURITY EMAIL]**
- Privacy / data-protection: **[PRIVACY EMAIL]**
- Grievance Officer: **[GRIEVANCE OFFICER NAME]**, **[GRIEVANCE EMAIL]**

## Changes
Material changes to this policy are recorded in the [CHANGELOG](CHANGELOG.md).
