# NIKSHA OS v1.0.0 — RC Closure Report

**Branch:** `release/v1.0-playstore` · **Date:** 2026-07-28
**Scope:** engineering closure only. Product Certification has NOT begun.

---

## Verdict

**Engineering RC: COMPLETE. Zero open P0s.**

Every P0 raised in this cycle is closed. Publication remains owner-gated —
Play Console account, domain, company registration, keystore password.

---

## Gate status (measured on the merged tree, not inherited)

| Gate | Result |
|---|---|
| `flutter analyze --fatal-infos` (CI Gate 1's real bar) | **No issues found** |
| Flutter suite | **4409 passed · 1 skipped · 0 failed** |
| Backend (`deno test supabase/functions/`) | **4165 passed · 0 failed · 3 ignored** |
| `deno check supabase/functions/api/index.ts` | **clean** |
| Goldens | **178 / 178** |
| Release AAB | **builds** — 132.2 MB; real arm64 download **57.9 MB** |
| Release signing | **fail-closed verified both ways** — signs with a keystore, refuses without |
| App on device | boots, signs in, navigates (Android 16 / API 36) |

Session baseline was 4316 Flutter tests. Net +93.

---

## RC items completed

### P0
1. **Support pipeline** — the app displayed a fabricated `SUP-####` for reports
   that were never sent. Now truthful in both directions: real server id on
   success, and on failure no reference at all, an honest message, retry, and a
   draft-persisted form. The lane **probed the live backend** rather than
   guessing — a `422 VALIDATION` body whose string exists in exactly one file
   proved the support router is deployed — so `SUPPORT_API_ENABLED` is now set
   with that evidence recorded inline.
2. **Audit retention** — the published policy promised deletion that no code
   performed, and cited 3 years where the config default was 730 days.
   Reconciled per claim: audit documented as append-only and immutable (what the
   code does, and defensible for a legal record), 24-month comms and 12-month
   diagnostics claims withdrawn, read-only sizing route added, operator purge
   script shipped dry-run-by-default behind `--force`.
3. **Principal Morning Brief** — had zero production call sites. Decided
   intentionally unfinished and marked NOT WIRED with the four gaps that must
   close first; fixed a comment claiming a verification that had not happened
   and a route that would have silently bounced a principal to `/admin`.
4. **Event architecture claims** — corrected the rollout checklist and
   `BackendArchitecture.md` §10. The event **log** is certified; event-driven
   **propagation** is explicitly not.

### P1
5. **AuditUploadQueue** — unbounded and never purged; on parent/student devices
   (permanent 403 from a staff-scope-only ingest) it grew for the life of the
   install. Now capped at 500, self-healing on enqueue, with drops **counted**
   because silently losing audit data is itself an audit defect.
6. **Request identity** — the only durable diagnostic could not be narrowed to a
   user. Now carries userId/sessionId/tenantId/schoolId/scope from the
   **verified JWT**, plus a `tokenState` so a forged token degrades honestly.
   `student_id` and `child_ids` deliberately excluded.
7. **Attendance server audit** — a parent's correction request could be approved
   or rejected with no trail. All three mutations now audit in-transaction with
   real before→after. The false completeness-test exemption is withdrawn and
   pinned.

### Earlier in this cycle
Two security P0s (five routes failing open; a student able to open the
school-wide medical console) · a WCAG P0 whose test asserted the wrong threshold
· honest-state violations · a reliability defect that silently killed durability
forever · the hosted privacy policy · the analyzer gate · the AI-button collision
· a token/OTP leak in the dev lane · unbounded container logs.

---

## Counts

| | Open | Closed this cycle |
|---|---|---|
| **P0** | **0** | 11 |
| **P1** | 9 tracked, none release-blocking | 20+ |

---

## Remaining known issues (all tracked, none blocking)

**Verification boundaries — stated, not papered over:**
- Backend tests prove spec shape and write-path against a spy DB. **Live-DB
  persistence assertions are pending a Postgres lane** — this harness has none.
- Whether migrations `20260920000000–050` are applied on the live pilot DB is
  unverified (SSH is owner-bound). Now fail-safe: absent tables produce an
  honest "not sent", not a fake ticket.

**Tracked P1s:** per-student before/after on the pilot marking path ·
`applyAttendanceCorrection` not in the mutation catalog · two attendance routes
missing from `rbac_route_inventory.ts` · `GET /audit/retention` not yet in the
route inventory · `docs/legal/CHANGELOG.md` needs the retention-policy 1.0→2.0
entry · error-storm throttle on `FlutterError.onError` (deferred: behaviour
change on the global error handler, not worth taking unverified this late) ·
`MoreNavSheet` filters on hidden-route scope but never role/permission ·
screenshot-upload retry from the detail screen · 5 more store screenshots.

**Not certified, by design:** event-driven propagation. The log is production
grade; the bus is not, and no document now claims otherwise. Flipping the status
literal without first installing the drain cron would strand every event —
**scheduler first, status second, separate releases.**

---

## Release readiness

- **Engineering:** complete. 0 P0.
- **Build:** release AAB builds; signing fail-closed in both directions.
- **Store assets:** listing rewritten for NIKSHA OS, feature graphic generated,
  3 real device screenshots (Play minimum is 2; 5 more recommended).
- **Legal:** pack generated from source with a fail-closed publish gate.
  Currently **PUBLISH_BLOCKED** on owner placeholders — by design.

## Owner actions — the only remaining work

1. **Confirm the upload keystore password.** Free to fix today; terminal after a
   first upload without Play App Signing.
2. **Buy the domain** → fills the legal placeholders → unblocks the publish gate.
3. **Register the company** → registered address + governing law.
4. **Name a Grievance Officer** (legally required in India).
5. **Create the Play Console account** and complete identity verification.
6. Confirm migrations `20260920000000–050` are applied on the live pilot DB.

---

**Engineering is complete. Product Certification has not begun and is a separate
phase.**
