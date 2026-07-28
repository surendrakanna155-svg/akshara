# NIKSHA OS — Data Retention & Deletion Policy

**Document version:** 2.0
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
  service, and we delete or anonymise it when the school instructs us to, or when
  the school leaves the service (§4) — unless the law requires us to keep it longer.
- **The school decides.** Retention of academic, financial and operational records
  follows the school's instructions and its own legal obligations.
- **Some records must be kept by law.** For example, financial/accounting records
  in India are generally retained for several years to meet tax and audit
  obligations.
- **We describe what the system actually does.** The periods below are the ones the
  running system applies. Where deletion is a manual, operator-run procedure rather
  than an automatic one, this policy says so instead of implying a timer that does
  not exist.

## 2. How retention works in NIKSHA OS today

**Please read this before the categories below.** NIKSHA OS does **not** run an
automatic background job that deletes school records once they reach a certain
age. With the narrow exceptions listed in §2.7, records persist for as long as the
school's account is active, and are removed when:

- the school instructs us to delete or correct them (§3), or
- the school leaves the service and off-boarding runs (§4), or
- an operator runs a retention purge by hand (§6).

We state this plainly because the alternative — publishing a deletion schedule the
system does not keep — would be worse than the truth. Where an outer limit is
required by a school's own policy or by law, we apply it through the procedures in
§3, §4 and §6.

### 2.1 Active account & profile

Name, role and phone number are retained while the account is active. They are
deleted or anonymised after account closure, as part of off-boarding (§4).

### 2.2 Academic records

Attendance, marks, results and homework are retained while the student is enrolled
and for the school's stated archival period. Schools commonly keep academic history
for the student's lifecycle and beyond. These records are retained until the school
instructs deletion; NIKSHA OS does not expire them on its own.

### 2.3 Financial records

Invoices, receipts and payments are retained for at least the period Indian tax and
audit obligations require — commonly up to **8 years** — and are not deleted on
request where the law requires them to be kept. In practice they are retained for
the life of the account and then handled under §4.

### 2.4 Communication & notification logs

Message threads, broadcasts and notification-delivery records are retained for the
life of the school's account and are removed at off-boarding (§4) or on the
school's instruction (§3).

**These are not automatically deleted after a fixed period.** An earlier version of
this policy stated that they were deleted or aggregated after 24 months. That was
not accurate — no such deletion runs — and the claim has been withdrawn rather than
left in place.

### 2.5 Audit & security logs — append-only by design

Audit and security entries — who changed a mark, who recorded a payment, who
accepted which policy version — are written to an **append-only** record.

**Nothing in the NIKSHA OS application can edit or delete an audit entry.** There
is no such feature, for any role, including school administrators and our own
support staff. This is deliberate: an audit trail the system could quietly rewrite
would be worthless as evidence, both for the school's own accountability and under
the DPDP Act. Legal-acceptance records live here too and are kept for as long as
they are needed to evidence consent.

The consequence, stated honestly: **audit entries are retained for the life of the
school's account by default.** A configurable retention horizon exists — **730 days
(2 years)** unless a deployment sets otherwise — but it is enforced by an operator
running a purge deliberately (§6), not by an automatic job. Until such a purge is
run, entries older than the horizon are still present.

Authorised school leadership can review the trail in-product, and can see how many
entries currently sit beyond the configured horizon before any purge is requested.

### 2.6 AI request content

NIKSHA OS uses AI for assistive features only. Specifically:

- **We do not store your prompts.** The content sent to the AI provider is not
  persisted by NIKSHA OS. We record only technical metadata about each call —
  which feature invoked it, which provider and model, and whether it succeeded —
  with none of the request or response text.
- **We do cache generated answers.** To avoid re-billing and re-generating the same
  answer, generated output is cached inside the school's own data, scoped to that
  school, for a limited lifetime. Cached answers can contain personal data about
  students, because that is what the answer was about.
- **The cache self-invalidates.** A cached answer is discarded when the underlying
  records it was derived from change, and it stops being served once its lifetime
  expires.
- Expired cache entries are never served again, and are physically removed when an
  operator runs the cache purge (§6).
- The AI provider does not use this content to train its models. See
  [AI Usage & Disclaimer](AI_USAGE_AND_DISCLAIMER.md) and
  [Sub-processors](SUBPROCESSORS.md).

Earlier wording said we "do not retain a separate AI transcript store". That was
imprecise: we retain no prompts, but we do retain a bounded cache of generated
answers, and this section now describes it accurately.

### 2.7 Authentication artefacts

- **One-time passwords (OTP)** stop working within minutes — the code is validated
  against a short expiry, and an expired or already-used code cannot log anyone in.
- The underlying login-attempt record (phone number and a hash of the code — never
  the code itself) is retained beyond that and is removed by the operator purge
  (§6), which clears expired attempts.
- **Sessions** are short-lived and revocable; revoking a user's access ends their
  sessions.

### 2.8 Uploaded media

Photos and documents are retained while relevant to the school and per the school's
instruction. They are deleted on request or at off-boarding (§4).

### 2.9 Diagnostic & operational data

- **No crash, analytics or device telemetry is collected from the app.** NIKSHA OS
  ships with no analytics or crash-reporting SDK active — no Google Analytics, no
  Firebase Analytics, no Crashlytics, no Sentry. See
  [Sub-processors](SUBPROCESSORS.md).
- **Server-side operational logs** exist for stability and security. Each service's
  logs are capped at a fixed **size** (50 MB per file, 5 files retained per
  service) and older entries are discarded as new ones arrive. Ops job logs (backup
  and restore-drill output) rotate weekly and 8 rotations are kept.

**This is a size-based bound, not a time guarantee.** A busy service reaches the cap
sooner and a quiet one later, so we cannot and do not promise that operational log
entries disappear after any particular number of months. An earlier version of this
policy stated a 12-month diagnostic retention period; log rotation does not provide
that guarantee, so the claim has been withdrawn.

### 2.10 Backups

Backups are encrypted and rolling, per the
[Backup Policy](DATA_BACKUP_AND_RECOVERY_POLICY.md): **7 daily, 4 weekly and 12
monthly** copies are kept.

Deleted records age out of backups as those copies are pruned. Because monthly
copies are kept for a year, **a record deleted from the live system can still exist
in an encrypted backup for up to about 12 months** before the last copy containing
it is pruned. We do not surgically edit backups, because a backup that can be
rewritten cannot be trusted to restore.

## 3. Deletion & correction requests

- **Individuals** (parents, staff) should direct requests to **their school**, which
  is the Data Fiduciary. The school can correct or remove records, and can instruct
  NIKSHA OS to do so.
- **Schools** can request deletion or return of their data at any time, subject to
  records the law requires to be retained, and subject to the append-only nature of
  the audit trail (§2.5).
- NIKSHA OS will assist the school in fulfilling valid access, correction and erasure
  requests, and will action them within a reasonable period (and within statutory
  timelines where they apply). These are **operator-performed procedures**, carried
  out by a person on request — not an automated self-service erase button.
- To raise a request directly with NIKSHA OS: **[PRIVACY EMAIL]**.

## 4. Account closure (off-boarding a school)

When an Institution leaves the service:

1. Access is disabled.
2. The school may request an **export** of its data within an agreed window. Today
   this means: the in-product exports the application already offers (for example
   student and staff lists, finance and Tally exports, and management reports),
   plus, on request, an **encrypted database extract of the school's data prepared
   by our operators**. There is no one-click, self-service "download my whole
   tenant" archive in this release; the export is a supported manual procedure.
3. After that window, NIKSHA OS **deletes or anonymises** the school's personal data
   from active systems, except records that must be retained by law (e.g. certain
   financial records) or that are already de-identified. This deletion is an
   operator-run procedure (§6), performed on instruction — not an automatic timer.
4. Residual copies in **encrypted backups** are deleted as those backups age out of
   the rolling backup cycle (§2.10) — up to about 12 months.

## 5. Anonymisation

Where we keep data for analytics, product improvement or statistics, we
**aggregate or anonymise** it so it no longer identifies an individual. Anonymised
data is not subject to this policy's deletion timelines.

## 6. How deletion is performed

- Deletions respect database integrity (related records are handled consistently)
  and are **audit-logged**.
- Destructive operations on the backend are performed through controlled,
  permissioned routines — not ad-hoc — to prevent accidental or unauthorised loss.
- Retention purges (audit horizon, expired AI cache, expired login attempts) are run
  by an operator with a deliberate confirmation step. The tooling reports exactly
  how many records would be removed and **changes nothing unless the operator
  confirms**. Every purge that does run is recorded with the operator, the record
  count and the time.
- **We do not run these purges automatically on a schedule.** Unattended, recurring
  destruction of a school's records — especially the append-only audit trail — is
  not something we are willing to leave to a background job in this release.

## 7. What this policy does not promise

So there is no ambiguity:

- We do **not** promise automatic deletion of school records after a fixed number of
  months. Deletion happens on instruction, at off-boarding, or by a deliberate
  operator purge.
- We do **not** promise that audit entries are deleted at all; they are append-only
  and retained for the life of the account unless a purge is run.
- We do **not** promise a fixed retention period for operational logs; they are
  bounded by size, not by time.
- We do **not** promise immediate removal from encrypted backups; that follows the
  backup cycle (§2.10).

## 8. Changes

Material changes to this policy are recorded in the [CHANGELOG](CHANGELOG.md).
