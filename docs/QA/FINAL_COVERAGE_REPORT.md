# QA Final Coverage Report (Post M13 Expansion — Cycle 1)

**Generated:** 2026-06-15 20:06 UTC
**Commit baseline:** `8e30075`

## Inventory totals

| Metric | Count |
|--------|------:|
| Screens | 252 |
| Routes | 255 |
| QaTestKeys | 485 |
| Button instances (lib scan) | 111 |
| Filter surfaces | 59 |
| Export surfaces | 91 |
| AI action surfaces | 546 |
| Patrol suite files (pre-expansion) | 79 |
| Patrol suite files (after batch 1) | 89 |
| Patrol test cases | 222 |
| Flutter tests (gate) | 1683 |

## Coverage vs targets

| Target | Goal | Current (proxy) | Status |
|--------|-----:|----------------:|:------:|
| Routes | >95% | 20% | In progress |
| Screens | >95% | 35% | In progress |
| Critical actions | 100% | ~75% | In progress |
| Exports | >90% | ~35% | Gap |
| AI actions | >95% | ~60% | In progress |
| Patrol suites | 150–300 | 89 | Expanding |

## Batch 1 certification

All 10 Tier-1 expansion suites passed on `emulator-5554` (see `qa/patrol/reports/batch1_run.log`).

## Deliverables

- `docs/QA/TEST_COVERAGE_BASELINE.md`
- `docs/QA/ACTION_COVERAGE_MATRIX.md`
- `docs/QA/UNTESTED_ACTIONS_REPORT.md`
- `docs/QA/PATROL_EXPANSION_PLAN.md`
- `qa/inventory/coverage_expansion.json`

## Next cycle

Execute Patrol Expansion Plan Tier 2 backlog (batch 2: 10–20 suites) and refresh this report.
