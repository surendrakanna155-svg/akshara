# UX Review Demo — Akshara ERP (temporary, reversible)

A minimal demo for a manual UI/UX review of the **web app**. One login-able account
per role, linked into the existing staging school so every dashboard resolves.

> **Not production.** Everything runs against the isolated VPS test tenant
> `akshara_tenant_test` (NOT prod `akshara_db`). Prod edge, velora-salon and n8n
> are never touched. Fully removable with one command.

## Review site

**https://akshara.veloraunisexsalon.com/review/**

- Static production build of `web/`, served by the existing nginx + TLS cert.
- Its API calls go to a same-origin proxy `…/review-api` → the **test edge**
  (`akshara-edge-test`, `akshara_tenant_test` DB). It never calls the prod backend.

## Login credentials

Backend is in **dev-OTP mode**, so the login screen **auto-fills the 6-digit code** —
just enter the phone, tap send, then **Verify & continue**. Enter phones as 10 digits
(the backend adds +91).

| Role | Login phone | Lands on |
|------|-------------|----------|
| **Owner / Super Admin** | `9900100001` *(placeholder — change to your number, see below)* | Admin Hub |
| **Principal** | `9900100002` | Management dashboard |
| **Teacher** | `9900100003` | Teacher dashboard |
| **Finance** | `9900100004` | Finance dashboard |
| **HR** | `9900100005` | Admin Hub |
| **Office Staff** | `9900100006` | Admin Hub |
| **Parent** | `9900100007` | Parent dashboard (child = "UXR Student") |
| **Student** | `9900100008` | Student dashboard |

**School:** *Akshara Staging School* (org *Akshara Staging Organization*), academic year
**2026-27**. The demo student is enrolled in **Class 5, Section A**; the teacher is
assigned English in 5-A; the parent is the student's guardian.

### Set the Owner to your real number
```bash
scripts/uxr_review/uxr_review.sh set-owner +9198XXXXXXXX
```

## Create / remove (one command each)

Requires an SSH master to the VPS:
```bash
ssh -fN -M -S ~/.ssh/akshara-cm.sock -o ControlPersist=12h root@46.28.44.46
```

```bash
# create everything (stack + seed + web + nginx) — idempotent
scripts/uxr_review/uxr_review.sh create [+9198XXXXXXXX]

# remove everything completely (nginx → web files → DB rows → stop test stack)
scripts/uxr_review/uxr_review.sh destroy

# helpers
scripts/uxr_review/uxr_review.sh status     # what's up
scripts/uxr_review/uxr_review.sh verify      # log in as every role, check dashboards
```

## Files
- `uxr_review.sh` — orchestrator (create / destroy / status / verify / set-owner).
- `seed.sql` — inserts the 8 accounts + links. Idempotent. Refuses any DB ≠ `akshara_tenant_test`.
- `teardown.sql` — removes exactly the seeded rows (sentinel ids `de…` + markers). Idempotent.

## Prod-safety guarantees
- Seed/teardown SQL **abort** unless `current_database() = 'akshara_tenant_test'`.
- The orchestrator hard-codes the test DB and refuses `akshara_db`.
- All demo rows carry unique markers (`@uxreview.demo`, phone `+9199001000xx`,
  ids `de…`, admission `UXR-2026-0001`); teardown targets only those — verified 0
  collisions with existing data.
- nginx changes are 2 additive `location` blocks with a timestamped backup and
  `nginx -t` + auto-rollback; `destroy` removes them and reloads.

## What "never automatically in production" means here
Nothing here runs on a schedule or in CI. It only acts when you invoke `uxr_review.sh`,
and it can only reach the isolated test tenant. The prod stack has dev-OTP disabled, so
these demo phones cannot even authenticate against production.

## Assumptions (school onboarding is incomplete)
1. **Reused the existing staging school** (`a2000000-…0001`) as the container rather
   than building a new school from scratch — its tenant plumbing is already proven, so
   dashboards resolve. Only the 8 accounts + one student + minimal links were created.
2. **HR and Office Staff have no dedicated web dashboard yet** — the web app has no
   `hrManager`/`officeStaff` role, so both land on the generic **Admin Hub**
   (differentiated only by permitted module cards). This is a real product gap, not a
   seed limitation. Finance, Principal, Teacher, Student, Parent each have a dedicated
   dashboard.
3. **Owner phone is a placeholder** (`9900100001`) until you provide your number.
4. The demo student's supporting data (fees/attendance/marks) is intentionally minimal;
   dashboards that have no rows show their normal empty/awaiting states (by design — no
   fabricated data), which is itself valid to review.
