# COM-4 — Scheduled-Broadcast Internal-Cron Activation Runbook

**Status: STAGED, NOT ACTIVE.** The code (edge functions) and the client-side
cron script are built and tested, but the live VPS has **not** been touched —
no SSH, no container restart, no secret provisioned. This document is the
exact, ordered sequence to flip it on when the owner approves activation. Do
not run these steps as part of building/reviewing the code change itself.

## What this activates

`POST /communications/broadcasts/run-scheduled` normally requires a full user
JWT + the `manageCommunications` permission, scoped to one org. A VPS cron has
no user session, so it authenticates instead with a shared secret header,
`x-internal-cron-token`, checked in constant time against the server-side
`INTERNAL_CRON_TOKEN` env var
(`supabase/functions/_shared/communication/communication_cron_auth.ts`). When
that header verifies, the call runs the due-scheduled-broadcast dispatch for
**every** org in one shot (a scheduler has no single org to scope to) instead
of just the caller's own. It is **never** reachable without a credential:

- No `x-internal-cron-token` header AND no JWT → 401.
- Wrong `x-internal-cron-token` AND no JWT → 401.
- Server-side `INTERNAL_CRON_TOKEN` unset/empty → **always** 401 for any
  presented token — there is no "unconfigured = open" mode for this path
  (unlike `INTERNAL_HEALTH_TOKEN`, which is intentionally open in
  non-production when unset). Until step 2 below is done, the cron will run
  and get 401 every time — that is the safe, expected state.
- The pre-existing full-JWT + `manageCommunications` single-org path is
  untouched and keeps working regardless of any of the above.

## Files involved

| File | Role |
|---|---|
| `supabase/functions/_shared/communication/communication_cron_auth.ts` | token verification (fail-closed), already deployed as part of the edge function bundle whenever `supabase/functions` is next shipped |
| `supabase/functions/_shared/communication/communication_handlers.ts` | `handleRunScheduledBroadcasts` — dispatches to the cron branch or the existing JWT branch |
| `deploy/akshara-vps/communication-cron/communication-cron.env.example` | env template (no secret) → copy to `communication-cron.env` on the VPS |
| `deploy/akshara-vps/communication-cron/akshara-broadcast-cron.sh` | the actual cron script — `curl`s the endpoint with the header |
| `deploy/akshara-vps/communication-cron/install-communication-cron.sh` | idempotent installer: seeds the env file, installs `/etc/cron.d/akshara-communications` |

## Ordered activation steps

### 0. Prerequisite — ship the code

The `communication_cron_auth.ts` / `communication_handlers.ts` change ships as
part of the normal edge-function deploy (`supabase functions deploy` per the
`/deploy` recipe). Confirm it's live before wiring the cron — until then the
new branch doesn't exist server-side and any `x-internal-cron-token` header is
simply ignored (falls through to the existing JWT path, still safe, just not
useful yet).

### 1. Generate a strong random token

On any machine (does not need to be the VPS):

```bash
openssl rand -base64 48
```

Treat this like any other production secret — do not paste it into chat logs,
tickets, or commit it anywhere. Two copies are needed: one for the
akshara-edge container's env, one for the cron's env file (same value).

### 2. Set `INTERNAL_CRON_TOKEN` in the akshara-edge container env

`akshara-edge` reads `env_file: .env.akshara`
(`deploy/akshara-vps/docker-compose.akshara.yml`), same as
`INTERNAL_HEALTH_TOKEN` and the other secrets. On the VPS:

```bash
# Append (do not overwrite the file):
echo "INTERNAL_CRON_TOKEN=<the generated token>" >> /opt/akshara/.env.akshara
```

**⚠ ACTIVATION TRIGGER — this step alone does nothing until the container is
recreated.** Per the established deploy recipe (`.claude/skills/deploy/SKILL.md`):
"env is not re-read unless the container is recreated" — a plain
`docker restart akshara-edge` will **not** pick up the new var. Recreate it
surgically, matching the existing pattern (`--no-deps` to avoid disturbing the
rest of the stack / the pre-existing broken postgres healthcheck):

```bash
cd /opt/akshara   # wherever docker-compose.akshara.yml lives on the VPS
docker compose -f docker-compose.akshara.yml up -d --no-deps --force-recreate akshara-edge
# if it doesn't come up cleanly:
docker start akshara-edge
```

Verify the var landed and the endpoint is reachable:

```bash
docker exec akshara-edge printenv INTERNAL_CRON_TOKEN   # should print the token, not empty
curl -s http://127.0.0.1:3000/health   # liveness, should be 200 (confirms the recreate didn't break anything)
```

This is the one step in this whole runbook that touches a live container —
everything else (steps 3-4) is inert until this is done, and everything
before it is inert without this.

### 3. Add the Akshara-namespaced cron

Deploy `deploy/akshara-vps/communication-cron/` to the VPS (same pattern as
the backup/monitoring installers):

```bash
# From the repo, on your machine:
tar czf - -C deploy/akshara-vps communication-cron \
  | ssh -S ~/.ssh/akshara-cm.sock root@<vps-host> 'mkdir -p /opt/akshara && tar xzf - -C /opt/akshara'
```

Then on the VPS:

```bash
cd /opt/akshara/communication-cron
./install-communication-cron.sh
```

This seeds `communication-cron.env` from the `.example` (chmod 600,
root-only — the installer will NOT overwrite an existing one) and installs
`/etc/cron.d/akshara-communications` (every 5 minutes; matches the watchdog's
cadence — safe to overlap since `claimDueScheduledBroadcasts` claims rows
atomically with `FOR UPDATE SKIP LOCKED`, so two overlapping runs never
double-send).

**Set the token in the cron's own env file** (same value as step 1/2):

```bash
vi /opt/akshara/communication-cron/communication-cron.env
# INTERNAL_CRON_TOKEN=<the same generated token>
```

This is a **separate** cron namespace from the existing `akshara-ops`
(backup/restore) and `akshara-watchdog` cron files — it does not touch or
depend on either.

### 4. Verify via the audit event

Each org's cron-triggered run writes a distinct audit row,
`communication.broadcasts.cron_run` (category `workflow`, entity type
`comm_broadcast_cron_run`, `entity_id` = the org id), inside that org's own
tenant-RLS context — separate from the `scheduledBroadcastSent` event that
already fires per dispatched broadcast. Confirm activation actually worked by
either:

```bash
# a) manual trigger + inspect the response (per-org results array):
/opt/akshara/communication-cron/akshara-broadcast-cron.sh
tail -20 /var/log/akshara/communication-cron.log
```

```sql
-- b) confirm the audit trail landed for the orgs that had due broadcasts
--    (run against the tenant DB with an org context, or via the ops role):
SELECT organization_id, event_type, metadata, created_at
FROM audit_events
WHERE event_type = 'communication.broadcasts.cron_run'
ORDER BY created_at DESC
LIMIT 20;
```

A healthy activation shows: the cron log reporting `http=200`, and fresh
`communication.broadcasts.cron_run` rows appearing on the 5-minute cadence.

## Rollback

To disable without touching code: remove/blank `INTERNAL_CRON_TOKEN` from
`/opt/akshara/.env.akshara` and recreate `akshara-edge` again (same recreate
step as above) — the endpoint fails closed (401) for every cron call
immediately, and the pre-existing JWT-authenticated path is completely
unaffected. Optionally also `rm /etc/cron.d/akshara-communications` to stop
the client-side calls.
