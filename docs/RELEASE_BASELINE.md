# Release Baseline — v1.0-preprod

**Branch:** `release/v1.0-preprod`  
**Date:** June 2026  
**Stabilization commit:** `28e7ec0`  
**Program:** Akshara Release Stabilization (Post M13)

---

## Completion metrics

| Metric | Value |
|--------|-------|
| ERP completion | ~99.5% |
| Vision completion | ~98% |
| Intelligence | ~96% |
| Copilot | ~97% |
| Multi-school | ~92% |
| Milestones M1–M13 | ✅ Complete |

---

## Quality gates (baseline)

| Gate | Result |
|------|--------|
| `flutter analyze` | 0 issues |
| `flutter test` | **1646** passing (~1 skipped) |
| Patrol workflow files | 79 |
| Patrol full suite targets | 78 (+ 1 smoke in fast mode) |
| Protected routes | 120+ |

---

## Audit scores (post-M13)

| Audit | Score | Document |
|-------|------:|----------|
| Platform | 94/100 | `FINAL_PLATFORM_AUDIT.md` |
| UX | 88/100 | `FINAL_UX_AUDIT.md` |
| Workflow | 90/100 | `FINAL_WORKFLOW_AUDIT.md` |
| Production | 88/100 | `FINAL_PRODUCTION_AUDIT.md` |
| Production checklist (app) | 96/100 | `ProductionReadinessChecklist.md` |

---

## Release scope

- **In scope:** School ERP (11 modules), mobile apps, intelligence, multi-school, platform ops, multi-industry MVPs
- **Out of scope for v1.0-preprod:** New roadmap features; backend RLS GA; pen test; deploy pipelines

---

## Related

- `docs/AKSHARA_V1_FINAL_STATUS.md`
- `docs/FULL_REGRESSION_REPORT.md`
- `docs/PILOT_READINESS_REPORT.md`
