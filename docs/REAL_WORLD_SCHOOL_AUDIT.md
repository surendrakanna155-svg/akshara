# REAL-WORLD SCHOOL AUDIT — Akshara ERP

> **Audit date:** 2026-06-18 · **Base commit:** `70194d6`
> **Method:** Walk a normal school day in each persona's shoes and ask: *Can they finish their real work? What frustrates them? What takes too many clicks?*
> **Headline:** On **mock data** most daily journeys are credible. For a **real school with real data**, the operational completeness is ~**58–62%** (consistent with the team's own `RED_TEAM_OPERATIONAL_AUDIT.md`). The two day-one breakers are: **the exam chain is missing/fake**, and **anything a principal approves is not durably stored.**

---

## Persona-by-persona reality

### 👨‍🏫 Teacher
- ✅ **Mark attendance** — excellent, fast, mobile (`teacher/attendance/`).
- ✅ **View timetable / classes** — works.
- ⚠️ **Homework** — review-oriented; create flow is thin (red-team flagged create as review-only).
- ❌ **Enter exam marks into a real exam** — marks entry exists but is **orphaned**: there's no ERP exam to attach them to in the education flow, and marks don't propagate to parent/student result views.
- ⚠️ **Message a parent** — conversation is largely read-only.
- **Frustration:** "I can take attendance beautifully, but I can't run an exam end-to-end."

### 👩‍👧 Parent
- ✅ **Attendance, homework, fees** — clean, certified journeys.
- ✅ **Pay fees (QR/offline)** — works.
- ⚠️ **Exam results / report card** — read-only, no unified report card, **no ranks**.
- ⚠️ **Attendance correction request** — exists but the request **doesn't reliably reach the principal's inbox** (open defect B02b-ATT-01).
- ⚠️ **Transport** — read-only.
- ❌ **Push/SMS/WhatsApp notifications** — in-app only; Indian parents live on WhatsApp/SMS.
- **Frustration:** "I get a fee reminder in an app I rarely open, not on WhatsApp; I can't see my child's rank or full report card."

### 🎓 Student
- ✅ **Timetable, homework, results tabs** — clean.
- ⚠️ Results depend on the broken exam chain upstream.

### 🧑‍💼 Principal
- ✅ **Approval inbox, school KPIs** — responsive UI.
- ❌ **Approvals are not durable** — decisions live in-memory; lost on restart/reinstall. A real principal needs an auditable record.
- ❌ **School-wide attendance rollup** — only per-module views; no "whole school today" number.
- ❌ **Publish exam results** — no publish gate (because the exam chain is missing).
- ⚠️ **Vice-Principal / acting-principal** — no real delegation model.
- **Frustration:** "I approved leave yesterday; today there's no record. I can't publish results. I have no one to delegate to."

### 💰 Accountant / Finance
- ✅ **Fees, receipts, refunds** — strongest admin module; refunds API is the most complete path.
- ⚠️ **Concessions** — in-memory governance; approval doesn't post to the ledger.
- ⚠️ **Reports/exports** — several are stub buttons ("queued" snackbars).
- **Frustration:** "Refunds work, but a concession I approve never reaches the books automatically."

### 📦 Inventory Manager / Storekeeper
- ✅ Stock, purchase orders (maker-checker) on mock.
- ⚠️ Write methods throw `ApiNotConnectedException` when API mode is on; PO is hybrid mock fallback.

### 🧑‍🤝‍🧑 HR Manager
- ✅ Employee directory, leave UI.
- ⚠️ Staff-leave create is stubbed; employee CRUD write methods stub on API.

### 🚌 Transport Manager
- ✅ Routes/vehicles/drivers, table→card on mobile.
- ⚠️ Dedicated driver/coordinator mobile flows still planned.

### 🏨 Hostel Manager
- ✅ Rooms/allocation/attendance on mock.
- ❌ **Admissions → hostel pipeline broken** — `needsHostel` flag doesn't trigger allocation; visitor QR is placeholder.

### 📚 Librarian
- ✅ Catalog, issue/return on mock.
- ⚠️ Issue/return write methods stub on API; **fines don't post to finance**; copilot is mapped to HR context, not library.

### 🏫 Director / Trust
- ⚠️ Portfolio UI exists but is **mock-heavy with hardcoded demo school IDs**; can't truly compare schools.
- ⚠️ Weakest mobile adaptation.

---

## The two day-one breakers

### Breaker 1 — The exam chain 🔴
A school's year *is* exams. Today:
- Paper generation is **fake** (appends literal "AI generated" strings — `mock_education_repository.dart:126-193`).
- There are **two disconnected exam systems**: a real marks-lifecycle store (`lib/core/exams/`) and a separate fake education/paper suite (`lib/features/education/`) — they don't share models.
- No report-card generation, no ranks, no publish-to-parent that actually works end-to-end.
- Prior audit: every exam capability rated **D ("missing")** except mobile marks-entry UI.

### Breaker 2 — Non-durable governance 🔴
Approvals, leave, concessions, attendance corrections all live in **in-memory stores** (`PRE_PRODUCTION_GAP_REPORT.md` A2/A5/A6/A7). On a real device they vanish on restart. A school cannot run on decisions that don't persist.

---

## "Takes too many clicks / causes confusion"

- Admin sub-nav with 10–15 items buries common tasks.
- Principal's menu shows **Salon/Restaurant/Healthcare** (over-granted roles) — confusing and unprofessional in front of a real principal.
- Two "promotion" screens; timetable in four places; QA persona switcher visible.
- Dead export buttons that look functional.

---

## Can each persona complete daily work?

| Persona | On mock today | On real data (without fixes) |
|---------|:-------------:|:----------------------------:|
| Teacher (attendance) | ✅ | ⚠️ no durable record |
| Teacher (exams) | ❌ | ❌ |
| Parent (fees/attendance/homework) | ✅ | ⚠️ no push/SMS |
| Parent (results/report card) | ⚠️ | ❌ |
| Principal (approvals) | ✅ UI | ❌ not durable |
| Accountant | ✅ | ⚠️ concessions not posted |
| Inventory/HR/Library/Hostel | ✅ | ⚠️ writes stub on API |
| Director | ⚠️ demo data | ❌ |

---

## What to fix for real schools (ranked)

1. 🔴 **Make governance durable** (server persistence for approvals/leave/concessions/corrections).
2. 🔴 **Build the real exam chain** (unify the two systems; create→marks→publish→report card→ranks).
3. 🔴 **Turn on a real backend + production auth + server RBAC** for the pilot tenant.
4. 🟠 **Add SMS/WhatsApp/push notifications.**
5. 🟠 **Fix the parent attendance-correction → principal inbox defect** (B02b-ATT-01).
6. 🟠 **Strip non-school modules** so principals don't see Salon/Restaurant.
7. 🟡 **Unify student identity** across modules; wire admissions→hostel; library fines→finance.
8. 🟡 **Make report cards / receipts real PDFs.**

**Bottom line:** Akshara already *looks and feels* like a school product and nails several daily journeys on mock data. To survive contact with a real school it needs **depth on a few core flows** — durable approvals, a working exam chain, real notifications — far more than it needs new features. See `FIRST_10_SCHOOLS_STRATEGY.md` for the sequencing.
