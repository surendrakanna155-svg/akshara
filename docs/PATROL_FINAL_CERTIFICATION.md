# Patrol Final Certification — Release Candidate

**Program:** Akshara Release Candidate — Phase 1  
**Branch:** `release/v1.0-preprod`  
**Run ID:** `20260616_135757`  
**Mode:** `ERP_COVERAGE_MODE=full`  
**Log:** `qa/patrol/reports/erp_coverage/20260616_135757/run.log`

---

## Certification status: **IN PROGRESS → STABILIZING**

| Metric | Value |
|--------|-------|
| Registered suites | **89** |
| Completed (at last scan) | ~27 |
| Passed | **24** |
| Failed | **1** (admissions E2E — fix applied, re-run pending) |
| Certification % (completed) | **96%** (24/25) |
| Target certification % | **≥98%** after re-run |

---

## Failure classification

| Suite | Result | Class | Root cause | Action |
|-------|--------|-------|------------|--------|
| `admissions_e2e_journey_test` | ❌ 1/1 | **A — Product** | `enrollment_continue_button` not hit-testable on academic wizard step — actions scrolled off-screen in nested scroll | Sticky enrollment action bar (`admissions_enrollment_screen.dart`); re-run suite |
| All other completed suites | ✅ | — | — | — |

**Not classified as Patrol defect (B) or emulator (C):** Button exists in widget tree but nested `AdminContentScaffold` scroll + long form caused visibility timeout — product layout issue.

---

## Suites confirmed green (sample)

| Domain | Suites |
|--------|--------|
| Mobile | teacher, parent, student |
| ERP core | erp, finance, inventory, sis, principal |
| Workflows | teacher/parent/student workflows, continuity, sis academic ops |
| HR / management | hr workflows (in progress at scan) |

Full per-suite logs: `qa/patrol/reports/erp_coverage/20260616_135757/*.log`

---

## Fixes applied (product defects only)

| ID | Fix | File |
|----|-----|------|
| PATROL-RC-01 | Enrollment wizard sticky Continue/Submit bar | `admissions_enrollment_screen.dart` |
| PATROL-RC-02 | Finance KPI overflow on mobile grids | `akshara_kpi_card.dart` (compact layout) |
| (prior) PATROL-002 | QA logout route | `auth_logout.dart` |
| (prior) PROD-01 | Inventory PO finance link | `inventory_mutations_provider.dart` |

---

## Re-run plan

```bash
# Single suite (post-fix verification)
patrol test -t patrol_test/workflows/admissions_e2e_journey_test.dart --device emulator-5554

# Full remaining coverage (if needed)
ERP_COVERAGE_MODE=full ./qa/patrol/run_erp_coverage.sh
```

---

## Gates

| Gate | Status |
|------|--------|
| Zero product-defect failures | 🔄 Pending admissions re-run |
| `flutter test` | ✅ 1688 passed |
| `flutter analyze` | ✅ 0 issues |

---

## Final certification formula

```
certification % = (passed_suites / (passed_suites + failed_product_defect_suites)) × 100
```

Patrol harness/infrastructure failures are excluded from the denominator per program rules.

**Sign-off target:** ≥98% with zero unresolved product defects.

---

## Related

- `docs/PATROL_CERTIFICATION_REPORT.md`
- `docs/PATROL_RECERTIFICATION_PLAN.md`
- `docs/FINAL_PRE_PATROL_STATUS.md`
