# CRITICAL SECURITY FINDING — live environment

**Raised:** 2026-07-29 · **Status:** ⛔ PAUSED FOR OWNER REVIEW
**Host:** `https://akshara.veloraunisexsalon.com` (the deployed pilot)
**Method:** unauthenticated read-only HTTP GET. No mutation, no auth attempt,
no real data submitted. Nothing was changed.

## Verification requested, and what it found

The instruction was to determine whether API-105/106/107/108 are *confirmed on
the live environment* or merely inferred from configuration. **They are
confirmed.** Reproduced directly, from an ordinary internet client, with no
credentials:

```
GET /health/tenant-access  -> 503  {"status":"degraded","connection":{"ok":true,
                                    "role":"erp_tenant","bypassRls":false},
                                    "isolation":{"pass":false,...}}
GET /health/backup         -> 200  {"status":"ok","maxAgeHours":26,
                                    "lastBackup":{"kind":"nightly","ageHours":3.1,"bytes":19...}}
GET /health/operations     -> 200  {"status":"ok","connection":{...},"snapshot":{...}}
GET /health/providers      -> 200  {"status":"ok","storage":{"bucket":"sch..."}}

GET /audit/events                  -> 404   (expected 401)
GET /identity/roles                -> 404   (expected 401)
GET /attendance/register/monthly   -> 422   (expected 401 — it answered
                                             "classLabel is required" instead)
```

## Two confirmed findings

**1. Unauthenticated operational disclosure (API-107).** Four `/health/*`
endpoints answer the public internet with backup age and size, database role,
RLS-bypass status, storage bucket name, and the tenant-isolation verdict.

**2. No central auth chokepoint (API-105).** `/attendance/register/monthly`
performs *validation* before authentication — it tells an anonymous caller what
parameter it wants. `eng4_5_forced_auth_test` asserts ICA-F1 returns 401 on
exactly these paths, and it passes. **That is a property of this repository,
not of the deployed build.** The running system is behind the code, and no test
in this repo can detect that gap.

## And the finding that makes this urgent

`/health/tenant-access` currently reports **`status: degraded`, `isolation.pass:
false`**. The pilot's own tenant-isolation self-check is **failing right now**,
and that failure is readable by anyone.

Cycle-1 evidence (API-108) attributes this to 4 student-scope probes:
school↔school and parent↔child isolation both pass, so on that evidence this is
a **persona boundary failure, not a cross-tenant leak**. That distinction is
material and should be verified, not assumed, before any conclusion is drawn.

## What I could NOT determine — stated plainly

**Whether this instance holds real school data.** No probed endpoint exposes a
school count or any record, and I did not attempt authentication or any
mutation to find out. That question decides the severity, and it is the owner's
to answer:

- **Real pupil/parent data present** → treat as a live exposure, act before
  anything else in the remediation program.
- **Demo/seed data only** → serious, but schedulable with Phase 1.

## Why the program is paused here

The instruction was explicit: confirmed on a live environment → classify
Critical, document the evidence, and pause for owner review before any
infrastructure decision. The findings are confirmed. Infrastructure changes
also need SSH, which is owner-bound.

**No infrastructure action has been taken.** No remediation wave has started.

## Owner decisions required

1. **Does this instance hold real school data?** Decides urgency.
2. **Authorise the fix** — `/health/*` requires a token, and the auth chokepoint
   must precede route dispatch. Both are deploy-time changes.
3. **Investigate `isolation.pass: false`** — is it the 4 student-scope probes
   (persona boundary) or something wider?
4. Note that the `/health/*` guard keys off the **same `APP_ENV` flag** that
   controls whether login OTPs appear in the response body. If that flag is
   wrong in production, both fail together — so check the flag, not just the
   endpoints.

## Explicitly NOT concluded

This is **not** a declaration that the pilot has been breached. There is no
evidence of exploitation, and none was sought. The finding is that the exposure
exists and that the isolation self-check is red — both facts, neither an
incident report.

---

## Remediation attempt 1 — REVERTED (2026-07-29)

Owner authorised the fix. The attempt died mid-edit on an infrastructure error
(connection closed), leaving four modified files plus one new file. The state
**typechecked but broke the test suite** — `qa_r_010_health_routes_test.ts`
failed type-checking because a dependent test was not updated.

**Reverted to baseline** rather than committed. Half-finished security code that
compiles is more dangerous than none: it reads as done. Baseline re-verified —
`deno check` clean, `qa_r_010_health_routes_test.ts` 11 passed / 0 failed, tree
clean. **No fix is in place. The live exposure stands.**

### What the attempt established — do not re-derive

1. **`supabase/functions/_shared/internal_health_auth.ts` already exists.** The
   authorisation mechanism for `/health/*` is present in the codebase and simply
   is not enforced on these routes. The fix is to enforce an existing control,
   not to build one — which makes it smaller and safer than it first appeared.
2. It judged a **route-table split** worthwhile (`_shared/health_routes.ts`), so
   health routes are declared in one place and cannot be added without passing
   through the auth decision. That is the right shape for the guard.
3. It was touching `auth_handlers.ts` and `api/app.ts` together — consistent
   with moving authentication ahead of route dispatch (TASK 1).
4. **Lead on `isolation.pass=false`:** it found a misleading comment on the SIS
   create probe — the comment says INSERT, the SQL is a SELECT. A probe whose
   comment and query disagree is a strong candidate for a probe that does not
   test what it claims. Start there, and do NOT assume the certification's
   attribution (4 student-scope probes) is correct.

### Sequencing note for the retry

Update `qa_r_010_health_routes_test.ts` **in the same change** as the route-table
split. That single omission is what made this attempt unshippable.

### Status

- Root cause: **partially established** (see above), not yet confirmed
- Fix implemented: **none — reverted**
- Verification evidence: baseline restored and re-verified
- Regression coverage: **not yet added**
- Deployment status: **not deployed; live exposure unchanged**

---

## ROOT CAUSE — established 2026-07-29. It is not a code defect.

**The application code is correct and already fails closed.**

`requireInternalHealthAccess` (`_shared/internal_health_auth.ts`) is invoked as
the FIRST statement of all five sensitive handlers (`_shared/tenant_handlers.ts`
lines 32, 102, 155, 195, 284) — before any probe runs. It uses a constant-time
compare, and when no token is configured it returns **403 in production**.

The deduction is airtight from the code plus the observed live behaviour:

1. A token configured + no header sent ⟹ **403**. We sent no header and got
   **200** ⟹ `INTERNAL_HEALTH_TOKEN` is **not configured**.
2. No token configured + `environment === "production"` ⟹ **403**. We got
   **200** ⟹ `config.environment` is **not `"production"`**.
3. `config.environment = Deno.env.get("APP_ENV") ?? "development"` (`config.ts:91`).

⟹ **The deployed pilot is running with `APP_ENV` unset or not `"production"`.**

### Why this is worse than the health endpoints alone

`APP_ENV` is the master production switch. The same flag gates
`canReturnOtpInResponse` (`auth_handlers.ts:112-117`), which short-circuits on
production *before* consulting the pilot allowlist or the dev flag. With
`APP_ENV` not production, **that OTP protection is also off**, and any other
production-only hardening with it. The health exposure is a symptom; the flag is
the defect.

This also explains API-105: the forced-auth behaviour the repo test asserts is
almost certainly gated the same way. One misconfiguration, several symptoms.

### The fix is a deployment action, not a code change

Nothing in this repository can close this exposure. It requires, on the VPS:

1. Set `APP_ENV=production` in `/opt/akshara/deploy/akshara-vps/.env.akshara`
2. Set `INTERNAL_HEALTH_TOKEN` to a high-entropy value in the same file
3. **RECREATE** the edge container — `docker compose ... up -d --no-deps
   --force-recreate akshara-edge`. A `restart` does **not** re-read env.
4. Re-run the verifier below; it must exit 0.

⚠️ Setting `APP_ENV=production` will also enable `requireTls` and
`requireAuthentication`, and will disable demo-auth paths. That is correct and
intended — but it is a behaviour change on a running pilot, so run the verifier
immediately afterwards and confirm the app still logs in.

### Guard shipped — `deploy/akshara-vps/verify-deployment-security.sh`

Probes the DEPLOYMENT from outside with no credentials, because the repo test
passing was never evidence about the running system. Run after every deploy.

**Executed against the live pilot 2026-07-29 — 8 checks FAILED**, exactly
matching the confirmed findings:

```
[1] Internal health endpoints reject anonymous access
  FAIL  /health/tenant-access -> 503      FAIL  /health/operations -> 200
  FAIL  /health/providers     -> 200      FAIL  /health/backup     -> 200
  FAIL  /health/storage       -> 200
[2] Public liveness discloses nothing sensitive
  PASS  /health exposes no internals
[3] Auth precedes validation on protected routes
  FAIL  /attendance/register/monthly -> 422 (validated BEFORE authenticating)
  FAIL  /audit/events -> 404   FAIL  /identity/roles -> 404
RESULT: 8 check(s) FAILED
```

This script is the regression coverage. It fails today and must pass after the
deployment fix — that is the acceptance test.

### Status

- **Root cause:** ✅ established — `APP_ENV` not `"production"` on the deployment
- **Fix implemented:** ⛔ owner/infra action; no code change can do it
- **Verification evidence:** ✅ verifier run against live, 8 failures recorded above
- **Regression coverage:** ✅ `verify-deployment-security.sh`, fails today
- **Deployment status:** ⛔ NOT deployed — **live exposure unchanged**
