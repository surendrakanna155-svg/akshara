# Production Hardening Report — Release Candidate

**Program:** Akshara Release Candidate — Production Hardening  
**Branch:** `release/v1.0-preprod`  
**Date:** June 2026  
**References:** `docs/ArchitectureReview/FINAL_PRODUCTION_AUDIT.md`, `docs/PRODUCTION_READINESS_PROGRESS.md`, `docs/ProductionReadinessChecklist.md`

---

## Executive summary

| Layer | Score | Pilot | GA SaaS |
|-------|------:|-------|---------|
| **Flutter complete** | **96/100** | ✅ Ready | App layer done |
| **Backend required** | 70/100 | ⚠️ Staging/mock | Blockers remain |
| **DevOps required** | 65/100 | ⚠️ Manual deploy | Pipelines needed |
| **Security required** | 80/100 (client) / 72 (server) | ⚠️ Demo auth OK for mock | Pen test + RLS |

**Recommendation:** Proceed to **single-school pilot** in mock or controlled staging. Defer **multi-tenant GA** until backend/DevOps/security blockers close.

---

## Flutter complete (application-side)

| Capability | Status | Evidence |
|------------|--------|----------|
| RBAC + route guards (120+ routes) | ✅ | `test/security/`, router inventory |
| Client audit logging | ✅ | Audit queue + upload |
| Observability UI (Platform Operations) | ✅ | M12 hub |
| Tenant isolation verification UI | ✅ | 213 probes |
| Alert center + acknowledgment | ✅ | Platform operations |
| Production readiness in-app report | ✅ | Readiness tab |
| Multi-school / director flows | ✅ | Patrol + widget tests |
| Smart school configuration (M14) | ✅ | Capability-filtered nav |
| Copilot + intelligence | ✅ | M8/M14 |
| UX + performance RC gates | ✅ | This release |

**No further Flutter features required for pilot.**

---

## Backend required

| # | Item | Checklist | Pilot impact |
|---|------|-----------|--------------|
| 1 | Server RLS enforcement | R8, FV-PLAT-13 | Multi-tenant only |
| 2 | Production auth (no demo OTP) | A9 | **Required for real PII** |
| 3 | Live write API parity | P3–P6 | Staging or mock OK |
| 4 | Tamper-evident audit trail | U6 | GA |
| 5 | OpenAPI CI validation | P8 | GA |

---

## DevOps required

| # | Item | Checklist | Pilot impact |
|---|------|-----------|--------------|
| 1 | Web/mobile deploy pipelines | D3, D4 | Manual deploy OK |
| 2 | TLS on all endpoints | S5 | Staging config |
| 3 | Feature flag rollout automation | D5 | GA |
| 4 | Staging environment | D1 | Recommended |

---

## Security required

| # | Item | Checklist | Pilot impact |
|---|------|-----------|--------------|
| 1 | Penetration test | S6 | GA public internet |
| 2 | Disable demo OTP | A9 | **Real users** |
| 3 | Backup restore drill | B2 | Operations sign-off |

---

## RC hardening applied (this program)

| Change | Purpose |
|--------|---------|
| QA login → full role matrix in `rbac_service` | Prevents stale partial permission sync breaking Patrol/automation |
| Enrollment sticky actions | Wizard reliability + UX |
| KPI compact layout | Finance mobile overflow fix |

---

## Deployment recommendation

```
Pilot (now)     → mock mode OR staging + PI1 checklist
Staging         → API write parity for admissions/finance/SIS
Pre-GA          → RLS + pen test + backup restore drill
GA              → deploy pipelines + multi-tenant RLS
```

---

## Metrics

| Metric | Value |
|--------|-------|
| `flutter analyze` | 0 issues |
| `flutter test` | 1688 passed |
| Production checklist (app) | 96/100 |
| In-app readiness score | ~86 (ready with gaps) |

---

## Related

- `docs/PRODUCTION_SIGNOFF_REPORT.md`
- `docs/BACKUP_RECOVERY_ARCHITECTURE.md`
- `docs/PILOT_DEPLOYMENT_CHECKLIST.md`
