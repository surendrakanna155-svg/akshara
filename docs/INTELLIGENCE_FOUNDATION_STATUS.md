# Intelligence Foundation Status — INTEL-04 Track E

**Date:** June 2026  
**Purpose:** Pre-prediction-engine audit — what exists before building recommendation / at-risk / automation engines  
**Do not implement prediction engines in INTEL-04** — framework and entry points only.

---

## Readiness summary

| Engine domain | Existing infrastructure | Missing infrastructure | Readiness % | Recommended order |
|---------------|-------------------------|------------------------|-------------|-------------------|
| At-risk student | Mock models, Student Success UI, contract tests | Live model, attendance feed, action queue | **35%** | 3 |
| Recommendation engine | Stub replies, persona prompts, intelligence mutations partial | Ranked actions, persistence, feedback loop | **25%** | 4 |
| Attendance intelligence | MG KPI drills, student success mock predictions | Cross-module attendance pipeline, alerts API | **40%** | 2 |
| Academic intelligence | Exam intelligence screens, teacher effectiveness mock | Promotion engine, live grade analytics | **45%** | 2 |
| Fee intelligence | Finance copilot mock, defaulter KPI drill | Collection scoring, predictive defaulter model | **38%** | 3 |
| Growth intelligence | Management dashboard KPIs, operations hub display | Multi-school analytics API, portfolio scoring | **42%** | 1 |

**Weighted intelligence foundation readiness:** **~38%**  
**With INTEL-04 persona routing + context injection:** **~55%** platform readiness for engines

---

## 1. At-risk student engine

| Layer | Status | Key refs |
|-------|--------|----------|
| UI | **B** — Student Success dashboard, MG insight routes | `student_success/` |
| Data | **C** — Mock compute in repository | `mock_student_success_repository.dart` |
| Context | **B** — KPI/filters via `CopilotScreenContext` | INTEL-03/04 |
| Actions | **D** — No ranked intervention queue | — |
| Tests | **B** — Contract + provider | `test/contracts/` |

**Gap:** No production scoring service; copilot can reference at-risk KPIs but cannot recommend interventions.

---

## 2. Recommendation engine

| Layer | Status | Key refs |
|-------|--------|----------|
| Persona routing | **B** — 8 persona experiences with starter prompts | `copilot_persona_experience.dart` |
| Stub inference | **C** — `buildContextAwareStubReply` | `copilot_stub_responses.dart` |
| Server orchestrator | **B** — Context engine merges screenContext | `copilot_context_engine.ts` |
| Persistence | **D** — No recommendation store | — |

**Gap:** Prompt chips return context-aware stubs only; no ranked recommendation list or accept/dismiss workflow.

---

## 3. Attendance intelligence

| Layer | Status | Key refs |
|-------|--------|----------|
| Owner KPIs | **A** — Attendance MTD drill to Student Success | INTEL-02 |
| Predictions | **C** — Mock prediction fields | `student_success_models.dart` |
| Teacher alerts | **C** — Dashboard copy only | Teacher persona focus areas |
| Live feed | **D** — Not wired attendance module → intelligence | — |

---

## 4. Academic intelligence

| Layer | Status | Key refs |
|-------|--------|----------|
| Exam intelligence | **B** — Read screens + routes | `/intelligence/exam` |
| Teacher effectiveness | **C** — Mock repo | `teacher_effectiveness/` |
| Principal persona | **B** — Focus areas defined | INTEL-04 |
| Promotion engine | **D** — Backlog P1-08 | — |

---

## 5. Fee intelligence

| Layer | Status | Key refs |
|-------|--------|----------|
| Defaulter drill | **A** — MG-01 → finance defaulters | INTEL-02 |
| Finance copilot | **C** — Mock screen | `finance_copilot_screen.dart` |
| Director persona | **B** — Fee collection focus | INTEL-04 |
| Predictive collection | **D** — No scoring model | — |

---

## 6. Growth intelligence

| Layer | Status | Key refs |
|-------|--------|----------|
| Multi-school KPIs | **B** — MG dashboard mock | `management_dashboard` |
| Platform owner persona | **B** — Portfolio focus areas | INTEL-04 |
| Expansion signals | **D** — No engine | — |
| Risk detection | **D** — Static insight cards only | — |

---

## Recommended implementation order

1. **Growth / portfolio analytics API** — feeds Platform Owner persona and MG dashboards with real multi-school aggregates.
2. **Attendance + academic pipelines** — unify SIS attendance and exam results into intelligence repositories (replace mock compute).
3. **At-risk student scoring MVP** — deterministic rules before ML; wire to Student Success + Principal persona prompts.
4. **Fee defaulter scoring** — collection risk tiers from finance ledger.
5. **Recommendation engine MVP** — persist suggested actions from copilot sessions; accept/dismiss in UI.
6. **Workflow automation** — P2-06 rules engine consuming recommendation outputs.

---

## INTEL-04 deliverables (foundation, not engines)

- Global floating dock with context injection on open
- Eight persona experience configs (focus + starter prompts)
- `/ai-assistant` persona shell with stub replies
- Context validation tests + Patrol dock journeys
- This audit + `docs/AI_ENTRYPOINT_AUDIT.md`

---

## Related

- `docs/AI_INTELLIGENCE_AUDIT.md`
- `docs/AI_COPILOT_STATUS.md`
- `docs/AI_ENTRYPOINT_AUDIT.md`
