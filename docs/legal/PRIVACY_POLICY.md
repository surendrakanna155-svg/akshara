# Akshara ERP — Privacy Policy

**Document version:** 2.0
**Last updated:** 27 June 2026
**Applies to:** the Akshara ERP mobile application (Android) and related services
operated by **[LEGAL ENTITY NAME]** ("Akshara", "we", "us", "our").

> OWNER ACTION: Before publishing on the Play Store, (1) fill in every placeholder
> from [PLACEHOLDERS.md](PLACEHOLDERS.md), (2) host this document at a public HTTPS
> URL, and (3) set that URL in the app
> ([`lib/core/legal/legal_links.dart`](../../lib/core/legal/legal_links.dart) →
> `privacyPolicyUrl`) and in the Play Console "Privacy Policy" field. The two URLs
> must match.

---

## 1. Who we are and our role

Akshara ERP is a school-management platform used by schools ("Institutions") to run
admissions, attendance, examinations, fees, transport, hostel, library, HR and
parent communication.

- For most personal data of students, parents and staff, the **Institution is the
  Data Fiduciary** (controller). Akshara acts as a **Data Processor**, processing
  that data on the Institution's documented instructions (see the
  [Institution Agreement / DPA](INSTITUTION_AGREEMENT.md)).
- For account, device and diagnostic data we collect to operate the app itself,
  **Akshara is the Data Fiduciary**.

This policy is written to be consistent with India's **Digital Personal Data
Protection Act, 2023 (DPDP Act)** and the **Digital Personal Data Protection Rules,
2025** (notified 14 November 2025; the substantive compliance obligations apply from
**13 May 2027**), the **Information Technology Act, 2000** and its rules, and the
Google Play Developer Program / Data safety requirements.

**Operator / contact:** [LEGAL ENTITY NAME], [REGISTERED ADDRESS]
**Privacy / Data Protection contact:** [PRIVACY EMAIL]
**Grievance Officer:** [GRIEVANCE OFFICER NAME], [GRIEVANCE EMAIL]

## 2. What personal data we process

We process only the data needed to deliver the service to your Institution:

**Account & identity**
- Name, role (student / parent / teacher / principal / director / staff).
- Mobile phone number — used to send and verify a one-time password (OTP) for login.
  We do not use it for marketing.
- Email address (where provided by the Institution).
- Optional government identifiers (e.g. Aadhaar) only where an Institution chooses to
  store them; these are treated as sensitive, stored masked, and are **never required**
  to use the app.

**Student academic & operational data** (entered by the Institution / staff)
- Enrolment, class/section, attendance records, examination marks and results,
  homework, library issues, transport route/stop, hostel allocation.

**Financial data**
- Fee structures, invoices, payments, receipts and discounts. We do **not** store
  full card numbers; payments are handled by a payment partner (see §5).

**Family linkage**
- Parent–child relationships so a parent sees only their own children's data.

**Device & technical data**
- App version, device model, OS version, crash/diagnostic logs, push device token,
  and authentication tokens stored securely on the device.

**Media (optional)**
- Photos/files an Institution or user uploads (e.g. school memories, admissions
  documents), stored in our managed storage and served via expiring signed URLs.

**Acceptance records**
- When you accept this policy or our terms in-app, we record the policy version, your
  user/role, the timestamp, and the originating IP/device (see §10).

We do **not** sell personal data, and we do not use student data for advertising or
to train unrelated AI models. We do **not** embed third-party advertising,
analytics, or behavioural-tracking SDKs in the app.

## 3. Why we process it (purposes & legal basis)

We process personal data to perform the contract with the Institution and to provide
the service its users expect:

- Authenticate users and secure accounts (OTP verification, rate limiting, session
  validation).
- Operate the modules above (attendance, exams, fees, transport, etc.).
- Send service notifications (e.g. results published, fee due, attendance alerts) to
  the relevant parent/staff member.
- Maintain security, prevent abuse/fraud, and keep audit logs.
- Provide optional AI features (e.g. assistant summaries, parent insights); these run
  on the data the user is already authorised to see and are not used to build
  profiles for third parties (see [AI Usage & Disclaimer](AI_USAGE_AND_DISCLAIMER.md)).
- Comply with legal obligations.

Where the DPDP Act requires consent (for example processing a child's data beyond the
school's educational function), the **Institution is responsible for obtaining
verifiable parental consent**. By law we do not undertake tracking or targeted
advertising directed at children. See [Children's Data & Consent](CHILDREN_DATA_AND_CONSENT.md).

## 4. Notifications

With your permission (Android 13+ asks at runtime), we send push and in-app
notifications strictly for school-service events, delivered via Firebase Cloud
Messaging (see §5). You can turn these off in your device settings or in the app's
notification preferences at any time.

## 5. Who we share data with (sub-processors)

We share personal data only as needed to run the service:

- **The Institution** and its authorised staff, under role-based access controls (a
  parent sees only their child; a teacher sees only their classes).
- **Sub-processors** that host and operate the service. The current active ones are:
  - **Razorpay** (India) — online fee payments (where the school enables them); card
    details are handled by Razorpay, not stored by us;
  - **Fast2SMS** (India) — sending login OTPs by SMS;
  - **Anthropic / Claude** (USA) — optional AI features (when enabled); only the
    minimum text needed, not used to train its models;
  - **Firebase Cloud Messaging / Google** (USA) — delivering push notifications.

  Hosting (database, API and file storage) is **self-managed on our own server
  infrastructure**, not on a third-party managed cloud database. The full and
  current list — including integrations that are **off by default** — is in
  [SUBPROCESSORS.md](SUBPROCESSORS.md).
- **Authorities**, where required by valid legal process.

We do not share personal data with advertisers or data brokers.

## 6. Where data is stored & international transfers

Core service data is hosted on our **self-managed infrastructure located in India**.
Some sub-processors (currently Anthropic and Google/FCM) may process limited data
**outside India**; where this happens we rely on contractual safeguards, send only
the minimum necessary data, and do not transfer data to any jurisdiction restricted
by the Central Government under the DPDP Act.

## 7. Security

- Encrypted transport (HTTPS/TLS) for all network traffic.
- Authentication tokens stored in the device's secure keystore; short-lived,
  revocable sessions validated on every request.
- Role-based access control and row-level security so users only see data they are
  entitled to; tenant isolation per school.
- Encrypted, restore-tested backups and monitoring of the production service.
- Audit logging of key actions.

No system is perfectly secure, but we take reasonable technical and organisational
measures appropriate to the sensitivity of the data. See the
[Security & Responsible Disclosure Policy](SECURITY_AND_RESPONSIBLE_DISCLOSURE.md).

## 8. Data retention

We retain personal data for as long as the Institution's account is active and as
needed to provide the service, then delete or anonymise it within a reasonable
period, unless a longer period is required by law (for example financial records). On
account closure, data is deleted or returned per our agreement with the Institution.
Full details: [Data Retention & Deletion Policy](DATA_RETENTION_AND_DELETION_POLICY.md).

## 9. Your rights

Subject to the DPDP Act and your relationship with the Institution, you may:

- Access and correct your personal data.
- Request erasure of data no longer required.
- Withdraw consent where processing relies on consent.
- Nominate another person to exercise your rights (as the Act allows).
- Raise a grievance with us and, if unresolved, with the **Data Protection Board of
  India**.

Because the Institution is usually the Data Fiduciary, requests about student, exam,
fee or attendance records are first directed to your Institution; we will assist the
Institution in responding. To exercise rights or raise a grievance, contact
**[PRIVACY EMAIL]** or our Grievance Officer **[GRIEVANCE OFFICER NAME]** at
**[GRIEVANCE EMAIL]**. We aim to respond within statutory timelines.

## 10. In-app acceptance

On first login, and whenever a mandatory policy changes materially, we ask the
relevant user to **review and accept** the applicable policies before continuing.
We record the **policy version, user, role, timestamp and originating IP/device** so
the Institution can demonstrate who agreed to what, and when. You can re-open the
current policies any time from the app's **Profile / Legal** section.

## 11. Children's data

The app is used by and about children in a school context. We process children's data
only to provide school services, on the Institution's instructions and with the
parental consent the Institution obtains. We do not undertake behavioural tracking or
targeted advertising directed at children and do not knowingly use children's data
for any purpose likely to cause a detrimental effect. See
[Children's Data & Consent](CHILDREN_DATA_AND_CONSENT.md).

## 12. Data breaches

If a personal-data breach occurs, we follow the process in our
[Security & Responsible Disclosure Policy](SECURITY_AND_RESPONSIBLE_DISCLOSURE.md):
as Processor we notify the affected Institution without undue delay and assist with
notifying the Data Protection Board and affected individuals within the DPDP Rules'
timelines.

## 13. Changes to this policy

We may update this policy as the service evolves or the law changes. Material changes
are notified in-app or via the Institution and recorded in the
[CHANGELOG](CHANGELOG.md). The "Last updated" date and "Document version" reflect the
latest version.

## 14. Contact

**[LEGAL ENTITY NAME]**
[REGISTERED ADDRESS]
Privacy: **[PRIVACY EMAIL]** · Support: **[SUPPORT EMAIL]**
Grievance Officer: **[GRIEVANCE OFFICER NAME]**, **[GRIEVANCE OFFICER DESIGNATION]**,
**[GRIEVANCE EMAIL]**
