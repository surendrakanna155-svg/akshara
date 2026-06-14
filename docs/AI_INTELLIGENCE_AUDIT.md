# AI Intelligence Audit

**Version:** 1.1  
**Date:** June 2026  
**Purpose:** Phase 1 — classify all Akshara intelligence surfaces  
**Classification:** **A** Fully Implemented · **B** Partial · **C** Mock Only · **D** Not Implemented  
**Baseline:** P0 complete · ERP ~83% · INTEL-02 complete

---

## Executive summary

| Domain | A | B | C | D | Overall |
|--------|---|---|---|---|---------|
| AI Chat / Copilot | 0 | 1 | 1 | 1 | **B** |
| Owner dashboard intelligence | 0 | 2 | 1 | 0 | **B** |
| Student intelligence | 0 | 1 | 2 | 0 | **C** |
| Teacher intelligence | 0 | 1 | 2 | 0 | **C** |
| Parent intelligence | 0 | 2 | 1 | 0 | **B** |
| Finance intelligence | 0 | 1 | 2 | 0 | **C** |
| Attendance intelligence | 0 | 0 | 1 | 1 | **C** |
| Academic intelligence | 1 | 1 | 1 | 0 | **B** |
| Transport intelligence | 0 | 1 | 1 | 0 | **C** |
| Hostel intelligence | 0 | 1 | 1 | 0 | **C** |
| **Cross-cutting** | 1 | 6 | 12 | 3 | **C** |

**Intelligence completion (weighted):** ~**44%** functional · ~**74%** UI/mock surfaces  
**Live AI inference:** Not production-ready — mock repository + OpenAI edge stubs  
**Copilot detail:** See `docs/AI_COPILOT_STATUS.md` (~48% copilot vision)

---

## 1. AI Chat Bubble / Copilot

| Capability | Class | UI | Service | Provider | RBAC | Tests | Gaps |
|------------|-------|-----|---------|----------|------|-------|------|
| ERP Copilot screen (`/copilot`) | **B** | Yes | Mock + API hybrid | `copilot_provider.dart` | `copilotCanUseProvider` | Contract + integration | No floating bubble; admin route only |
| Admin app-bar AI button | **B** | Yes | Nav to `/copilot` | `admin_content_scaffold.dart` | Role-gated | Partial | Not context-aware |
| Mobile AI app-bar (teacher/student) | **C** | Yes | Nav action IDs only | Dashboard providers | Persona | Mobile tests | Routes to stub handlers in shell |
| **Floating chat bubble (FAB)** | **D** | No | No | No | — | — | **Not implemented** |
| Context-aware Copilot | **C** | Partial | `copilot_context_engine.ts` (server) | Session + assistant type | Yes | Server tests | Client does not pass screen context |
| Role-specific assistants | **B** | Yes | `CopilotAssistantType` enum | Mock assistants list | RBAC | Contract | Finance/HR/principal types; not all modules |
| Universal AI Assistant (#29) | **D** | No | No | No | — | — | FutureVision P3 |

**Key files:** `lib/features/copilot/` · `lib/core/repositories/mock/mock_copilot_repository.dart` · `supabase/functions/_shared/copilot/`

---

## 2. Owner Dashboard Intelligence

| Capability | Class | UI | Service | Provider | RBAC | Tests | Gaps |
|------------|-------|-----|---------|----------|------|-------|------|
| MG-01 dashboard KPIs | **A** | Yes | Mock read + drill nav | `managementDashboardFutureProvider` | View mgmt | Navigation + Patrol | Drill routes wired (INTEL-02) |
| MG-01 export | **B** | Yes | Nav to FN reports | Wired P1-01 | manageManagement | Patrol | PDF still queued snackbar |
| AI insight card (MG-01) | **B** | Yes | Static string | Dashboard data | — | — | Action → tasks (works) |
| MG-02–07 insight cards | **A** | Yes | Static | Per-screen data | — | Navigation test + Patrol | Routed to intelligence surfaces |
| Intelligence hub (MG analytics) | **B** | Yes | Analytics repo | `intelligence_hub_screen.dart` | `intelligenceCanViewProvider` | Contract | Read-only tabs |
| Operations Hub | **B** | Yes | Mock aggregate | `operations_hub_screen.dart` | View | Partial | Actions display-only |
| Principal Command Center | **B** | Yes | Partial | Principal routes | Patrol read | Priority cards null onTap |
| Executive intelligence / PDF | **C** | Yes | Snackbar queue | Finance executive | — | Partial | Not real export |

**Key files:** `lib/features/management/` · `docs/OWNER_DASHBOARD_AUDIT.md`

---

## 3. Student Intelligence

| Capability | Class | UI | Service | Provider | RBAC | Tests | Gaps |
|------------|-------|-----|---------|----------|------|-------|------|
| Student Success dashboard | **C** | Yes | Mock compute | `student_success_provider.dart` | `viewStudentSuccessIntelligence` | Contract | Mock predictions |
| At-risk student detection | **C** | Yes | Mock | `student_success_models.dart` | Yes | Contract + provider | No live model |
| Attendance predictions | **C** | Yes | Mock field | Predictions list | Partial | Partial | Not wired to attendance module |
| Student Risk tab (legacy UI) | **C** | Yes | Mock | `intelligence_screen.dart` | `intelligenceCanGenerateProvider` | Feature tests | Dev-style forms |
| Student mobile AI insight | **C** | Yes | Inline mock | `student_dashboard_provider.dart` | Student | Golden | Nav to `ai_quiz` stub |
| Recommendation engine | **D** | No | No | No | — | — | No ranked action queue |

**Key files:** `lib/features/intelligence/student_success/` · `/intelligence/student-success`

---

## 4. Teacher Intelligence

| Capability | Class | UI | Service | Provider | RBAC | Tests | Gaps |
|------------|-------|-----|---------|----------|------|-------|------|
| Teacher Copilot (mobile) | **C** | App-bar AI | Action id | Teacher shell | Teacher | Mobile | Stub navigation |
| Teacher Success Center tab | **C** | Yes | Mock | `intelligence_screen.dart` | Yes | Partial | Generate buttons mock |
| Teacher Effectiveness screen | **C** | Yes | Mock repo | `teacher_effectiveness_provider.dart` | Permission | Contract | Read-only insights |
| Teacher scheduling intelligence | **D** | No | No | — | — | — | Timetable read only |
| Auto assignment recommendations | **D** | No | Suggestions model only | school_completion | Contract | No wizard |
| Workload balancing apply | **D** | No | Metrics read | Optimization screen | Contract | No rebalance action |

**Key files:** `lib/features/intelligence/teacher_effectiveness/` · `lib/features/teacher/`

---

## 5. Parent Intelligence

| Capability | Class | UI | Service | Provider | RBAC | Tests | Gaps |
|------------|-------|-----|---------|----------|------|-------|------|
| Parent Guidance Assistant | **C** | Tab in intelligence UI | Mock generate | `intelligence_provider.dart` | Yes | Contract | Not in parent app natively |
| Parent Experience Bridge | **B** | Yes | Mock hub | `parent_experience_hub_screen.dart` | Parent | Partial | Homework intelligence read |
| Parent homework insight card | **B** | Yes | Mock | `parent_homework_provider.dart` | Parent | Provider | Action wired |
| Parent Guidance (FutureVision #4 full) | **C** | Partial | Mock | Intelligence repo | — | — | Staff copilot not parent-facing chat |
| Parent mobile AI bubble | **D** | No | — | `showAi: false` on parent app bar | — | — | By design currently |

**Key files:** `lib/features/parent/` · `lib/features/intelligence/intelligence_screen.dart`

---

## 6. Finance Intelligence

| Capability | Class | UI | Service | Provider | RBAC | Tests | Gaps |
|------------|-------|-----|---------|----------|------|-------|------|
| Finance Copilot screen | **C** | Yes | Mock | `financeCopilotProvider` | View finance | Patrol finance | Forecast mock |
| Finance executive dashboard | **C** | Yes | Mock | Executive provider | Management | Partial | Export stub |
| Fee collection insights | **C** | Yes | Mock | Copilot + defaulters | Yes | Contract | Not live |
| Defaulter prediction | **C** | Yes | Mock list | Finance copilot data | Yes | — | — |
| MG-04 finance insight card | **C** | Yes | Static | Management finance | — | — | **Action stub** |
| Operational fee alerts | **B** | Yes | Dashboard banner | MG-01 | Yes | Patrol | Defaulter link works |

**Key files:** `lib/features/finance/intelligence/` · `getFinanceCopilot` repo

---

## 7. Attendance Intelligence

| Capability | Class | UI | Service | Provider | RBAC | Tests | Gaps |
|------------|-------|-----|---------|----------|------|-------|------|
| Attendance prediction (student risk) | **C** | Yes | Mock field | Student success | Partial | Contract | Not attendance-admin |
| MG-02 class attendance analytics | **A** | Yes | Mock read + KPI drill | Analytics screen | View | Screen + Patrol | Attendance KPI → student success intel |
| ERP attendance admin intelligence | **D** | No | No | — | — | — | Module incomplete |
| Teacher attendance mark (data source) | **A** | Yes | Write | Teacher mutations | Yes | Patrol | Feeds risk mock only |

**Key files:** Analytics class summary · teacher attendance features

---

## 8. Academic Intelligence

| Capability | Class | UI | Service | Provider | RBAC | Tests | Gaps |
|------------|-------|-----|---------|----------|------|-------|------|
| Exam intelligence screen | **C** | Yes | Mock | `exam_intelligence_provider.dart` | Yes | Contract | Read-only |
| AI Education Suite (generative) | **A** | Yes | Mock AI | Education screens | Yes | Yes + Patrol | Mock inference |
| MG-05 academic insight card | **A** | Yes | Static + KPI drill | Academics screen | — | Patrol | Pass rate / at-risk → exam intelligence |
| Report card remark AI | **A** | Yes | Yes (mock) | Education mutations | Yes | Patrol | — |
| Academic promotion intelligence | **D** | No | No | — | — | — | Promotion engine absent |

**Key files:** `lib/features/intelligence/exam/` · `lib/features/education/`

---

## 9. Transport Intelligence

| Capability | Class | UI | Service | Provider | RBAC | Tests | Gaps |
|------------|-------|-----|---------|----------|------|-------|------|
| Transport dashboard AI insight | **B** | Yes | Static | Transport dashboard | View | Partial | Action → SIS (should be allocation) |
| Route performance metrics | **B** | Yes | Mock read | Transport providers | Yes | — | Read-only |
| GPS / live tracking intelligence | **D** | No | Placeholder | Tracking screen | — | — | P3 |
| Occupancy optimization | **C** | Yes | Mock | Dashboard metrics | — | — | No recommendations |

**Key files:** `lib/features/transport/dashboard/`

---

## 10. Hostel Intelligence

| Capability | Class | UI | Service | Provider | RBAC | Tests | Gaps |
|------------|-------|-----|---------|----------|------|-------|------|
| Hostel dashboard AI insight | **B** | Yes | Static | Hostel dashboard | View | Partial | Action → SIS |
| Health alerts panel | **B** | Yes | Mock | Dashboard data | — | — | Display-only |
| Mess / visitor intelligence | **C** | Yes | Insight cards | Mess screen | — | — | Read-only |
| Bed optimization recommendations | **D** | No | No | — | — | — | — |

**Key files:** `lib/features/hostel/dashboard/`

---

## Cross-cutting intelligence infrastructure

| Component | Class | Notes |
|-----------|-------|-------|
| `IntelligenceRepository` | **B** | Mock + API hybrid; compute methods work in mock |
| `intelligence_mutations_provider.dart` | **B** | Refresh/compute actions; partial |
| `/intelligence` hub (5 tabs) | **C** | Dev/admin lab UI + production routes split |
| Supabase intelligence edge | **B** | Server-side; not all wired to Flutter live |
| RBAC intelligence permissions | **A** | `viewStudentRisk`, `viewAnalytics`, etc. |
| Recommendation engine (unified) | **D** | No central ranked recommendations |
| Live OpenAI inference | **C** | Copilot server only; most modules mock |

---

## Phase 2 completion queue (priority order)

| # | Feature | Current | Target class | Sprint |
|---|---------|---------|--------------|--------|
| 1 | Management insight card routes | **A** | **A** | ✅ INTEL-01 |
| 2 | KPI drill-down (MG-01) | **A** | **A** | ✅ INTEL-02 |
| 3 | Context-aware copilot (screen context) | C | **B** | **INTEL-03** ← next |
| 4 | At-risk detection (live pipeline) | C | **B** | P2 |
| 5 | Floating chat bubble | D | **B** | INTEL-04 |
| 6 | Recommendation engine | D | **B** | P2 |
| 7 | Universal AI Assistant | D | **B** | P3 |

### Ranked next features (INTEL-02 Track C)

| Priority lens | Recommendation | Rationale |
|---------------|----------------|-----------|
| Highest business value | Context-aware copilot | Server context engine exists; unlocks actionable answers on any screen |
| Lowest effort | Context-aware copilot | ~2–3 d client API wiring vs 5–7 d per persona chat shell |
| Biggest differentiator | Universal floating assistant + live inference | Matches FutureVision #29; requires INTEL-03/04 first |

---

## Related documents

| Document | Role |
|----------|------|
| `ADVANCED_FEATURE_STATUS.md` | Structural/automation gaps |
| `AKSHARA_MASTER_FEATURE_REGISTRY.md` | Feature SSOT |
| `FUTURE_VISION_RECONCILIATION.md` | FutureVision # mapping |
| `docs/Vision/FutureVision.md` | Original vision |
| `docs/OWNER_DASHBOARD_AUDIT.md` | Owner surface audit |
| `docs/AI_COPILOT_STATUS.md` | Copilot persona + capability audit (INTEL-02) |

**Next audit trigger:** After each intelligence feature closes (update class + completion %)
