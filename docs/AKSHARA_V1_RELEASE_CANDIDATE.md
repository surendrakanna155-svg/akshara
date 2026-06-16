# Akshara v1.0 Release Candidate

**Branch:** `release/v1.0-preprod`  
**Date:** 2026-06-16  
**Milestone:** M14 complete · Patrol certification in progress

---

## Release candidate summary

Akshara ERP v1.0 is a **pilot-ready release candidate** for school ERP with multi-school, multi-industry MVP, white-label, and smart configuration (FV-PLAT-14).

| Dimension | Status |
|-----------|--------|
| Roadmap M1–M13 | ✅ Complete |
| M14 Smart Configuration | ✅ Shipped |
| Static quality gates | ✅ Green |
| Patrol device certification | ⏳ 89-suite run in progress |
| Production SaaS GA | ⏳ Backend blockers remain |

---

## Answers

### 1. Is every planned feature implemented?

**Yes** — for roadmap scope M1–M13 plus M14 FV-PLAT-14. FutureVision partials (FV-01–06 depth, live API, FV-PLAT-01 employee system) are documented post-roadmap items, not missing milestones.

### 2. Is Smart Configuration implemented?

**Yes.** FV-PLAT-14 includes:

- Guided discovery wizard (`/school-config/discovery`)
- Capability flags (transport, hostel, library, inventory, alumni, HR, multi-branch, trust)
- Dynamic admin navigation filtering
- Management + parent dashboard adaptation
- Copilot school metadata (board, type, capabilities, branch count)

### 3. Is UX modernization complete?

**Plan complete; execution phased.** `docs/AKSHARA_UX_MODERNIZATION_PLAN.md` defines 4 phases. M14 shipped capability-driven dashboard filtering and per-role AI access. Full spacing/KPI polish is post-RC.

### 4. Are all Patrol suites certified?

**Not yet.** 10/89 device-certified from batch-1. Full `ERP_COVERAGE_MODE=full` regression running post-M14. See `docs/PATROL_CERTIFICATION_REPORT.md`.

### 5. Is Akshara ready for pilot deployment?

**Yes — with conditions.**

| Ready for | Condition |
|-----------|-----------|
| School ERP pilot (mock/demo) | ✅ Now |
| QA / demo builds | ✅ Now |
| Multi-school director demo | ✅ Now |
| Production SaaS GA | ❌ Server RLS, pen test, deploy pipelines |
| Full Patrol sign-off | ⏳ Await 89/89 green |

---

## Version metrics

| Metric | Value |
|--------|------:|
| ERP completion | ~99.5% |
| Vision completion | ~98% |
| `flutter test` | 1688 pass |
| Patrol suites registered | 89 |
| Protected routes | 120+ |

---

## Pilot deployment checklist

- [x] `flutter analyze` clean
- [x] `flutter test` green
- [x] Gap inventory complete
- [x] FV-PLAT-14 smart configuration
- [x] AI access modes per role
- [ ] 89/89 Patrol certified
- [ ] Staging API write parity (admissions, finance, SIS)
- [ ] Server RLS sign-off

---

## Recommended next steps

1. Complete Patrol full regression → update `PATROL_CERTIFICATION_REPORT.md`  
2. Pilot school onboarding via Smart School Configuration wizard  
3. Staging deploy with `ENABLE_API_MODE=false` feature flag  
4. Begin UX modernization Phase 1 (executive surfaces)
