# Akshara ERP — Children's Data & Consent Policy

**Document version:** 1.0
**Status:** Draft for owner sign-off (see [PLACEHOLDERS.md](PLACEHOLDERS.md))
**Applies to:** the Akshara ERP application and backend services operated by
**[LEGAL ENTITY NAME]** ("Akshara", "we", "us").

> This policy explains how children's personal data is handled in Akshara ERP and
> who is responsible for the consent the law requires. It should be read together
> with the [Privacy Policy](PRIVACY_POLICY.md) and the
> [Institution Agreement](INSTITUTION_AGREEMENT.md).

---

## 1. Why this matters

Akshara is a **school management platform**. Almost everyone it is *about* —
students — is a child. Under India's **Digital Personal Data Protection Act, 2023
(DPDP Act)**, a **child is anyone under 18 years of age**, and processing a
child's personal data carries specific obligations. This policy sets out, in plain
terms, how those obligations are met and how responsibility is split between the
**school (Institution)** and **Akshara**.

## 2. Who is responsible for what

| Role under the DPDP Act | Who | What they are responsible for |
|---|---|---|
| **Data Fiduciary** (decides why/how children's data is processed) | The **Institution** (school) | Lawful basis for enrolling and processing the child; obtaining and recording **verifiable parental consent** where the law requires it; deciding what data to collect; responding to parent requests. |
| **Data Processor** (processes on instructions) | **Akshara** | Processing children's data **only** on the Institution's documented instructions to deliver the service; securing it; not using it for any independent purpose; helping the Institution meet its obligations. |
| **Data Fiduciary** for Akshara's own operational data | **Akshara** | The minimal account/device/diagnostic data Akshara needs to run the app itself. |

In short: **the school owns the relationship with the parent and the child; Akshara
is the secure tool the school uses.**

## 3. The "educational institution" position

The DPDP Rules, 2025 give educational institutions **operational relief**: a school
processing student data **for educational purposes** — admissions, attendance,
assessment, curriculum delivery, fees, transport, communication with parents — can
do so without re-running the full verifiable-parental-consent mechanism for every
routine academic action, because that processing is part of the school's function.

**However**, every *other* DPDP obligation continues to apply in full:

- **Purpose limitation** — data is used only for the school service.
- **Data minimisation** — only what is needed is collected.
- **Security safeguards** — see the [Security Policy](SECURITY_AND_RESPONSIBLE_DISCLOSURE.md).
- **Retention limits** — see the [Retention Policy](DATA_RETENTION_AND_DELETION_POLICY.md).
- **No tracking, behavioural monitoring, or targeted advertising directed at
  children** — Akshara does **none** of these (see §5).

Akshara is built to support this position: it processes children's data strictly
to operate the school's modules, and never for advertising, profiling for third
parties, or sale.

## 4. Verifiable parental consent

Where consent is the basis being relied on (for example, optional features beyond
core school operations, or where an Institution chooses to rely on consent):

- **The Institution obtains and records the parent's / lawful guardian's
  verifiable consent.** This is the school's responsibility as Data Fiduciary.
- Akshara provides the technical means for a parent to **review, give, and withdraw
  consent in the app**, and records the **policy version, the accepting user, their
  role, the timestamp, and the originating IP/device** when a parent accepts the
  Parent/User Terms and Privacy Policy (see the
  [in-app acceptance flow](#7-in-app-acceptance--records)).
- Akshara does **not** independently determine a child's age or a parent's
  identity; that linkage (parent ↔ child) is established by the Institution during
  enrolment. Where the law later requires a stronger verification method (e.g.
  DigiLocker-based identity checks under Rule 10 of the DPDP Rules), Akshara will
  support the Institution in adopting it.

## 5. What Akshara will never do with children's data

- ❌ No behavioural tracking of children.
- ❌ No profiling of children for advertising.
- ❌ No targeted or interest-based advertising directed at children.
- ❌ No sale or rental of children's data.
- ❌ No use of children's data to train third-party or unrelated AI models.
- ❌ No sharing with data brokers.

AI features in Akshara operate **only** on data the requesting user is already
authorised to see, to assist school staff and parents — never to build profiles of
children. See the [AI Usage & Disclaimer](AI_USAGE_AND_DISCLAIMER.md).

## 6. A child's own account (older students)

Some students use the app directly (e.g. to see homework, results, timetable). When
a student uses Akshara:

- They see only their **own** records (enforced by role-based access control and
  row-level security).
- The account exists because the **school enrolled them**; the school remains
  responsible for the lawful basis.
- Student-facing screens carry no advertising and no third-party trackers.

## 7. In-app acceptance & records

On first login, and whenever a mandatory policy is updated to a new version, the
relevant user (parent, staff, principal) is asked to **review and accept** the
applicable terms before continuing. Akshara records, for each acceptance:

- the **user** and their **role**,
- the **Institution / tenant** they belong to,
- the **policy key and version** accepted,
- the **timestamp**, and
- the **originating IP address and device identifier** (where available).

These records let an Institution demonstrate, if asked, *who* agreed to *what
version* and *when* — which supports the Institution's accountability as Data
Fiduciary. Acceptance records are retained per the
[Retention Policy](DATA_RETENTION_AND_DELETION_POLICY.md).

## 8. Parents' rights regarding their child's data

A parent or lawful guardian may, through the school:

- **access** and **review** their child's data held in Akshara,
- request **correction** of inaccurate data,
- request **erasure** when the data is no longer required,
- **withdraw consent** where processing relies on consent, and
- **raise a grievance** if they believe the data is mishandled.

Because the **Institution is the Data Fiduciary**, parents should first contact
their **school**. Akshara will assist the school in fulfilling valid requests. A
parent may also contact Akshara's Grievance Officer (see
[PLACEHOLDERS.md](PLACEHOLDERS.md) → `[GRIEVANCE EMAIL]`) and, if unsatisfied,
the **Data Protection Board of India**.

## 9. Data breaches involving children's data

If a personal-data breach affecting children's data occurs, Akshara will, as
processor, **notify the affected Institution without undue delay** and assist the
Institution with its obligations to notify the **Data Protection Board** and
affected parents within the timelines required by the DPDP Rules. See the
[Security & Responsible Disclosure Policy](SECURITY_AND_RESPONSIBLE_DISCLOSURE.md).

## 10. Changes

This policy will be updated as the DPDP Rules' children's-data provisions reach
full enforcement (substantive obligations apply from **13 May 2027**) and as
guidance from the Data Protection Board is issued. Material changes are recorded in
the [CHANGELOG](CHANGELOG.md) and surfaced in-app.

## 11. Contact

**[LEGAL ENTITY NAME]** — Grievance Officer: **[GRIEVANCE OFFICER NAME]**,
**[GRIEVANCE EMAIL]**. Privacy contact: **[PRIVACY EMAIL]**.
