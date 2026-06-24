# First-Time Student Data Onboarding — Plan

_Created 2026-06-24. Plain-language plan for how a brand-new school gets its
students into Akshara on day one. Owner-approved design decisions are recorded
at the top so we build it once, correctly._

## The problem in one line

When a school joins, it either has a **big list of students already** (most
schools — they keep it in Excel) or **only knows its structure** (e.g. "Grade 6
has 2 sections of 30"). We must handle both, and the parent must be able to log
in with their phone (OTP) right after.

## Owner decisions (2026-06-24)

1. **Aadhaar = optional, stored safely.** The system's **admission number stays
   the real student ID.** Aadhaar is an *optional* extra field, stored
   encrypted/masked, used only to catch duplicates. We do **not** make Aadhaar
   the login or primary key (legal/PII risk; not every child has it handy).
2. **Auto-created students = editable placeholders.** When a school gives only
   structure, we create skeleton students (e.g. "Grade 6A — Roll 1") marked
   `is_placeholder = true`, with **no real parent phone**, so nobody can wrongly
   OTP-login. Staff edit/replace them later with real data.
3. **File format = downloadable Excel template.** We give a `.xlsx` template
   with the exact columns + one example row. We accept `.xlsx` and `.csv`.

## What already exists (do not rebuild)

A real, tested CSV import pipeline is already live on the backend:

- `POST /onboarding/imports/students/preview` — validates rows, returns a
  preview (valid/invalid count + per-row errors).
- `POST /onboarding/imports/{id}/commit` — creates the students.
- `POST /onboarding/imports/{id}/rollback` — undoes a commit.
- Endpoint already accepts **either** a `rows` array **or** raw `csvText`
  (see `supabase/functions/_shared/onboarding/onboarding_handlers.ts`).
- Row validation in `onboarding_repository.ts` already requires:
  `studentName, admissionNumber, classLabel, sectionLabel, academicYear,
  parentName, parentPhone` (+ optional `studentPhone, rollNumber`).
- On commit it calls `upsertUserByPhone(parentPhone)` → **the parent user is
  created and can immediately OTP-login.** This is exactly the behaviour we want.
- Flutter side already has `OnboardingImportJob` / `OnboardingImportPreviewRow`
  models and a `previewStudentImport(...)` provider
  (`lib/features/onboarding/`).

**Because the endpoint already accepts a `rows` array, we can parse Excel on the
phone/app side and POST rows — no heavy server-side xlsx library needed.**

## The three paths a school can take

A school can mix these — e.g. auto-fill the structure first, then replace
placeholders by uploading the real file later.

- **Path 1 — Upload real data** (most schools). Download template → fill in
  Excel → upload → preview → commit. Parents can log in right away.
- **Path 2 — Structure only → placeholders.** Tell us classes, sections per
  class, and students per section. We create editable placeholder students so
  the school can see and use its structure immediately.
- **Path 3 — Add one-by-one.** A small quick-add form for tiny schools or for
  adding a student after the bulk import.

## The Excel template (exact columns)

Header row + one example row. Required columns first.

| Column | Required | Notes |
|---|---|---|
| Student Name | Yes | Full name |
| Admission Number | Yes | The real student ID in our system |
| Class | Yes | e.g. "Grade 6" — must match a class created at onboarding |
| Section | Yes | e.g. "A" — must match a section of that class |
| Academic Year | Yes | e.g. "2026-27" |
| Father / Parent Name | Yes | maps to `parentName` |
| Parent Phone | Yes | 10–15 digits; used to create the parent OTP login |
| Aadhaar Number | No | 12 digits; stored masked/encrypted; dedupe only |
| Mother Name | No | optional |
| Student Phone | No | optional |
| Roll Number | No | optional |
| Date of Birth | No | optional |
| Gender | No | optional |

## What we still need to build

### Backend (Track A)

1. **Migration:** add `aadhaar` (nullable, stored masked/encrypted) and
   `is_placeholder` (boolean, default false) to the students table; add a
   partial unique index on Aadhaar (where not null) for dedupe.
2. **Extend `parseStudentImportRow`** to accept the new optional columns
   (`aadhaar`, `motherName`, `dob`, `gender`). Validate Aadhaar is 12 digits if
   present; flag duplicate Aadhaar in preview.
3. **Placeholder-generation endpoint:** `POST /onboarding/students/generate`
   — input: per-class section count + students-per-section; creates skeleton
   students marked `is_placeholder=true`, **no parent user created**.
   Idempotent and rollbackable (reuse the import job/rollback machinery).
4. **Section-structure persistence:** store "sections per class" and "students
   per section" captured at onboarding.
5. **Deno tests** for all of the above.

### Flutter (Track B)

1. **Onboarding "Class & section structure" step:** for each class, how many
   sections (or name them), and default students-per-section (with optional
   per-section override).
2. **Onboarding "Bring your students" step:**
   - "Download Excel template" button (generates the `.xlsx` above).
   - File picker accepting `.xlsx` / `.csv`; parse **on device** to a `rows`
     array.
   - Preview screen: valid vs invalid rows with per-row error messages → fix →
     commit. (Reuse existing preview/commit providers.)
   - "Generate placeholder students" action driven by the structure step.
3. **Quick "Add one student" form** (name, admission no, class, section, parent
   name, parent phone, optional Aadhaar) for Path 3 and post-import additions.
4. **Placeholder badge** in the SIS roster + an "edit/replace" flow that flips a
   placeholder into a real student (and creates the parent login on save).

### Tests / QA (Track C)

New journeys (author in mock first, then run in live mode):

1. Download template → file has the correct headers + example row.
2. Upload a valid Excel → all rows valid → commit → students appear in SIS;
   a parent from the file can OTP-login.
3. Upload a file with bad rows → preview shows row-level errors → fix → commit.
4. Rollback an import → students removed cleanly.
5. Set structure (Grade 6 = 2 sections × 30) → generate → 60 placeholders,
   marked placeholder, no parent login possible.
6. Replace a placeholder with real data → becomes real; parent login now works.
7. Add one student manually → appears; parent OTP-login works.
8. Aadhaar: import without it works; with it, stored masked; duplicate Aadhaar
   flagged in preview.
9. Live-mode versions of 2, 5, 7 (the high-value ones).

## How this connects to the AI School Builder idea

This is the **concrete first slice** of the AI School Builder
([docs/FUTURE_VISION_AI_SCHOOL_BUILDER.md](../FUTURE_VISION_AI_SCHOOL_BUILDER.md)).
The AI interview ("what board, how many classes, sections, strength?") feeds
exactly the **structure step** above. Build this plain version first; let the AI
pre-fill it later. Nothing about the AI idea was lost — it was gated behind UX
consolidation, which is now done, so it is unblocked.

## Effort & how to split the work (go faster)

Lock the **contract first** (the column list + the two new endpoints) in ~half a
day, then run three tracks in parallel:

| Track | Scope | Rough effort |
|---|---|---|
| A — Backend | columns + Aadhaar migration + generate endpoint + Deno tests | ~1 week |
| B — Flutter | structure step + template download + upload/preview/commit + quick-add | ~1 week |
| C — Tests/QA | the 9 journeys, mock then live | ongoing, in parallel |

Tracks A and B only touch each other through the locked contract, so they don't
block each other. Total wall-clock ≈ **1.5 weeks** if split, ≈ 2.5–3 weeks if
done by one person in sequence.

## Open follow-ups (not blocking)

- Aadhaar encryption-at-rest key handling (reuse backend secret management).
- "Promote a whole section of placeholders" bulk-edit (nice-to-have after v1).
- Map mother/guardian to a second login later if schools ask for it.
