# Wave 1 — Authenticated Live-Mode Certification

**Date:** 2026-06-24 · **Target:** live VPS `https://akshara.veloraunisexsalon.com` · **Branch:** `feature/scope-trim-school-build` @ `01d405c`
**Method:** real OTP login per persona (allowlisted staging phones → OTP in response) + read **and** write workflow per domain + an RBAC denial probe. Harness: `scripts/qa/live_cert_wave1.py` (re-runnable).
**Result:** **19 PASSED · 0 FAILED · 1 BLOCKED.** Not route-existence — every check is an authenticated request with a real JWT.

## Personas (live `users` + memberships)
| Phone | Role | Used for |
|---|---|---|
| +919876543210 | schoolAdmin + organizationAdmin (school …0001) | config, HR, SIS, finance, attendance |
| +919876543213 | teacher (school …0001) | RBAC-denial probe |
| +919876543211 | parent | parent visibility |

## PASSED (19)
| Domain | Check | Evidence |
|---|---|---|
| Auth | OTP login × 3 personas | real OTP issued + verified → JWT |
| Auth | JWT + `/auth/me` | HTTP 200, role=schoolAdmin |
| Auth | `/auth/permissions` | HTTP 200, **107 permissions** loaded |
| School config | read | `GET /school-config` 200 |
| School config | **write (roundtrip)** | `PUT` toggled `library` true→false, GET confirmed, then restored |
| HR | read | `GET /hr/leave` 200 |
| HR | **write — leave approval e2e** | `POST /hr/leave/lv_req_1/approve` → status flipped to **approved** (re-read verified) |
| SIS | read | `GET /sis/students` 200 |
| SIS | **write** | `POST /sis/students` → **201** (test row, since cleaned) |
| Finance | read | `GET /finance/dashboard` 200 |
| Finance | **write** | `POST /finance/fee-structures` → **201** (test row, since cleaned) |
| Attendance | read | `GET /attendance/sessions` 200 |
| Attendance | **write** | `POST /attendance/corrections` 200 (admin / `manageSis`) |
| RBAC | teacher denied | teacher `POST /attendance/corrections` → **403** (correct enforcement) |
| Parent visibility | reads | `GET /parent/dashboard`, `/parent/fees`, `/parent/attendance` all 200 |

## FAILED (0)

## BLOCKED (1)
| Domain | Check | Reason |
|---|---|---|
| Parent | write — book-distribution acknowledge | Route/auth/validation **proven** (reaches handler, returns `400 studentId+distributionId required`). Completing it needs a seeded book-distribution for the child. Not a defect; deferred to feature E2E. |

## REQUIRES CREDENTIALS / OWNER (not part of this auth cert, tracked separately)
- `ANTHROPIC_API_KEY` on the edge → copilot/parent-insights run in safe-fallback until set (verified: `AI_PROVIDER` set, no key).
- Firebase project (push), S3/R2 (offsite backup) — future waves.

## FOUND & FIXED DURING CERTIFICATION (1)
- **Parent-experience router shadowing bug** (pre-existing): `routeParentExperience` (registered before `routeParent`) returned a hard 404 for any unmatched `/parent/experience/*`, making `/parent/experience/acknowledge` and `/parent/experience/hub` unreachable. **Fixed** (return `null` to continue the chain), redeployed to the edge, re-verified (acknowledge now reaches its handler). Commit `01d405c`.

## Deploy state verified
- Migration `20260714000000_school_configuration` applied (table + RLS + ledger). Edge rebuilt clean (`Listening on :8000`). Pre-deploy encrypted backup taken. `/health/ready` → `database:true`.

## Test-data hygiene
- Created CERT student + fee-structure rows → **deleted** (0 residual). Test-phone OTP cooldown was reset (staging phones only). Minor residuals: seed leave `lv_req_1` left `approved`; a few `cert-smoke` attendance-correction rows (harmless, staging).

**Verdict: the deployed Wave-1 system is certified for authenticated live-mode operation across auth, school-config, HR, SIS, finance, attendance, parent visibility, and RBAC.**
