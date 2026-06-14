# AI Copilot Status

**Version:** 1.0  
**Date:** June 2026  
**Program:** INTEL-02 Track B — Copilot verification  
**Classification:** **A** Fully Implemented · **B** Partial · **C** Mock Only · **D** Not Implemented

---

## Executive summary

| Metric | Value |
|--------|-------|
| **Overall copilot completion** | **~48%** functional · **~62%** UI/surface |
| **Live AI inference** | Server edge only (OpenAI stub); client default = mock |
| **Production-ready chat** | ERP admin copilot only (hybrid mock/API) |
| **Persona coverage** | 1 of 6 personas has real chat UI (admin/owner ERP) |

Akshara has a **solid ERP copilot foundation** (screen, repository, RBAC, contract tests, Supabase orchestration) but **no universal assistant**. Mobile personas route to stubs or non-chat surfaces. Context-aware prompting exists **server-side only** — the Flutter client never passes screen/module context.

---

## Capability matrix

Legend: ✅ Yes · ⚠️ Partial · ❌ No · — N/A

| Surface | Class | UI | Navigation | Service | Prompt routing | Context | RBAC | Tests |
|---------|-------|-----|------------|---------|----------------|---------|------|-------|
| Floating AI bubble (FAB) | **D** | ❌ | ❌ | ❌ | ❌ | ❌ | — | ❌ |
| ERP AI Copilot screen (`/copilot`) | **B** | ✅ | ✅ Admin app bar | ✅ Mock + API hybrid | ✅ Assistant picker | ⚠️ Server only | ✅ `viewAiCopilot` / `runAiCopilot` | ✅ Contract + integration + RBAC |
| Context-aware assistant | **C** | ⚠️ Same screen | ✅ | ✅ `copilot_context_engine.ts` | ✅ Orchestrator | ⚠️ Not wired from client | ✅ Permission-scoped bundles | ✅ Server tests |
| Student assistant | **C** | ⚠️ App-bar icon only | ⚠️ → homework stub | ❌ No student chat repo | ❌ | ❌ | Student persona | ⚠️ Mobile nav pilot |
| Teacher assistant | **B** | ✅ Insights screen | ✅ App bar → `/teacher-assistant` | ✅ Evolution repo + edge | ⚠️ Insights not chat | ❌ | ✅ `viewTeacherAssistant` | ✅ Contract + integration |
| Parent assistant | **C** | ⚠️ Experience hub only | ⚠️ `ai_copilot` → hub | ⚠️ Guidance mock in intelligence lab | ❌ | ❌ | Parent persona | ⚠️ Partial |
| Admin assistant | **B** | ✅ Copilot screen | ✅ Admin scaffold | ✅ Copilot repository | ✅ 5 assistant types | ⚠️ Server bundles | ✅ Full RBAC | ✅ Full suite |
| Owner assistant | **B** | ✅ Same as admin copilot | ✅ Management + admin routes | ✅ Copilot + management intel | ⚠️ Module copilots mock | ⚠️ KPI/insight drills now wired | ✅ Super-admin / mgmt perms | ✅ Management + copilot tests |

---

## Per-surface detail

### 1. Floating AI chat bubble — **D**

| Check | Status |
|-------|--------|
| UI | Not implemented (DesignSystem §17 specifies dock/FAB; no widget) |
| Navigation | — |
| Service | — |
| Prompt routing | — |
| Context awareness | — |
| RBAC | — |
| Tests | — |

**Effort:** 3–5 d (shared `ChatPanel` dock + route-aware entry)  
**Business value:** High — matches FutureVision #29 universal entry point  
**Gap:** No global entry; users must know module-specific paths

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
