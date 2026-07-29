# Google Play listing — NIKSHA OS v1.0.0

> Everything needed to create the Play Console entry and publish V1.
> **Owner actions are marked ⚠️ — those are the only steps engineering cannot do.**
> Package: `com.akshara.erp` · Version `1.0.0` · versionCode `1` ·
> minSdk 24 · targetSdk 36

> **Rewritten 2026-07-28.** The previous revision predated the rename and would have
> published the app as **"Akshara — School ERP"** while the installed launcher icon
> reads **NIKSHA OS** (`AndroidManifest.xml:22`). A store name that does not match
> the on-device name is both a Play policy problem and a user-trust problem. It also
> carried a ✅ against "Phone screenshots — captured, see `docs/release/screenshots/`"
> for a directory that did not exist, and ticked items in §6 that were not true.

**The package id `com.akshara.erp` is permanent and must NOT change** — it can never
be altered after the first upload. The retired brand surviving inside an application
id is normal and invisible to users.

---

## 0. Reality check on timing — read first

A brand-new app cannot be publicly live the same day.

| Step | Realistic time |
|---|---|
| Play Console account + **identity verification** | **1–3 days** (longer for an organisation account needing D-U-N-S) |
| First production review | **1–7 days** |
| *If the account is a **personal** account created recently:* Google additionally requires **12 testers on a closed test for 14 continuous days** before production access can be requested | **14+ days** |
| **Internal testing track** | **minutes–hours** after upload |

**For a school demo, use the Internal testing track.** Testers install from the real
Play Store app — which is what the school remembers — and it skips full production
review. Up to 100 testers by email address.

---

## 1. Store listing copy

**App name** (30 char max) — 22 chars
```
NIKSHA OS — School ERP
```

**Short description** (80 char max) — 69 chars
```
Run your whole school from one app: attendance, exams, fees, parents.
```

**Full description** (4000 char max)
```
NIKSHA OS is a mobile-first school operating system built for how Indian schools
actually work. Principals, teachers, office staff and parents each get a workspace
showing only what their role needs — no training manual required.

FOR PRINCIPALS
• Morning Brief — your day assembled before you ask: who is absent, what needs
  approving, what changed overnight. Composed from your school's own records.
• Student 360 — search any student by name, ERP number or student ID and see their
  whole school life on ONE screen: photo, parent contact numbers, marks, attendance,
  leave history, transport route and bus, fee status and care alerts. Built for
  parent meetings, so nothing is buried behind a tab.
• Staff 360 — the same one-screen dossier for any employee.
• Ask anything — type what you want in plain words and go straight there. It runs
  entirely on your phone: no cloud call, no data leaving the device.
• Approve exam results, fee concessions and leave from your phone.

FOR TEACHERS
• Exception-first attendance — mark only the absentees, not all sixty children.
• Marks entry built for speed: type, press Enter, move to the next student.
  Supports Unit Test, FA, SA, Half-Yearly and Annual assessments, including the
  Andhra Pradesh / Telangana State Board (SSC) grading scale.
• Absent, Medical Leave and Debarred are recorded properly — never as zero — and
  are excluded from totals, averages and rank instead of quietly dragging them down.
• Homework, timetable, substitutions and parent messaging in one place.

FOR PARENTS
• Your child's attendance, marks and report cards as soon as the school publishes
  them.
• Fee dues, payment history and downloadable receipts.
• Apply for leave, message teachers, and see the school bus route and stop.
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
• When a number has not been measured yet, the app says so, instead of showing a
  zero and letting you believe it.
• Works on modest Android phones, and queues your work safely when the network
  drops.
• Full dark mode.

Fee collection in this version is recorded by the school office. Online payment is
not enabled yet.

NIKSHA OS is sold to schools. You need an account from your school to sign in.
```

**Category:** Education
**Tags:** Education, Productivity
**Contact email:** ⚠️ *owner to supply*
**Website:** ⚠️ *owner to supply*

### Honesty review of the copy above

Every claim was checked against the code rather than assumed:

- **No online-payment promise.** `RAZORPAY_STUB_MODE` defaults to `true` and there
  is no payment SDK in `pubspec.yaml` at all, so no money can move. The description
  claims only dues, history and receipts, and states the limitation explicitly. A
  reviewer who taps "Pay Now" gets an honest *"Online payment not enabled yet — you
  have NOT been charged"*, which now agrees with the listing instead of contradicting
  it. The previous copy left a reviewer to discover that mismatch themselves.
- **"no cloud call"** is literally true — the deterministic intent layer
  (`lib/core/dai/`) resolves entirely on-device.
- **Transport** says "route and stop", not live GPS tracking.
- **Question Paper / QIE is deliberately hidden in V1** and so is absent from the copy.

---

## 2. ⚠️ Privacy policy — REQUIRED, must be a live URL

Play will not publish without a publicly reachable privacy policy URL, and the URL
in the Console must match the one in `lib/core/legal/legal_links.dart`.

The policy pack is generated from `docs/legal/*.md` — never hand-edited:

```
node scripts/legal/build_legal_site.js
```

It renders `/privacy`, `/terms`, `/terms/user`, `/terms/acceptable-use`,
`/terms/institution` and the rest, and **exits non-zero while any owner placeholder
is unfilled**. Deploy per `docs/Operations/VPS-Deployment-Runbook.md` §6.

**Current gate status: PUBLISH_BLOCKED** — nine tokens remain, every one downstream
of one remaining owner action (company registration — the domain is now live). See
`docs/legal/PLACEHOLDERS.md`.

✅ **The policy host is `https://nikshaos.in`** — the canonical production domain.

This was previously served from an unrelated business's hostname, so a parent
tapping "Privacy Policy" inside their child's school app landed somewhere that
read as a phishing redirect. That is resolved. The Play Console field and
`legal_links.dart` must stay byte-identical to this host.

---

## 3. Data safety form — answers

Derived from the app's actual permissions and code.

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
- ✅ Data is encrypted in transit — production sets `requireTls`, so HTTPS is enforced.
- ✅ Users can request deletion — per `docs/legal/DATA_RETENTION_AND_DELETION_POLICY.md`. ⚠️ owner must supply the deletion-request URL/email.
- ❌ **Independent security review — do NOT tick this.** The project has *internal*
  certifications; that is not third-party review. The previous revision rendered this
  row with a ✅, which is exactly how an untrue claim gets transcribed into a
  compliance form.

**Location justification** (Play will ask): *"Precise location is used only to
confirm a staff member is physically at the school campus when they mark their own
attendance. It is never collected for students or parents, and is not used for
tracking."*

---

## 4. ⚠️ Target audience — answer carefully

**Select: 18 and over.** Accurate, and the simplest compliance path:

- Users are **school staff and parents**, all adults.
- Login is **OTP to the parent's registered mobile**; children have no login in V1.
- The app stores data *about* children but is not *directed to* children.

Declaring the app as targeting children triggers the **Play Families Policy**, which
adds substantial requirements (ads restrictions, extra review, Families-compliant SDK
constraints). Do not select it unless a student-facing login ships.

**Content rating:** Education, no violence/sexual content/gambling, no public
user-generated content. Expected: **Everyone / 3+**. In-app messaging is
**school-moderated and closed** (parent↔teacher only, not public chat) — say so if
the questionnaire asks about user interaction.

---

## 5. Graphic assets

| Asset | Spec | Status |
|---|---|---|
| App icon | 512×512 PNG, 32-bit | ✅ `brand/niksha-os/icons/play-store-512.png` (verified 512×512) |
| Feature graphic | 1024×500 PNG/JPG | see `brand/niksha-os/play/` |
| Phone screenshots | 2–8, min 320px, 16:9 or 9:16 | see `docs/release/screenshots/` |
| Tablet screenshots | optional | not provided |

Screenshots are captured from the real app running on a real Android device — never
mocked up, never composited. `docs/release/screenshots/README.md` records exactly how
they were produced, on what device, and with what data.

**Recommended order** (tells the buying story):
1. Principal Morning Brief · 2. **Student 360** (the differentiator) ·
3. Teacher attendance (exception-first) · 4. Marks entry · 5. Parent — marks /
report card · 6. Parent — fees and receipt · 7. Ask-anything search · 8. Dark mode

---

## 6. "What's new in this release" (500 char max)

```
First release of NIKSHA OS.

• Student 360 and Staff 360 — a person's whole school life on one screen
• Principal Morning Brief — your day, assembled before you ask
• Ask anything, on-device — no cloud call, no data leaving the phone
• Exception-first attendance and fast marks entry
• FA/SA and AP/Telangana SSC grading
• Absent, medical leave and debarred recorded honestly, never as zero
```

(464 characters.)

---

## 7. Release checklist

Engineering-side, verified this cycle:

- [x] Version `1.0.0+1` (`pubspec.yaml`)
- [x] targetSdk 36 — above Play's API-35 floor; minSdk 24
- [x] R8 minify + resource shrink enabled, keep-rules reviewed
- [x] Release AAB builds end to end (132.1 MB; **57.9 MB** real arm64 download after
      Play strips BUNDLE-METADATA — measured via `--split-per-abi`)
- [x] `flutter analyze` → No issues found
- [x] QIE / Question Paper module hidden for V1, verified unreachable by route audit
- [x] Legal pack generated, with a fail-closed publish gate

Owner-side, outstanding:

- [ ] ⚠️ Play Console account created + identity verified
- [ ] ⚠️ Domain bought → legal placeholders filled → policy pack hosted
- [ ] ⚠️ Company registered (registered address, governing law)
- [ ] ⚠️ Grievance Officer named, with a monitored inbox
- [ ] ⚠️ Contact email + website supplied
- [ ] ⚠️ `android/key.properties` created and release AAB signed with the real key
- [ ] ⚠️ Enrol in **Play App Signing** on first upload
- [ ] ⚠️ Internal testing track created, tester emails added

---

## 8. ⚠️⚠️ Keystore — the one irreversible thing

```
Keystore : ~/akshara-upload-keystore.jks   (exists — verified present, 2273 bytes)
Alias    : akshara-upload
Validity : 10000 days
```

⚠️ **The password may not be recorded anywhere.** The previous revision of this file
stated the password was "stored **only** in `android/key.properties` on this
machine". **That file does not exist** — not in this worktree and not in any other
checkout on this machine (all were scanned on 2026-07-28). So unless the owner
already copied it into a password manager, the password for this keystore is gone.

**This is recoverable right now and fatal later.** Before the first upload, a lost
keystore costs nothing: generate a new one and carry on. After the first upload
*without* Play App Signing, a lost keystore means the app **can never be updated
again** — every future release would ship as a brand-new listing with zero installs
and zero reviews.

So, in order:

1. Confirm you still have the password. If not, delete
   `~/akshara-upload-keystore.jks` and generate a fresh one **now**, before any
   upload — see `android/key.properties.example` for the exact `keytool` command.
2. Put the password in a password manager, and back up the `.jks` file offline.
3. **Enrol in Play App Signing on the first upload.** That makes this an *upload*
   key, which Google can help you rotate if it is ever lost again.
