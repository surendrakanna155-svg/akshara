# NIKSHA OS — Data Backup & Recovery Policy

**Document version:** 1.0
**Status:** Draft for owner sign-off (see [PLACEHOLDERS.md](PLACEHOLDERS.md))
**Operator:** **NIKSHA Technologies Pvt. Ltd.** ("NIKSHA OS", "we", "us").

> This policy explains how NIKSHA OS protects against data loss through backups, and
> how it restores service after an incident. It supports the
> [Security Policy](SECURITY_AND_RESPONSIBLE_DISCLOSURE.md) and the
> [Privacy Policy](PRIVACY_POLICY.md).

---

## 1. Goal

Protect schools' data against accidental loss, corruption, or hardware/software
failure, and be able to restore the service to a recent, consistent state.

## 2. What we back up

- The **production database** (all school operational data: students, attendance,
  exams, fees, communication, audit logs, legal-acceptance records, etc.).
- **Uploaded files** held in managed storage (photos, documents).
- **Configuration** needed to rebuild the service.

## 3. How backups work

- **Schedule:** automated **nightly** backups of the production database.
- **Encryption:** backups are **encrypted at rest**.
- **Integrity:** backups are **restore-tested** so we know they actually work — a
  backup that cannot be restored is not a backup.
- **Health monitoring:** a backup-health signal is exposed to operations
  monitoring, and alerts fire if a backup is missed or fails.
- **Retention:** backups are kept on a **rolling cycle**; older backups age out and
  are deleted, which is also how deleted records eventually disappear from backups
  (see the [Retention Policy](DATA_RETENTION_AND_DELETION_POLICY.md)).

## 4. Where backups are stored

Backups are stored within the operator's controlled infrastructure. The production
service is **self-hosted** (not on a third-party managed cloud database), which
keeps primary data and backups within infrastructure the operator controls.

## 5. Recovery objectives (targets)

These are operational targets, not guarantees, and will be tightened as the service
matures:

| Objective | Target |
|---|---|
| **RPO** (Recovery Point Objective — maximum acceptable data loss) | Up to the last successful nightly backup (≤ 24 hours), and shorter where point-in-time recovery is available. |
| **RTO** (Recovery Time Objective — time to restore service) | Best effort to restore core service within a small number of hours of a confirmed loss event. |

## 6. Restore process

1. Confirm the incident and decide the recovery point.
2. Provision/clean the target environment.
3. Restore the most recent **verified** backup (database + files).
4. Validate integrity and key journeys before reopening access.
5. Communicate status to affected Institutions.
6. Record a post-incident review and improvements.

## 7. Responsibilities

- **NIKSHA OS** maintains backups and runs recovery of the central service.
- **Schools** remain responsible for data they choose to export and hold outside
  NIKSHA OS, and for following their own continuity practices.
- Backups are subject to the same **security and access controls** as production
  data; only authorised operations personnel can access them.

## 8. Limits

Backups reduce, but cannot entirely eliminate, the risk of data loss. In a severe
event, the most recent recoverable state may be the last successful backup. Schools
should keep their own copies of records they are legally required to retain.

## 9. Changes

Material changes to this policy are recorded in the [CHANGELOG](CHANGELOG.md).
