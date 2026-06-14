# AI Copilot Status

**Version:** 1.1  
**Date:** June 2026  
**Program:** INTEL-04 — Floating dock + persona shells  
**Classification:** **A** Fully Implemented · **B** Partial · **C** Mock Only · **D** Not Implemented

---

## Executive summary

| Metric | Value |
|--------|-------|
| **Overall copilot completion** | **~72%** functional · **~85%** UI/surface |
| **Live AI inference** | Server edge only (OpenAI stub); client default = mock |
| **Production-ready chat** | ERP staff copilot + context injection |
| **Persona coverage** | 8 persona experiences; staff → `/copilot`, mobile → `/ai-assistant` |

Akshara has a **production-grade ERP copilot** (screen, repository, RBAC, context injection, floating dock) plus **role-aware persona shells** on mobile. Prediction engines and live inference remain future work (P3).

---

## Capability matrix

Legend: ✅ Yes · ⚠️ Partial · ❌ No · — N/A

| Surface | Class | UI | Navigation | Service | Prompt routing | Context | RBAC | Tests |
|---------|-------|-----|------------|---------|----------------|---------|------|-------|
| Floating AI bubble (FAB) | **B** | ✅ | ✅ All shells | ✅ Dock providers | ✅ Persona icons | ✅ On open | ✅ Hidden on AI routes | ✅ Unit + Patrol |
| ERP AI Copilot screen (`/copilot`) | **B** | ✅ | ✅ Admin + dock | ✅ Mock + API hybrid | ✅ Assistant picker | ✅ Client + server | ✅ `viewAiCopilot` | ✅ Contract + integration + RBAC |
| Context-aware assistant | **B** | ✅ Banner + scope | ✅ | ✅ Context engine | ✅ Orchestrator | ✅ `CopilotScreenContext` | ✅ | ✅ Unit + Patrol |
| Student assistant | **B** | ✅ Persona shell | ✅ Dock + dashboard | ⚠️ Stub replies | ⚠️ Focus prompts | ✅ Context inject | Student persona | ✅ Nav + Patrol |
| Teacher assistant | **B** | ✅ Persona + insights | ✅ Dock + dashboard | ⚠️ Stub + evolution repo | ⚠️ | ✅ Context inject | ✅ | ✅ Contract + Patrol |
| Parent assistant | **B** | ✅ Persona shell | ✅ Dock + dashboard | ⚠️ Stub replies | ⚠️ | ✅ Context inject | Parent persona | ✅ Nav pilot |
| Admin assistant | **B** | ✅ Copilot screen | ✅ Admin scaffold | ✅ Copilot repository | ✅ 5 assistant types | ⚠️ Server bundles | ✅ Full RBAC | ✅ Full suite |
| Owner assistant | **B** | ✅ Same as admin copilot | ✅ Management + admin routes | ✅ Copilot + management intel | ⚠️ Module copilots mock | ⚠️ KPI/insight drills now wired | ✅ Super-admin / mgmt perms | ✅ Management + copilot tests |

---

## Per-surface detail

### 1. Floating AI chat bubble — **B**

| Check | Status |
|-------|--------|
| UI | `CopilotFloatingDock` + `CopilotDockHost` on all shells |
| Navigation | Tap → expand panel → open staff copilot or persona shell |
| Service | Context captured via `openAiAssistantFromDock` |
| Prompt routing | Persona icon + experience title |
| Context awareness | `copilotEffectiveContextProvider` summary in panel |
| RBAC | Staff → full copilot when `viewAiCopilot`; else persona shell |
| Tests | `copilot_dock_test.dart` + `copilot_dock_e2e_test.dart` |

**Remaining gap:** Module-specific copilots not unified; no persistent dock position prefs

---

### 2. ERP AI Copilot screen — **B**

**Key files:** `lib/features/copilot/` · `lib/router/copilot_navigation.dart` · `lib/core/repositories/mock/mock_copilot_repository.dart`

| Check | Status |
|-------|--------|
| UI | Full chat workspace with sessions, suggestions, message list |
| Navigation | Admin Hub → AI Copilot; `AdminContentScaffold` default `onAiCopilotTap` |
| Service | `CopilotRepository` mock + `HybridCopilotRepository` + Supabase edge |
| Prompt routing | `CopilotAssistantType` (admissions, finance, sis, academic, communication) |
| Context | Session + assistant type only; no `screenContext` param from Flutter |
| RBAC | `copilotCanUseProvider`, route guard on `/copilot` |
| Tests | `copilot_repository_contract_test.dart`, `copilot_api_integration_test.dart`, `copilot_rbac_test.dart` |

**Effort to reach A:** 2–3 d — pass client context (route, entity ids) to API  
**Business value:** High — only production-grade chat UX today

---

### 3. Context-aware assistant — **C**

**Key files:** `supabase/functions/_shared/copilot/copilot_context_engine.ts` · `copilot_prompt_orchestrator.ts`

| Check | Status |
|-------|--------|
| UI | Same copilot screen; no “context chip” showing active module |
| Navigation | N/A |
| Service | Server loads finance/admissions/SIS/timetable bundles by permission + assistant type |
| Prompt routing | Orchestrator merges context into system prompt |
| Context awareness | **Server-side only** — client does not send current route or selection |
| RBAC | `claimsHasPermission` gates each bundle |
| Tests | `copilot_repository_test.ts` (Deno) |

**Effort:** 2–3 d client wiring + 1 d QA  
**Business value:** **Highest near-term ROI** — unlocks “ask about this screen” without new models

---

### 4. Student assistant — **C**

| Check | Status |
|-------|--------|
| UI | `showAi: true` on student dashboard app bar |
| Navigation | `ai_assistant` / `ai_quiz` → `RouteNames.studentHomework` (stub) |
| Service | No `StudentCopilotRepository` |
| Prompt routing | None |
| Context | Inline mock insight on dashboard only |
| RBAC | Student persona |
| Tests | `student_navigation_pilot_test.dart` |

**Effort:** 5–7 d (mobile chat shell + scoped student context API)  
**Business value:** Medium — differentiation for student engagement

---

### 5. Teacher assistant — **B**

| Check | Status |
|-------|--------|
| UI | `TeacherAssistantScreen` — insights cards, not conversational chat |
| Navigation | Teacher dashboard app bar → `/teacher-assistant` |
| Service | `teacherAssistantInsightsProvider` · evolution API `/teacher-assistant/insights` |
| Prompt routing | Edge `teacher_assistant_service.ts` |
| Context | Class/subject filters on screen; not copilot session model |
| RBAC | `viewTeacherAssistant` route guard |
| Tests | Evolution contract + integration |

**Effort:** 4–5 d to unify with chat copilot pattern  
**Business value:** High — daily teacher workflow aid

---

### 6. Parent assistant — **C**

| Check | Status |
|-------|--------|
| UI | `showAi: false` on most parent screens; guidance in intelligence lab |
| Navigation | Dashboard `ai_copilot` action → parent experience hub (not chat) |
| Service | Parent guidance generate in `intelligence_provider` (mock) |
| Prompt routing | Server has `parentGuidance` assistant type; not exposed in parent app |
| Context | Active child id available; not passed to assistant |
| RBAC | Parent persona + child scope |
| Tests | Parent provider tests; no copilot journey |

**Effort:** 5–6 d (parent chat tab + child-scoped API)  
**Business value:** High — parent retention and fee/attendance queries

---

### 7. Admin assistant — **B**

Same implementation as ERP Copilot with admin RBAC. Module-specific intelligence screens (Finance Copilot, Inventory Copilot) are **C** — read-only mock panels, not integrated chat.

---

### 8. Owner assistant — **B**

Owners use management dashboards + ERP copilot. **INTEL-01/02** wired insight actions and KPI drills to intelligence surfaces; copilot itself unchanged. No separate “owner persona” assistant type — super-admin uses finance/academic assistant types.

---

## Module copilots (related)

| Module | Screen | Class | Notes |
|--------|--------|-------|-------|
| Finance | `FinanceCopilotScreen` / executive dashboard | **C** | Mock forecasts; Patrol finance workflows |
| Inventory | `InventoryCopilotScreen` | **C** | Mock reorder suggestions |
| Transport / Hostel | Insight cards only | **C** | Static strings, some misrouted actions (fixed transport in INTEL-01) |

---

## Missing capabilities (priority)

| # | Capability | Class today | Effort | Business value |
|---|------------|-------------|--------|----------------|
| 1 | Client screen context → copilot API | C | 2–3 d | **Highest** |
| 2 | Floating / docked chat entry (ERP + mobile) | D | 3–5 d | High |
| 3 | Student conversational assistant | C | 5–7 d | Medium |
| 4 | Parent native chat (child-scoped) | C | 5–6 d | High |
| 5 | Teacher chat unified with insights | B | 4–5 d | High |
| 6 | Live inference (replace mock responses) | C | 2–4 w | Medium (infrastructure) |
| 7 | Universal AI Assistant (#29) | D | 3–4 w | Strategic differentiator |

---

## Recommended implementation order

1. **INTEL-04 — Floating copilot dock** — DesignSystem §17 entry point
2. **INTEL-05 — Parent guidance chat** — child-scoped mobile shell
3. **INTEL-05 — Parent guidance chat** — high parent-facing value  
4. **INTEL-06 — Teacher copilot chat** — unify insights + conversation  
5. **INTEL-07 — Student study assistant** — replace homework stub routing  
6. **P3-01 — Live AI inference** — swap mock for production models module-by-module

---

## Distance to full vision

| Vision element | Status | Gap |
|----------------|--------|-----|
| Universal AI entry (#29) | ~15% | FAB + persona shells |
| Context-aware answers | ~55% | Server ready; client wiring missing |
| Role-specific assistants | ~50% | Admin/teacher partial; student/parent stubs |
| Module intelligence + chat merge | ~35% | Separate mock panels vs `/copilot` |
| Live inference | ~25% | Edge stub; mocks default |

**Weighted copilot vision completion: ~48%**

---

## Related documents

| Document | Role |
|----------|------|
| `docs/AI_INTELLIGENCE_AUDIT.md` | Cross-domain intelligence audit |
| `docs/QA/intel_02_completion_report.md` | INTEL-02 delivery report |
| `docs/QA/vision_completion_progress.md` | Program tracker |
| `docs/AKSHARA_FINAL_ROADMAP.md` | P1–P3 sequencing |
| `docs/DesignSystem.md` §17 | Target AI UI spec |
