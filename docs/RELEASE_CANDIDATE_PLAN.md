# Release Candidate Plan — v19-rc1

**Date:** 14 June 2026  
**Decision target:** Create branch `release/v19-rc1`  
**Aligns with:** `docs/ReleaseGovernance.md`

---

## Current branch status

| Item | State |
|------|--------|
| Active branch | `main` (tracks `origin/main`) |
| Working tree | **Dirty** — QA mission changes uncommitted (HR/Inventory/Transport writes, Patrol E2E, multi-agent tooling, docs) |
| `pubspec.yaml` version | `18.6.2+187` |
| Flutter gates (local) | `flutter analyze` 0 issues · `flutter test` **1304** passed |
| Patrol full regression | In progress — see `docs/QA/full_regression_report.md` |
| Prior full Patrol baseline | 22/22 (`20260614_002828`) + 3 new E2E suites verified individually |

**Blocker before RC branch:** commit or stash gated changes; RC must not cut from failing or unvalidated tree.

---

## Version and naming

| Artifact | Value |
|----------|--------|
| RC branch | `release/v19-rc1` |
| App version (RC cut) | `19.0.0-rc.1+190` in `pubspec.yaml` |
| Annotated tag (after GO) | `v19.0.0-rc1` |
| Release doc | `docs/Releases/v19.0-rc1.md` (create at tag time) |

Governance uses `release/v{X.Y}`; RC suffix `v19-rc1` matches pilot naming convention.

---

## RC creation steps

1. Complete **full regression** (`ERP_COVERAGE_MODE=full qa/patrol/run_erp_coverage.sh`).
2. Commit gated changes on `main` with message: `v19.0.0-rc.1 QA stabilization — HR/inventory/transport writes, Patrol E2E, emulator fix`.
3. Create branch: `git checkout -b release/v19-rc1`
4. Bump `pubspec.yaml` to `19.0.0-rc.1+190` (Agent G).
5. Push: `git push -u origin release/v19-rc1`
6. CI: `Flutter CI` (analyze + test) + `Flutter Patrol RC` (fast smoke on push; full via workflow_dispatch).
7. Tag after GO: `git tag -a v19.0.0-rc1 -m "Akshara ERP v19.0.0 RC1 — mock pilot scope"`

---

## Merge policy (RC stabilization)

| Allowed | Forbidden |
|---------|-----------|
| P0/P1 bugfixes with tests | New features or modules |
| Test-only / QA key additions for flakes | Repository interface breaking changes |
| Doc updates (release, audit, QA) | Large refactors (module scaffolds, provider migrations) |
| Security hotfixes (Agent D) | Version bumps except RC patch (`rc.2`) |

**Merge flow:**

- `fix/*` → `release/v19-rc1` (PR or direct after gates)
- `release/v19-rc1` → `main` after RC validated (merge-back before GA tag)
- No force-push to `main` or `release/v19-rc1`

---

## Hotfix policy

Per `docs/ReleaseGovernance.md`:

1. Branch from RC tag: `hotfix/{slug}` off `v19.0.0-rc1`
2. Minimal fix; `flutter analyze` + `flutter test` required
3. Optional: fast Patrol smoke on hotfix PR
4. Merge to `release/v19-rc1` and `main`
5. Tag: `v19.0.0-rc.2` or `v19.0.0-rc1-hotfix-{slug}`

---

## CI gates (RC branch)

| Job | Trigger | Commands |
|-----|---------|----------|
| `Flutter CI` | push, PR | `flutter analyze`, `flutter test --coverage` |
| `Flutter Patrol RC` | push `release/**`, manual | `qa/patrol/run_erp_coverage.sh` (fast default; full on dispatch) |

See `docs/QA/ci_validation_report.md`.

---

## Pilot scope (frozen for RC)

**Primary write paths:** Admissions, Finance (assign + collect), Teacher attendance, optional HR leave / inventory PO / transport route (mock).

**Excluded:** Exam admin, HR payroll, live API production, production SaaS (98+ checklist).

---

## GO decision

**Verdict: GO WITH CONDITIONS** (see `docs/QA/full_regression_report.md`)

Full regression **25/25 Patrol · 1304 tests · analyze clean** (`20260614_104528`).

| Outcome | Action |
|---------|--------|
| **GO WITH CONDITIONS** | Commit `main` → create `release/v19-rc1` → bump version → push → tag after CI |
| ~~NO GO~~ | Not applicable — all gates green |
