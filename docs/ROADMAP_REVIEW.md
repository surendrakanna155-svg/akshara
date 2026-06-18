# ROADMAP REVIEW — Akshara ERP

> **Audit date:** 2026-06-18 · **Base commit:** `70194d6`
> **Reviewed:** `ORCHESTRATOR_AGENT.md`, `PRODUCTION_BACKEND_ROADMAP.md`, `Roadmap.md`, `AKSHARA_MASTER_FEATURE_REGISTRY.md`, `AKSHARA_FINAL_ROADMAP.md`, `FUTURE_VISION_MASTER_INDEX.md`, and current code.
> **Headline:** The roadmap is **technically well-run but strategically over-scoped**. It executed 15+ milestones (M1–M15) and 5 backend phases (F1–F5) with discipline — but it conflates "Flutter code complete" with "ready for a real school," and it kept building SaaS/multi-industry breadth while the school's operational core stayed mock.

---

## 1. The two roadmaps that exist

| Track | Document | What it really measures | Status |
|-------|----------|-------------------------|--------|
| **Product milestones M1–M15** | `Roadmap.md`, `AKSHARA_FINAL_ROADMAP.md` | Flutter feature breadth on mock | ~88–91% "complete" |
| **Backend production F1–F7** | `PRODUCTION_BACKEND_ROADMAP.md`, `ORCHESTRATOR_AGENT.md` | Real APIs for pilot workflows | F1–F5 done (~89% of the F-track); F6/F7 frozen |

**The trap:** these get summarized into single numbers that contradict each other (35% / 45% / 58% / 72% / 89% / 96%). They're all "true" against different baselines. Recommendation: **publish one scoreboard** with explicit columns — *Code-complete (mock)* · *Production-ready (real data)* · *In scope for first 10 schools*.

## 2. Backend phases (F1–F7) — still valid, correctly sequenced

| Phase | Scope | Verdict |
|-------|-------|---------|
| F1 Auth + RBAC | ✅ certified | **Valid — keep.** But note: enforcement still client-side until API mode is on. |
| F2 Approval API | ✅ certified | **Valid — keep.** This is the backbone (approvals gate exams/leave/finance). |
| F3 SIS + Student 360 | ✅ certified | **Valid — keep.** |
| F4 Exams API | ✅ certified | **Valid, but incomplete in product terms** — covers marks lifecycle, *not* the question/paper/report-card chain. |
| F5 Attendance API | ✅ certified | **Valid — keep.** |
| F6 Audit upload | ⏸ frozen | **Valid — needed for compliance/durability.** Unblock after this audit. |
| F7 Leave + Finance orchestration | ⏸ frozen | **Valid — needed for durable governance.** Unblock after F6. |

→ The F-track is the **right** track. The problem isn't its content; it's that it's only 5/7 done and the product roadmap raced ahead of it.

## 3. Product milestones — what's still valid vs obsolete vs reorder

### KEEP / still valid (core school value)
- M1 Promotion & reshuffle, M6 P1 ERP closure, **M7 Advanced academic** (but finish the *blocked* exam admin — see below), M14 Smart School Config (finish teacher/student adaptation), M15 Theme modernization (low-cost polish).

### REORDER (do these earlier — they're the real blockers)
- **ERP Exam Administration (P3-02, currently "blocked, no owner")** → this should be a **top-3 priority**, not a deferred/blocked item. The exam chain is a day-one school need.
- **F6/F7 + durable governance** → before any more breadth.
- **Real notifications (push/SMS/WhatsApp)** → not prominent in the roadmap; should be.

### POSTPONE (valid someday, not for first 10 schools)
- M8 AI evolution (live LLM) — keep the scaffold, defer real inference until the question-intelligence design is funded.
- M10 Organization Builder, M11 Dynamic Widgets — nice future SaaS, not school-critical.
- M4/M9 Multi-school SaaS, Director portal depth — only when you have multiple paying schools.

### REMOVE / SHELVE (scope creep for a school ERP)
- **M13 Multi-industry verticals** (salon, restaurant, healthcare, accommodation) — 20 shipped screens, zero school relevance. Shelve behind flags.
- **White-label / franchise / platform-ops breadth** — shelve until a SaaS customer exists.
- **phase4/phase5 organizational shells** — delete.

## 4. The registry-drift problem

`AKSHARA_MASTER_FEATURE_REGISTRY.md` tracks ~215 features with an A–F maturity scale and a 58-item FutureVision list. It is genuinely useful — but:
- **~15 rows say "Planned" that code shows "Shipped"** (e.g. QR/offline, PTM summary, Org Builder).
- Many "Shipped" rows are **mock-only** (Copilot, Multi-school, RLS) — "shipped" should not imply "production-ready."

→ The registry should be the **single feature SSOT**, refreshed, with a hard "Production-ready (real data)?" column.

## 5. Contradictions to resolve (one-time cleanup)

| Claim in docs | Reality | Fix |
|---------------|---------|-----|
| "AI ~96%" (`AI_COPILOT_STATUS.md`) | No real LLM; simulated providers | Restate as "scaffold complete, inference simulated" |
| "Exam admin M7 complete" | Exam chain missing/fake | Reclassify as in-progress, assign owner |
| "Governance M-D1–D7 100% certified" | Stores in-memory, not durable | Add "durable persistence" as the missing certification criterion |
| Readiness 89% vs 35% | Different baselines | One scoreboard, labeled columns |
| 238 doc files / "600+ markdown" | Unmaintainable sprawl | Collapse to ~15 living docs |

## 6. Documentation consolidation

There are **238 entries in `docs/`** (the team itself cites "600+ markdown files"). Most are point-in-time milestone/certification reports that will never be read again. Recommendation (no deletions yet — owner approval first):
- **Keep ~15 living docs:** this audit set + one roadmap + one feature registry + the backend decision + the QA orchestrator + persona specs.
- **Archive** the rest under `docs/_archive/` (milestone reports, week reports, superseded plans).
- Replace the chain of "FINAL", "TRUTH", "RC_LOCK", "SIGNOFF" docs with one continuously-updated status page.

## 7. Recommended roadmap going forward

**Phase 1 — "Make it real for one school" (the only thing that matters next)**
1. Unblock & build the **exam chain** (assign an owner). 2. **F6/F7 + durable governance**. 3. **Production auth + server RBAC** (turn on API mode for pilot tenant). 4. **Notifications (push/SMS/WhatsApp)**. 5. Fix B02b-ATT-01.

**Phase 2 — "Make it simple"**
6. **Workspace model** + role tightening. 7. Screen consolidation (delete phase4/5, shelve verticals/SaaS, merge duplicates). 8. UX polish (nav density, dead buttons, breakpoints).

**Phase 3 — "Differentiate"**
9. **Question Intelligence Platform** (see its dedicated audit) — the genuine moat. 10. Multi-language rollout. 11. Selectively re-introduce SaaS/multi-industry *only* when a customer pays for it.

**Bottom line:** Stop adding breadth. The roadmap should **shrink and deepen**: finish the exam chain, make data durable and server-backed, then invest the freed capacity into Question Intelligence as the differentiator. Everything multi-industry/SaaS goes behind a flag until a paying customer demands it.

→ See `FIRST_10_SCHOOLS_STRATEGY.md` for the concrete must-have/cut list and `QUESTION_INTELLIGENCE_PLATFORM_AUDIT.md` for the differentiator.
