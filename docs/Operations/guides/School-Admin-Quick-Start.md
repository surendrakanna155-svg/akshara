# School Admin Quick-Start Guide

**Version:** 1.0 (v1.0-rc1)  
**For:** School administrators using Akshara ERP web

---

## 1. First login

1. Open the ERP web URL provided by Akshara.
2. Enter your **registered mobile number** (the one given during school setup).
3. Tap **Send OTP** — you will receive an SMS code (not shown on screen in production).
4. Enter the 6-digit OTP.
5. Select scope **School** and your school name.
6. You land on the admin dashboard.

**Problems?** Wait 60 seconds and request a new OTP. Confirm you selected **School** scope, not Parent or Student.

---

## 2. Complete setup before importing students

| Step | Where in ERP |
|------|----------------|
| Academic year | Academic → Years → create `2026-27` (or your year) → mark current |
| Classes | Academic → Classes → add every grade you use |
| Sections | Academic → Sections → add A, B, … per class |

Class names in your CSV must match these labels **exactly**.

---

## 3. Import teachers (do this first)

1. Download the teacher template from your Akshara contact (or use the sample CSV).
2. Fill: `displayName`, `phone`, `role` (`principal` for principal, `teacher` for staff).
3. Go to **SIS → School Onboarding**.
4. Upload teacher CSV → **Preview** → fix any red/invalid rows → **Commit**.
5. Ask principal and one teacher to test login before student import.

---

## 4. Import students and parents

1. Download the student template.
2. Required columns: student name, admission number, class, section, academic year, parent name, parent phone.
3. Upload **≤ 50 students at a time** → Preview → Commit.
4. Repeat for remaining batches.
5. Check **SIS → Students** — search a few admission numbers to confirm.

Each parent phone on the sheet can log in to the **Parent app** after import — no separate parent file.

---

## 5. Day-one tasks

| Task | Menu path |
|------|-----------|
| View all students | SIS → Students |
| Onboarding status | SIS → School Onboarding |
| Fee structures | Finance → Fee Structures |
| Send announcement | Communications → Broadcasts |
| Mark attendance (or assign teachers) | Attendance / Academic |

Full opening-day list: [`First-Day-Go-Live-Checklist.md`](../First-Day-Go-Live-Checklist.md)

---

## 6. Invite extra guardians (optional)

If a student needs a second parent/guardian not on the import sheet:

1. SIS → School Onboarding → **Invites**
2. Create invite: type **parent**, phone, label (e.g. “Father — Ravi”)
3. Share the WhatsApp link with the guardian

---

## 7. Who to contact

Log issues with your Akshara pilot contact. Include: your school name, phone number used, screenshot of error, and time of failure.
