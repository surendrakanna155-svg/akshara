# Akshara VPS — Wave 1 deploy runbook

**Branch:** `feature/scope-trim-school-build` @ `9a16a3a` (A1 + packaging + capability-gating + AI-activation + write-completeness)
**Host:** 46.28.44.46 · public: https://akshara.veloraunisexsalon.com · stack dir on VPS = the dir holding `docker-compose.akshara.yml` (call it `$STACK`)
**What changes go live:** 1 new DB migration + updated edge functions. AI surfaces (copilot, parent insights) stay in safe-fallback until `ANTHROPIC_API_KEY` is set (separate owner step, §5).

> ⚠️ Touches the live pilot DB + edge. Do §0 (backup) first. Each step is reversible (§6).

---

## 0. Pre-flight (local + VPS)
```bash
# local: confirm tree is the verified Wave-1 tip and push it
cd /Users/surendrakanna/Documents/Akshara_ERP
git rev-parse --short HEAD            # expect 9a16a3a (or later)
git push origin feature/scope-trim-school-build

# VPS: take a fresh backup BEFORE applying (Batch-7 backup script)
ssh root@46.28.44.46 'cd $STACK/backup && ./akshara-backup.sh'   # adjust path; produces an encrypted snapshot
```

## 1. Apply the one new migration
Only **`20260714000000_school_configuration.sql`** is new since the last deploy (`20260712` already applied). It is standalone (creates the `school_configuration` table + school-scope RLS); no data backfill.
```bash
# copy the migration to the VPS (or `git pull` if $STACK has a checkout)
scp supabase/migrations/20260714000000_school_configuration.sql root@46.28.44.46:/tmp/

ssh root@46.28.44.46 '
  set -euo pipefail
  # apply as supabase_admin (superuser in this image), abort on any error
  docker exec -i akshara-postgres psql -U supabase_admin -d akshara_db -v ON_ERROR_STOP=1 \
    < /tmp/20260714000000_school_configuration.sql
  # record in the migration ledger so a future db push will not re-run it
  docker exec -i akshara-postgres psql -U supabase_admin -d akshara_db -c \
    "INSERT INTO supabase_migrations.schema_migrations(version) VALUES (\"20260714000000\") ON CONFLICT DO NOTHING;"
  # sanity: table + RLS present
  docker exec -i akshara-postgres psql -U supabase_admin -d akshara_db -c \
    "SELECT relrowsecurity FROM pg_class WHERE relname=\"school_configuration\";"
'
```

## 2. Deploy the edge functions
The `akshara-edge` container mounts `$STACK/functions:/app:ro` and runs `api/index.ts`. Sync the repo's `supabase/functions/` into `$STACK/functions/`, then recreate the container.
```bash
# from local repo (rsync the function source onto the VPS stack dir)
rsync -az --delete supabase/functions/ root@46.28.44.46:$STACK/functions/
# OR, if $STACK is a git checkout:  ssh root@46.28.44.46 'cd $STACK && git pull'

ssh root@46.28.44.46 'cd $STACK && docker compose -f docker-compose.akshara.yml up -d --force-recreate akshara-edge'
```

## 3. Smoke test (against the public URL)
```bash
BASE=https://akshara.veloraunisexsalon.com
curl -fsS $BASE/health && echo                      # gateway/edge up
curl -fsS $BASE/health/ready && echo                # database:true

# (with a schoolAdmin/principal bearer token TOKEN + X-School-Id header)
# capability gating persists:
curl -fsS -H "Authorization: Bearer $TOKEN" $BASE/school-config && echo
# write fix: HR leave approve no longer 404s (expect 200 / business error, NOT 404)
curl -i -X POST -H "Authorization: Bearer $TOKEN" $BASE/hr/leave/SOME_ID/approve
# syllabus hard boundary: an off-syllabus chapter must return 422 OFF_SYLLABUS
```
Also click-test in the app build: Management → Settings → School configuration (toggle a module, reload, confirm it persisted); teacher at-risk screen loads live; generate a question paper with a bogus chapter → blocked.

## 4. Tag the release
```bash
git tag -a wave1-live -m "Wave 1 live on VPS" 9a16a3a && git push origin wave1-live
```

## 5. Owner follow-ups (flip AI fully real)
- `ANTHROPIC_API_KEY` — set on the edge env (compose `akshara-edge.environment` or the admin provider panel) and recreate edge. Until then copilot/parent-insights return safe deterministic output (by design).

## 6. Rollback
- **Edge:** `rsync`/checkout the previous functions revision and `up -d --force-recreate akshara-edge` (read-only mount, instant).
- **Migration:** `DROP TABLE IF EXISTS public.school_configuration CASCADE;` then delete its ledger row. The table is additive — dropping it cannot affect any other module (capability gating just falls back to the SharedPreferences cache client-side).
- **Full:** restore the §0 snapshot via `backup/akshara-restore.sh`.

---
**Not in this deploy (later waves):** push notifications (A5), off-site backups/WAL (A7), live-mode E2E (A4), and the B7 first-time-onboarding feature (preserved on branch `wip/b7-onboarding`, incl. migration `20260713000000`).
