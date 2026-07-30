# Backup Runbook — moved

> **Consolidated (DOC-7, 2026-07-04).** There is now **one canonical backup & restore runbook**:
> **[`../BACKUP_RESTORE_RUNBOOK.md`](../BACKUP_RESTORE_RUNBOOK.md)**.
>
> The previous content of this file described **Supabase-managed PITR / daily snapshots**, which does
> **not** match the actual deployment. NIKSHA OS runs on a **self-hosted VPS** with nightly, AES-256
> **encrypted** `pg_dump` backups (script `deploy/akshara-vps/backup/akshara-backup.sh`), an
> `ops_backup_runs` ledger, a monthly restore drill, and an operator-only `/health/backup` probe. The
> stale Supabase-PITR description was removed to avoid contradicting the canonical runbook.
>
> A tighter RPO via WAL archiving / PITR is a **tracked follow-up** (owner-gated `P0-INFRA-2`), not the
> current mechanism — see the canonical runbook §5.

**Go to → [`../BACKUP_RESTORE_RUNBOOK.md`](../BACKUP_RESTORE_RUNBOOK.md)** for backup production,
restore (operator-over-SSH), restore-drill thresholds, RPO/RTO, and escalation.
