# Akshara ERP — Orchestrator Agent

**Version:** 1.2  
**Last updated:** 2026-06-17  
**Branch:** `feature/m15-theme` — Governance Foundation complete  
**Purpose:** Single source of truth for program execution order, agent ownership, gates, and stop rules.  
**Authority:** Supersedes ad-hoc session prompts. Every orchestrator session **must read this file first**, then the linked milestone docs.

**Companion docs (read order):**

1. `docs/ORCHESTRATOR_AGENT.md` ← **this file**
2. `docs/OPERATIONAL_GAP_MASTER_TRACKER.md` — 94-gap backlog
3. `docs/OPERATIONAL_REMEDIATION_ROADMAP.md` — phase sequencing
4. `docs/PHASE_D_EXECUTION_PLAN.md` — active governance track
5. [`GOVERNANCE_COMPLETION_REPORT.md`](./GOVERNANCE_COMPLETION_REPORT.md) — Phase D complete; parallel plan
6. Latest certification report (`PHASE_D_M7_FINAL_CERTIFICATION.md`)
7. `AGENTS.md` — Cursor agent A–G ownership
8. `docs/CURSOR_WORKFLOW.md` — session lifecycle
9. `docs/MULTI_AGENT_EXECUTION_PLAN.md` — parallel workstreams + future architecture constraints

---

## CORE PRODUCT ARCHITECTURE PRINCIPLE

**Permanent rule — does not change execution order or current milestone scope.**

Akshara ERP will evolve toward:

```
USER → ROLE → WORKSPACE → TASK
```

and **not**:

```
USER → MODULE → 100 MENUS
```

### Target model (examples)

| Persona | Workspaces (not module menus) |
|---------|-------------------------------|
| **Teacher** | Teacher Workspace · Class Teacher Workspace · Exam Coordinator Workspace · Inventory Workspace |
| **Principal** | Principal Workspace · Academic Workspace · Finance Workspace · Marketing Workspace |
| **Inventory Manager** | Inventory Workspace · Procurement Workspace |

### Purpose

| Goal | Outcome |
|------|---------|
| Reduce menu clutter | Fewer top-level nav items per persona |
| Improve mobile UX | Task-first shells on phone/tablet |
| Simplify testing | Scope tests per workspace, not per module tree |
| Simplify permissions | `ROLE + WORKSPACE` gates tasks; avoid module-wide `manage*` sprawl |
| Improve AI assistant context | Copilot receives workspace + task context, not full ERP module map |
| Role-focused dashboards | Dashboards answer “what must I do in this hat?” not “open Finance module” |

### Dynamic Role Assignment Engine

Akshara ERP must support **dynamic role assignment** — roles are not fixed at build time per user persona.

**Example — roles assignable to one Teacher:**

| Assigned role | Unlocks (when active) |
|---------------|----------------------|
| Teacher | Teacher Workspace, core teaching tasks |
| Class Teacher | Class Teacher Workspace, class-scoped tasks |
| Inventory Manager | Inventory Workspace, stock/procurement tasks |
| Exam Coordinator | Exam Coordinator Workspace, exam admin tasks |

**Who assigns roles:** Authorized users — Principal, HR, Management (tenant-scoped; audited).

**When a role is added or removed, the following must update automatically — without app release or code change:**

| # | Surface | Expected behavior |
|---|---------|-------------------|
| 1 | **Permissions** | RBAC sync from assigned roles; route guards and mutations reflect current role set |
| 2 | **Workspace visibility** | Workspaces appear/disappear based on active roles |
| 3 | **Dashboard content** | Widgets and KPIs scoped to assigned roles |
| 4 | **Navigation** | Shell nav generated from role → workspace map, not static module tree |
| 5 | **AI Copilot context** | Copilot receives current roles, workspaces, and tasks — not a hardcoded persona profile |

**Architecture model (target):**

```
User
  → Assigned Roles
    → Permissions
      → Workspaces
        → Tasks
          → Dashboards
```

**Anti-pattern (forbidden long-term):**

```
User → Fixed Dashboard → Hardcoded Menus
```

#### Implementation guidance

| Rule | Detail |
|------|--------|
| **No hardcoded role dashboards** | Future modules must not ship persona-specific dashboard layouts baked into code per role name |
| **Role-driven workspace generation** | Workspaces, nav entries, and dashboard slots are **derived** from the user’s current role assignment set |
| **Runtime assignment** | Role add/remove is a **data/configuration operation** (Principal/HR UI + backend sync), not a deploy |

**Example scenario:**

Principal assigns **Inventory Manager** role to a Science Teacher.

The teacher **immediately** gains (no app update):

- Inventory Workspace
- Inventory Tasks
- Inventory Notifications
- Inventory Approvals (where role permits)

Removing the role revokes the same surfaces automatically.

#### Future systems — must design around Dynamic Roles

The following systems **must** be built so role assignment drives visibility and capability — not static persona shells:

| System | Dynamic-role dependency |
|--------|-------------------------|
| Student 360 | Dossier entry and tab visibility per assigned roles |
| Teacher Workspace | Shell aggregates roles assigned to that user |
| Principal Workspace | Exec roles may combine Principal + Academic + Finance hats |
| Approval Center | Inbox filters and actions per role-derived permissions |
| Marketing Platform | Marketing Workspace only when Marketing role assigned |
| Inventory | Inventory / Procurement workspaces gated by role |
| Finance | Finance Workspace gated by finance-related roles |
| Transport | Transport Workspace gated by transport roles |
| HR | Staff role assignment is source of truth for ERP roles |
| AI Copilot | Context = assigned roles + active workspace + current task |

**Current program note:** M-D4–M-D7 and Phases A–E ship on existing RBAC patterns; new work must remain **forward-compatible** with dynamic assignment (additive permissions, workspace-groupable approvals, no fixed teacher/principal dashboard forks).

### Design constraint for all new work

Whenever **new screens, dashboards, approvals, Student 360, Marketing, Finance, Inventory, or Teacher workflows** are built — including work **currently in progress** — implement against **today’s milestone deliverables**, but **design with future Role Workspace architecture in mind**:

- Group tasks by **workspace intent**, not by ERP module folder alone.
- Prefer **workspace-scoped routes and permissions** over adding another module root menu.
- Keep **approval types and inbox filters** workspace-aware (e.g. Academic vs Finance queue), not siloed per module screen.
- **Student 360** remains a **task surface inside workspaces** (SIS, teacher, principal), not a fourth navigation paradigm.
- **Do not block** current governance adapters (M-D4–M-D7) or phase delivery for a full workspace shell — **forward-compatible structure only**.

### Affected future milestones (architecture tag — execution order unchanged)

| Milestone / phase | Workspace lens | Tag |
|-------------------|----------------|-----|
| **M-D4** (active) | Leave/attendance approvals → Principal Workspace + Class Teacher Workspace tasks | `WORKSPACE-AWARE` |
| **M-D5** | Fee concession/refund approvals → Finance Workspace | `WORKSPACE-AWARE` |
| **M-D6** | PO maker-checker → Procurement Workspace | `WORKSPACE-AWARE` |
| **M-D7** | Notifications/audit → workspace-scoped requester context | `WORKSPACE-AWARE` |
| **Phase A** | Exam admin, marks, publish → Exam Coordinator + Teacher Workspaces | `WORKSPACE-TARGET` |
| **Phase B** | Attendance correction → Class Teacher Workspace | `WORKSPACE-TARGET` |
| **Phase C** | Student 360 → dossier task inside Principal / Class Teacher / SIS workspaces | `WORKSPACE-TARGET` |
| **Phase E** | Concessions, refunds, exports → Finance Workspace | `WORKSPACE-TARGET` |
| **Phase F** | Catalog, stock, PO → Inventory + Procurement Workspaces | `WORKSPACE-TARGET` |
| **Phase G** | Fleet, routes → Transport Workspace (ops persona) | `WORKSPACE-TARGET` |
| **Phase H** | MK-01–MK-10 → Marketing Workspace | `WORKSPACE-TARGET` |
| **Phase I** | Reports → workspace-scoped export entry points | `WORKSPACE-TARGET` |
| **Teacher mobile** | Homework, attendance, exams, leave → Teacher / Class Teacher Workspaces | `WORKSPACE-TARGET` |
| **Principal / Management** | Approval Center, notices, 360 drill-down → Principal Workspace | `WORKSPACE-TARGET` |

**Execution order remains:** M-D4 → M-D5 → M-D6 → M-D7 → Phase A → Phase B → Phase C → Phase E (Phases F/G/H/I per pilot scope). This principle informs **how** features are shaped, not **when** they ship.

---

## 1. Current project status

| Dimension | State |
|-----------|--------|
| **Program phase** | Governance Foundation (Phase D) — **✅ COMPLETE** |
| **Visual / theme** | M15 + M15.5 UI complete (not operational scope) |
| **Operational audit** | Complete — 94 gaps tracked |
| **Backend API** | Stub/mock-first; production APIs lag domain work |
| **Pilot viable** | **No** — requires Phases A + B + C + D + E minimum |
| **Parallel domain work** | **Unlocked** — Phase A / B / C / E ready for parallel execution (not auto-started) |
| **Last push** | Governance Foundation M-D4–M-D7 (pending push) |

### What is working today (operational)

| Capability | Status | Notes |
|------------|--------|-------|
| Unified approval repository + service | ✅ M-D1 | `ApprovalCenterService`, mock + API stub |
| Principal Approval Center UI | ✅ M-D2 | Queue, filters, approve/reject, audit, RBAC |
| Exam results approval adapter | ✅ M-D3 | Submit → approve → publish; feature flag |
| Student / staff leave approval adapters | ✅ M-D4 | Parent + HR submit → inbox → status sync |
| Attendance correction adapter | ✅ M-D4 stub | Phase B plugs UI |
| Finance approval adapters | ✅ M-D5 | Fee structure, concession, refund |
| Inventory PO maker-checker | ✅ M-D6 | Storekeeper create; principal approve |
| Approval notifications + stale insight | ✅ M-D7 | In-app stub + workflow banner |
| Teacher attendance submit (mock) | ✅ Built | No correction / approval gate UI (Phase B) |
| Parent attendance calendar (mock) | ✅ Built | Disputes → WhatsApp only |
| Admissions approval | ✅ Built | Siloed — pattern reference only |

### What is explicitly NOT started

| Track | Status |
|-------|--------|
| Phase A (Exams & Academic Governance) | ⛔ Unlocked — **not started** |
| Phase B (Attendance Governance UI) | ⛔ Unlocked — **not started** |
| Phase C (Student 360) | ⛔ Unlocked — **not started** |
| Phase E (Finance operations UI) | ⛔ Unlocked — **not started** |
| Phase F/G/H/I (Inventory ops, Transport, Marketing) | ⛔ Locked / partial |
| Multi-agent parallel execution | ⛔ Prepared — see [`GOVERNANCE_COMPLETION_REPORT.md`](./GOVERNANCE_COMPLETION_REPORT.md) |

---

## 2. Current readiness %

Readiness figures come from `OPERATIONAL_REMEDIATION_ROADMAP.md` baseline, adjusted for certified governance progress.

| Metric | Baseline (pre-Phase D) | **Current (2026-06-17)** | Pilot target (A–E + D) |
|--------|------------------------|--------------------------|-------------------------|
| **Overall operational** | 42% | **~52%** | ~68% |
| **Management / Principal** | 50% | **~75%** | 75% |
| **Cross-module governance** | 30% | **~70%** | 70% |
| **Academics & Exams** | 25% | **~32%** | 65% |
| **Attendance** | 40% | **~48%** | 70% |
| **Governance Foundation (Phase D)** | 0% | **100%** (7/7 milestones) | 100% |

**How current overall (~52%) is derived:**

- Baseline **42%** for most modules (P0 gaps in Phases A–E still open).
- **+6%** Unified approval inbox with 8 adapter types (exam, leave×2, attendance stub, finance×3, inventory PO).
- **+4%** Principal RBAC matrix, maker-checker, notification/audit stubs (M-D4–M-D7).

**Test gate (Governance complete):** `flutter analyze` 0 errors · `flutter test` **1904 passed**, 1 skipped.

---

## 3. Completed milestones

| Milestone | Name | Commit / cert | Verdict |
|-----------|------|---------------|---------|
| **M15** | Theme modernization | Prior releases | ✅ Complete |
| **M15.5** | UI polish / glass system | Prior releases | ✅ Complete |
| **M-D1** | Approval domain + repository + service | Certified | ✅ [`PHASE_D_M1_FINAL_CERTIFICATION.md`](./PHASE_D_M1_FINAL_CERTIFICATION.md) |
| **M-D2** | Principal Approval Center UI | Certified | ✅ [`PHASE_D_M2_FINAL_CERTIFICATION.md`](./PHASE_D_M2_FINAL_CERTIFICATION.md) |
| **M-D3** | Exam Results Approval Adapter | `44ba25b` | ✅ [`PHASE_D_M3_FINAL_CERTIFICATION.md`](./PHASE_D_M3_FINAL_CERTIFICATION.md) |
| **M-D4** | Leave & Attendance Approval Adapters | This release | ✅ [`PHASE_D_M4_FINAL_CERTIFICATION.md`](./PHASE_D_M4_FINAL_CERTIFICATION.md) |
| **M-D5** | Finance Approval Adapters | This release | ✅ [`PHASE_D_M5_FINAL_CERTIFICATION.md`](./PHASE_D_M5_FINAL_CERTIFICATION.md) |
| **M-D6** | Inventory PO Maker-Checker | This release | ✅ [`PHASE_D_M6_FINAL_CERTIFICATION.md`](./PHASE_D_M6_FINAL_CERTIFICATION.md) |
| **M-D7** | Notifications & Audit Hardening | This release | ✅ [`PHASE_D_M7_FINAL_CERTIFICATION.md`](./PHASE_D_M7_FINAL_CERTIFICATION.md) |

**Governance Foundation completion report:** [`GOVERNANCE_COMPLETION_REPORT.md`](./GOVERNANCE_COMPLETION_REPORT.md)

### M-D3 gaps partially closed

| Gap | Closure |
|-----|---------|
| APR-002 | Exam publish approval chain (mock) |
| P0-EXAM-003 | Governance half — direct publish blocked when `EXAM_APPROVAL_REQUIRED=true` |
| P1-EXAM-006 | Exam permissions (`manageExamMarks`, `submitExamResults`, `approveExamResults`, `publishExamResults`) |
| P1-PRIN-001 | Unified inbox (partial — exam type has side effects) |
| DISC-007 | Partial — exam path unified; leave/attendance/finance still siloed |

---

## 4. Active milestone

| Field | Value |
|-------|-------|
| **Milestone** | **None — Governance Foundation complete** |
| **Phase** | Phase D — **✅ COMPLETE** |
| **Status** | **Awaiting Program Director authorization for parallel Phase A/B/C/E** |
| **Next authorized step** | Review [`GOVERNANCE_COMPLETION_REPORT.md`](./GOVERNANCE_COMPLETION_REPORT.md) §4 parallel plan |
| **Do not auto-start** | Academics, Student360, Finance Phase E, multi-agent execution |

### Previously active: M-D4 (now complete)

See [`M-D4_ANALYSIS.md`](./M-D4_ANALYSIS.md) · [`M-D4_EXECUTION_PLAN.md`](./M-D4_EXECUTION_PLAN.md) for historical scope.

---

## 5. Governance roadmap (Phase D)

Phase D must reach **M-D7 certified** before parallel domain phases unlock.

```mermaid
flowchart LR
  D1[M-D1 Infrastructure ✅]
  D2[M-D2 Principal UI ✅]
  D3[M-D3 Exam Adapter ✅]
  D4[M-D4 Leave/Attendance ⏳ Analysis]
  D5[M-D5 Finance Adapters]
  D6[M-D6 Inventory PO]
  D7[M-D7 Notifications/Audit]
  UNLOCK[Unlock Phase A/B/E parallel]

  D1 --> D2 --> D3 --> D4 --> D5 --> D6 --> D7 --> UNLOCK
```

| Milestone | Week (plan) | Gaps / APR | Status |
|-----------|-------------|------------|--------|
| **M-D1** | 1 | P1-PRIN-001, DISC-007 | ✅ Certified |
| **M-D2** | 1–2 | P1-PRIN-001, WF-011, WF-014 | ✅ Certified |
| **M-D3** | 2–3 | APR-002, P0-EXAM-003 (partial) | ✅ Certified @ `44ba25b` |
| **M-D4** | 3 | APR-003, APR-004, APR-005, P1-PRIN-002/003 | 📋 Analysis only |
| **M-D5** | 3–4 | APR-006, APR-012, P0-FIN-001 (half), RBAC-009 | ⛔ Not started |
| **M-D6** | 4 | P0-INV-003, P0-INV-004, APR-008, RBAC-006/007 | ⛔ Not started |
| **M-D7** | 4–5 | Audit hardening, requester notifications, APR-014 stub | ⛔ Not started |

**After Phase D complete:** Management 75% · Cross-module governance 70% · enables quality closure of P0 workflows in A, B, E, F.

### Post-governance domain roadmap (locked until M-D7)

| Phase | Name | P0 blockers | Unlock after |
|-------|------|-------------|--------------|
| **A** | Exams & Academic Governance | 4 | M-D7 ✅ (+ M-D3 exam adapter) |
| **B** | Attendance Governance | 2 | M-D7 ✅ (+ M-D4 attendance adapter stub) |
| **C** | Student 360 Unification | 2 | Phase A marks data (partial nav wire earlier) |
| **E** | Finance Completion | 3 | M-D7 ✅ (+ M-D5 finance adapters) |
| **F** | Inventory | 4 | M-D6 ✅ · optional for pilot |
| **G** | Transport | 2 | Optional for pilot |
| **H** | Marketing | 1 | **Deferred** — not on pilot path |
| **I** | Reports & Compliance | 0 | Phase E exports stable |

Full sequencing: `OPERATIONAL_REMEDIATION_ROADMAP.md` §Execution order.

---

## 6. Agent ownership

Two layers apply: **Cursor agents (A–G)** from `AGENTS.md` and **workstream agents** from `MULTI_AGENT_EXECUTION_PLAN.md`. The orchestrator assigns by milestone type.

### 6.1 Cursor agents (A–G) — file ownership

| Agent | Role | Primary paths |
|-------|------|---------------|
| **A** | Backend / API | `lib/core/repositories/`, `test/contracts/`, `test/integration/` |
| **B** | ERP features | `lib/features/{admissions,finance,sis,management,...}/`, ERP routes |
| **C** | Mobile | `lib/features/{parent,teacher,student}/`, mobile routes, `test/golden/` |
| **D** | Security | `lib/core/auth/`, `lib/core/security/`, route guards, security tests |
| **E** | QA | `test/` (all), test scripts |
| **F** | Documentation | `docs/`, `AGENTS.md`, `README.md` |
| **G** | Release | `pubspec.yaml` version, gates, tags, governance docs |

### 6.2 Workstream agents — program phases

| Workstream | Agent | Phases | Owns |
|------------|-------|--------|------|
| **WS1 Governance** | Governance Agent | D (M-D3–M-D7) | `lib/core/approvals/`, adapters, `management/approval/`, additive RBAC |
| **WS2 Academics** | Academic Agent | A | Exam admin, teacher exams, subject catalog |
| **WS3 Student Ops** | Student Operations Agent | B, C | Attendance correction UI, Student 360 nav |
| **WS4 Finance** | Finance Agent | E | Finance features, exports |
| **WS5 Operations** | Operations Agent | F, G | Inventory, transport, hostel |
| **WS6 Growth** | Growth Agent | H | Marketing — **deferred** |
| **WS7 Compliance** | Compliance Agent | I | Report exports — late track |

### 6.3 Milestone → agent assignment (Governance track)

| Milestone | Primary | Supporting |
|-----------|---------|------------|
| M-D1 – M-D2 | Governance (B + D) | E, F, G |
| M-D3 – M-D7 adapters | Governance (A pattern for adapters) | D (permissions), E (tests), F (docs), G (gate) |
| M-D4 | Governance | C (parent/teacher wire), D (RBAC), E |
| Phase A (when unlocked) | Academic Agent | Governance (approve hooks only), E |
| Phase B (when unlocked) | Student Ops Agent | Governance (attendance adapter consume), E |

### 6.4 Shared artifacts — merge owner

| Artifact | Owner | Rule |
|----------|-------|------|
| `permissions.dart`, `role_permissions.dart` | Agent **D** / Governance | Additive only; domain agents propose, Governance merges |
| `mutation_permission_registry.dart` | Governance | Batch weekly |
| `approval_permissions.dart`, adapters | Governance | Sole writer during Phase D |
| `repository_providers.dart` | First registrant + Governance review | One provider block per PR |
| `route_guards.dart`, `app_router.dart` | Governance + domain | Domain PR; Governance resolves conflicts |
| `ApprovalCenterService.submit()` | Governance | Modules call service — never duplicate queue logic |

---

## 7. Dependency rules

### 7.1 Hard dependencies (must not violate)

```
M-D1 → M-D2 → M-D3 → M-D4 → M-D5 → M-D6 → M-D7
                              ↓
                    Governance Foundation COMPLETE
                              ↓
         ┌────────────────────┼────────────────────┐
         ↓                    ↓                    ↓
     Phase A              Phase B              Phase E
   (needs M-D3)         (needs M-D4 stub)    (needs M-D5)
```

| Rule ID | Rule |
|---------|------|
| **DEP-01** | No Phase A implementation until **M-D7 certified** (Governance Foundation complete). |
| **DEP-02** | No Phase B attendance correction UI until **M-D4 adapter contract** exists. |
| **DEP-03** | No finance concession/refund approval UX until **M-D5** adapters exist. |
| **DEP-04** | No PO maker-checker until **M-D6** complete. |
| **DEP-05** | Domain agents **submit** approvals via `ApprovalCenterService`; they do **not** implement parallel queue logic. |
| **DEP-06** | Approve/reject **side effects** live in adapters (`ApprovalAdapterRegistry`), not in module silos. |
| **DEP-07** | Phase C Student 360 needs Phase A marks data for full dossier; nav wire-only may precede with governance approval. |
| **DEP-08** | Marketing (Phase H), Inventory (F), Transport (G) are **optional** for day-school pilot — do not block governance. |

### 7.2 Soft dependencies (coordinate, do not block M-D4)

| Consumer | Provider | Handshake |
|----------|----------|-----------|
| Phase A M-A5 | M-D3 | Exam submit payload + approve hook — **done** |
| Phase B | M-D4 | Attendance correction payload schema — **defined in M-D4 analysis §5.3** |
| Phase E | M-D5 | Fee concession / refund approval types |

### 7.3 Foundation systems status

| ID | System | Status |
|----|--------|--------|
| F-01 | ApprovalCenterService | ✅ M-D1 |
| F-02 | Principal Approval Center UI | ✅ M-D2 |
| F-03 | Module approval adapters | 🟡 1/5+ (exam only) |
| F-04 | ExamAdministrationRepository | ⛔ Phase A |
| F-05 | Academic master catalog | ⛔ Phase A |
| F-06 | Attendance correction entity | ⛔ Phase B |
| F-07 | Student 360 navigation | ⛔ Phase C |
| F-08 | Report export service | ⛔ Phase E |
| F-09 | RBAC registry completeness | 🟡 Partial (exam + M-D3) |

---

## 8. Unlock conditions

Parallel development and downstream phases unlock only when conditions below are met.

| Unlock | Condition | Verification |
|--------|-----------|--------------|
| **M-D4 implementation** | Program Director approves `M-D4_ANALYSIS.md` + `M-D4_EXECUTION_PLAN.md` | Explicit authorization in session prompt |
| **M-D5 start** | M-D4 certified + pushed | `PHASE_D_M4_FINAL_CERTIFICATION.md` |
| **M-D6 start** | M-D5 certified + pushed | M-D5 cert doc |
| **M-D7 start** | M-D6 certified + pushed | M-D6 cert doc |
| **Phase A parallel** | **M-D7 certified** (Governance Foundation complete) | Phase D gate checklist 100% |
| **Phase B parallel** | M-D7 + M-D4 attendance adapter registered | Integration test green |
| **Phase E parallel** | M-D7 + M-D5 finance adapters | Integration test green |
| **Phase C wire-only** | Orchestrator explicit approval | SIS→360 nav without full Phase A |
| **Multi-agent parallel (5 agents)** | M-D7 + orchestrator session with manifest | `MULTI_AGENT_EXECUTION_PLAN.md` §4 |
| **Pilot school go-live** | Phases A + B + C + D + E complete; ~68% readiness | `PilotSchoolChecklist.md` |

**Currently unlocked:** M-D4 implementation (pending authorization only).  
**Currently locked:** Everything else listed above.

---

## 9. Certification requirements

Every governance milestone (M-D*) follows the same certification pattern established in M-D1–M-D3.

### 9.1 Pre-certification gates (mandatory)

| # | Gate | Command / evidence |
|---|------|-------------------|
| 1 | Static analysis | `flutter analyze` → **0 errors** |
| 2 | Full test suite | `flutter test` → **all pass** (note skip count) |
| 3 | Milestone test gate | Per execution plan (e.g. M-D3: 64 approval tests) |
| 4 | Regression | Prior milestone gate still green |
| 5 | Scope audit | No files outside milestone ownership |
| 6 | RBAC | Permission mapping tests updated |

### 9.2 Deliverables per milestone

| Deliverable | Path pattern |
|-------------|--------------|
| Analysis (before impl) | `docs/M-D{N}_ANALYSIS.md` |
| Execution plan | `docs/M-D{N}_EXECUTION_PLAN.md` or section in `PHASE_D_EXECUTION_PLAN.md` |
| Final certification | `docs/PHASE_D_M{N}_FINAL_CERTIFICATION.md` |
| Push report | `docs/M-D{N}_PUSH_REPORT.md` |
| Patrol stub | `qa/journeys/workflow_*_approval.yaml` |

### 9.3 Certification verdict criteria (M-D4 example)

- [ ] Parent submit creates `studentLeave` pending item
- [ ] HR create creates `staffLeave` pending item
- [ ] Principal approve/reject updates domain records (leave status / mock attendance)
- [ ] `attendanceCorrection` adapter registered with mock side effects
- [ ] Dedicated permissions replace coarse `manageManagement` for wired types
- [ ] M-D2/M-D3 approval gate ≥64 tests pass
- [ ] `flutter analyze` 0 errors · full suite green

### 9.4 Who certifies

| Role | Responsibility |
|------|----------------|
| **Agent E** | Test evidence, gate commands |
| **Agent G** | Final gate run, version coordination |
| **Agent F** | Certification + push report documents |
| **Orchestrator** | Verdict: PASS / FAIL / BLOCKED |

Human QA is **not required** when automated certification checklist is fully green (M-D2/M-D3 precedent).

---

## 10. Commit requirements

### 10.1 When to commit

- Commit **only when explicitly requested** by Program Director or at milestone certification handoff (M-D* push step).
- Never commit analysis-only docs unless the session goal includes doc delivery + explicit commit instruction.

### 10.2 Pre-commit checklist

1. `flutter analyze` — 0 errors  
2. `flutter test` — all pass  
3. Milestone gate — pass  
4. No secrets (`.env`, credentials)  
5. No `test/golden/failures/*` artifacts  
6. Stage only milestone-scoped files  

### 10.3 Commit message format

```
Phase D M{N} — {Short milestone name}

{Why: 1–2 sentences on governance/workflow outcome.}
```

Example: `Phase D M-D3 — Exam Results Approval Adapter`

### 10.4 Push protocol

1. Commit milestone on `feature/m15-theme` (or assigned release branch)  
2. `git push -u origin HEAD`  
3. Create `docs/M-D{N}_PUSH_REPORT.md` with commit hash, push result, test summary  
4. Report to Program Director — **STOP** unless next milestone authorized  

### 10.5 Prohibited git operations

- No force-push to `main` / `master`  
- No `--no-verify` unless explicitly requested  
- No amend of pushed commits unless user explicitly requests  
- Never update git config  

---

## 11. Stop conditions

Orchestrator and sub-agents **stop immediately** when any condition applies.

| ID | Condition | Action |
|----|-----------|--------|
| **STOP-01** | Milestone certification complete and push report delivered | STOP — await next authorization |
| **STOP-02** | Analysis-only session scope (e.g. M-D4 analysis) | STOP after docs — **no code, no commit** |
| **STOP-03** | Unauthorized scope detected (Phase A, Marketing, Inventory, Student360, multi-agent) | STOP — report scope violation |
| **STOP-04** | `flutter analyze` or `flutter test` fails after fix attempt | STOP — BLOCKED report to Agent G |
| **STOP-05** | P0 blocker — backend/API unavailable for required cert | STOP — mark BLOCKED |
| **STOP-06** | Human decision required — security regression, tenant breach, data loss, ambiguous spec | STOP — escalate |
| **STOP-07** | Cross-agent file conflict on shared infrastructure | STOP — sequential merge required |
| **STOP-08** | Execution depth reached (default 3 milestones per `CURSOR_WORKFLOW.md`) | STOP — combined summary |

### Default session scope guardrails

**Do NOT start unless explicitly authorized:**

- Phase A · Phase B · Phase C · Phase E · Phase F · Phase G · Phase H  
- Multi-agent parallel execution  
- Marketing · Inventory · Student360 · Attendance implementation (Phase B UI)  

**Authorized now (Governance Foundation only):**

- M-D4 implementation (after approval)  
- M-D4 analysis ✅ complete  
- Documentation for orchestrator / governance  

---

## 12. Parallel execution rules

Parallel work is **disabled** until Governance Foundation (M-D7) is certified.

### 12.1 Current mode: **SERIAL GOVERNANCE**

```
Orchestrator → M-D4 → certify → push → M-D5 → … → M-D7 → unlock parallel
```

Only one governance milestone in flight. No domain phase coding.

### 12.2 Future mode: **CONTROLLED PARALLEL** (after M-D7)

From `MULTI_AGENT_EXECUTION_PLAN.md`:

| Rule | Detail |
|------|--------|
| **Max parallel agents** | 4–5 workstreams |
| **File lock** | No overlapping writes — use manifest paths |
| **Shared infra** | Governance Agent merge gate on `permissions.dart`, routers, adapters |
| **Validation order** | `flutter analyze` → unit tests → milestone gate → (Patrol if required) → commit |
| **Patrol** | Full regression only on Agent G gate or program end — not per sub-task |
| **Coordinator** | Parent orchestrator runs loop; subagents edit manifest-listed files only |
| **Handoff** | `complete --summary` for cross-agent waits |

### 12.3 Parallel allowed combinations (post M-D7)

| Track 1 | Track 2 | Track 3 | Notes |
|---------|---------|---------|-------|
| Phase A (Academic) | Phase B (Attendance) | — | After M-D4 stub |
| Phase A | Phase E (Finance) | — | After M-D5 |
| Phase C (360 wire) | Phase A | — | Nav-only subset |

**Never parallelize:** Two agents editing same adapter file · Governance + domain both changing `approval_permissions.dart` without merge gate.

### 12.4 Emulator / Patrol policy

Per `.cursor/rules/emulator-validation-workflow.mdc`:

1. Reuse existing emulator when available  
2. Unit/widget tests **before** Patrol  
3. Emulator boot non-blocking  
4. Broader Patrol only on infra changes or release gate  

---

## 13. Orchestrator session playbook

### Start of session

```
1. Read docs/ORCHESTRATOR_AGENT.md          (this file)
2. Confirm active milestone + authorization
3. Read active M-D{N}_ANALYSIS + EXECUTION_PLAN
4. Read latest PHASE_D_M{N-1}_FINAL_CERTIFICATION
5. Assign agents per §6
6. Execute ONLY authorized scope
7. Run gates per §9
8. Certify → push report → STOP per §11
```

### Milestone execution depth

Default: **1 governance milestone per session** unless Program Director specifies multi-milestone governance sprint. Domain phases use 3-milestone depth only **after** M-D7 unlock.

### Reporting template

Each session ends with:

- Milestone status (complete / analysis only / blocked)  
- Readiness delta (if measurable)  
- Commit hash (if pushed)  
- Test counts  
- Next authorized step  
- Explicit STOP confirmation  

---

## 14. Quick reference — approval adapter registry

| Type | Adapter | Status |
|------|---------|--------|
| `examResults` | `ExamResultsApprovalAdapter` | ✅ M-D3 |
| `studentLeave` | `StudentLeaveApprovalAdapter` | ⛔ M-D4 |
| `staffLeave` | `StaffLeaveApprovalAdapter` | ⛔ M-D4 |
| `attendanceCorrection` | `AttendanceCorrectionApprovalAdapter` | ⛔ M-D4 stub |
| `feeConcession` / `refund` / `feeStructure` | Finance adapters | ⛔ M-D5 |
| `inventoryPo` | PO adapter | ⛔ M-D6 |

---

## 15. Document maintenance

| Event | Update |
|-------|--------|
| Milestone certified + pushed | §3 Completed, §4 Active, §2 Readiness, §14 registry |
| New analysis authorized | §4 Active milestone docs |
| M-D7 complete | §8 unlock Phase A/B/E; §12 enable parallel |
| Gap tracker version bump | §2 readiness baseline footnote |

**Maintainer:** Orchestrator Agent (Agent F + G on certification)  
**Next review trigger:** M-D4 certification or Program Director re-baseline

---

## 16. Change log

| Version | Date | Notes |
|---------|------|-------|
| 1.2 | 2026-06-17 | Added Dynamic Role Assignment Engine under CORE PRODUCT ARCHITECTURE PRINCIPLE |
| 1.1 | 2026-06-17 | Added CORE PRODUCT ARCHITECTURE PRINCIPLE (USER→ROLE→WORKSPACE→TASK); milestone workspace tags |
| 1.0 | 2026-06-17 | Initial orchestrator SSOT — post M-D3 push @ `44ba25b`; M-D4 analysis complete |
