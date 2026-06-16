# Backup & Restore Architecture

## Overview

Akshara provides **Akshara-managed backups** for operational recovery and optional **school-owned export packages** for compliance and portability.

## Components

| Layer | Responsibility |
|-------|----------------|
| Backup Scheduler | Nightly incremental + weekly full per tenant |
| Snapshot Store | Encrypted object storage (Akshara-managed) |
| Export Service | School-initiated package generation |
| Restore Orchestrator | Validates manifest, applies tenant/school scope |
| Audit | All backup/restore/export events logged |

## Backup Types

### Akshara-managed

- **School backup** — single school within tenant
- **Tenant backup** — all schools + config for organization
- **Incremental** — changes since last snapshot

### School-owned exports

- **Export package** — ZIP with manifest + anonymization options
- **Destinations**: Google Drive, OneDrive, direct download archive

## Data Domains in Package

```
manifest.json
sis/
finance/
attendance/
exams/
communications/
school_config/
audit_index.json
```

## Restore Flow

```mermaid
flowchart LR
  A[Select snapshot] --> B[Validate manifest]
  B --> C[Staging import]
  C --> D[Admin review]
  D --> E[Commit restore]
  E --> F[Audit + notify]
```

## Security

- AES-256 at rest
- Tenant isolation keys
- RBAC: `manageBackup` / `restoreTenant`
- Restore requires dual approval for production tenants

## UI Entry Points

- Admin → Operations → Backup & Restore (`/admin/backup-restore`)
- Export wizard with destination picker
- Restore runbook linked from confirmation dialog

## Remaining Gaps (post-implementation)

- Production object storage wiring (S3/GCS)
- Google Drive / OneDrive OAuth connectors
- Point-in-time recovery for Supabase Postgres
