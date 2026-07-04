# Batch 7 — Storage, Backups, Monitoring (live)

Date: 2026-06-24. Branch: `feature/scope-trim-school-build`. Sequenced
backups → storage → monitoring (highest data-loss risk first). All three were
built as version-controlled artifacts AND deployed + verified live on the VPS
(46.28.44.46 / https://akshara.veloraunisexsalon.com).

---

## 1. Backups (was: NONE — the single biggest production risk)

The live DB had zero backups. Now: **nightly encrypted, retained, restore-tested,
freshness-monitored** backups.

- Migration `20260709000000_ops_backup_ledger.sql` — `ops_backup_runs` +
  `ops_restore_drills` (platform/ops tables; RLS enabled, **no policy** → only
  superuser + service_role reach them).
- `deploy/akshara-vps/backup/`:
  - `akshara-backup.sh` — `pg_dump -Fc` streamed straight into AES-256
    (`openssl enc -aes-256-cbc -pbkdf2`); plaintext never hits disk. Records a
    ledger row (size, sha256, offsite, duration). GFS retention 7d/4w/12m. Off-site
    via rclone (opt-in).
  - `akshara-restore.sh` — decrypt + `pg_restore` (refuses live DB without `--force`).
  - `akshara-restore-drill.sh` — restores latest backup into a throwaway DB, checks
    table count + non-empty `organizations`, records `ops_restore_drills`, drops it.
  - `install-ops-cron.sh` — generates the encryption key, cron (nightly 02:15 +
    monthly drill on the 2nd 03:30), logrotate. `backup.env` config.
- Edge: `GET /health/backup` (internal-token guarded) reads the ledger → **503 when
  no success within `BACKUP_MAX_AGE_HOURS` (26)** or the last run failed; surfaces
  `offsiteWarning` and the last drill.
- **Live-verified:** first backup OK (1 MB encrypted, 454 ms); restore drill OK
  (162 tables, orgs=1, users=5); `/health/backup` flips 503→200; cron active.
- **Open (needs owner):** off-site copy needs an external S3/R2 bucket + rclone —
  built + configurable; honestly reported as `offsite=false` / `offsiteWarning:true`
  until provisioned. Current RPO ≈ 24h (nightly); WAL/PITR for ≤15 min RPO is a
  documented layer-2 follow-up.

## 2. Storage (was: BROKEN — signed-URL code pointed at a Storage service that
   was never deployed; every upload failed)

Stood up real Supabase Storage so School Memories uploads/downloads work on devices.

- `supabase/storage-api:v1.19.3` container on `akshara-net`, file backend on the
  `akshara_storage_data` volume, host port `127.0.0.1:5000`. Added to
  `docker-compose.akshara.yml`.
- DB: set `supabase_storage_admin` password, dropped the lean stub `storage` schema
  (0 objects → non-destructive), `CREATE SCHEMA storage AUTHORIZATION
  supabase_storage_admin`; storage-api ran its 36 migrations. Then
  `storage/storage_grants_bucket_policies.sql` (grants to the supabase roles since
  `DB_INSTALL_ROLES=false`; re-create `school-memories` bucket; re-apply v104
  tenant-isolation policies).
- Routing: gateway `/storage/v1/*`→storage-api (internal) AND the **public Nginx
  vhost** `/storage/v1/*`→`127.0.0.1:5000` (so devices can PUT/GET signed URLs).
- Edge: new `PUBLIC_STORAGE_BASE_URL` + `toPublicStorageUrl()` rewrites the origin
  of generated signed URLs from the internal gateway to the public domain before
  returning them to the app (the phone can't reach the internal host).
- **Live-verified:** `/health/storage` → ok/reachable; full signed-URL round-trip
  **over the public internet from a dev machine** (create upload URL → PUT → sign →
  GET → byte-identical → delete), all 200.
- Gotchas captured in `storage/README.md`: `DB_INSTALL_ROLES=false` + manual grants;
  `service_role` has BYPASSRLS but still needs table GRANTs (the misleading "new row
  violates RLS" was really `42501`); storage_admin needs `ALL ON DATABASE` to migrate.

## 3. Monitoring (was: health endpoints only; no logging discipline, no alerting)

- Edge: structured **one-JSON-line-per-request** logging in `api/index.ts`
  (method/path/status/durationMs/correlationId/clientIp; level 50 on 5xx). NO
  bodies/tokens/query-strings logged. `x-correlation-id` echoed back for tracing.
- `deploy/akshara-vps/monitoring/`:
  - `akshara-watchdog.sh` (cron every 5 min) — checks `/health/ready|backup|storage`,
    disk %, TLS cert expiry, every container running (+ postgres health). Alerts via
    log (always) + webhook + Fast2SMS (CRIT only), with per-check **cooldown** and a
    one-time **RECOVERED** notice. `install-monitoring.sh`, `monitoring.env`.
- **Live-verified:** watchdog all-green (api/backup/storage OK, disk 30%, cert 89d,
  5/5 containers up); alert state machine proven (fire → cooldown-suppress → recover);
  edge request logs confirmed in `docker logs`.
- **Open (needs owner / external):** set `ALERT_WEBHOOK_URL`/`ALERT_SMS_PHONES` to
  actually receive alerts (currently log-only). Backend Sentry/Datadog, Prometheus
  `/metrics` + Grafana, log aggregation = deliberately deferred (need vendor accounts;
  app-side Sentry/Datadog adapters already exist, just need a DSN).

---

## Certification
- `flutter analyze` (lib): **0 errors** (info/warnings pre-existing; no Dart changed
  this batch).
- `deno check supabase/functions/api/index.ts`: clean.
- `deno test _shared`: 521 passed / 1 failed / 1 ignored — the single failure is the
  `tenant_isolation` self-test that requires a live DB (environmental); also **fixed
  4 pre-existing academic tests** that referenced a renamed migration path.
- Backup/monitoring shell scripts: `bash -n` clean.

## Deploy mechanics (this batch)
- Migration piped to `docker exec -i akshara-postgres psql -U supabase_admin`; then
  `NOTIFY pgrst,'reload schema'` so PostgREST sees `ops_backup_runs`.
- Edge code: `tar … | ssh … tar xzf -C /opt/akshara/functions` + `docker restart
  akshara-edge`.
- storage-api first started via `docker run` (compose entry now matches); host nginx
  reloaded via `systemctl reload nginx` after adding the `/storage/v1/` location
  (Velora/n8n vhosts untouched; `.bak.batch7` saved).

Roadmap: Batches 1–7 done; next **Batch 8 (real AI)**.
