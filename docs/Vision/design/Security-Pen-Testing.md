# Design — Security & Penetration Testing

**Status:** Future hardening track · not v1.0 blocker if pilot scope limited

## Goals

- Independent validation of auth, RBAC, RLS, and API attack surface  
- OWASP ASVS L2 alignment for SaaS multi-tenant  
- Annual pen test cadence post-GA  

## Architecture

| Area | v1.0 baseline | Target |
|------|---------------|--------|
| Auth | JWT + OTP | + device binding option |
| RBAC | Client + partial server | Full server enforcement |
| RLS | 213 probes | Continuous probe CI |
| Secrets | Supabase vault | Rotation runbook |
| Audit | Client + ingestion | Immutable server audit |

## Permissions

Pen test scope accounts: `pentest_readonly`, `pentest_school_admin` — isolated tenants, no production PII.

## Data model

No schema change — test fixtures in dedicated `pentest_*` org/school IDs.

## APIs

Test inventory from OpenAPI + route inventory tests. Focus: IDOR across `school_id`, JWT scope confusion, webhook replay.

## Rollout plan

1. Pre-GA: internal OWASP ZAP on staging  
2. First school pilot: targeted manual test (auth, onboarding, finance)  
3. Post-GA: third-party pen test  
4. Remediation sprints from findings register  

## Risks

| Risk | Mitigation |
|------|------------|
| Test in prod | Staging clone only |
| Probe false negatives | Expand tenant-access probes per new module |
