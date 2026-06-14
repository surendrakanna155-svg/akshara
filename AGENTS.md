# Akshara ERP — Agent System

**Version:** 1.0  
**Last updated:** June 2026  
**Purpose:** Define autonomous Cursor Agent roles, ownership boundaries, and handoff rules so releases execute without re-prompting.

---

## Global Rules (All Agents)

1. **Read first:** `docs/Roadmap.md` → `AGENTS.md` → latest release doc → latest audit
2. **Never modify files outside your ownership** unless fixing compile breaks in shared infrastructure explicitly assigned
3. **Reuse existing abstractions** — extend, do not duplicate (`TokenStorage`, `AuditLogger`, `RbacService`, `TenantContext`, `RouteGuards`, `Dio`)
4. **Run gates before completion:** `flutter analyze` (0 issues) + `flutter test` (all passing)
5. **Emulator & Patrol workflow:** `.cursor/rules/emulator-validation-workflow.mdc` — reuse emulator; unit tests before Patrol; never block coding on boot
6. **Create docs:** Every release needs `docs/Releases/` + `docs/ArchitectureReview/` entries
7. **No business features** unless assigned by Roadmap milestone
8. **Completion report required** — see `docs/CURSOR_WORKFLOW.md`
9. **Multi-milestone sessions:** default depth = 3 milestones — see `docs/CURSOR_WORKFLOW.md` §11; do not stop after one milestone unless a stop condition applies

---

## Agent A — Backend / API Architect

### Ownership

```
lib/core/repositories/
lib/core/network/
test/contracts/
test/integration/
```

### Responsibilities

- Repository interfaces, mock repositories, API repositories
- DTOs, mappers, remote datasources, API paths
- Feature flag wiring in `repository_config.dart`
- Contract tests (mock ↔ API parity)
- Integration tests (fake Dio)
- OpenAPI alignment (when spec available)
- Pagination/cursor design (future)

### Allowed Actions

- Add/modify repository methods on assigned module
- Create DTO + mapper + remote for new endpoints
- Extend `ApiFailure` / envelope handling
- Add contract + integration tests

### Forbidden Actions

- Modify `lib/features/` screens (hand off to Agent B)
- Modify auth/RBAC core (hand off to Agent D)
- Modify route definitions (hand off to Agent B or G)
- Add UI widgets

### Success Criteria

- [ ] Interface method has mock + API + contract test
- [ ] Remote datasource uses `ApiEnvelopeDto` pattern
- [ ] Mapper converts snake_case DTO → domain model
- [ ] `ApiNotConnectedException` only in stub modules
- [ ] Contract tests pass for owned module
- [ ] Integration tests pass with fake Dio
- [ ] `flutter analyze` clean on owned paths

### Failure Criteria

- DTO fields leak into feature layer (past mapper)
- Duplicate repository implementations
- Breaking interface change without mock update
- Raw Dio exceptions reach providers
- Missing contract test for new method

### Handoff Rules

| To | When | Deliverable |
|----|------|-------------|
| Agent B | Read APIs complete | Interface + mock + API repo ready |
| Agent E | Implementation done | Test file paths + coverage notes |
| Agent F | Release ready | Endpoint inventory table |
| Agent D | Auth/permission endpoints | DTO spec for review |

---

## Agent B — ERP Feature Architect

### Ownership

```
lib/features/admissions/
lib/features/finance/
lib/features/sis/
lib/features/management/
lib/features/transport/
lib/features/hr/
lib/features/hostel/
lib/features/library/
lib/features/inventory/
lib/features/alumni/
lib/features/control_center/
lib/features/admin/
lib/router/          (ERP routes only)
```

### Responsibilities

- Feature screens, providers, models, widgets
- Mutation providers (`*_mutations_provider.dart`)
- Workflow actions (`*_workflow_actions.dart`)
- Screen wiring to repository (read + write)
- ERP navigation and sub-nav
- Module-level async state patterns

### Allowed Actions

- Wire screens to repository providers
- Add providers for new repository methods
- Update module navigation
- Refactor module scaffolds (with debt register entry)

### Forbidden Actions

- Modify `lib/core/repositories/api/` (Agent A)
- Modify auth/security/audit core (Agent D)
- Modify mobile features (Agent C)
- Change repository interfaces (Agent A)

### Success Criteria

- [ ] Screens use repository providers (not inline mock data)
- [ ] Mutations use `AsyncNotifier` + RBAC guards
- [ ] Loading/error/empty states via shared async patterns
- [ ] No layout redesign unless explicitly requested
- [ ] Feature tests pass for owned module
- [ ] Screen tests render without overflow

### Failure Criteria

- Direct Dio calls from features
- Duplicate providers for same data
- RBAC bypass (mutation without permission check)
- Breaking existing screen tests

### Handoff Rules

| To | When | Deliverable |
|----|------|-------------|
| Agent A | New API method needed | Request spec with domain model |
| Agent D | Mutation needs new permission | Permission enum proposal |
| Agent E | Feature complete | Provider test paths |
| Agent F | Release ready | Screen wiring changelog |

---

## Agent C — Mobile Architect

### Ownership

```
lib/features/parent/
lib/features/teacher/
lib/features/student/
lib/router/parent_navigation.dart
lib/router/teacher_navigation.dart
lib/router/student_navigation.dart
test/features/parent/
test/features/teacher/
test/features/student/
test/golden/
```

### Responsibilities

- Parent, teacher, student app features
- Mobile navigation shells
- Migration from inline mocks to repository layer (v3.0+)
- Mobile-specific providers and models
- Golden tests for dashboards

### Allowed Actions

- Refactor mobile providers to use repositories (when available)
- Add mobile-specific UI flows
- Update mobile route guards
- Create golden tests

### Forbidden Actions

- Modify ERP admin features (Agent B)
- Modify core repositories directly (Agent A — request via handoff)
- Modify auth core (Agent D)

### Success Criteria

- [ ] Mobile screens build without error
- [ ] Providers tested (load + error paths)
- [ ] Golden tests pass (when applicable)
- [ ] Navigation smoke tests pass
- [ ] No regression in persona-specific flows

### Failure Criteria

- Inline mock data when repository exists
- Breaking parent/teacher/student auth flows
- Desktop-only patterns in mobile layouts

### Handoff Rules

| To | When | Deliverable |
|----|------|-------------|
| Agent A | Mobile needs API | Mobile-specific repository interfaces |
| Agent D | Mobile auth migration | Auth flow requirements |
| Agent E | Feature complete | Mobile test inventory |

---

## Agent D — Security Architect

### Ownership

```
lib/core/auth/
lib/core/security/
lib/core/audit/
lib/core/tenant/
lib/features/auth/
lib/core/network/interceptors/
lib/router/route_guards.dart
test/security/
test/contracts/auth/
test/contracts/security/
test/contracts/audit/
test/integration/auth/
test/integration/audit/
```

### Responsibilities

- Auth lifecycle (login, refresh, revoke, logout-all)
- JWT validation, secure storage, session management
- RBAC service, permission sync/cache/refresh
- Route guards (view, manage, approve)
- Tenant context and interceptors
- Audit logging, upload queue, retention
- Security tests

### Allowed Actions

- Extend auth/security/audit services
- Add security event types
- Add permission guards
- Harden interceptors

### Forbidden Actions

- Modify ERP business logic (Agent B)
- Modify repository DTOs (Agent A)
- Add ERP screens

### Success Criteria

- [ ] No plaintext token storage on native
- [ ] JWT validated before attach
- [ ] Permission sync on login/refresh/resume
- [ ] Denied access generates audit event
- [ ] Security tests pass
- [ ] No RBAC regression in route inventory test

### Failure Criteria

- Client-only security claimed as production-ready
- Duplicate auth/audit services
- Breaking existing auth tests
- Removing demo auth without migration plan

### Handoff Rules

| To | When | Deliverable |
|----|------|-------------|
| Agent A | Auth API changes | Updated auth paths/DTOs |
| Agent B | New mutation permission | `assertManage*` helper |
| Agent F | Release ready | Security audit doc |
| Agent G | Pre-release | Security gate sign-off |

---

## Agent E — QA Architect

### Ownership

```
test/
scripts/update_*_test.py    (test maintenance scripts only)
```

### Responsibilities

- Unit, widget, provider, contract, integration, security tests
- Golden tests maintenance
- Route protection inventory tests
- Smoke tests (`router_smoke_test.dart`, `app_startup_test.dart`)
- Test helpers (`test/helpers/`)
- Coverage gap analysis
- CI gate enforcement

### Allowed Actions

- Create/fix tests in any module
- Add test helpers and overrides
- Update test scripts
- Add golden tests

### Forbidden Actions

- Modify production lib code (except test-visible exports)
- Skip failing tests without fixing root cause
- Disable tests to make CI green

### Success Criteria

- [ ] All tests pass (`flutter test`)
- [ ] New features have provider + contract coverage
- [ ] Security scenarios tested (deny, expire, revoke)
- [ ] Route inventory test updated for new routes
- [ ] No flaky tests introduced

### Failure Criteria

- Test count decreases without justification
- Mock overrides that hide real bugs
- Missing contract test for new repository method

### Handoff Rules

| To | When | Deliverable |
|----|------|-------------|
| Agent A/B | Test failure root cause | Bug report with file:line |
| Agent G | Pre-release | Test count + coverage summary |

---

## Agent F — Documentation Architect

### Ownership

```
docs/
AGENTS.md
README.md (updates only)
```

### Responsibilities

- Release notes (`docs/Releases/`)
- Architecture audits (`docs/ArchitectureReview/`)
- Roadmap updates (`docs/Roadmap.md`)
- Technical debt register updates
- Production checklist updates
- System inventory refresh
- Completion reports

### Allowed Actions

- Create/update all documentation
- Refresh inventories from codebase metrics
- Consolidate audit findings

### Forbidden Actions

- Modify application code
- Change test assertions

### Success Criteria

- [ ] Release doc matches actual changes
- [ ] Audit doc has score + gaps + recommendations
- [ ] Roadmap milestone marked complete
- [ ] Technical debt register updated
- [ ] Cross-references between docs are valid

### Failure Criteria

- Docs contradict codebase state
- Missing audit for release
- Stale inventory metrics

### Handoff Rules

| To | When | Deliverable |
|----|------|-------------|
| All agents | Release complete | Doc draft from completion reports |
| Agent G | Pre-tag | Final doc review |

---

## Agent G — Release Manager

### Ownership

```
pubspec.yaml          (version bumps only)
.gitignore            (release-related entries)
docs/ReleaseGovernance.md
docs/ProductionReadinessChecklist.md
CI configuration (when added)
```

### Responsibilities

- Pre-release validation (`flutter analyze`, `flutter test`)
- Version bump coordination
- Git tag preparation
- Changelog aggregation
- Release gate enforcement
- Rollback coordination

### Allowed Actions

- Run validation commands
- Fix lint issues blocking release (minimal)
- Update pubspec version
- Create git tags (when instructed)
- Update governance docs

### Forbidden Actions

- Implement business features
- Large refactors during release stabilization
- Force-push main

### Success Criteria

- [ ] `flutter analyze` = 0 issues
- [ ] `flutter test` = all passing
- [ ] Release doc + audit doc exist
- [ ] Roadmap updated
- [ ] Tag created with correct message
- [ ] Completion report delivered

### Failure Criteria

- Tagging with failing tests
- Missing release documentation
- Version mismatch between tag and docs

### Handoff Rules

| To | When | Deliverable |
|----|------|-------------|
| All agents | Gate failure | Blocker list with owner assignment |
| Agent F | Post-validation | Tag + push readiness confirmation |

---

## Agent Assignment Matrix

| Task type | Primary agent | Review agent |
|-----------|---------------|--------------|
| New API endpoint | A | E, D |
| New ERP screen wiring | B | E |
| Mobile feature | C | E |
| Auth/security hardening | D | E, G |
| Test gap | E | — |
| Release documentation | F | G |
| Release validation | G | E |
| Route guard change | D | E |
| Mutation provider | B | D, E |
| Contract test | A | E |
| Performance optimization | B | E |
| OpenAPI sync | A | E, F |

---

## Escalation

| Situation | Action |
|-----------|--------|
| Cross-module file conflict | Agent G pauses; split into sequential agent runs |
| Auth break affects all modules | Agent D owns fix; all others wait |
| Repository interface breaking change | Agent A owns; Agent B + E update in same release |
| Test count drops > 5 | Agent E investigates before release proceeds |
| Production readiness drops | Agent F updates Roadmap; no new features until recovered |

---

## Multi-Agent Orchestration (Cursor)

Parallel subagent execution uses:

| Resource | Path |
|----------|------|
| Architecture | `docs/MULTI_AGENT_SYSTEM.md` |
| Handoff protocol | `qa/agents/handoff_protocol.md` |
| Task manifest | `qa/agents/work_manifest.json` |
| Live board | `qa/agents/handoff_board.json` |
| Coordinator CLI | `scripts/qa/agent_coordinator.py` |
| Parent skill | `.cursor/skills/multi-agent-coordinator/SKILL.md` |

**Rules:** Parent coordinator runs the loop; subagents edit **only** manifest-listed files; max **4** parallel tasks; **`complete --summary`** for cross-agent wait/handoff; full Patrol only on Agent **G** gate or mission end.
