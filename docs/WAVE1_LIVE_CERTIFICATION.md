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

## AI status (corrected)
- **AI is LIVE via OpenRouter** — the edge has `AI_PROVIDER=openrouter` + `OPENROUTER_API_KEY` set (the owner configured it). The provider-flexible client resolves the key DB-first then env. No Anthropic key needed; an earlier note here wrongly said "safe-fallback / no key" (it only checked for an Anthropic key).
- Copilot verified live after fixing a session-create bug (below): `POST /copilot/sessions` → 201, `POST /…/messages` → 200 with a generated assistant reply.

## REQUIRES CREDENTIALS / OWNER (future waves)
- Firebase project (push notifications), S3/R2 (offsite backup).

## SECOND BUG FOUND & FIXED (copilot)
- `ai_copilot_sessions.title` is `NOT NULL`, but the create-session handler inserted `NULL` when the client omitted a title → **500 on every titleless session create**. Fixed: default the title to the assistant's label. Deployed + verified (201). Also noted: the `assistant_type` CHECK allows only `admissions/finance/sis/academic/communication`, so any future `principal`/`teacher` copilot type would 500 (handler-vs-DB mismatch) — flagged for a follow-up.

## FOUND & FIXED DURING CERTIFICATION (1)
- **Parent-experience router shadowing bug** (pre-existing): `routeParentExperience` (registered before `routeParent`) returned a hard 404 for any unmatched `/parent/experience/*`, making `/parent/experience/acknowledge` and `/parent/experience/hub` unreachable. **Fixed** (return `null` to continue the chain), redeployed to the edge, re-verified (acknowledge now reaches its handler). Commit `01d405c`.

## Deploy state verified
- Migration `20260714000000_school_configuration` applied (table + RLS + ledger). Edge rebuilt clean (`Listening on :8000`). Pre-deploy encrypted backup taken. `/health/ready` → `database:true`.

## Test-data hygiene
- Created CERT student + fee-structure rows → **deleted** (0 residual). Test-phone OTP cooldown was reset (staging phones only). Minor residuals: seed leave `lv_req_1` left `approved`; a few `cert-smoke` attendance-correction rows (harmless, staging).

## A4 — cross-persona spine journey (added)
**Fee → receipt → parent visibility: PASS (6/6)** — `scripts/qa/live_journey_fee_to_parent.py`.
Admin records a ₹500 collection against the child's live invoice (`POST /finance/collections` → 201) → **parent's `/parent/receipts` count goes 2→3** (parent sees the new receipt) → collection cancelled to restore. Proves write-by-staff → visible-to-parent end to end.
*Follow-up:* results → parent loop (enter marks → publish → parent sees) needs exam scaffolding; parent read side already green (`/parent/exams` 200).

**Verdict: the deployed Wave-1 system is certified for authenticated live-mode operation across auth, school-config, HR, SIS, finance, attendance, parent visibility, RBAC, and the fee→receipt→parent cross-persona spine.**
