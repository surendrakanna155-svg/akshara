# Akshara ERP — Release Governance

**Version:** 1.0  
**Last updated:** June 2026

---

## Branch Strategy

| Branch | Purpose | Lifetime |
|--------|---------|----------|
| `main` | Production-ready code; always green (analyze + test) | Permanent |
| `release/v{X.Y}` | Stabilization branch for large releases (optional) | Until tagged |
| `feature/{module}-{slug}` | Agent-scoped feature work | Until merged to main |
| `hotfix/{slug}` | Emergency production fixes | Until merged + tagged |

**Rules:**

- All work merges to `main` via PR or direct commit after validation
- Never force-push `main`
- Feature branches must not modify files outside agent ownership (see `AGENTS.md`)
- Delete feature branches after merge

---

## Release Strategy

### Release Types

| Type | Version bump | Example |
|------|--------------|---------|
| **Major** | X.0.0 | v3.0 — Mobile API layer |
| **Minor** | x.Y.0 | v2.6 — SIS write APIs |
| **Patch** | x.y.Z | v2.7.1 — Hotfix |
| **Tag slug** | Annotated tag | `v2.6-api-completion` |

### Release Cadence (Target)

| Phase | Cadence | Focus |
|-------|---------|-------|
| MVP (v0.x) | As needed | Module UI + mock data |
| API (v1.x–v2.x) | 2–4 weeks | Live API per module |
| Security (v2.7+) | 2–3 weeks | Hardening, no features |
| Platform (v3.x+) | 4–6 weeks | Mobile API, pagination, E2E |

### Release Process

1. Agent G validates gates (`flutter analyze`, `flutter test`)
2. Agent F creates release + audit docs
3. Agent G updates `docs/Roadmap.md` milestone
4. Commit to `main` with message: `v{X.Y} {summary}`
5. Annotated tag: `git tag -a v{X.Y}-{slug} -m "{description}"`
6. Push `main` + tag to `origin`

---

## Tagging Strategy

```
v{major}.{minor}-{slug}
```

Examples:

- `v2.6-api-completion` — Admissions, Finance, SIS write APIs
- `v2.7-security-hardening` — Auth, RBAC, audit hardening
- `v3.0-mobile-api` — Parent/teacher/student repository layer

**Rules:**

- Tags are annotated (`-a`) with descriptive messages
- One tag per release milestone (not per commit)
- Tags reference `docs/Releases/` document

---

## Versioning Rules

| Component | Scheme |
|-----------|--------|
| Release docs | `v{X.Y}-{Module-Feature}.md` |
| Audit docs | `v{X.Y}-{Area}-Audit.md` |
| App version (`pubspec.yaml`) | Semantic; bump on production deploy only |
| API contract | Backend version tracked separately; client DTOs versioned by release |

**Compatibility:**

- Repository interface changes require mock + API + contract test updates in same release
- Breaking DTO changes require migration note in release doc

---

## Hotfix Rules

1. Branch from tagged release: `hotfix/{issue-slug}`
2. Minimal fix — no feature work
3. Must pass `flutter analyze` + `flutter test`
4. Tag: `v{X.Y}.{Z}-hotfix-{slug}`
5. Merge back to `main`
6. Release doc: `docs/Releases/v{X.Y}.{Z}-Hotfix-{slug}.md`

---

## Rollback Process

1. Identify last good tag: `git tag -l "v*"`
2. Revert commit on `main`: `git revert {bad-commit}` (preferred) or checkout tag for deploy artifact
3. Create hotfix release doc noting rollback reason
4. Re-run full test suite on reverted state
5. Notify stakeholders; update Roadmap milestone to `rolled back`

---

## Pilot Rollout Process

1. Deploy backend APIs for target modules (Auth, Admissions, Finance, SIS minimum)
2. Enable flags in staging: `enableApiModeProvider` + per-module `*ApiEnabledProvider`
3. Run contract tests against staging OpenAPI
4. Manual smoke: login → ERP module → read → write mutation
5. Pilot with 1 school tenant for 2 weeks
6. Collect audit logs + permission sync validation
7. Go/no-go checklist: `docs/ProductionReadinessChecklist.md`

---

## Production Rollout Process

1. All P0 items in `docs/TechnicalDebtRegister.md` resolved or accepted
2. Production readiness score ≥ 98
3. Server-side RBAC/RLS enforced
4. Audit ingestion endpoint live
5. Monitoring + alerting configured
6. Backup + DR tested
7. Tag production release
8. Enable API flags per tenant (gradual rollout)
9. Post-deploy: 24h monitoring window; rollback plan ready
