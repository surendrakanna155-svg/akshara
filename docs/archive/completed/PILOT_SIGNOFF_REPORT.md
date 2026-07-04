# Pilot Sign-Off Report — Akshara v1.0-preprod

**Program:** Akshara Final Stabilization & Pilot Sign-Off  
**Branch:** `release/v1.0-preprod`  
**Date:** June 2026  

**Question:** Can a real school run an entire academic year on Akshara?

---

## Verdict: **Ready With Conditions**

A school **can** operate on Akshara for a full academic year in **pilot mode** (mock repositories or controlled staging backend). Production multi-tenant SaaS at scale is **not ready** without infrastructure blockers closing.

---

## Classification rationale

| Criterion | Assessment | Evidence |
|-----------|------------|----------|
| Admissions → enrollment | ✅ Ready | `admissions_e2e_journey`, contract tests |
| SIS lifecycle (promote, reshuffle) | ✅ Ready | `sis_academic_operations_e2e` |
| Fee assignment → collection | ✅ Ready | `finance_full_journey_e2e` |
| HR + payroll | ✅ Ready | `hr_payroll_e2e`, `hr_leave_e2e` |
| Transport / hostel / library / inventory | ✅ Ready | Module Patrol e2e suites |
| Year rollover | ✅ Ready | `continuity_e2e_test` |
| Parent / teacher / student apps | ✅ Ready | Mobile stress tests + Patrol |
| Intelligence & copilot | ✅ Ready | M8 Patrol suites |
| Flutter quality gates | ✅ Ready | analyze 0; 1683 tests; 7/7 perf |
| Live production API + RLS | ⚠️ Conditional | Infra blockers — mock/staging OK |
| Real PII without demo auth | ❌ Not ready | A9 — disable demo OTP |

---

## Evidence summary

### Academic year workflows (17 domains certified)

See `docs/WORKFLOW_CERTIFICATION_REPORT.md` — all modules **Certified** at Flutter layer.

### Quality gates (June 2026 sign-off run)

| Gate | Result |
|------|--------|
| `flutter analyze` | 0 issues |
| `flutter test` | **1683** passing (~1 skipped) |
| Performance benchmarks | 7/7 |
| UX stress (mobile + ERP + vertical) | Pass |
| Patrol full certification | In progress / see `PATROL_CERTIFICATION_REPORT.md` |

### Operations readiness

| Capability | Status |
|------------|--------|
| RBAC (120+ guarded routes) | ✅ |
| Client audit logging | ✅ |
| Pilot dashboard | ✅ |
| Management approvals | ✅ |
| Platform operations hub | ✅ |

---

## Conditions for pilot go-live

| # | Condition | Owner | Blocking? |
|---|-----------|-------|-----------|
| 1 | Deploy mock mode (`ENABLE_API_MODE=false`) OR staging with write parity | DevOps | Yes (live data) |
| 2 | Disable demo OTP before real PII (A9) | Backend | Yes (real users) |
| 3 | Complete `ERP_COVERAGE_MODE=full` Patrol on CI/device farm | QA | Recommended |
| 4 | PI1 pilot school checklist signed | Operations | Yes |
| 5 | Support / backup runbook acknowledged | Operations | Yes |
| 6 | Single-tenant pilot only until RLS GA | Product | Yes (multi-tenant) |

---

## Not ready without additional work

- Multi-tenant production SaaS at scale
- Public internet deployment without pen test
- Real payment gateway production (QR/offline mock OK for pilot)
- Multi-school chain on production API

---

## Pilot deployment profile

```
Environment:  Staging or demo-mode
Tenant:       Single school
Users:        Admin, principal, teachers, parents, students
Data:         Mock repositories OR staging API (write parity subset)
Duration:     Full academic year supported in application workflows
Support:      Operations runbooks in docs/Operations/
```

---

## Recommendation

| Stakeholder | Action |
|-------------|--------|
| **Product** | Approve single-school pilot with conditions above |
| **QA** | Complete Patrol full certification; attach to release tag |
| **DevOps** | Stand staging OR ship mock-mode build |
| **Backend** | Prioritize A9 + admissions/finance/SIS write parity for live pilot |
| **Executive** | Defer production GA 4–8 weeks pending infra program |

---

## Conclusion

**Pilot sign-off: Ready With Conditions.** The application supports a full academic-year school operation in mock or controlled staging. Live production pilot requires backend auth and API parity gates.
