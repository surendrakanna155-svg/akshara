# Restore Runbook — moved

> **Consolidated (DOC-7, 2026-07-04).** There is now **one canonical backup & restore runbook**:
> **[`../BACKUP_RESTORE_RUNBOOK.md`](../BACKUP_RESTORE_RUNBOOK.md)** (§2 Restore procedure, §3 drill
> thresholds, §5 RPO/RTO, §6 escalation).
>
> The previous content of this file described a **Supabase PITR restore** with an **RPO of 15 minutes**.
> That does **not** match the deployment: NIKSHA OS restores are **operator-assisted over SSH** from the
> nightly encrypted `pg_dump` artifacts (`deploy/akshara-vps/backup/akshara-restore.sh`, with the
> `--force`-to-overwrite-production guard), giving a current **RPO ≈ 24h**. The 15-minute PITR target
> requires WAL archiving that is **not yet enabled** (owner-gated `P0-INFRA-2`). The stale content was
> removed to avoid contradicting the canonical runbook and overstating recovery guarantees.

**Go to → [`../BACKUP_RESTORE_RUNBOOK.md`](../BACKUP_RESTORE_RUNBOOK.md)** for the real restore
procedure and recovery objectives.
