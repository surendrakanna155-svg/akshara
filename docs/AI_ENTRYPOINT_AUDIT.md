# AI Entry Point Audit — INTEL-04 Track D

**Date:** June 2026  
**Scope:** ERP · Parent App · Teacher App · Student App  
**Classification:** **Implemented** · **Partial** · **Missing**

---

## Summary

| App shell | Global dock | App-bar AI | Module copilots | Persona shell (`/ai-assistant`) | Full ERP copilot (`/copilot`) |
|-----------|-------------|------------|-----------------|----------------------------------|-------------------------------|
| ERP Admin | **Implemented** | **Implemented** | Partial | N/A (staff → `/copilot`) | **Implemented** |
| Parent | **Implemented** | **Partial** | — | **Implemented** | Missing (by design) |
| Teacher | **Implemented** | **Partial** | Partial (`/teacher-assistant`) | **Implemented** | Missing (by design) |
| Student | **Implemented** | **Partial** | — | **Implemented** | Missing (by design) |

---

## ERP Admin

| Entry point | Route / trigger | Class | Notes |
|-------------|-----------------|-------|-------|
| Floating copilot dock | All admin routes except `/copilot` | **Implemented** | `CopilotDockHost` on `AdminShell` |
| Admin app-bar AI button | `QaTestKeys.erpCopilotButton` | **Implemented** | `openCopilotWithCurrentContext()` |
| Management dashboard context scope | MG-01 KPI context | **Implemented** | INTEL-03 `CopilotContextScope` |
| Full copilot screen | `/copilot` | **Implemented** | RBAC `viewAiCopilot` |
| Finance / HR module copilots | Module routes | **Partial** | Mock insight screens, not unified dock routing |

---

## Parent App

| Entry point | Route / trigger | Class | Notes |
|-------------|-----------------|-------|-------|
| Floating copilot dock | All parent shell routes | **Implemented** | `CopilotDockHost` on `ParentShell` |
| Dashboard AI chip | `ai_copilot` action | **Implemented** | `openAiPersonaAssistant()` → `/ai-assistant` |
| Persona shell | `/ai-assistant` | **Implemented** | Focus areas + stub prompts (no prediction engine) |
| Experience hub legacy | `/parent/experience` | **Partial** | Still available; no longer default AI target |
| Full ERP copilot | — | **Missing** | Parent lacks `viewAiCopilot` |

---

## Teacher App

| Entry point | Route / trigger | Class | Notes |
|-------------|-----------------|-------|-------|
| Floating copilot dock | All teacher shell routes | **Implemented** | `CopilotDockHost` on `TeacherShell` |
| Dashboard AI | `ai_copilot` action | **Implemented** | Persona shell |
| Teacher Assistant module | `/teacher-assistant` | **Partial** | Insights repo; separate from persona shell |
| Persona shell | `/ai-assistant` | **Implemented** | Teacher focus areas + stub replies |
| Full ERP copilot | — | **Missing** | Teacher lacks `viewAiCopilot` |

---

## Student App

| Entry point | Route / trigger | Class | Notes |
|-------------|-----------------|-------|-------|
| Floating copilot dock | All student shell routes | **Implemented** | `CopilotDockHost` on `StudentShell` |
| Dashboard AI | `ai_assistant` / `ai_quiz` | **Implemented** | Persona shell (was homework stub) |
| Persona shell | `/ai-assistant` | **Implemented** | Study guidance focus areas |
| Full ERP copilot | — | **Missing** | Student lacks `viewAiCopilot` |

---

## Cross-cutting navigation helpers

| Helper | File | Behavior |
|--------|------|----------|
| `openCopilotWithCurrentContext` | `copilot_navigation.dart` | Staff → `/copilot` with pending context |
| `openAiAssistantFromDock` | `copilot_navigation.dart` | Staff → `/copilot`; mobile personas → `/ai-assistant` |
| `openAiPersonaAssistant` | `copilot_navigation.dart` | Mobile dashboards → `/ai-assistant` with context |

---

## Recommended follow-ups (post INTEL-04)

1. Wire finance/HR module copilot screens to shared dock open helper.
2. Add parent/teacher/student Patrol journeys for dashboard AI chip (dock covered in `copilot_dock_e2e_test.dart`).
3. Unify Teacher Assistant insights with persona shell prompt routing (INTEL-05+).

---

## Key files

- `lib/features/copilot/dock/` — floating dock
- `lib/features/copilot/persona/` — persona shells
- `lib/features/copilot/copilot_navigation.dart` — entry helpers
- `lib/router/app_router.dart` — `CopilotDockHost` on all shells
