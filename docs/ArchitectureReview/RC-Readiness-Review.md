# RC Readiness Review — Akshara ERP v1.0

**Date:** June 2026  
**Scope:** v1.0 RC finalization (v8.0 → v10.4.2)  
**Verdict:** Code-ready — **deploy blocked** on staging Edge bundle

---

## Readiness Scores

| Dimension | Score | Notes |
|-----------|-------|-------|
| **Production readiness** | **93%** | All modules code-complete; live validation pending deploy |
| **Security readiness** | **94%** | RLS 213 probes, RBAC inventory 78 routes, audit on mutations |
| **Deployment readiness** | **72%** | Scripts complete; staging not deployed |
| **Test coverage** | **92%** | 1126+ tests; Phase 5 integration + contract parity |

**Overall RC readiness: 93%**

---

## Test Coverage Summary

| Category | Count | Status |
|----------|-------|--------|
| Flutter unit/widget/integration | 1126+ | Passing |
| Contract tests | 15+ modules | Passing |
| Security / RBAC | Route inventory + permission enum | Passing |
| Tenant isolation probes | 213 | Server-side |
| Deno handler tests | Onboarding, memories, promotion | Partial |

**Gaps (documented, not blocking RC code):** Live staging E2E, production SMS OTP, large CSV load test.

---

## Remaining Blockers

| # | Blocker | Owner | Resolution |
|---|---------|-------|------------|
| 1 | **Phase 5 Edge routes not on staging** | DevOps | `./scripts/deploy_staging.sh` |
| 2 | Production SMS provider for OTP | Ops | Wire Twilio/msg91 before parent go-live |
| 3 | Staging verify exit 0 not yet achieved | QA | Post-deploy run |

---

## Priority A Fixes (This RC Sprint)

| Fix | Status |
|-----|--------|
| Deploy script + verify chain | ✅ |
| RBAC inventory gaps (onboarding GET job, count sync) | ✅ |
| Stale `useApiRepositoriesProvider` missing Phase 4/5 flags | ✅ |
| Employee dashboard N+1 → single snapshot query | ✅ |
| Student 360 parallel SQL | ✅ |
| Operations Hub parallel SQL (v10.4.2) | ✅ |
| Deployment guide + env var documentation | ✅ |
| Production launch verify Phase 5 probes | ✅ |

---

## Priority B (Post-RC, Pre-Scale)

| Item | Recommendation |
|------|----------------|
| Parent hub Student 360 caching | Redis or edge cache |
| Analytics dashboard materialized views | Nightly refresh job |
| `image_picker` for memories mobile upload | v10.4.1 follow-up |
| CI pipeline for deploy_staging.sh | GitHub Actions |
| Promotion image generation | Document Engine track |

---

## Priority C (Future)

Universal org builder, salon/hospital verticals, Copilot image gen, public memory gallery.

---

## Security Review

| Area | Status |
|------|--------|
| RLS | 213 tenant isolation probes |
| RBAC | 78 routes inventoried; permission middleware on all |
| Audit | Mutations emit domain events; onboarding uses recordMutationAudit |
| Storage | Private bucket, signed URLs, tenant path prefix |
| OTP | Demo stub staging; production requires SMS |
| Onboarding imports | Preview/commit/rollback with audit |

---

## Performance Review

| Endpoint | Before | After |
|----------|--------|-------|
| Operations Hub | 7 sequential SQL | Parallel |
| Student 360 profile | 6 sequential SQL | Parallel |
| Student 360 timeline | 4 sequential SQL | Parallel |
| Employee intelligence dashboard | N × buildEmployee360 | Single JOIN query |

**Remaining:** Intelligence compute POST endpoints (batch CPU) — async job queue recommended at scale.

---

## Recommended Go-Live Sequence

1. **Deploy staging** — `export SUPABASE_ACCESS_TOKEN=... && ./scripts/deploy_staging.sh`
2. **Green gates** — `phase5_staging_verify.sh` exit 0, `production_launch_verify.sh` exit 0
3. **Pilot import** — 10-student CSV per `RealSchoolValidation.md`
4. **Parent OTP smoke** — imported parent phone login
5. **UAT sign-off** — `docs/Operations/UAT-Checklist-v1.0-rc1.md`
6. **Production deploy** — same script with production project ref
7. **Monitor** — `/health/operations`, audit ingestion, tenant probes
8. **Tag RC** — `v1.0-rc1` (already baseline; re-tag after deploy validation)

---

## Do Not Proceed Until

- [ ] Staging Phase 5 routes return 401 (not 404) on unauthenticated probe
- [ ] `phase5_staging_verify.sh` — 0 failures
- [ ] Pilot school CSV import committed successfully on staging

---

## Related Documents

- [Deployment-Guide.md](../Operations/Deployment-Guide.md)
- [RealSchoolValidation.md](../Releases/RealSchoolValidation.md)
- [Rollback-Checklist.md](../Operations/Rollback-Checklist.md)
- [v10.4.2-Production-Readiness.md](./v10.4.2-Production-Readiness.md)
