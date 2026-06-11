# Parent & Guardian Provisioning Guide (v1.0-rc1)

**There is no separate parent-only CSV import.** Parents are provisioned through:

1. **Primary guardian** — `parentName` + `parentPhone` columns on each **student import** row  
2. **Secondary / additional guardians** — `POST /onboarding/invites` (ERP → School Onboarding → Invites)

---

## Primary parent (student import)

| Column | Required | Notes |
|--------|:--------:|-------|
| `parentName` | Yes | Display name for guardian user |
| `parentPhone` | Yes | 10–15 digits; `9876500001` or `+919876500001` |

**Duplicate phone behavior:** Same `parentPhone` on multiple student rows creates **one** guardian user and links each student (siblings).

**Login:** Parent app → phone OTP → **parent** scope → school ID.

---

## Secondary guardian (invite)

Use when a student needs an extra parent/guardian not listed on the import row.

| Field | Required | Example |
|-------|:--------:|---------|
| `inviteType` | Yes | `parent` |
| `recipientPhone` | Yes | `9876520001` |
| `recipientLabel` | Yes | `Grandmother — Ananya` |
| `studentId` | Optional | UUID of linked student |
| `channel` | Optional | `whatsapp` (default) or `sms` |

**Response:** WhatsApp deep-link URL to share manually.

---

## Student app login (optional)

To enable **student ID login**, include `studentPhone` on the student import row. This:

1. Creates a user for the student  
2. Links `students.user_id`  
3. Allows login: Student ID = `admissionNumber` + school + OTP  

Without `studentPhone`, only the **parent** can access the child's data via parent app.

---

## Reference: invite tracking sheet

Ops may track secondary invites in a spreadsheet using:

| inviteType | recipientPhone | recipientLabel | studentAdmissionNumber | channel |
|------------|----------------|----------------|------------------------|---------|
| parent | 9876520001 | Secondary Guardian 1 | SCH-2026-0001 | whatsapp |

Admission number is for ops reference only — API uses `studentId` UUID when linking.
