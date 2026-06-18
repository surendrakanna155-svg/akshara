# EXAMS BUILD PLAN — Akshara ERP

> **Date:** 2026-06-18 · **Status:** Plan approved in principle; build order awaiting owner "go".
> **Priority:** #1 product gap (owner: exams = top priority). See `QUESTION_INTELLIGENCE_PLATFORM_AUDIT.md`, `REAL_WORLD_SCHOOL_AUDIT.md`.

## Owner decisions (2026-06-18)
1. **Exam structure = fully flexible** — each school names its own exams/terms.
2. **Report card = marks/percentage + letter grade** (both).
3. **Rank = per-school setting** (always computed; shown to parents only if the school turns it on).
4. **Delivery = in-app view first**; downloadable PDF later.

## Today's reality
- `lib/core/exams/` — real marks lifecycle with approval-gated publish (KEEP, reuse).
- `lib/features/academics/exam_admin/` — exam admin UI (recent F4 work).
- `lib/features/education/` — fake question-paper generator (PARK — future Question Intelligence).
- **Missing:** report cards (totals/grade/rank/remarks), results flowing to parents/students, board-aware grading.

## The flow to build
`Set up exam → Teacher enters marks → Coordinator/Principal approves → Publish to parents/students → Report card (in-app)`

## Build order (small, verifiable slices)
- **Phase 1 — Foundation (per-school exam config):** flexible exam-term definitions; board-aware grading scale (marks + letter grade); rank on/off toggle. *Backbone for everything; low UI risk.*
- **Phase 2 — Exam setup screen:** office/principal creates an exam (term, classes, subjects, max marks, dates).
- **Phase 3 — Marks entry wiring:** connect existing teacher marks-entry to the exam setup (real link, not orphaned).
- **Phase 4 — Approve + publish:** reuse the existing approval gate; on approve, results become visible.
- **Phase 5 — Results for parents/students:** clean in-app results view.
- **Phase 6 — Report card (in-app):** per-student card — subjects, marks, %, grade, total, attendance, remark; rank shown per school setting.
- **Later:** report-card PDF download; ranks polish; (future) Question Intelligence for real papers.

## Notes
- Everything mock/in-memory first (matches current app); durable server backing comes with the broader backend work (F6/F7) — flagged so results persistence is a known follow-up.
- Each phase ships with tests and `flutter analyze` clean.

## Production exam workflow (security-hardened)

The certified end-to-end flow, with the role and the gate that enforces each step
on **both** client (RBAC) and server (edge permission + assignment scope). See
`docs/EXAM_SECURITY_AUDIT.md` for the gap analysis this hardens.

| Step | Actor | Permission gate | Scope enforced |
|------|-------|-----------------|----------------|
| Create / schedule / open marks | Office / Principal | `manageExams` | school |
| Enter & edit marks | **Subject teacher** | `manageExamMarks` | **own subject + class-section** (server-checked vs `teacher_subject_assignments`) |
| Process (submit) | Subject teacher | `submitExamResults` | own assignment |
| Verify | **Exam Coordinator** | `verifyExamResults` | school (oversight) |
| Approve | **Principal** (≠ verifier) | `approveExamResults` | school |
| Publish (auto on approve) | system | `publishExamResults` | school |
| View results | Parent / Student | scope claim (`child_ids` / `student_id`) | own child / self |
| View ranks | Parent / Student | per-school `showRankToParents` | own child / self |

Roles:
- **Subject teacher** = `teacher` role; scoped to `teacher_subject_assignments`. Marks follow the *subject* assignment, not class-teacher status.
- **Exam Coordinator** = a `teacher_assignments` row with `role = 'coordinator'` (the enum already exists), or any staff holding `verifyExamResults`. Should differ from the approver (separation of duties — target; see audit S7).
- A teacher who is also a class teacher gains no extra exam rights; class-teacher status is irrelevant to marks entry.
