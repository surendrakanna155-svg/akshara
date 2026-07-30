# Changelog — NIKSHA OS

All notable user-facing changes to the NIKSHA OS mobile app.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versioning is [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

This file tracks the **product**. For changes to the legal and privacy documents
see [`docs/legal/CHANGELOG.md`](docs/legal/CHANGELOG.md), which is a separate,
independently-versioned record.

---

## [1.0.0] — unreleased

First public release. Android, `com.akshara.erp`, versionCode 1, minSdk 24,
targetSdk 36.

Released as **NIKSHA OS**. The product was developed under the working name
"Akshara ERP"; that name survives in the package id and in internal identifiers,
where it is permanent and invisible to users.

### For principals and school leaders
- **Morning Brief** — the day composed from the school's own records before you
  ask for it: absences, pending approvals, and what changed overnight. Assembled
  deterministically, not generated.
- **Student 360** — any student's whole school life on one screen: photo, parent
  contact numbers, marks, attendance, leave history, transport route and bus, fee
  status and care alerts. Built for parent meetings, so nothing is behind a tab.
- **Staff 360** — the same one-screen dossier for any employee.
- **Ask anything** — type in plain words and go straight to the record or screen.
  Resolves entirely on the device: no cloud call, and no data leaves the phone.
- Approvals for exam results, fee concessions and leave.

### For teachers
- **Exception-first attendance** — mark the absentees, not all sixty children.
- **Marks entry for speed** — type, press Enter, next student. Unit Test, FA, SA,
  Half-Yearly and Annual, including the Andhra Pradesh / Telangana State Board
  (SSC) grading scale.
- Absent, Medical Leave and Debarred are recorded as themselves — never as zero —
  and are excluded from totals, averages and rank rather than silently depressing
  them.
- Homework, timetable, substitutions and parent messaging.

### For parents
- Attendance, marks and report cards as soon as the school publishes them.
- Fee dues, payment history and downloadable receipts.
- Leave applications, teacher messaging, and the child's bus route and stop.
- Login is an OTP to the registered mobile number. Children never need a phone.

### For the office
- Admissions, fee structures, invoicing, collections and receipts.
- Transport, library, inventory and hostel.
- Staff attendance (campus geofence + face verification), payroll inputs, HR.

### Platform
- Per-school data isolation enforced at the database level.
- Money operations are audited, idempotent, and two-person approved where it
  matters.
- Offline-safe: work queues locally and replays exactly once on reconnect.
- Full dark mode.

### Known limitations in 1.0.0
- **Online fee payment is not enabled.** Fees are recorded by the school office.
  The payment backend exists and is inactive; the app says so plainly rather than
  presenting a button that appears to charge you.
- **Question Paper / question-intelligence is hidden** in this version.
- No tablet-specific layouts. The app runs on tablets at phone proportions.
- English only. Localisation is deliberately limited to parent communications.

---

## Release-candidate hardening

Changes made while preparing 1.0.0 for submission. Recorded because several
corrected defects that were user-visible or that made a release gate meaningless.

### Fixed — security
- Five routes reached the admin console with **no authentication gate and no
  permission gate** (`/certificate-requests`, `/gate-passes`, `/complaints`,
  `/staff-360/:employeeId`, `/sync-center`), and the Infirmary route had its role
  check inverted — a student could open the school-wide medical console while the
  staff who should use it were bounced out. Root cause was a gating list that had
  drifted out of sync with the permission map, with no test asserting the two
  agreed.

### Fixed — startup and memory
- The splash screen imposed a hard **2-second floor on every cold start**: it
  paired session restore with a fixed delay under `Future.wait`, which returns on
  the *slowest* future. Reduced to a 400 ms anti-flicker minimum.
- Firebase initialisation was awaited *before* the first frame, for a result only
  used after it. Two independent storage initialisations were awaited in sequence.
  Both moved off the pre-frame path.
- Capped the decoded-image cache. Flutter's 100 MB default is far too generous for
  a 2 GB phone — one full-resolution photo decodes to ~48 MB — so memory pressure
  could reach an OOM kill before the cache evicted anything.

### Fixed — honesty of displayed data
- Several screens presented **unmeasured values as measured**: a 0% class average
  before any marks existed, "Average: 0.0%" on a report card with nothing
  published, "0% of your annual fees paid" before a fee structure existed, and a
  student with no results being congratulated on "strong performance".
- A teacher's class-average insight hardcoded the exam and subject, so every
  teacher of every subject was told the average was for "Unit Test — Mathematics".
- Errors that rendered as facts: a failed message-history fetch showed "No
  messages sent to this parent yet" (prompting duplicate contact on a sensitive
  channel), and a failed day-close fetch showed "No day closed yet" on a money
  screen.
- Raw exception text — including internal endpoint URLs — reached users on the
  day-one student-import screen.

### Fixed — accessibility
- Status chips ("Paid", "Overdue", "Absent") failed WCAG AA contrast at their real
  11 px size, and the test that should have caught it asserted the large-text
  threshold instead of the normal-text one.
- Tap targets below the 48 dp minimum on parent and teacher screens, caused by
  local overrides cancelling the global guarantee.
- Section titles and fee line items clipped at large system font sizes.

### Fixed — the one public page
- The hosted privacy policy — the URL a Play reviewer clicks — was a hand-made
  copy that had drifted a full version and a rename behind its source, rendered
  raw `**` markers on screen, and left unfilled placeholders visible. Three of the
  four policies users must accept were not hosted at all. The pack is now
  generated from its markdown source with a fail-closed publish gate.

### Fixed — release gates that were not gates
- `flutter analyze` reported 13,008 errors, all inside vendored build artefacts,
  so the gate only ever passed when a human filtered the output by hand.
- Deployment documentation described infrastructure that was never deployed and
  named three environment variables that are read by nothing — each failing
  silently, leaving the operator believing a feature was configured.

[1.0.0]: https://github.com/
