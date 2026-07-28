# Google Play listing — Akshara ERP v1.0.0

> Everything needed to create the Play Console entry and publish V1.
> **Owner actions are marked ⚠️ — those are the only steps Claude cannot do.**
> Package: `com.akshara.erp` · Version `1.0.0` · versionCode `1` ·
> minSdk 24 · targetSdk 36

---

## 0. Reality check on timing — read first

A brand-new app cannot be publicly live the same day.

| Step | Realistic time |
|---|---|
| Play Console account + **identity verification** | **1–3 days** (longer for an organisation account needing D-U-N-S) |
| First production review | **1–7 days** |
| *If the account is a **personal** account created recently:* Google additionally requires **12 testers on a closed test for 14 continuous days** before production access can even be requested | **14+ days** |
| **Internal testing track** | **minutes–hours** after upload |

**For a school demo, use the Internal testing track.** Testers install from the
real Play Store app — which is what the school will remember — and it skips full
production review. Up to 100 testers by email address.

---

## 1. Store listing copy

**App name** (30 char max)
```
Akshara — School ERP
```

**Short description** (80 char max)
```
Run your whole school from one app — attendance, fees, exams, parents.
```

**Full description** (4000 char max)
```
Akshara is a mobile-first school ERP built for how Indian schools actually work.
Principals, teachers, office staff and parents each get a workspace showing only
what their role needs — no training manual required.

FOR PRINCIPALS
• Student 360 — search any student by name, ERP number or student ID and see
  their entire school life on ONE screen: photo, parent contact numbers, marks,
  attendance, leave history, transport route and bus, fee status and care alerts.
  Built for parent meetings, so nothing is buried behind a tab.
• Live dashboards for attendance, fees collected and pending approvals.
• Approve exam results, fee concessions and leave from your phone.

FOR TEACHERS
• Exception-first attendance — mark only the absentees, not all sixty children.
• Marks entry built for speed: type, press Enter, move to the next student.
  Supports Unit Test, FA, SA, Half-Yearly and Annual assessments.
• Absent, Medical Leave and Debarred are recorded properly — never as zero.
• Homework, timetable, substitutions and parent messaging in one place.

FOR PARENTS
• Your child's attendance, marks and report cards as soon as the school
  publishes them.
• Fee dues, payment history and downloadable receipts.
• Apply for leave, message teachers, and track the school bus route.
• Login is a one-time password to your registered mobile number. Children never
  need a phone of their own.

FOR THE OFFICE
• Admissions, fee structures, invoicing, collections and receipts.
• Transport routes, stops and allocations. Library, inventory and hostel.
• Staff attendance, payroll inputs and HR records.

BUILT PROPERLY
• Every school's data is isolated at the database level.
• Money operations are audited, idempotent and two-person approved where it
  matters — no silent edits to what a family owes.
• Works on modest Android phones and recovers cleanly from poor connectivity.
• Full dark mode.

Akshara is sold to schools. You need an account from your school to sign in.
```

**Category:** Education
**Tags:** Education, Productivity
**Contact email:** ⚠️ *owner to supply*
**Website:** ⚠️ *owner to supply*

---

## 2. ⚠️ Privacy policy — REQUIRED, must be a live URL

Play will not publish without a publicly reachable privacy policy URL.

The text already exists at `docs/legal/PRIVACY_POLICY.md`. It needs **hosting**.
Fastest options:
1. GitHub Pages on the existing repo → `https://<user>.github.io/akshara/privacy`
2. A static page on the existing Hostinger hosting
3. Any static host — it only needs to be a stable public URL

Also required by the same policy family (host these too — they are already
written): `TERMS_AND_CONDITIONS.md`, `CHILDREN_DATA_AND_CONSENT.md`,
`DATA_RETENTION_AND_DELETION_POLICY.md`.

---

## 3. Data safety form — answers

Derived from the app's actual permissions and code, not guesses.

**Does your app collect or share user data?** → **Yes**

| Data type | Collected | Shared | Required | Purpose |
|---|---|---|---|---|
| Name | Yes | No | Required | App functionality (school records) |
| Phone number | Yes | No | Required | Account login via OTP |
| Email address | Yes | No | Optional | App functionality |
| Photos | Yes | No | Optional | Student/staff profile photos, document upload |
| Approximate location | Yes | No | Optional | Staff attendance geofence only |
| Precise location | Yes | No | Optional | Staff attendance geofence only |
| Other personal info | Yes | No | Required | Academic records, attendance, fees |

**Security practices**
- ✅ Data is encrypted in transit — the production environment sets `requireTls`, so HTTPS is enforced.
- ✅ Users can request that data be deleted — per `DATA_RETENTION_AND_DELETION_POLICY.md`. ⚠️ *owner must supply the deletion-request URL/email.*
- ✅ Committed to the Play Families Policy — **not applicable** if target audience is adults (see §4).
- ✅ Independent security review — the project has internal security certifications; do **not** claim third-party review unless one was actually commissioned.

**Location justification** (Play will ask): *"Precise location is used only to confirm a staff member is physically at the school campus when they mark their own attendance. It is never collected for students or parents, and is not used for tracking."*

---

## 4. ⚠️ Target audience — answer carefully

**Select: 18 and over.**

This is both accurate and the simplest compliance path:
- The app's users are **school staff and parents**, all adults.
- Login is **OTP to the parent's registered mobile**; children do not have their own login in V1.
- The app stores data *about* children but is not *directed to* children.

Declaring the app as targeting children triggers the **Play Families Policy**,
which adds substantial requirements (ads restrictions, additional review,
Families-compliant SDK constraints). Do not select it unless a student-facing
login ships.

**Content rating questionnaire:** Education app, no violence, no sexual content,
no gambling, no user-generated public content. Expected rating: **Everyone / 3+**.
Note that in-app messaging is **school-moderated and closed** (parent↔teacher
only, not public chat) — say so if the questionnaire asks about user interaction.

---

## 5. Graphic assets

| Asset | Spec | Status |
|---|---|---|
| App icon | 512×512 PNG, 32-bit | ✅ exists (`android/app/src/main/res/mipmap-*`) — needs 512×512 export |
| Feature graphic | 1024×500 PNG/JPG | ⚠️ **to create** |
| Phone screenshots | 2–8, min 320px, 16:9 or 9:16 | ✅ captured — see `docs/release/screenshots/` |
| 7-inch tablet | optional | optional |
| 10-inch tablet | optional | optional |

**Recommended screenshot order** (tells the buying story):
1. Principal dashboard
2. **Student 360** — the differentiator
3. Teacher attendance (exception-first)
4. Marks entry
5. Parent — child's marks / report card
6. Parent — fees and receipt
7. Transport route
8. Dark mode

---

## 6. Release checklist

- [x] Version set to `1.0.0+1`
- [x] Upload keystore generated (`~/akshara-upload-keystore.jks`, outside the repo, gitignored)
- [x] `android/key.properties` written and gitignored
- [x] Release build signs (SEC-2 fail-closed guard satisfied)
- [x] targetSdk 36 — above Play's API-35 floor
- [x] R8 minify + resource shrink enabled
- [x] QIE / Question Paper module hidden for V1
- [ ] ⚠️ Play Console account created + identity verified
- [ ] ⚠️ Privacy policy hosted at a public URL
- [ ] ⚠️ Enrol in **Play App Signing** on first upload (keeps this key as a rotatable *upload* key)
- [ ] ⚠️ Feature graphic created
- [ ] ⚠️ Contact email + website supplied
- [ ] ⚠️ Internal testing track created, tester emails added

---

## 7. ⚠️⚠️ Keystore — the one irreversible thing

```
Keystore : ~/akshara-upload-keystore.jks
Alias    : akshara-upload
Validity : 10000 days
```

**Back up this file and its password somewhere offline, today.**

If it is lost, and Play App Signing was not enabled, **the app can never be
updated again** — every future release would have to ship as a brand-new listing
with zero installs and zero reviews. Enrolling in Play App Signing on first
upload makes the key recoverable/rotatable, which is why it is on the checklist
above.

The password was printed once in the session that generated it. It is stored
**only** in `android/key.properties` on this machine — a file git will never
commit. Copy it into a password manager now.
