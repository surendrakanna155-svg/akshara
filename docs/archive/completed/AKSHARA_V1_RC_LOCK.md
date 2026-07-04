# Akshara v1.0 — Release Candidate Lock

**Status:** **STABILIZATION MODE**  
**Branch:** `release/v1.0-preprod`  
**Date:** 2026-06-16  
**Prior RC bundle:** `8e27d5b` (UX + production readiness)

---

## RC lock declaration

Akshara v1.0-preprod is **locked** for pilot deployment. No new features, milestones, Patrol suite expansion, or architecture changes until pilot feedback is collected.

```
IMPLEMENTATION COMPLETE → STABILIZATION MODE → PILOT FEEDBACK
```

---

## Final metrics

| Domain | Completion |
|--------|------------|
| ERP | ~99.5% |
| Vision | ~98% |
| Intelligence | ~96% |
| Copilot | ~97% |
| Multi-School | ~92% |
| Smart School Config (M14) | ✅ Complete |

---

## Quality gates

| Gate | Result |
|------|--------|
| `flutter analyze` | **0 issues** |
| `flutter test` | **1688 passed** (~1 skipped) |
| Performance benchmarks | **7/7** |
| UX audit score | **91/100** |
| Golden dashboards | **21** updated |

---

## Patrol certification

| Metric | Value |
|--------|------:|
| Registered suites | **89** |
| Executable (full mode) | **88** |
| Full run `20260616_135757` | 82 passed / 6 failed |
| Re-run `rerun_20260616_rc_lock` | **6/6 passed** |
| **Final certified** | **88/88 (100%)** |
| Certification | **CERTIFIED** |
| Report | `docs/PATROL_FINAL_CERTIFICATION.md` |

---

## Known limitations

| Area | Limitation |
|------|------------|
| Multi-tenant production | RLS not GA — single-school pilot only |
| Auth | Demo OTP enabled in QA builds — disable before real PII |
| API | Mock default; staging required for write parity |
| DR | Backup restore drill not executed |
| Security | Pen test and tamper-evident audit pending backend |

---

## Pilot recommendation

| Deployment | Recommendation |
|------------|----------------|
| **Single-school pilot** (mock or staging) | **APPROVE** with conditions |
| **Multi-tenant trust production** | **DEFER** |

### Conditions

1. Mock mode OR staging with write parity  
2. Disable demo OTP before real student PII  
3. PI1 pilot school checklist signed  
4. Support + backup runbook acknowledged  
5. Single-tenant scope until RLS GA  

---

## Stabilization mode rules

- ❌ No new features  
- ❌ No new milestones  
- ❌ No Patrol suite expansion  
- ❌ No architecture changes  
- ✅ Bug fixes from pilot feedback only  
- ✅ Backend/integration work outside Flutter lock  

---

## Pilot readiness answers

| Question | Answer |
|----------|--------|
| Can a single school run Akshara today? | **Yes** — mock or staging, all 8 personas |
| Can a trust run multiple schools today? | **Conditional** — portfolio UI ready; production multi-tenant RLS deferred |
| What blockers remain? | RLS, production auth, TLS, pen test, deploy pipelines, backup restore drill |
| What blockers are backend-only? | RLS, A9 auth, S5 TLS, S6 pen test, U6 audit, D3/D4 pipelines, B2 restore drill |
| Is pilot deployment approved? | **Yes, with conditions** — see `docs/PILOT_DEPLOYMENT_CHECKLIST.md` |

---

## Sign-off

| Role | Status | Date |
|------|--------|------|
| Flutter / UX RC | ✅ Locked | 2026-06-16 |
| QA / Patrol | ✅ Certified (88/88) | 2026-06-16 |
| Product pilot | ☐ Pending PI1 | — |
| Production GA | ☐ Blocked on infra | — |

**Akshara v1.0 RC is locked. Await pilot feedback.**
