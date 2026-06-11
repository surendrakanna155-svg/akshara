# User Acceptance Testing (UAT) Checklist — Akshara ERP v1.0-rc1

**Version:** 1.0  
**Release:** `v1.0-rc1` (feature freeze — no new features)  
**Environment:** Staging or pilot production with **Demo School** dataset seeded  
**School:** Akshara Staging School (`a2000000-0000-4000-8000-000000000001`)  
**Academic year:** 2026-27  

**Defect logging:** All failures → [`Pilot-Issue-Tracker.md`](./Pilot-Issue-Tracker.md)

---

## How to use this checklist

| Column | Meaning |
|--------|---------|
| **ID** | Unique test reference (log in issue tracker) |
| **Steps** | Manual actions in ERP web or mobile app |
| **Expected** | Pass criteria — record **Pass / Fail / Blocked / N/A** |
| **Tester** | Name + date in sign-off section |

**Pre-requisite:** Run `python3 scripts/demo_school_seed.py` (full 500/35/750) or confirm existing Demo School data per [`Demo-School-Validation-Plan.md`](./Demo-School-Validation-Plan.md).

---

## Demo School test accounts

| Role | Identifier | Login scope | Notes |
|------|------------|-------------|-------|
| **School Admin** | Phone `9876543210` | School | Staging school admin; full ERP permissions |
| **Principal** | Phone `9000000001` | School | Demo Teacher 01 — imported as `principal` |
| **Teacher** | Phone `9000000002` | School | Demo Teacher 02 — standard teacher |
| **Parent (demo import)** | Phone `9000100001` | Parent | Linked to `DEMO-2026-0001` student |
| **Parent (probe)** | Phone `9876543211` | Parent | Pre-seeded probe parent (School A) |
| **Student (probe)** | Phone `9876543212` | Student | Pre-seeded probe student |
| **Accountant** | *See note* | School | Use `financeAdmin` role if provisioned; else use School Admin for finance UAT and verify permission denial tests separately |

**Reserved — do not use for new tests:** `9876543213`, `9876543214` (probe teachers).

**OTP (staging):** OTP appears in login API response message (`Use code XXXXXX`) unless live SMS is enabled.

**WhatsApp (RC):** Invite API returns a **deep-link URL** when `channel: "whatsapp"`. Live WhatsApp delivery may be **stubbed** on staging — verify link format and UI action, not carrier delivery, unless production keys are configured.

---

## Global pre-flight (all roles)

| ID | Test | Steps | Expected |
|----|------|-------|----------|
| G-01 | Demo dataset present | ERP → SIS → Students; filter/search `DEMO-2026` | ≥ 500 students listed |
| G-02 | Academic year | ERP → Academic → Years | `2026-27` exists and marked current |
| G-03 | Health | Ops runs `GET /health/ready` (or launch verify script) | HTTP 200 |
| G-04 | Tenant isolation | Ops runs tenant-access probes | 213/213 pass |
| G-05 | Automated smoke | `python3 scripts/demo_school_validate.py` | 31/31 pass |

---

# 1. School Admin

## 1.1 Login

| ID | Test | Steps | Expected |
|----|------|-------|----------|
| SA-L01 | Phone OTP login | Open ERP → Login → enter `9876543210` → request OTP → enter OTP → select **School** scope | Dashboard loads; school name visible |
| SA-L02 | Session persistence | Close browser tab; reopen ERP within token lifetime | Still authenticated or clean re-login prompt (no corrupt state) |
| SA-L03 | Logout | Profile → Logout | Redirected to login; back button does not expose protected screens |
| SA-L04 | Wrong OTP | Enter invalid OTP | Clear error; no partial session |
| SA-L05 | Expired OTP | Wait beyond OTP TTL; submit old code | Error message; can request new OTP |

## 1.2 Daily workflow

| ID | Test | Steps | Expected |
|----|------|-------|----------|
| SA-D01 | Admin hub | Open Admin Hub / home dashboard | KPIs load without error |
| SA-D02 | SIS dashboard | Navigate to SIS dashboard | Student counts reflect demo dataset (500+ active) |
| SA-D03 | Student search | SIS → Students → search `DEMO-2026-0042` | Student profile opens with class, section, guardian |
| SA-D04 | Onboarding import list | SIS → School Onboarding → import jobs | Student and teacher jobs show committed rows |
| SA-D05 | New student CSV (smoke) | Upload 1-row student CSV → Preview → Commit | Preview shows valid; commit succeeds or duplicate clearly flagged |
| SA-D06 | Teacher import status | Onboarding → teacher jobs | Latest job shows committed teachers |
| SA-D07 | Guardian invite | Create parent invite for unused phone; channel WhatsApp | 201 response; invite appears in list |
| SA-D08 | Admissions dashboard | Admissions → Dashboard | Loads; funnel metrics visible |
| SA-D09 | Finance dashboard | Finance → Dashboard | Loads; non-zero or zero-state UI (no crash) |
| SA-D10 | Fee structure | Finance → Fee structures | Demo Pilot Annual Plan (or latest) visible |
| SA-D11 | Fee assignment | Assign fee structure to one demo student | Assignment + invoice created (issued status) |
| SA-D12 | Fee collection | Finance → record cash collection against issued invoice | Collection + receipt created; outstanding reduced |
| SA-D13 | Attendance (admin) | Teacher attendance → submit for one class (today) | Session saved; counts updated |
| SA-D14 | Timetable generate | Academic → Timetable → generate for current year | Timetables created for sections (no 404) |
| SA-D15 | Timetable summary | View timetable summary for 2026-27 | Section counts / status visible |
| SA-D16 | Broadcast | Communications → send broadcast to `All teachers` | Success toast; no 500 |
| SA-D17 | Process notification queue | Communications → process queue (if exposed) or ops API | Processed count > 0 when queue pending |
| SA-D18 | Analytics | Management → Analytics / Intelligence dashboard | Risk metrics and school health load |
| SA-D19 | Copilot | Copilot → Finance assistant → ask fee summary question | Session created; read-only reply (stub or live) |
| SA-D20 | Audit | Perform one mutation (e.g. collection); check audit log if UI available | Event recorded or API audit batch accepted |

## 1.3 Edge cases

| ID | Test | Steps | Expected |
|----|------|-------|----------|
| SA-E01 | Duplicate admission | Import CSV with existing `DEMO-2026-0001` | Preview marks duplicate; commit does not corrupt row |
| SA-E02 | Invalid CSV | Upload CSV with missing required column | Preview validation errors; commit blocked |
| SA-E03 | Collection over outstanding | Attempt collection amount > invoice outstanding | Validation error; no negative outstanding |
| SA-E04 | Refund over collection | Create refund > collected amount | Rejected with clear message |
| SA-E05 | Empty class attendance | Submit attendance with zero students selected | Validation error or empty-state handled |
| SA-E06 | Large broadcast audience | Broadcast to `All parents` (~750) | Completes or retries; eventual 201 (allow ~15 s) |
| SA-E07 | Long session seed | Remain logged in >15 min then run finance action | Either works (refresh) or prompts re-login — not silent 401 on UI |
| SA-E08 | Cross-school data | If UI allows school switch, attempt School B | No School B data visible without membership |

## 1.4 Permissions

| ID | Test | Steps | Expected |
|----|------|-------|----------|
| SA-P01 | Full module access | Open Admissions, Finance, SIS, Onboarding, Timetable, Analytics | All accessible (schoolAdmin role) |
| SA-P02 | Manage finance | Create fee structure, collection, refund request | Allowed |
| SA-P03 | Approve refund | Approve pending refund | Allowed |
| SA-P04 | Publish timetable | Publish one validated timetable | Allowed |
| SA-P05 | Copilot run | Create session and send message | Allowed |

## 1.5 Notifications

| ID | Test | Steps | Expected |
|----|------|-------|----------|
| SA-N01 | Broadcast → delivery | Send broadcast → process queue | Delivery records created |
| SA-N02 | Teacher receives | Login as teacher `9000000002`; check notifications/dashboard | Announcement visible or inbox updated |
| SA-N03 | Parent receives | Login as parent `9000100001`; Parent → Notifications | At least one notification or empty-state (no error) |
| SA-N04 | Idempotent queue | Process queue twice | No duplicate sends for same delivery |

## 1.6 WhatsApp actions

| ID | Test | Steps | Expected |
|----|------|-------|----------|
| SA-W01 | Invite deep link | Create onboarding invite `channel: whatsapp` | Response includes shareable deep-link URL |
| SA-W02 | Copy / share UI | Use copy/share button on invite (if in UI) | Link copies; format is valid `https://` URL |
| SA-W03 | Parent follows link | Open deep link on mobile (staging) | Lands on login or app entry (not 404) |
| SA-W04 | Stub mode indicator | If staging stubs SMS/WA | Ops documents stub ref in delivery record (`stub_*`) — N/A if live keys set |

## 1.7 Error handling

| ID | Test | Steps | Expected |
|----|------|-------|----------|
| SA-X01 | Network offline | Disconnect network; trigger save action | User-friendly error; no data corruption on reconnect |
| SA-X02 | 403 handling | N/A for school admin full access | — |
| SA-X03 | Server 500 | Trigger known heavy action during outage (optional) | Error banner; retry possible |
| SA-X04 | Validation messages | Submit empty required form fields | Inline field errors; no generic crash |

---

# 2. Principal

*Use phone `9000000001` (school scope). Principal has broad view + academic authority; **no** `manageFinance` / `approveRefunds` per role matrix.*

## 2.1 Login

| ID | Test | Steps | Expected |
|----|------|-------|----------|
| PR-L01 | Teacher-principal OTP | Login `9000000001` → school scope | ERP loads with principal role |
| PR-L02 | Role display | Profile / auth me | Role shows principal (not generic teacher) |
| PR-L03 | Logout / re-login | Logout and login again | Consistent access |

## 2.2 Daily workflow

| ID | Test | Steps | Expected |
|----|------|-------|----------|
| PR-D01 | Admin hub | Open dashboard | Loads |
| PR-D02 | SIS overview | SIS dashboard + student search | Read access to demo students |
| PR-D03 | Admissions review | View leads/applications; approve one if pending | View works; approve if permission granted |
| PR-D04 | Attendance oversight | View attendance reports / submit for class | Can mark or view per pilot UI |
| PR-D05 | Timetable | View summary; validate one timetable | Summary loads; validation results shown |
| PR-D06 | Publish timetable | Publish validated section timetable | Success (principal has publish permission) |
| PR-D07 | Analytics / principal summary | Intelligence → Principal summary | Headline + risks load |
| PR-D08 | School health | Analytics → School health score | Composite score visible |
| PR-D09 | Copilot academic | Ask timetable workload question | Read-only academic assistant reply |
| PR-D10 | Onboarding | View import jobs; optional small teacher CSV preview | View/manage onboarding per principal permissions |
| PR-D11 | Parent message | Teacher messages → send to parent (if principal uses teacher shell) | Message thread created |

## 2.3 Edge cases

| ID | Test | Steps | Expected |
|----|------|-------|----------|
| PR-E01 | Publish invalid timetable | Attempt publish without validation pass | Blocked with validation message |
| PR-E02 | Cross-class student edit | Edit student outside assigned scope (if limited) | Allowed or denied consistently per RBAC |
| PR-E03 | Finance write attempt | Try create fee collection (if UI exposed) | **Denied** or hidden (no manageFinance) |

## 2.4 Permissions

| ID | Test | Steps | Expected |
|----|------|-------|----------|
| PR-P01 | View finance | Finance dashboard | **Allowed** (viewFinance) |
| PR-P02 | Manage finance | Create collection / fee structure | **Denied** (403 or UI disabled) |
| PR-P03 | Approve refund | Approve refund | **Denied** |
| PR-P04 | Manage SIS | Update student record | **Allowed** |
| PR-P05 | View analytics | Analytics dashboard | **Allowed** |
| PR-P06 | Admissions approve | Approve application | **Allowed** |

## 2.5 Notifications

| ID | Test | Steps | Expected |
|----|------|-------|----------|
| PR-N01 | Receive broadcast | After admin broadcast to teachers | Visible on principal/teacher dashboard or notifications |
| PR-N02 | Send to parent | Send direct message to demo parent | Parent sees thread |

## 2.6 WhatsApp actions

| ID | Test | Steps | Expected |
|----|------|-------|----------|
| PR-W01 | Teacher compose WA link | Teacher app → message parent → WhatsApp action (if shown) | Opens share sheet or copies WA deep link |
| PR-W02 | No bulk WA without permission | Marketing bulk WA (if separate module) | Not accessible to principal unless granted |

## 2.7 Error handling

| ID | Test | Steps | Expected |
|----|------|-------|----------|
| PR-X01 | Finance write 403 | API/UI fee collection as principal | Clear forbidden message |
| PR-X02 | Invalid OTP | Wrong OTP on login | Error without account lock (staging) |

---

# 3. Teacher

*Use phone `9000000002` (school scope). Demo teachers use **school** scope JWT for attendance APIs.*

## 3.1 Login

| ID | Test | Steps | Expected |
|----|------|-------|----------|
| TE-L01 | OTP login | `9000000002` → school scope | Teacher dashboard loads |
| TE-L02 | Mobile teacher app | Same phone on Teacher mobile app | Dashboard loads |
| TE-L03 | Wrong scope | Attempt parent scope with teacher phone | Membership error |

## 3.2 Daily workflow

| ID | Test | Steps | Expected |
|----|------|-------|----------|
| TE-D01 | Teacher dashboard | Open teacher home | Today's classes / tasks visible |
| TE-D02 | Timetable view | Teacher → Timetable | Weekly periods for assigned classes |
| TE-D03 | Attendance draft | Select class `Nursery` (or assigned class) → mark 10 students present → save draft | Draft saved |
| TE-D04 | Attendance submit | Submit same session | Submitted status; counts locked or editable per policy |
| TE-D05 | Attendance amend | Change one student to absent after submit (if allowed) | Updates or shows policy restriction |
| TE-D06 | Student list | View class roster for demo students | Names match SIS |
| TE-D07 | Message parent | Send message to parent of `DEMO-2026-0001` | 201; thread created |
| TE-D08 | View parent reply | Parent replies (coordinate with parent tester) | Thread shows reply |
| TE-D09 | Notifications | Check teacher notifications after admin broadcast | Announcement visible |

## 3.3 Edge cases

| ID | Test | Steps | Expected |
|----|------|-------|----------|
| TE-E01 | Wrong class_id | Submit attendance with invalid class label | Validation error |
| TE-E02 | Duplicate submit same day | Submit attendance twice same class/date | Upsert or clear duplicate policy |
| TE-E03 | Student not in class | Mark student from another section | Rejected or warning |
| TE-E04 | Zero entries | Submit empty entries array | Validation error |

## 3.4 Permissions

| ID | Test | Steps | Expected |
|----|------|-------|----------|
| TE-P01 | Admissions dashboard | Navigate to Admissions ERP module | **Denied** (403 or not in nav) |
| TE-P02 | Finance manage | Open fee collection screen | **Denied** or not visible |
| TE-P03 | SIS manage | Edit student registry | **Denied** unless explicitly granted |
| TE-P04 | Attendance submit | Submit attendance | **Allowed** (pilot path) |
| TE-P05 | Analytics | Open school analytics | **Denied** |

## 3.5 Notifications

| ID | Test | Steps | Expected |
|----|------|-------|----------|
| TE-N01 | Broadcast receipt | After `all_teachers` broadcast | Notification or dashboard notice |
| TE-N02 | Parent message notification | Parent sends message | Teacher sees unread indicator |

## 3.6 WhatsApp actions

| ID | Test | Steps | Expected |
|----|------|-------|----------|
| TE-W01 | Share PT meeting via WA | Compose message → tap WhatsApp share | Pre-filled text or link opens share intent |
| TE-W02 | No admin broadcast via WA | Teacher cannot send school-wide WA | Action unavailable |

## 3.7 Error handling

| ID | Test | Steps | Expected |
|----|------|-------|----------|
| TE-X01 | Session timeout | Idle past JWT expiry → submit attendance | Re-login prompt |
| TE-X02 | Offline mark | Mark attendance offline (mobile) | Queue or error message per app behavior |

---

# 4. Parent

*Primary demo parent: `9000100001` (parent scope, School A).*

## 4.1 Login

| ID | Test | Steps | Expected |
|----|------|-------|----------|
| PA-L01 | OTP login | Parent app → `9000100001` → parent scope | Parent dashboard loads |
| PA-L02 | Child context | Dashboard shows linked child name | Matches `DEMO-2026-0001` (or assigned child) |
| PA-L03 | Probe parent | Login `9876543211` parent scope | Probe child `Ravi Kumar` dashboard loads |
| PA-L04 | Wrong OTP | Invalid OTP | Error message |
| PA-L05 | No linked children | Phone with no guardian link (if test user available) | Clear forbidden / no children message |

## 4.2 Daily workflow

| ID | Test | Steps | Expected |
|----|------|-------|----------|
| PA-D01 | Parent dashboard | Open home | Greeting, child class, quick actions |
| PA-D02 | Attendance | Parent → Attendance | KPI % and recent logs (from live attendance overlay) |
| PA-D03 | Timetable | Parent → Timetable | Week view with periods (from slots or snapshot) |
| PA-D04 | Fees | Parent → Fees | Installments / outstanding amounts for assigned student |
| PA-D05 | Fee payment summary | Tap one installment / payment summary | Line items and amount due |
| PA-D06 | Receipts | Parent → Receipts (if payments made) | Demo collection receipt visible when seeded |
| PA-D07 | Notifications | Parent → Notifications | List loads (may be empty) |
| PA-D08 | Messages | Parent → Messages → open teacher thread | Thread from teacher UAT visible |
| PA-D09 | Reply to teacher | Send reply message | 201; teacher sees update |
| PA-D10 | Notices / events | Parent → Notices or Events | List or empty-state (no crash) |
| PA-D11 | Profile | Parent → Profile | Parent name, children list, school name |
| PA-D12 | Homework / exams | Open homework and exams tabs | Snapshot loads |

## 4.3 Edge cases

| ID | Test | Steps | Expected |
|----|------|-------|----------|
| PA-E01 | Second child | If parent has multiple children, switch active child | Data refreshes for selected child |
| PA-E02 | Other parent's child | Attempt API/query other student ID | 403 forbidden |
| PA-E03 | No fee assignment | Parent of student without fee assign | Zero due / empty installments (not error) |
| PA-E04 | Payment stub | Initiate online payment (Razorpay) | Stub checkout or live gateway per env config |

## 4.4 Permissions

| ID | Test | Steps | Expected |
|----|------|-------|----------|
| PA-P01 | ERP admissions | Open ERP admissions URL as parent JWT | **403** |
| PA-P02 | SIS admin | Access student registry | **Denied** |
| PA-P03 | Own child fees | View fees for linked child | **Allowed** |
| PA-P04 | Another school | Parent scope School B with School A phone | Membership / scope error |

## 4.5 Notifications

| ID | Test | Steps | Expected |
|----|------|-------|----------|
| PA-N01 | Post-broadcast | After admin `all_parents` broadcast + queue process | New notification or inbox entry |
| PA-N02 | Teacher message | After teacher sends message | Notification or unread thread |
| PA-N03 | Mark read | Open notification | Read state updates |

## 4.6 WhatsApp actions

| ID | Test | Steps | Expected |
|----|------|-------|----------|
| PA-W01 | Invite link onboarding | Open WhatsApp invite link from admin | Lands on login / app download flow |
| PA-W02 | Fee reminder link | If fee reminder template includes WA deep link | Opens parent fees route (when live templates enabled) |
| PA-W03 | Reply via WA | Reply outside app (native WA) | Does not break in-app thread (expected: no sync unless integrated) |

## 4.7 Error handling

| ID | Test | Steps | Expected |
|----|------|-------|----------|
| PA-X01 | Expired token | Use app after long idle | Re-auth prompt |
| PA-X02 | Network error | Load fees offline | Cached or friendly error |

---

# 5. Student

*Probe account: `9876543212` (student scope). Demo import students may lack student-app login unless `user_id` linked.*

## 5.1 Login

| ID | Test | Steps | Expected |
|----|------|-------|----------|
| ST-L01 | Probe student OTP | Student app → `9876543212` → student scope | Student dashboard loads |
| ST-L02 | Student ID login | If enabled: login with student ID + school + OTP | Dashboard loads for linked student |
| ST-L03 | Demo student login | Attempt `DEMO-2026-0001` student ID login | **Pass** if user linked; **Blocked** with clear message if not provisioned |
| ST-L04 | Parent phone on student app | `9000100001` on student login | Wrong app / scope error |

## 5.2 Daily workflow

| ID | Test | Steps | Expected |
|----|------|-------|----------|
| ST-D01 | Student dashboard | Open home | Greeting and today summary |
| ST-D02 | Attendance | Student → Attendance | Own attendance history |
| ST-D03 | Timetable | Student → Timetable | Class timetable periods |
| ST-D04 | Homework | Student → Homework | Assignment list or empty-state |
| ST-D05 | Exams | Student → Exams | Upcoming exams / results |
| ST-D06 | Notices | Student → Notices | School notices list |

## 5.3 Edge cases

| ID | Test | Steps | Expected |
|----|------|-------|----------|
| ST-E01 | Other student data | Attempt view classmate marks | **Denied** |
| ST-E02 | Unlinked demo student | Login without `user_id` | Clear provisioning message |

## 5.4 Permissions

| ID | Test | Steps | Expected |
|----|------|-------|----------|
| ST-P01 | Parent fees route | Student JWT on `/parent/fees` | **403** |
| ST-P02 | Teacher attendance | Student JWT on attendance submit | **403** |
| ST-P03 | Own profile | View own student profile | **Allowed** |

## 5.5 Notifications

| ID | Test | Steps | Expected |
|----|------|-------|----------|
| ST-N01 | School notice push | After broadcast to students (if audience used) | Notice appears or N/A if audience not student-facing |

## 5.6 WhatsApp actions

| ID | Test | Steps | Expected |
|----|------|-------|----------|
| ST-W01 | Student invite link | N/A for student role typically | **N/A** — students use OTP not WA invite |

## 5.7 Error handling

| ID | Test | Steps | Expected |
|----|------|-------|----------|
| ST-X01 | Invalid student ID format | Login with malformed ID | Validation error |

---

# 6. Accountant (Finance Admin)

*Role: `financeAdmin`. If no dedicated user exists in Demo School, provision one membership or use tests **AC-P** / **AC-X** with School Admin vs Finance Admin comparison.*

**Suggested test user:** Assign `financeAdmin` role to a dedicated phone (e.g. `9000000035`) via ops, or use ERP demo role switcher if available in non-production build.

## 6.1 Login

| ID | Test | Steps | Expected |
|----|------|-------|----------|
| AC-L01 | Finance admin OTP | Login finance admin phone → school scope | ERP loads |
| AC-L02 | Limited nav | Observe navigation menu | Finance-focused; no full SIS write clutter |
| AC-L03 | Logout | Logout | Clean session end |

## 6.2 Daily workflow

| ID | Test | Steps | Expected |
|----|------|-------|----------|
| AC-D01 | Finance dashboard | Finance → Dashboard | KPIs: collections, outstanding, summaries |
| AC-D02 | Invoice list | Finance → Invoices | Demo issued invoices listed |
| AC-D03 | Invoice detail | Open one demo invoice | Status, amounts, student link |
| AC-D04 | Record collection | Cash collection for outstanding invoice | Receipt generated; invoice partially paid or paid |
| AC-D05 | Daily summary | Finance → daily collections summary | Today's totals match test collection |
| AC-D06 | Cancel collection | Cancel mistaken collection (if policy allows) | Reverses balances correctly |
| AC-D07 | Refund request | Create refund against collection | Refund pending approval |
| AC-D08 | Approve refund | Approve refund (financeAdmin has approveRefunds) | Balances restored; status approved |
| AC-D09 | Fee structure view | List fee structures | Demo structure visible |
| AC-D10 | Fee assignment | Assign structure to additional student | Assignment + invoice created |
| AC-D11 | Inventory reconciliation | Finance → Inventory reconciliation dashboard | Loads (v7.2c read path) |
| AC-D12 | Copilot finance | Ask copilot about collections | Read-only finance summary |
| AC-D13 | Export / print receipt | Open receipt detail | Printable receipt data |

## 6.3 Edge cases

| ID | Test | Steps | Expected |
|----|------|-------|----------|
| AC-E01 | Duplicate receipt number | Force duplicate reference (if testable) | Duplicate error surfaced |
| AC-E02 | Cancel paid invoice | Cancel fully paid invoice | Rejected per business rules |
| AC-E03 | Refund > collection | Excessive refund amount | Validation error |
| AC-E04 | Wrong student account year | Assign fee to wrong academic year | Validation or resolver error |

## 6.4 Permissions

| ID | Test | Steps | Expected |
|----|------|-------|----------|
| AC-P01 | Manage finance | Create collection | **Allowed** |
| AC-P02 | Approve refund | Approve refund | **Allowed** |
| AC-P03 | SIS manage | Edit student registry | **Denied** |
| AC-P04 | Admissions manage | Create lead | **Denied** |
| AC-P05 | Timetable publish | Publish timetable | **Denied** |
| AC-P06 | View analytics | School analytics dashboard | **Denied** (unless granted) |
| AC-P07 | Onboarding import | CSV student import | **Denied** |

## 6.5 Notifications

| ID | Test | Steps | Expected |
|----|------|-------|----------|
| AC-N01 | Fee receipt notification | After collection, parent notified (if template enabled) | Parent inbox update or stub delivery record |
| AC-N02 | Refund status | Parent sees refund status in fees view | Status reflected |

## 6.6 WhatsApp actions

| ID | Test | Steps | Expected |
|----|------|-------|----------|
| AC-W01 | Fee overdue WA template | Trigger overdue reminder (if manual trigger exists) | Template queued; WA deep link in payload when channel=whatsapp |
| AC-W02 | No broadcast admin | Finance admin cannot send `all_parents` broadcast | **Denied** unless `sendBroadcast` granted |

## 6.7 Error handling

| ID | Test | Steps | Expected |
|----|------|-------|----------|
| AC-X01 | Draft invoice collection | Collect against draft invoice | Rejected (not collectible) |
| AC-X02 | Concurrent collection | Two rapid collections same invoice | Second fails if exceeds outstanding |
| AC-X03 | Permission denied UI | Open SIS onboarding | 403 or hidden route |

---

## 7. First-school onboarding (critical — real school)

Use a **non–Demo School** tenant or a fresh academic batch after [`School-Setup-Checklist.md`](./School-Setup-Checklist.md). Templates: [`templates/`](./templates/).

| ID | Test | Steps | Expected |
|----|------|-------|----------|
| ONB-01 | Academic catalog before import | Create year + classes + sections; labels match CSV | Preview shows `valid` for sample row |
| ONB-02 | First student batch | Upload ≤50 rows from school CSV → Preview → Commit | Job `committed`; SIS count increases |
| ONB-03 | Sibling same parent phone | Two rows, same `parentPhone`, different `admissionNumber` | One parent user; both children linked |
| ONB-04 | Duplicate admission re-import | Re-upload row with existing `admissionNumber` | Preview `duplicate`; commit skips row |
| ONB-05 | Invalid class label | Row with unknown `classLabel` | Preview `invalid`; not committed |
| ONB-06 | Teacher without phone | Teacher CSV row missing `phone` | Preview `invalid` |
| ONB-07 | `studentPhone` → student login | Import row with `studentPhone`; login Student ID = `admissionNumber` | Student OTP login succeeds |
| ONB-08 | Import without `studentPhone` | Parent logs in for that student | Parent sees child; student ID login **fails** (expected) |
| ONB-09 | Secondary guardian invite | `POST /onboarding/invites` for extra parent | Invite listed; WA deep-link returned |
| ONB-10 | Student import rollback | Rollback a committed **student** job (`POST .../rollback`) | Students removed from SIS; job `rolled_back` |
| ONB-11 | Live SMS OTP (production) | Request OTP with `AUTH_OTP_DEV_MODE=false` | SMS received; code **not** in API body |

**Note:** Teacher import rollback marks rows `rolled_back` but does **not** remove teacher memberships — use only for student jobs in pilot; document manual cleanup if teacher rollback needed.

---

## Cross-role integration scenarios

| ID | Scenario | Roles involved | Steps | Expected |
|----|----------|----------------|-------|----------|
| XR-01 | Attendance → parent visibility | Teacher + Parent | Teacher submits attendance → parent refreshes attendance | Parent sees updated present/absent |
| XR-02 | Fee assign → parent fees | Admin + Parent | Admin assigns fee → parent opens fees | Outstanding amount matches |
| XR-03 | Collection → receipt | Accountant + Parent | Record collection → parent receipts | Receipt listed |
| XR-04 | Teacher ↔ parent chat | Teacher + Parent | Teacher sends → parent replies → teacher reads | Bidirectional thread |
| XR-05 | Broadcast cascade | Admin + Teacher + Parent | Admin broadcast teachers → admin broadcast parents | Both roles receive notifications |
| XR-06 | Timetable publish → mobile | Principal + Parent | Principal publishes → parent timetable | Periods visible for child class |
| XR-07 | Principal finance boundary | Principal + Accountant | Principal views finance; accountant records collection | Principal read-only; accountant write succeeds |
| XR-08 | Permission denial | Parent + ERP | Parent opens admissions dashboard URL | 403 |

---

## UAT sign-off

| Role | Tester | Date | Pass | Fail | Blocked | Notes |
|------|--------|------|-----:|-----:|--------:|-------|
| School Admin | | | | | | |
| Principal | | | | | | |
| Teacher | | | | | | |
| Parent | | | | | | |
| Student | | | | | | |
| Accountant | | | | | | |
| Cross-role | | | | | | |

**Overall UAT recommendation:**

- [ ] **Accept** v1.0-rc1 for real-school pilot  
- [ ] **Accept with conditions** (list PILOT issues)  
- [ ] **Reject** (blockers listed in Pilot Issue Tracker)

**Approver:** ___________________ **Date:** ___________

---

## Related documents

| Document | Purpose |
|----------|---------|
| [`v1.0-Release-Candidate.md`](../Releases/v1.0-Release-Candidate.md) | RC scope and known limits |
| [`Production-Validation-Report.md`](./Production-Validation-Report.md) | Automated validation evidence |
| [`Demo-School-Validation-Plan.md`](./Demo-School-Validation-Plan.md) | Dataset and seed strategy |
| [`Pilot-Issue-Tracker.md`](./Pilot-Issue-Tracker.md) | Defect log |
| [`Go-Live-Checklist.md`](./Go-Live-Checklist.md) | Production cutover |
| [`School-Setup-Checklist.md`](./School-Setup-Checklist.md) | Pre-import school setup |
| [`First-Day-Go-Live-Checklist.md`](./First-Day-Go-Live-Checklist.md) | Opening day ops |
| [`Operational-Readiness-Report.md`](./Operational-Readiness-Report.md) | Onboarding readiness summary |

---

## Known RC limitations (may affect UAT)

1. **WhatsApp / SMS** may be stubbed — verify deep links and queue records, not carrier delivery, unless live keys configured.  
2. **Student app login** for bulk-imported demo students requires `user_id` linkage — probe student (`9876543212`) is the reliable student UAT account.  
3. **Finance admin** may need one-time role assignment for Accountant section.  
4. **Principal** (`9000000001`) cannot perform finance writes — failures there are **expected pass** for permission tests.  
5. **Broadcast to all parents** may take ~15 s; transient 502 — retry once before logging defect.
