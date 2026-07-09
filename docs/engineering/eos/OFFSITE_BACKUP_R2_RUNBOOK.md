# Off-site Backup (Cloudflare R2) — Runbook

**Status: CREDENTIALS-PENDING.** The wiring described here is built, tested, and
committed. It is **not active**. Nothing goes off-site until an operator adds real
Cloudflare R2 credentials on the VPS, per §2 below. Until then the nightly backup
behaves exactly as it does today (local-only, `offsite=false`, a loud log warning) —
zero change in current behavior.

Related: `deploy/akshara-vps/backup/README.md` (system overview),
`docs/BACKUP_RESTORE_RUNBOOK.md` (day-to-day operator restore procedure),
[[dr-rpo-acceptance-decision]] (accepted ~24h RPO for pilot).

---

## 1. Why this exists (the gap)

The Akshara backup system (`deploy/akshara-vps/backup/`) has always shipped
**off-site-ready**: `akshara-backup.sh` already knows how to push the nightly
encrypted dump to an S3-compatible bucket via `rclone`, verify the upload landed,
and prune aged remote copies — see `offsite_copy()` / `offsite_prune()` in
`lib-common.sh`. What was missing was:

1. A concrete config **template** for the remote (`rclone.conf.example`) so an
   operator doesn't have to hand-write rclone's INI format from scratch.
2. This **runbook** — the exact values to obtain, where they go, and how to prove
   the first upload + a restore from the remote copy actually work.
3. A **`--dry-run`** mode so the plumbing can be proven correct with **zero**
   credentials and **without `rclone` even being installed** — useful right now,
   while credentials are still pending.

All three are now in place (see §5 for the dry-run proof). Live activation (§2–§4)
is intentionally left to the operator, because it requires a real Cloudflare
account/bucket that this prep work cannot and must not create on someone's behalf.

Today, without off-site, a VPS-level disaster (disk failure, host loss, VPS
provider incident) loses **every backup along with the live database** — the
nightly backup protects against operator/application-level mistakes (bad
migration, accidental delete) but not against losing the box itself. That is the
3-2-1 rule's "1 copy off-site" requirement, currently unmet (tracked as
`P0-INFRA-1` / `OPS-1` / `LV-3` across the engineering audits).

---

## 2. What the owner must provide

Exactly four values, all from the **Cloudflare dashboard → R2**:

| # | Value | Where to find it |
|---|-------|-------------------|
| 1 | **Account ID** | Cloudflare dashboard home page (right sidebar), or R2 overview page URL |
| 2 | **Bucket name** | R2 → create a bucket (e.g. `akshara-backups`) — a **private** bucket, no public access needed |
| 3 | **Access Key ID** | R2 → *Manage R2 API Tokens* → *Create API Token* → scope: **Object Read & Write**, restricted to the one bucket above |
| 4 | **Secret Access Key** | shown once when the token is created — copy it immediately, R2 will not show it again |

Recommended: scope the API token to **that one bucket only** (least privilege) —
a leaked token should not be able to touch anything else in the Cloudflare account.

No other product/account decision is needed. Region/provider choice is already
made (R2, for its zero egress-fee policy — cheap to run monthly restore drills
that pull data back down).

---

## 3. Where the values go on the VPS (root-only, chmod 600)

Two files, both already templated in the repo at
`deploy/akshara-vps/backup/` and deployed to `/opt/akshara/backup/` on the VPS
(see `README.md` §"First-time install"):

### 3a. `rclone.conf` (holds the R2 credentials)

```bash
# On the VPS, as root:
cd /opt/akshara/backup
cp rclone.conf.example rclone.conf   # install-ops-cron.sh also seeds this automatically
chmod 600 rclone.conf
```

Edit `rclone.conf` and replace the three placeholders with the real values from §2:

```ini
[r2]
type = s3
provider = Cloudflare
access_key_id = <ACCESS_KEY_ID>
secret_access_key = <SECRET_ACCESS_KEY>
endpoint = https://<ACCOUNT_ID>.r2.cloudflarestorage.com
acl = private
no_check_bucket = true
```

### 3b. `backup.env` (points at the remote + the config file)

Already deployed with `RCLONE_REMOTE=` and `RCLONE_CONFIG_FILE=` present but
empty (safe no-op). Add exactly two lines:

```bash
RCLONE_CONFIG_FILE=/opt/akshara/backup/rclone.conf
RCLONE_REMOTE=r2:<bucket-name>/db
```

`chmod 600 backup.env` (should already be 600 from `install-ops-cron.sh`).

**That's the entire enable step.** No code change, no restart, no cron edit — the
very next backup run (manual or the 02:15 UTC cron) will pick up `RCLONE_REMOTE`
and start pushing off-site.

### 3c. Install `rclone` itself (assumed not yet present)

```bash
curl https://rclone.org/install.sh | sudo bash
# or: apt-get update && apt-get install -y rclone
rclone version   # sanity check
```

If `RCLONE_REMOTE` is set but the `rclone` binary is missing, the backup script
logs `WARNING: RCLONE_REMOTE set but rclone not installed (backup is local-only)`
and continues local-only — it never hard-fails the nightly backup.
`install-ops-cron.sh` also prints this same note at install time.

---

## 4. Verifying it actually works (after credentials are added)

### 4a. First off-site upload

```bash
cd /opt/akshara/backup
./akshara-backup.sh manual
```

Confirm in the output / `backup.log`:

```
off-site copy OK -> r2:<bucket-name>/db/<hostname>/akshara_db_<ts>_manual.dump.enc
backup SUCCESS (manual) in <n>ms (offsite=true)
```

Cross-check two independent ways:

```bash
# 1. Directly list the bucket
rclone lsf r2:<bucket-name>/db/ --config /opt/akshara/backup/rclone.conf

# 2. Check the ledger row Postgres-side
docker exec -it akshara-postgres psql -U supabase_admin -d akshara_db -c \
  "SELECT kind, status, offsite, offsite_location, created_at FROM ops_backup_runs ORDER BY created_at DESC LIMIT 1;"
```

`offsite` should be `true` and `offsite_location` should match the rclone path.
The operator-only `GET /health/backup` endpoint will also reflect the latest run.

### 4b. Restore FROM the off-site copy (proves the round-trip, not just the upload)

```bash
# Pull a copy back down from R2 into a scratch dir
mkdir -p /tmp/offsite-restore-check
rclone copy r2:<bucket-name>/db/<hostname>/akshara_db_<ts>_manual.dump.enc \
  /tmp/offsite-restore-check/ --config /opt/akshara/backup/rclone.conf

# Restore that remote-fetched artifact into a THROWAWAY db (never the live db)
cd /opt/akshara/backup
./akshara-restore.sh /tmp/offsite-restore-check/akshara_db_<ts>_manual.dump.enc akshara_restore_check
```

A clean restore proves the artifact that reached R2 is byte-for-byte the same
encrypted dump produced locally (rclone's `--checksum` flag on upload already
verifies this at transfer time; this step proves it end-to-end through a real
decrypt + `pg_restore`).

### 4c. Ongoing proof

The existing monthly `akshara-restore-drill.sh` cron job (03:30 UTC on the 2nd)
is unaffected by off-site — it drills the latest **local** artifact. Off-site
freshness/health is what `/health/backup`'s `offsite` field and `ops_backup_runs`
already surface; no separate off-site cron is needed.

---

## 5. Testing the wiring RIGHT NOW, with no credentials (dry-run)

`akshara-backup.sh` accepts a `--dry-run` flag. It still performs the real
dump/encrypt/ledger cycle (that part needs no external credentials and already
works today), but for the off-site step it only **logs** the `rclone` command(s)
it would run — it never shells out to `rclone`, so it needs neither the binary
installed nor any R2 credentials configured:

```bash
./akshara-backup.sh manual --dry-run
```

Expected log output (with `RCLONE_REMOTE` set to anything, even a placeholder):

```
[dry-run] off-site wiring check (no network call, no rclone/credentials required):
[dry-run]   would run:    rclone copy "<artifact>" "<remote>/<host>/" --checksum --config <path> <flags>
[dry-run]   would verify: rclone lsf "<remote>/<host>/<artifact-name>" --config <path> <flags>
[dry-run]   would prune:  rclone delete "<remote>/<host>" --include 'akshara_db_*_nightly.dump.enc' --min-age <n>d --config <path> <flags>
[dry-run] off-site wiring OK — set real RCLONE_REMOTE credentials to go live
```

This was verified during this prep work by sourcing `lib-common.sh` in isolation
and calling `offsite_copy()` directly with a decoy `rclone` binary on `PATH` that
would loudly print if invoked — it was never invoked in dry-run mode, and the
existing "unset `RCLONE_REMOTE`" behavior (a single warning line, `offsite=false`,
zero crash) was also reconfirmed unchanged.

---

## 6. Retention / 3-2-1 statement

- **3 copies:** the live `akshara_db` + the local encrypted nightly dump
  (`/opt/akshara/backup/store/`) + the off-site R2 copy (once enabled).
- **2 media/locations:** VPS local disk + Cloudflare R2 (a different provider and
  infrastructure than the VPS host).
- **1 off-site:** R2, satisfied once `RCLONE_REMOTE` is configured per §3.
- **Local retention** (grandfather-father-son, unchanged by this work):
  `KEEP_DAILY=7`, `KEEP_WEEKLY=4`, `KEEP_MONTHLY=12` (in `backup.env`).
- **Remote retention:** the nightly off-site copies are pruned once they exceed
  `KEEP_DAILY` days old (`rclone delete --min-age ${KEEP_DAILY}d`, scoped to
  `*_nightly.dump.enc`); weekly/monthly off-site copies are kept indefinitely as
  a longer-horizon archive, mirroring how local weekly/monthly retention is a
  count (not an age) — this is a deliberate, conservative default and can be
  tightened later without any code change (it is driven entirely by
  `KEEP_DAILY`/`RCLONE_FLAGS` in `backup.env`).

## 7. Accepted RPO (unchanged by this work)

Per the standing DR decision ([[dr-rpo-acceptance-decision]], `docs/DEPLOYMENT_MODEL_AND_DR_PLAN.md`):
the pilot accepts **RPO ≈ 24h** (nightly backup cadence). Off-site closes the
3-2-1 site-loss gap but does **not** change the RPO — a VPS disaster recovered
from the R2 copy still loses up to ~24h of data, same as recovering from the
local copy. Tightening RPO requires WAL archiving / PITR, which is explicitly
deferred post-pilot and is a separate piece of work from this one.

---

## 8. Security notes

- `backup.env` and `rclone.conf` are both root-only (`chmod 600`) on the VPS —
  never committed to the repo (only the `*.example` templates are committed, and
  those contain zero real values).
- Scope the R2 API token to the one backup bucket only (§2).
- The backup content itself is already AES-256 encrypted before it is written to
  disk or copied anywhere — a compromised R2 bucket alone does not expose data
  without the separate `secret.key` (`/opt/akshara/backup/secret.key`, never
  copied to R2, kept off-box per existing key-custody guidance in `README.md`).
- Rotating the R2 access key: generate a new token in the Cloudflare dashboard,
  update `rclone.conf`, delete the old token. This does not affect existing
  off-site objects (no re-encryption needed — R2 access, not the backup
  encryption key, is what rotates).
