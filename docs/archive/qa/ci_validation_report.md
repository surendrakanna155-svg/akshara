# CI Validation Report — v19 RC1

**Date:** 14 June 2026  
**Scope:** Validate CI coverage vs RC gates · document gaps · recommendations

---

## Required RC gates

| Gate | Required | Current CI |
|------|:--------:|:----------:|
| `flutter analyze` | Yes | **Yes** — `.github/workflows/flutter_ci.yml` |
| `flutter test` | Yes | **Yes** — with `--coverage` |
| `ERP_COVERAGE_MODE=full` Patrol | Yes (RC) | **Partial** — new `flutter_patrol_rc.yml` |
| `ERP_COVERAGE_MODE=fast` Patrol smoke | Recommended on PR | **No** on PR (RC branch only) |

---

## Workflow inventory

### 1. `Flutter CI` (existing)

- **Trigger:** push, pull_request (all branches)
- **Runner:** `ubuntu-latest`
- **Steps:** `flutter pub get` → `flutter analyze` → `flutter test --coverage` → verify `lcov.info`
- **Runtime (local reference):** analyze ~4s · test ~55–75s
- **Patrol:** none

### 2. `Flutter Patrol RC` (added for RC)

- **Trigger:** push to `release/**` · `workflow_dispatch` (fast | full)
- **Runner:** `macos-latest` (emulator support)
- **Timeout:** 120 minutes
- **Steps:** Patrol CLI → `qa/patrol/run_erp_coverage.sh` → upload `qa/patrol/reports/erp_coverage/`
- **Default on push:** `ERP_COVERAGE_MODE=fast` (~2 min smoke)
- **Manual full:** select `full` (~60+ min, 25 suites)

### 3. `backend_staging.yml`

- Backend-only; not part of Flutter RC gates.

---

## Local validation (this session)

| Command | Result | Notes |
|---------|--------|-------|
| `flutter analyze` | **0 issues** | Clean before full regression |
| `flutter test` | **1304 passed**, ~1 skipped | `/tmp/flutter_test_rc.log` |
| Full Patrol | **In progress** | See `full_regression_report.md` |
| Emulator | **Fixed** | `scripts/qa/start_emulator.sh` cold boot |

---

## Failures

| Item | Status |
|------|--------|
| Flutter CI on GitHub | Not re-run in this session; local gates green |
| Patrol in CI | **Not historically run** — gap closed by new workflow on `release/**` |
| Full Patrol local | **PASS** — 25/25 (`20260614_104528`) |

---

## Flaky test policy

| Definition | Action |
|------------|--------|
| Suite fails once, passes on immediate rerun | Mark **flake suspect** in regression report; rerun 2× before RC GO |
| Patrol scroll / offline emulator | Use cold boot script; no snapshot load |
| Golden tests | ~1 skipped in suite; monitor on CI |

**Known non-flake fixes this cycle:**

- HR mock leave list (unmodifiable → growable)
- Patrol body button scroll (`scrollUntilVisible`)
- Emulator snapshot offline (cold boot)

---

## Recommendations

| Priority | Recommendation |
|----------|----------------|
| P0 | Run **workflow_dispatch → full** on first `release/v19-rc1` push |
| P0 | Commit QA mission changes before RC branch cut |
| P1 | Add PR comment gate: require `Flutter CI` green (already automatic on GitHub) |
| P1 | Nightly `ERP_COVERAGE_MODE=full` on `main` (optional cron workflow) |
| P2 | Split Patrol full across matrix (mobile ERP vs persona suites) to reduce 60 min wall time |
| P2 | Pin Flutter version in CI to match local SDK |

---

## Staged CI policy (recommended)

```
PR → main          : analyze + test (fast, ~2 min)
push release/**    : analyze + test + Patrol fast smoke (~5 min)
RC manual dispatch : Patrol full (25 suites, ~60 min)
Tag v19.0.0-rc1    : requires full Patrol artifact green
```

---

## Artifacts

- Patrol reports: `qa/patrol/reports/erp_coverage/<run_id>/`
- Coverage JSON: `qa/patrol/reports/erp_coverage/<run_id>/coverage_summary.json`
- Emulator log: `/tmp/akshara_emulator.log`
