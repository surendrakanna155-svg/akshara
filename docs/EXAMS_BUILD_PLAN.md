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
