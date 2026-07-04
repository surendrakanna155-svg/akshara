# Full Live-Journey Certification — Akshara Pilot

**Date:** 2026-06-24
**Target:** Live VPS pilot — `https://akshara.veloraunisexsalon.com` (real edge + real Postgres)
**Auth:** Real OTP login → real JWT for each pilot persona (admin, teacher, parent), one login each
**Harness:** [`scripts/qa/live_cert_full_journeys.py`](../scripts/qa/live_cert_full_journeys.py)

## Result: **25 PASS / 0 FAIL / 0 BLOCKED — GATE: PASS**

One consolidated run that logs in each persona exactly once (so it never trips the
OTP rate limit) and exercises every core cross-persona journey end-to-end, no mocks.

| Area | Checks | Result |
|------|--------|--------|
| Identity / auth | login admin·teacher·parent, `/auth/me`, `/auth/permissions` (107) | **PASS** |
| School config | read + capability write-roundtrip (then restored) | **PASS** |
| SIS | student list read | **PASS** |
| Finance | dashboard read | **PASS** |
| Attendance | sessions read | **PASS** |
| RBAC | teacher denied attendance-correction (403) | **PASS** |
| Parent visibility | dashboard, exams, receipts reads | **PASS** |
| **Journey: fee → parent** | admin records collection → parent sees new receipt → collection cancelled (restored) | **PASS** |
| **Journey: results → parent** | exam → marks → process → verify → publish gate (403 without approval) → publish → parent sees `examResults` | **PASS** |
| **Journey: onboarding** | import preview → commit → rollback | **PASS** |

The deeper onboarding checks (student/parent provisioning, Aadhaar mask+hash, placeholder
generation) are covered separately in [`B7_ONBOARDING_LIVE_CERTIFICATION.md`](./B7_ONBOARDING_LIVE_CERTIFICATION.md) (10/10).

## Defect found & fixed during certification

**AI Copilot 500'd on session creation** (`violates check constraint
ai_copilot_sessions_assistant_type_check`). The code (`copilot_types.ts`) added
`parentGuidance` / `teacher` / `principal` assistant types, but no migration ever
widened the DB CHECK constraint (the Deno tests use a constraint-free fake DB, so it
was never caught). Fixed with **migration `20260715100000_ai_copilot_assistant_types.sql`**
(applied live + recorded in the ledger). After the fix, the principal Copilot returned a
real model reply in ~4.4s with no stub marker — see AI activation below.

## AI activation — verified live

- `OPENROUTER_API_KEY` is provisioned on the VPS edge (`.env.akshara`, wired via `env_file`);
  `AI_PROVIDER=openrouter`.
- Live check: created a `principal` copilot session → sent a prompt → received a genuine,
  dynamic model response (~4.4s, no `read-only stub` marker). AI is **real**, not fallback.

## Test-data hygiene

All journeys self-restore (capability write reverted, fee collection cancelled, onboarding
rolled back). Published exams cannot be unpublished via the API, so the cert's test exams
were removed directly from the DB after the run; post-run residual = 0.
