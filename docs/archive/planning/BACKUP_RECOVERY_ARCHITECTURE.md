# Backup & Recovery Architecture — Akshara v1

> **Note (June 2026):** In-app school/tenant export and restore UI is documented in  
> [`BACKUP_RESTORE_ARCHITECTURE.md`](./BACKUP_RESTORE_ARCHITECTURE.md) and  
> [`BACKUP_RESTORE_RUNBOOK.md`](./BACKUP_RESTORE_RUNBOOK.md).  
> **This document** covers infrastructure-layer recovery (Supabase PITR, R2, DevOps).

**Program:** Release Candidate — Backup & Recovery  
**Date:** June 2026  
**Scope:** Architecture + operations (backend/DevOps implementation)  
**Related:** `docs/DeploymentArchitecture.md`, `docs/Operations/Restore-Runbook.md`

---

## Current state

| Layer | Backup capability | Implementation |
|-------|-------------------|----------------|
| **PostgreSQL (Supabase)** | Automated + PITR | Platform-managed |
| **Object storage (R2)** | Org export archives | Sprint 3 RBAC doc |
| **Client audit queue** | Local persistence + upload | Flutter — not a DB backup |
| **Flutter app** | Export UI stub + local prefs | `backup_restore_screen.dart` — see `BACKUP_RESTORE_ARCHITECTURE.md` |

**Gap:** Production object storage and OAuth export connectors not wired — operational recovery remains infrastructure-operated for Postgres.

---

## Target architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Akshara Control Plane                     │
│  (Supabase project · R2 · feature flags · audit store)      │
└─────────────────────────────────────────────────────────────┘
         │                    │                    │
         ▼                    ▼                    ▼
   ┌──────────┐        ┌──────────┐        ┌──────────┐
   │ Tenant A │        │ Tenant B │        │ School n │
   │ (org)    │        │ (org)    │        │ (branch) │
   └──────────┘        └──────────┘        └──────────┘
```

---

## Automated backups

| Asset | Method | Frequency | Retention |
|-------|--------|-----------|-----------|
| PostgreSQL | Supabase WAL + daily snapshot | Continuous PITR | 30 days PITR |
| File exports | Encrypted archive → R2 | On-demand + scheduled org export | 90 days default |
| Audit log store | Replicated write | Real-time | Policy per tenant tier |
| Secrets / config | Infra vault | Versioned | 12 months |

---

## Retention policies

| Tier | DB PITR | Export retention | DR RTO |
|------|---------|------------------|--------|
| Pilot | 7 days | 30 days | 4 hours |
| Standard | 30 days | 90 days | 2 hours |
| Enterprise | 30 days + geo replica | 1 year | 1 hour |

---

## School-level restore

**Use case:** Accidental deletion of a single school's configuration or academic year data.

1. Identify `school_id` + timestamp of last good state  
2. Restore DB branch to PITR point **or** run school-scoped export import  
3. Validate: student count, fee assignments, timetable  
4. Notify school admin; freeze writes during restore window  

**Flutter role:** None — operations runbook only. Future: read-only "restore status" in Platform Operations.

---

## Tenant-level restore

**Use case:** Org-wide corruption, ransomware, or bad migration.

1. Create new Supabase branch from PITR (`Restore-Runbook.md`)  
2. Run post-restore validation checklist  
3. DNS / API gateway cutover to restored instance  
4. Invalidate all sessions (force re-login)  
5. Audit log correlation for incident report  

---

## Disaster recovery workflow

| Scenario | RPO | RTO | Procedure |
|----------|-----|-----|-----------|
| DB corruption | 15 min | 2 hr | PITR → new instance |
| Region outage | 15 min | 4 hr | Restore backup + status comms |
| Supabase incident | 15 min | 2 hr | Vendor restore + comms |
| Client-only failure | N/A | Minutes | Reinstall app; session restore |

**DR drill:** Quarterly staging restore per `docs/ReleaseGovernance.md`.

---

## Flutter application responsibilities

| Responsibility | Status |
|----------------|--------|
| Offline audit queue durability | ✅ Implemented |
| Graceful degradation when API unavailable | ✅ Mock mode |
| User-facing backup UI | ❌ Out of scope |
| Export user data (GDPR) | Backend API (future) |

---

## Implementation backlog (non-Flutter)

| # | Task | Owner |
|---|------|-------|
| 1 | Automate pre-deploy SQL dump | DevOps |
| 2 | Quarterly restore drill in staging | Infra |
| 3 | School-scoped export API | Backend |
| 4 | Restore status endpoint for ops hub | Backend + Agent B |

---

## Sign-off

Architecture **documented**. Production backup restore test (checklist B2) remains an **infra gate** before GA.
