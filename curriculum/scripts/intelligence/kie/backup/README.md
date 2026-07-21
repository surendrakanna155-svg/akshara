# KIE/QIE certified-estate backup — remediation R0-1 · [C7]

Automated, encrypted, restore-verifiable backup of the entire certified knowledge/
question estate. Closes audit finding **C7** ("single-disk estate; 3 DBs had no
backup of any kind").

## What the audit found
- The whole certified estate (kie.db ~197 MB, knowledge_index.db, qdi.db, examdna.db,
  both question banks, snapshots) is gitignored and lived on **one 85 %-full laptop
  volume** (`/dev/disk3s5`).
- The pre-existing archive `~/Documents/Akshara_foundation_backup_v1.4_20260720` sits on
  the **same volume**, and **excluded `examdna.db`, `qdi.db`, `qpl_question_bank.db`** —
  those three had **no copy of any kind**.

## What this tooling does
- `backup_estate.sh` — consistent `sqlite3 .backup` snapshots of **every** live estate DB
  (top-level `*.db` + `snapshots/*.db`), a checksummed manifest with per-DB row counts,
  the recorded v1.4 fingerprint, then a single **AES-256 (PBKDF2, 200k iters)** encrypted
  `.tar.gz.enc` written to `$AKSHARA_BACKUP_DEST`. Prunes to the last `$AKSHARA_BACKUP_KEEP`
  (default 7). Bash-3.2 compatible (macOS default `/bin/bash`).
- `restore_verify.sh` — decrypts an archive, re-checks every snapshot's sha256, and
  **independently recomputes the frozen v1.4 certified-knowledge fingerprint** from the
  restored `knowledge_index.db`, asserting it equals both the recorded value and the
  constant `e3a146f3…`. This is the "restore on another machine reproduces the
  fingerprint" acceptance check.
- `com.akshara.kie-backup.plist.template` — daily LaunchAgent (02:30 local).

Proven end-to-end in this session: full backup → decrypt → checksum → fingerprint
**EXACT MATCH** (`e3a146f3…`), all snapshot row counts intact.

## Status after remediation R0-1
- ✅ **Tooling built + proven** (round-trip verified).
- ✅ **Interim safeguard applied:** the three previously-unbacked DBs (`qdi.db`,
  `examdna.db`, `qpl_question_bank.db`) now have consistent-snapshot copies in the
  existing archive `~/Documents/Akshara_foundation_backup_v1.4_20260720/databases/`
  (SHA256SUMS_databases.txt regenerated). This protects against DB-level
  corruption / accidental deletion.
- ⏳ **OWNER ACTION REQUIRED for full C7 closure — off-machine target (external
  dependency).** Everything above is still on the **same physical volume**, so it does
  **not** protect against volume loss. To finish:

### Owner one-time setup
```bash
# 1. Create a passphrase file (choose a strong secret; keep it OFF this machine too):
mkdir -p ~/.akshara && printf '%s' 'YOUR-STRONG-PASSPHRASE' > ~/.akshara/kie_backup.key
chmod 600 ~/.akshara/kie_backup.key

# 2. Pick an OFF-MACHINE destination — an external volume or owner-managed durable store.
#    (Do NOT use the prod VPS: the curriculum local-storage lock keeps the estate off
#     prod/shared hosts. An external drive or a personal cloud-synced folder is fine.)
export AKSHARA_BACKUP_DEST=/Volumes/AksharaBackup/kie

# 3. First run + verify:
cd curriculum/scripts/intelligence/kie/backup
AKSHARA_BACKUP_PASSPHRASE_FILE=~/.akshara/kie_backup.key \
AKSHARA_BACKUP_DEST="$AKSHARA_BACKUP_DEST" ./backup_estate.sh
AKSHARA_BACKUP_PASSPHRASE_FILE=~/.akshara/kie_backup.key \
  ./restore_verify.sh "$AKSHARA_BACKUP_DEST"/akshara_estate_*.tar.gz.enc

# 4. Schedule (edit the __PLACEHOLDERS__ first):
sed -e "s#__REPO_ROOT__#$(cd ../../../../.. && pwd)#" \
    -e "s#__HOME__#$HOME#" \
    -e "s#__OFF_MACHINE_DEST__#$AKSHARA_BACKUP_DEST#" \
    com.akshara.kie-backup.plist.template > ~/Library/LaunchAgents/com.akshara.kie-backup.plist
launchctl load ~/Library/LaunchAgents/com.akshara.kie-backup.plist
```

**Done when (roadmap R0-1):** a `restore_verify.sh` run on **another machine** reproduces
fingerprint `e3a146f3…` and all row counts. The interim same-volume copies + verified
tooling satisfy everything the machine can do autonomously; the off-machine leg is the
single owner/external step.

## Governance note
The owner local-storage lock forbids **git/prod promotion** of curriculum data, **not**
off-machine encrypted copies (audit-confirmed reading). This tooling never writes to git
or prod and encrypts everything at rest.
