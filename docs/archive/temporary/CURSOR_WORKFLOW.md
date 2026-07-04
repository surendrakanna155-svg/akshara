# Akshara ERP — Cursor Autonomous Workflow

**Version:** 1.1  
**Last updated:** June 2026  
**Purpose:** Step-by-step procedure for every Cursor Agent session. Follow this document at the start of every run — no ad-hoc prompts required.  
**Default execution depth:** 3 milestones per autonomous session (see §11).

---

## 1. Startup Procedure

Every agent session **must** begin with this sequence:

```
Step 1 → Read docs/Roadmap.md
         Identify current release + next unfinished milestone

Step 2 → Read AGENTS.md
         Determine which agent role(s) apply to the milestone

Step 3 → Read latest docs/Releases/v{X.Y}-*.md
         Understand what was last delivered

Step 4 → Read latest docs/ArchitectureReview/v{X.Y}-*.md
         Understand gaps, scores, and blockers

Step 5 → Read docs/TechnicalDebtRegister.md
         Check if milestone addresses open debt items

Step 6 → Determine next unfinished milestone
         If ambiguous, pick lowest-version open item from Roadmap Future Releases
```

**Do not write code until Steps 1–6 are complete.**

---

## 2. Agent Assignment

Automatically assign work based on milestone type:

| Milestone type | Primary agent | Supporting agents |
|----------------|---------------|-------------------|
| API read/write for ERP module | **A** | B, E, F |
| ERP screen wiring / mutations | **B** | A, D, E |
| Mobile repository migration | **C** | A, E |
| Auth / RBAC / audit / tenant | **D** | E, F |
| Test gap / coverage | **E** | — |
| Release docs / audits / roadmap | **F** | G |
| Release validation / tag | **G** | E, F |
| Security-only release | **D** | E, F, G |
| Full module MVP (UI + mock) | **B** | E, F |
| Full module API (end-to-end) | **A** + **B** | D, E, F |

### Multi-Agent Orchestration

For large releases (e.g., v2.6 SIS + Finance write):

1. **Lead architect** reads Roadmap + assigns scoped sub-agents
2. Spawn sub-agents **in parallel** only when file ownership does not overlap
3. After sub-agents complete → **integration agent** (Agent G) runs gates
4. Fix conflicts in orchestrator scope only
5. Never merge partial work with failing gates

---

## 3. Development Lifecycle

### Phase 1 — Planning (read-only)

**Duration:** 10–20% of session  
**Agent:** Lead architect or assigned primary agent

Outputs:
- [ ] Scope confirmation against Roadmap milestone
- [ ] File ownership list (no overlaps)
- [ ] Endpoint/method inventory (if API work)
- [ ] Risk list (from Technical Debt Register)
- [ ] Test plan (which test directories will be created/modified)

**Gate:** No code changes in this phase.

### Phase 2 — Architecture Validation

**Duration:** 5–10% of session  
**Agent:** Primary + review agent (D for security, E for tests)

Checklist:
- [ ] Reuses existing patterns (see AGENTS.md Global Rules #3)
- [ ] No duplicate services/providers/DTOs
- [ ] RBAC requirements identified
- [ ] Tenant headers considered for new API calls
- [ ] Audit events identified for mutations

**Gate:** Proceed only if architecture matches Project Charter principles.

### Phase 3 — Implementation

**Duration:** 50–60% of session  
**Agent:** Primary (scoped to ownership directories)

Rules:
- Minimal diff — focused changes only
- Match surrounding code conventions
- Extend existing abstractions
- Do not modify files outside ownership

### Phase 4 — Testing

**Duration:** 15–20% of session  
**Agent:** E (or primary agent for owned test dirs)

Required test types by change:

| Change | Required tests |
|--------|----------------|
| New repository method | Contract test |
| New API endpoint | Contract + integration |
| New mutation provider | Feature test + RBAC deny test |
| Auth/security change | Security test |
| New route | Route inventory test update |
| Bug fix | Regression test |

### Phase 5 — Documentation

**Duration:** 10–15% of session  
**Agent:** F

Required outputs:
```
docs/Releases/v{X.Y}-{Name}.md
docs/ArchitectureReview/v{X.Y}-{Area}-Audit.md  (≥1)
docs/Roadmap.md                                  (milestone status update)
docs/TechnicalDebtRegister.md                  (if debt resolved/added)
```

### Phase 6 — Release Review

**Duration:** 5–10% of session  
**Agent:** G

---

## 4. Mandatory Validation

Run before declaring any milestone complete:

```bash
flutter analyze    # MUST be 0 issues
flutter test       # MUST be all passing
```

**Rules:**
- Never stop with failing tests
- Never stop with analyzer errors or warnings (info included)
- If gates fail after sub-agent completion → orchestrator fixes before report
- Repeat until both gates pass

### Scoped Validation (during development)

Agents may run scoped analyze/test on owned paths for speed:

```bash
flutter analyze lib/core/repositories/api/sis/ lib/features/sis/
flutter test test/contracts/sis/ test/features/sis/ test/integration/sis/
```

But **full-project gates are required** before release sign-off.

---

## 5. Documentation Requirements

### Every Release

| Document | Path pattern | Owner |
|----------|-------------|-------|
| Release notes | `docs/Releases/v{X.Y}-{Name}.md` | F |
| Architecture audit | `docs/ArchitectureReview/v{X.Y}-{Area}-Audit.md` | F |
| Roadmap update | `docs/Roadmap.md` | F |
| Debt register update | `docs/TechnicalDebtRegister.md` | F (if applicable) |

### Release Doc Template

```markdown
# v{X.Y} — {Title}
## Summary
## Changes (repository methods / endpoints / screens)
## Architecture diagram
## Tests added
## Readiness delta
## Remaining gaps
```

### Audit Doc Template

```markdown
# v{X.Y} {Area} Audit
## Score: X / 10
## Before → After table
## Coverage matrix
## Findings (strengths + gaps)
## Recommendations
```

---

## 6. Release Requirements — Completion Report

Every agent session that completes a milestone **must** deliver:

```markdown
## Completion Report

### Agent Results
- files created: (list)
- files modified: (list)
- {domain-specific metrics: endpoints, methods, providers, etc.}
- tests added: (count + paths)

### Validation
- flutter analyze: {result}
- flutter test: {result}
- total test count: {N}
- production readiness score: {X / 100}
- readiness delta: {+N}

### Remaining Blockers
- (list)

### Roadmap Status
- milestone {ID}: COMPLETE | PARTIAL | BLOCKED
```

---

## 7. Common Workflows

### Workflow A — New Module Live Read API

```
Roadmap milestone → Agent A implements repository layer
                  → Agent E adds contract + integration tests
                  → Agent B wires dashboard screen (no layout change)
                  → Agent F creates release + audit docs
                  → Agent G validates gates
```

### Workflow B — Write API for Existing Module

```
Roadmap milestone → Agent A adds write methods + DTOs + remote
                  → Agent B adds mutation providers + screen wiring
                  → Agent D verifies RBAC on mutations
                  → Agent E adds write contract + security tests
                  → Agent F + G close release
```

### Workflow C — Security Hardening

```
Roadmap milestone → Agent D implements security changes
                  → Agent E adds security tests
                  → Agent F creates security audit
                  → Agent G validates gates
                  → NO business feature changes
```

### Workflow D — Mobile Repository Migration

```
Roadmap milestone → Agent A creates mobile-facing repository interfaces
                  → Agent C migrates providers from inline mocks
                  → Agent E updates provider tests
                  → Agent F documents parity matrix
                  → Agent G validates gates
```

---

## 8. Failure Recovery

| Failure | Recovery procedure |
|---------|-------------------|
| `flutter analyze` errors | Fix in orchestrator scope; re-run full analyze |
| Test failures | Agent E identifies root cause; owning agent fixes |
| Sub-agent file conflict | Sequential merge; re-run gates |
| Scope creep | Reject changes outside milestone; revert unrelated diffs |
| Missing docs | Agent F creates before release sign-off |
| Backend not ready | Mark milestone PARTIAL; mock-only validation passes |

---

## 9. Session End Checklist

Before ending any Cursor session:

- [ ] All assigned milestone tasks complete or explicitly BLOCKED
- [ ] `flutter analyze` = 0 issues (if code changed)
- [ ] `flutter test` = all passing (if code changed)
- [ ] Completion report delivered
- [ ] Roadmap milestone status updated (if release complete)
- [ ] No uncommitted secrets or crash logs
- [ ] No files modified outside agent ownership (unless orchestrator fix)

---

## 10. Quick Reference

| I need to… | Read… | Agent… |
|------------|-------|--------|
| Know what to build next | `docs/Roadmap.md` | Lead |
| Know file ownership | `AGENTS.md` | All |
| Understand last release | `docs/Releases/v*.md` | All |
| Check production gaps | `docs/ProductionReadinessChecklist.md` | G |
| Check open debt | `docs/TechnicalDebtRegister.md` | All |
| Tag a release | `docs/ReleaseGovernance.md` | G |
| Understand architecture rules | `docs/ProjectCharter.md` | All |
| Run the release process | This document | G |
| Run multi-milestone autonomous session | This document §11 | Lead + G |

---

## 11. Autonomous Multi-Milestone Execution

**Default execution depth = 3 milestones.**

An autonomous session must attempt to complete up to three consecutive roadmap milestones before stopping. Do not request a new prompt between milestones within the execution depth.

### After Each Milestone

When a milestone is complete, run this loop **before** stopping or continuing:

1. Update `docs/Roadmap.md` (milestone status → ✅ Complete)
2. Update `docs/TechnicalDebtRegister.md` (resolve/add debt items)
3. Update `docs/ProductionReadinessChecklist.md` (check applicable items)
4. Generate `docs/Releases/v{X.Y}-{Name}.md`
5. Generate `docs/ArchitectureReview/v{X.Y}-{Area}-Audit.md` (≥1)
6. Run `flutter analyze` — **must be 0 issues**
7. Run `flutter test` — **must be all passing**

Fix all analyzer and test failures before proceeding.

### Continue Automatically

If validation succeeds:

1. Re-read `docs/Roadmap.md`
2. Determine the next highest-priority unfinished milestone
3. Assign agents per §2
4. Execute the next milestone
5. Repeat until execution depth is reached or a stop condition applies

**Do not stop after a single milestone** unless a stop condition is met.

### Stop Conditions

Cursor may stop only when **one** of the following is true:

| ID | Condition | Example |
|----|-----------|---------|
| **A** | Execution depth reached | Three milestones completed in the session |
| **B** | P0 blocker encountered | TD-P0-01 server RBAC cannot be validated without backend deployment |
| **C** | Backend dependency required | Live staging endpoint unavailable; audit ingestion not deployed |
| **D** | Human decision required | Security regression, tenant isolation breach, data-loss risk, missing credentials, ambiguous spec |
| **E** | Blocking dependency prevents progress | Required OpenAPI spec undefined; migration needs approval |

**Alias mapping (legacy):** Condition B/C in prior docs map to **B + C + D** above.

**Production-risk examples (Condition D):**

- Security regression (auth bypass, token leak, RBAC bypass)
- Tenant isolation issue (cross-tenant data in mock or API path)
- Data-loss risk (audit queue drop, destructive migration)
- Missing specification (OpenAPI/backend contract undefined for required endpoint)
- Missing credentials (staging gate requires secrets not available)
- Backend dependency unavailable (live API required but not deployed)

When stopping under **B**, **C**, **D**, or **E**, mark the milestone **PARTIAL** or **BLOCKED** in Roadmap.md and document the blocker in the completion report.

### Multi-Agent Execution Rules

Execute agents **in parallel** whenever file ownership allows (no overlapping writes):

| Agent | Ownership |
|-------|-----------|
| **A** | APIs, repositories, DTOs, mappers, remote datasources, OpenAPI |
| **B** | ERP modules (Admissions, Finance, SIS, HR, Transport, etc.) |
| **C** | Mobile applications (Parent, Teacher, Student) |
| **D** | Security, RBAC, tenant, audit, permissions |
| **E** | Tests, coverage, validation, contract tests |
| **F** | Documentation, release notes, audits, inventories |
| **G** | Release management, analyze/test gates, completion reports |

Parallel rules:

- Spawn sub-agents only when directories do not overlap
- After parallel work → Agent G integrates and runs full gates
- Orchestrator fixes compile/test conflicts only

### Completion Requirement

- Deliver a **per-milestone completion report** (see §6) after each milestone
- Deliver a **combined summary** after the full execution depth
- Never continue to the next milestone with failing `flutter analyze` or `flutter test`
