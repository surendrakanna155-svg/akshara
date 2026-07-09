# Akshara backups (Batch 7)

The live database backup system for the VPS. Plain-language goal: **if the server
dies, no school loses more than one night's data, and we can prove the backups
actually restore.**

## What this does

- **Nightly** `pg_dump` of `akshara_db`, **AES-256 encrypted** before it touches
  disk (plaintext is never written), compressed (custom format).
- **Off-site copy** via `rclone` to an S3-compatible bucket (the "1" in 3-2-1).
- **Retention** grandfather-father-son: 7 daily, 4 weekly, 12 monthly.
- **Ledger**: every run writes a row to `ops_backup_runs`; every restore drill to
  `ops_restore_drills`. The edge endpoint **`GET /health/backup`** reads these and
  returns `503` if there is no successful backup within `BACKUP_MAX_AGE_HOURS`
  (default 26) — so monitoring/alerts can catch a silently-broken backup.
- **Monthly restore drill** restores the latest backup into a throwaway DB,
  checks it has the expected tables + non-empty `organizations`, records the
  result, and drops the throwaway DB. *A backup you have never restored is not a
  backup.*

## Files

| File | Role |
|------|------|
| `lib-common.sh` | shared config loader + helpers (sourced, not run directly); also owns `offsite_copy()` / `offsite_prune()` |
| `backup.env.example` | config template → copy to `/opt/akshara/backup/backup.env` |
| `rclone.conf.example` | **off-site** remote config template (inert placeholders) → copy to `/opt/akshara/backup/rclone.conf` |
| `akshara-backup.sh` | the nightly backup (run by cron; `manual` and/or `--dry-run` args for ad-hoc) |
| `akshara-restore.sh` | restore an artifact into a target DB (refuses live DB without `--force`) |
| `akshara-restore-drill.sh` | automated restore test into a throwaway DB |
| `install-ops-cron.sh` | idempotent installer: key, dirs, cron, logrotate, rclone.conf placeholder |

Full off-site setup (Cloudflare R2) walkthrough, including exactly what credentials
the owner must supply and how to verify the first upload + a restore-from-remote:
**`docs/engineering/eos/OFFSITE_BACKUP_R2_RUNBOOK.md`**.

## First-time install (on the VPS)

```bash
# 1. Deploy this directory to the VPS
ssh -S ~/.ssh/akshara-cm.sock root@46.28.44.46 'mkdir -p /opt/akshara/backup'
tar czf - -C deploy/akshara-vps backup \
  | ssh -S ~/.ssh/akshara-cm.sock root@46.28.44.46 'tar xzf - -C /opt/akshara'

# 2. Apply the ledger migration (creates ops_backup_runs / ops_restore_drills)
#    (piped to psql like every other Akshara migration)
#    then reload PostgREST schema cache so /health/backup can read it.

# 3. Run the installer (generates the encryption key, cron, logrotate)
ssh -S ~/.ssh/akshara-cm.sock root@46.28.44.46 \
  'cd /opt/akshara/backup && ./install-ops-cron.sh'

# 4. Take the first backup now and confirm it lands
ssh -S ~/.ssh/akshara-cm.sock root@46.28.44.46 \
  '/opt/akshara/backup/akshara-backup.sh manual'

# 5. Prove restore works
ssh -S ~/.ssh/akshara-cm.sock root@46.28.44.46 \
  '/opt/akshara/backup/akshara-restore-drill.sh'
```

> **Key custody:** `install-ops-cron.sh` generates `/opt/akshara/backup/secret.key`
> once. **Copy it somewhere safe and OFF this box.** Lose the key → the encrypted
> backups are unrecoverable. Never regenerate it (that orphans every old backup).

## Off-site (3-2-1)

Off-site is **off by default** — the script logs a loud warning and records
`offsite=false` until you configure it. To enable:

1. Install `rclone` on the VPS.
2. Copy `rclone.conf.example` → `/opt/akshara/backup/rclone.conf` (chmod 600) and
   fill in the real Cloudflare R2 (or any S3-compatible) values.
3. In `backup.env`, set `RCLONE_CONFIG_FILE=/opt/akshara/backup/rclone.conf` and
   `RCLONE_REMOTE=r2:akshara-backups/db`.

The remote bucket should live with a **different provider / region** than the VPS.
Full step-by-step (exact credentials needed, verification, restore-from-remote):
**`docs/engineering/eos/OFFSITE_BACKUP_R2_RUNBOOK.md`**.

**Test the wiring before you have credentials.** `akshara-backup.sh` supports a
`--dry-run` flag that runs a real dump/encrypt/ledger cycle as usual but only
*logs* the off-site `rclone` command(s) it would run instead of executing them —
so the plumbing can be proven correct with no `rclone` binary and no R2
credentials at all:

```bash
./akshara-backup.sh manual --dry-run
```

## Disaster recovery (server lost)

```bash
# On a fresh box with the stack running and the key file restored:
/opt/akshara/backup/akshara-restore.sh \
  /path/to/akshara_db_<ts>_<kind>.dump.enc akshara_db --force
# then: docker restart akshara-edge akshara-postgrest ; check /health/ready
```

## Current RPO/RTO

- This nightly system gives **RPO ≈ 24h** (worst case one day's data) and
  **RTO ≈ minutes-to-an-hour** (restore time).
- The 15-minute RPO target in `docs/DEPLOYMENT_MODEL_AND_DR_PLAN.md` needs **WAL
  archiving / PITR** — a layer-2 upgrade (requires a Postgres `archive_command` +
  restart). Tracked as a follow-up; nightly is the immediate safety net.
