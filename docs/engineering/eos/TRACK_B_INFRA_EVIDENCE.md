# Track B Infra Evidence — Nightly Backup + Scheduled-Broadcast Cron

**Date:** 2026-07-09
**Scope:** P0 infra tail (resumed now that VPS access is live) — verify/additively-fix (1) nightly
DB backup, (2) COM-4 scheduled-broadcast cron trigger.
**Method:** Read-only diagnosis first on the shared production VPS (`root@46.28.44.46`), Akshara
containers/files only. One additive, reversible manual-backup run for proof; zero edits to any
existing crontab line, script, or non-Akshara resource (velora-salon / n8n / redis untouched).
**Base commit (worktree):** `d8482029bb865eaf86a9b9d9812e3b26b4df629c` (worktree was behind this;
`git reset --hard d8482029` was run to align, per task instructions — no local changes were lost,
`git status` was clean beforehand).

---

## TASK 1 — Nightly database backup

### Verdict: **GREEN — already fully working, scheduled, and monitored.** No fix needed.

The task brief named legacy scripts (`/root/run_backup.sh`, `setup_auto_backup.sh`,
`setup_production_backup.sh`, `fix_production_backup.py`, `/root/backup.log`) as "the" backup
tooling to check. Diagnosis found those are **stale/superseded** (dated Oct 2025; `/root/backup.log`
last written 2025-10-06 and its final lines are a Django `ImportError` from a mis-pointed
velora-style script — dead, not cronned, not referenced anywhere in the current crontab).

The **real, current** production backup system lives at `/opt/akshara/backup/` (also checked into
this repo at `deploy/akshara-vps/backup/`), installed via `install-ops-cron.sh`, and is already
fully wired:

- **Cron (already present, already Akshara-namespaced):** `/etc/cron.d/akshara-ops`
  ```
  # Akshara ops — backups + restore drill. Managed by install-ops-cron.sh; edits overwritten.
  15 2 * * *   root   /opt/akshara/backup/akshara-backup.sh >> /var/log/akshara/backup.log 2>&1
  30 3 2 * *   root   /opt/akshara/backup/akshara-restore-drill.sh >> /var/log/akshara/drill.log 2>&1
  ```
- **What it does** (`/opt/akshara/backup/akshara-backup.sh`): `docker exec akshara-postgres
  pg_dump -Fc` piped straight into `openssl enc -aes-256-cbc -pbkdf2` (plaintext dump never touches
  disk), writes to `/opt/akshara/backup/store/`, records a row in `ops_backup_runs`
  (kind/status/bytes/sha256/duration/offsite) so `/health/backup` and the ledger stay authoritative,
  applies grandfather-father-son retention (7 daily / 4 weekly / 12 monthly), flock-guarded against
  overlap.
- **Log evidence (`/var/log/akshara/backup.log`):** unbroken nightly `SUCCESS` at 02:15 UTC every
  day from 2026-07-02 through **2026-07-09 (today)**, sizes growing steadily (~1.34 MB, expected for
  this pilot's data volume), each with a distinct sha256.
- **Ledger evidence (`ops_backup_runs`, last 10 rows queried live):** every run since 2026-06-26 is
  `status='success'`, `encrypted=true`; kinds correctly rotate nightly/weekly(Sun)/monthly(1st).
- **`/health/backup` (live, queried via `curl https://akshara.veloraunisexsalon.com/health/backup`):**
  ```json
  {"status":"ok","maxAgeHours":26,"lastRunFailed":false,
   "lastDrill":{"status":"success","tablesChecked":184,"rowsSampled":17,
                "finishedAt":"2026-07-02T03:30:09Z"},
   "offsiteWarning":true}
  ```
- **Restore-drill mechanism (separate from our manual test) is itself proven working**: the monthly
  cron already ran for real on 2026-07-02, restoring the prior night's dump into a throwaway
  `akshara_db_drill` database and validating 184 tables / 4 orgs / 13 users, logged to
  `/var/log/akshara/drill.log.1`.

### Proof-of-restore (this session, additive + fully cleaned up)

Ran the *existing* script by hand to prove the live pipeline end-to-end right now (not just
historically): `/opt/akshara/backup/akshara-backup.sh manual` →
`akshara_db_20260709T073015Z_manual.dump.enc`, 1,345,168 bytes, SHA256
`d6cfcf9650815f42f84560a79e4cbdeb2041fa97779345bcf1d6a53da9902de8`, ledger + `/health/backup` both
picked it up immediately (`lastBackup.ageHours: 0`).

Verified it is genuinely **restorable-shaped**: decrypted with the existing key
(`openssl enc -d -aes-256-cbc -pbkdf2 -pass file:/opt/akshara/backup/secret.key`), copied the
plaintext dump into the `akshara-postgres` container, ran `pg_restore --list`:

```
; Archive created at 2026-07-09 07:30:15 UTC
;     dbname: akshara_db
;     TOC Entries: 2388
;     Format: CUSTOM
;     Dumped from database version: 17.6
;     Dumped by pg_dump version: 17.6
```

2,388 valid TOC entries — a structurally sound, restorable `pg_dump` custom-format archive.
**Cleanup:** the decrypted plaintext copy was `rm -f`'d from both the host and the container
immediately after the `pg_restore --list` check (no plaintext DB dump was left anywhere). The
manual `.enc` artifact itself was left in place inside the real `/opt/akshara/backup/store/`
directory — per the task's own instruction ("clean up... if it's outside the real backup dir"),
since it landed via the production script inside the real store dir (consistent with ~10
pre-existing, never-pruned manual backups already sitting there from admin testing in June), it was
left as-is; it is a legitimate extra restore point, not clutter requiring removal.

### Remaining known gap (not fixed — needs owner input, not a silent fix)

**Off-site copy is not configured** (`RCLONE_REMOTE` empty in `backup.env` → every log line and the
health check flag `offsiteWarning:true`/`offsite:false`). This is the "1" in 3-2-1 and matches
**P0-INFRA-1** from the DR/RPO decision record, which explicitly deferred off-site backup "until the
owner opens the [VPS] lane" (`dr-rpo-acceptance-decision` memory, 2026-07-04). That lane is open now,
so this is unblocked, but wiring a real off-site destination (e.g. Cloudflare R2 / S3-compatible
bucket) requires **new credentials the owner must provision** and an edit to the existing
`backup.env` (existing config) — out of scope for an autonomous additive change per this task's
guardrails. **Flagged for owner sign-off; local RPO itself (~24h nightly, already accepted) is
unaffected and green.**

No cron line was added or changed for Task 1 — none was needed.

---

## TASK 2 — Scheduled-broadcast / reminder cron (COM-4)

### Verdict: **RED — confirmed absent in production; safe additive fix is NOT possible without a
code or credentials decision that needs owner/dev sign-off.** Not fixed this session; documented
precisely so it can be actioned deliberately.

### What's confirmed present (backend, already built and correct)

- Route: `POST /communications/broadcasts/run-scheduled` →
  `supabase/functions/_shared/communication/communication_router.ts:76-78` →
  `handleRunScheduledBroadcasts` in `communication_handlers.ts:569-594` →
  `runDueScheduledBroadcasts` in `communication_service.ts:545-591`.
- `scheduleBroadcastMessage` / `claimDueScheduledBroadcasts` (`FOR UPDATE SKIP LOCKED`, no
  double-send) are real and tested; `comm_broadcasts.scheduled_at` is live and written by the client
  schedule-send UI. Confirmed live in the production DB: 4 organizations exist, 0 currently
  overdue-but-unprocessed scheduled broadcasts (no active incident right now — but any org that
  schedules one will find it silently never fires, since nothing ever calls the endpoint).
- Already flagged as a known, owner-deferred residual in the repo itself — this is not a surprise
  finding, it's the exact gap the roadmap already named:
  `docs/roadmap/NEXT_ACTIVE_WAVE.md` (P1-PROD-15): *"COM-4 ... only the cron trigger to POST
  `/communications/broadcasts/run-scheduled` remains = live-lane/deploy"*;
  `docs/engineering/eos/EOS_RUN_LEDGER.md:69,151` and `docs/execution/IMPLEMENTATION_PROGRESS.md:137`
  say the same ("owner-deferred").

### Diagnosis — confirmed absent everywhere it could plausibly live (read-only checks)

- `crontab -l` (root): only velora's `send_scheduled_campaigns` / `scheduled_backup`, plus
  `cleanup_redis_chat_memory.sh` / `monitor_redis_memory.sh`. **No akshara broadcast/reminder line.**
- `/etc/cron.d/*`: only `akshara-ops` (backup, above) and `akshara-watchdog` (health monitoring,
  every 5 min) are Akshara's. **Nothing hits `/communications/broadcasts/run-scheduled`.**
- `systemctl list-timers --all`: only stock Ubuntu/system timers (apt, fstrim, sysstat, certbot,
  etc.) — nothing Akshara-related.
- **n8n** (`root-n8n-1`, shared with velora — inspected read-only via `n8n export:workflow --all`,
  export file deleted immediately after inspection): all 27 workflows are either velora-salon
  automations or a personal AI-agent stack (`ai_finance`, `ai_Reminder Engine`, `ai_Daily Briefing
  Engine`, etc.). **Zero workflows reference Akshara, broadcasts, or communications.**

### Why this can't be a simple "add one curl-cron line" additive fix

`handleRunScheduledBroadcasts` requires the **standard, full user-auth path** — same as every
regular business route, with no cron/service exemption:

```ts
// communication_handlers.ts:573-576
const auth = await authenticateRequest(req, config);
if (!auth.ok) return auth.response;
const denied = requirePermission(auth.claims, "manageCommunications");
```

`authenticateRequest` (`permission_middleware.ts:20-48`) needs a **live** app-issued access-token JWT
(HS256, `JWT_SECRET` — the app's own signing secret, *not* `SUPABASE_SERVICE_ROLE_KEY`), and then
`assertSessionValid` (`session_validation.ts:87-141`) re-checks the `sessions` row for
`claims.session_id` is **not revoked** and the org/school membership's `permissions_version` still
matches. Access tokens are short-lived — `ACCESS_TOKEN_TTL_SECONDS` defaults to 900s (15 min)
(`config.ts:94`). And `runDueScheduledBroadcasts` claims broadcasts scoped to **one**
`claims.tenant_id` per call (`communication_service.ts:551`) — there is no "all orgs" mode, so even a
valid caller only drains their own org per request (4 orgs currently live → 4 calls needed, one per
org, each independently authenticated).

There **is** a precedent internal-secret pattern in this codebase (`x-internal-health-token` /
`INTERNAL_HEALTH_TOKEN`, `internal_health_auth.ts:5-25`), already used by the existing
`deploy/akshara-vps/monitoring/akshara-watchdog.sh` cron to hit `/health/*` endpoints every 5
minutes — but it is wired **only** to health probes (`tenant_handlers.ts:24,94,163,203,300`), not to
`run-scheduled`, and `INTERNAL_HEALTH_TOKEN` isn't even present in the edge container's real env
file (`deploy/akshara-vps/.env.akshara.example` has no such key; it only lives in the separate
`monitoring.env` that the watchdog script itself sources).

So a production-safe cron for COM-4 needs **one** of two real changes, neither of which is "purely
additive ops wiring" and both need owner/dev sign-off before shipping:

**Option A (recommended) — extend the existing internal-token pattern to this one endpoint.**
Add a narrow, additive OR-alternative to `authenticateRequest` inside
`handleRunScheduledBroadcasts` only: accept `x-internal-cron-token` (new env var, e.g.
`INTERNAL_CRON_TOKEN`, following the exact shape of `INTERNAL_HEALTH_TOKEN`) as an alternative to a
user JWT; when present and valid, iterate every row in `public.organizations` server-side and call
`runDueScheduledBroadcasts` once per org (synthesizing a minimal system claims object, permission
pre-granted, no user session involved). Then add ONE new Akshara-namespaced cron entry (mirroring
`akshara-watchdog.sh`'s shape) that POSTs with that header on a short interval (e.g. every 5–15 min).
This is a genuine, if small, change to a live authentication chokepoint (`communication_handlers.ts`
/ `communication_router.ts` / possibly `communication_service.ts` for the all-orgs loop) — per this
task's own guardrail ("if a fix requires modifying existing config/code, STOP and report for owner
review"), **this needs explicit sign-off and a normal review/deploy cycle, not an unreviewed
same-session change to production auth.**

**Option B — mint/refresh a real admin session token via the standard login flow**, store the
credential root-only (0600, off-git, same handling discipline as the backup encryption key), and
have a cron script log in, obtain a fresh 900s access token, and POST once per org, repeating before
every expiry. This needs **no code change**, but needs (i) the owner to provision or designate a
dedicated schoolAdmin/superAdmin "service" account per org (or confirm reusing an existing admin's
credentials, which is worse practice), and (ii) a refresh loop tight enough to survive the 15-minute
TTL — meaningfully more moving parts than Option A, and still requires new credentials nobody should
generate unilaterally.

**Decision made this session: do neither autonomously.** Per the task's explicit safety rule
("if auth/secret handling is unclear, report the plan rather than committing secrets"), no code was
changed and no credentials were fabricated or stored. The gap is real, confirmed, and precisely
scoped above for a deliberate follow-up (Option A is the cleaner, more maintainable fix and the one
recommended).

No cron line was added for Task 2 — doing so without one of the two auth decisions above would mean
either (a) it 401/403s every run and does nothing, or (b) hardcoding a live admin credential into a
crontab/script, which the task explicitly forbids.

---

## Summary

| Item | Verdict | Action this session | Follow-up needed |
|---|---|---|---|
| Nightly DB backup | **GREEN** | Ran+verified one manual backup, confirmed restorable (`pg_restore --list`, 2388 TOC entries), cleaned up decrypted temp copies | Off-site copy (`RCLONE_REMOTE`) — owner to provide a remote + credentials (P0-INFRA-1) |
| Monthly restore drill | **GREEN** | Verified already running + passing (2026-07-02, 184 tables) | none |
| Scheduled-broadcast cron (COM-4) | **RED (confirmed absent)** | Diagnosed root cause precisely; confirmed no cron/systemd-timer/n8n workflow anywhere calls it | Owner/dev decision: Option A (internal-cron-token + all-orgs loop, small reviewed code change) vs Option B (per-org service login) — Option A recommended |

**Touched only Akshara-namespaced resources.** No existing crontab line, script, docker container,
or config file was modified or deleted; no velora-salon, n8n, or redis resource was changed (n8n was
inspected read-only via its own `export:workflow` CLI command and the export file was deleted
immediately after). No secret values are recorded in this document or anywhere in the repo.
