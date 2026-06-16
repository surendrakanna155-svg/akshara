# Backup & Restore Operational Runbook

## Akshara-managed school backup

1. Navigate to **Admin → Backup & Restore**
2. Select **School backup**
3. Choose school scope and label (e.g. `pre-term-2026`)
4. Confirm — job queues within 60 seconds
5. Verify status **Completed** in job list
6. Audit event `backup.school.completed` appears in Audit log

## Tenant restore (disaster recovery)

1. Require **Principal + Platform Admin** approval
2. Select tenant snapshot (newest verified full backup)
3. Run **Validate manifest** — resolve errors before proceed
4. Choose **Staging restore** first on non-production mirror
5. Smoke test: login, SIS count, fee balance sample
6. Production restore: maintenance window, notify schools
7. Post-restore: reconcile audit index, verify exam publish chain

## School export package

1. **Export package** → select domains (SIS, finance, exams, etc.)
2. Destination: Download / Google Drive / OneDrive
3. Package includes `manifest.json` with checksums
4. Store off-site per school IT policy (retention 7 years recommended)

## Rollback

- Restore jobs support **rollback to pre-restore snapshot** within 24h
- After 24h, use prior backup snapshot explicitly

## Escalation

| Symptom | Action |
|---------|--------|
| Backup job stuck > 30 min | Check scheduler pod, retry |
| Restore validation fails | Do not commit; open platform ticket |
| Export OAuth denied | Re-authorize Drive/OneDrive in school settings |

## Contacts

- Platform on-call: via Control Center escalation
- School IT: documented in tenant admin profile
