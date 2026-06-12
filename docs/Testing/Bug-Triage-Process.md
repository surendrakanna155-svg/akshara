# Bug Triage Process — Akshara Pilot

**Applies to:** Friend testing, pilot school, internal QA  
**Build baseline:** 16.6.0 (166)  
**Template:** [Bug-Report-Template.md](Bug-Report-Template.md)

---

## Workflow overview

```
Tester reports → Coordinator logs → Triage (severity) → Owner assigned → Fix / defer → Verify on build → Close
```

---

## Severity categories

| Level | Definition | Examples | Response SLA |
|-------|------------|----------|--------------|
| **Critical** | App unusable; data loss; security | Crash on launch, login loop, payment double-charge | Same day |
| **High** | Core workflow blocked | Cannot mark attendance, fees blank for all parents, dashboard never loads | 1–2 days |
| **Medium** | Workaround exists | One screen fails but alternate path works; intermittent API error with retry | Next patch |
| **Low** | Cosmetic / copy | Misaligned chip, typo, minor spacing | Backlog |

### Mapping from tester template

| Tester "Severity" | Triage category |
|-------------------|-----------------|
| Blocker | **Critical** |
| Major | **High** |
| Minor | **Medium** |
| Cosmetic | **Low** |

---

## Triage steps (coordinator)

1. **Intake** — Log bug with ID `BUG-NNN` in spreadsheet or `reports/pilot_validation/bugs/`.
2. **Reproduce** — Coordinator or dev reproduces on same build + device class.
3. **Classify** — Assign Critical / High / Medium / Low.
4. **Scope** — Tag module: `auth`, `parent`, `teacher`, `student`, `finance`, `sis`, `ui`, `api`.
5. **Assign owner** — See ownership table below.
6. **Decide** — Fix now, defer post-pilot, or won't fix (document reason).
7. **Verify** — Tester confirms on new build.
8. **Close** — Update status; link commit or release tag.

---

## Ownership

| Module / area | Primary owner | Review |
|---------------|---------------|--------|
| Auth / login / OTP | Agent D (Security) | QA |
| Parent mobile | Agent B + Agent C | QA |
| Teacher mobile | Agent B + Agent C | QA |
| Student mobile | Agent B + Agent C | QA |
| ERP dashboards (principal) | Agent B | QA |
| API / staging 5xx | Agent A (Backend) | Release manager |
| UI overflow / layout | Agent B | QA (v16.5 regression) |
| TestFlight / APK install | Release manager | — |

During **development freeze**, only **Critical** and **High** bugs get code fixes. Medium/Low go to backlog unless zero-cost doc/config fix.

---

## Fix priority matrix

| Severity | Pilot blocking? | Action |
|----------|-----------------|--------|
| Critical | Yes | Hotfix build; pause tester rollout |
| High | Often | Patch in next RC; notify testers |
| Medium | No | Log for v17+ polish |
| Low | No | Backlog |

---

## Release criteria (pilot go / no-go)

### Go — distribute to wider pilot

- [ ] Zero open **Critical** bugs
- [ ] Zero open **High** bugs in assigned journey (see [Real-User-Journeys.md](Real-User-Journeys.md))
- [ ] `flutter test` green on release tag
- [ ] `demo_school_validate.py` 58/58 green
- [ ] Android APK smoke passed on 2+ devices
- [ ] TestFlight smoke passed on 1+ iPhone (when iOS ready)

### No-go — hold distribution

- Any **Critical** unresolved
- Login failure for all staging personas
- Data leak across tenants (escalate immediately)
- Crash rate > 5% in smoke cohort

### Conditional go

- **High** bugs only on non-pilot modules (e.g. alumni, transport GPS) → document known issues in tester pack
- iOS not ready → **Android-only pilot** with explicit comms

---

## Bug log format (spreadsheet)

| ID | Build | Severity | Module | Summary | Owner | Status | Fixed in |
|----|-------|----------|--------|---------|-------|--------|----------|
| BUG-001 | 16.6.0+166 | High | parent | Fees blank | Agent B | Open | — |

**Status values:** `Open` · `In Progress` · `Fixed` · `Verified` · `Deferred` · `Won't Fix`

---

## Escalation

| Condition | Escalate to |
|-----------|-------------|
| Critical security | Agent D + Release manager immediately |
| Staging API down | Run `demo_school_validate.py`; check Supabase status |
| > 10 High bugs in 48h | Pause pilot; triage meeting |
| iOS signing blocked | Release manager + Apple Developer admin |

---

## Reference

- Report template: [Bug-Report-Template.md](Bug-Report-Template.md)
- Release audit: [Release-Go-Live-Audit.md](Release-Go-Live-Audit.md)
- Tester packs: [Android-Tester-Pack.md](Android-Tester-Pack.md) · [iPhone-Tester-Pack.md](iPhone-Tester-Pack.md)
