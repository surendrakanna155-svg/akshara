# Akshara ERP — Deployment Architecture

**Document ID:** `AKS-DEPLOY-ARCH-v1.0`  
**Status:** Architecture specification (no infrastructure code)  
**Last updated:** June 2026

---

## 1. Environment Topology

| Environment | Purpose | Data | Access |
|-------------|---------|------|--------|
| **Development** | Local dev; mock + local Supabase | Synthetic | Developers |
| **Staging** | Integration testing; contract validation | Anonymized copy | Team + CI |
| **Pilot** | Single real school; limited users | Real (pilot school) | Pilot school staff |
| **Production** | Live SaaS | Real | Customers |

Flutter client environments map via `Environment.development | staging | production` (existing).

---

## 2. Staging Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    STAGING                               │
├─────────────────────────────────────────────────────────┤
│  Cloudflare (DNS + WAF + CDN)                           │
│       │                                                  │
│       ▼                                                  │
│  Supabase Project (staging)                             │
│    ├── PostgreSQL (db-staging)                          │
│    ├── Auth (OTP test mode)                             │
│    ├── PostgREST (/rest/v1)                             │
│    ├── Edge Functions (/functions/v1)                   │
│    └── Storage (staging bucket)                         │
│       │                                                  │
│       ├── Redis (Upstash staging)                       │
│       └── R2 (staging files)                            │
├─────────────────────────────────────────────────────────┤
│  CI Runners → contract tests → staging deploy gate       │
│  Flutter integration tests → fake Dio + staging E2E     │
└─────────────────────────────────────────────────────────┘
```

**Staging gates before production:**
- `flutter analyze` = 0
- `flutter test` = all passing
- Contract tests vs staging OpenAPI
- RBAC + tenant isolation integration tests (v5.6)
- Audit ingestion smoke test (v5.7)

---

## 3. Production Architecture

```
┌─────────────────────────────────────────────────────────┐
│                   PRODUCTION                             │
├─────────────────────────────────────────────────────────┤
│  Cloudflare (DNS + WAF + DDoS + Rate limiting)          │
│       │                                                  │
│       ▼                                                  │
│  Supabase Project (production) — Multi-AZ               │
│    ├── PostgreSQL (primary + read replica)              │
│    ├── Connection pooling (PgBouncer)                   │
│    ├── PostgREST (auto-scaled)                          │
│    ├── Edge Functions (regional)                        │
│    └── Storage → R2 (production bucket)                 │
│       │                                                  │
│       ├── Redis (HA cluster)                            │
│       └── Message queue (audit drain, notifications)    │
├─────────────────────────────────────────────────────────┤
│  Observability                                           │
│    ├── Sentry (errors — client v5.5 adapter)            │
│    ├── Datadog (APM + logs — client v5.5 adapter)       │
│    └── Uptime monitoring (health endpoints)             │
├─────────────────────────────────────────────────────────┤
│  External services                                       │
│    ├── FCM (push notifications)                         │
│    ├── MSG91/Twilio (OTP SMS)                           │
│    ├── Razorpay (payments — future)                     │
│    └── OpenAI (copilot — future)                        │
└─────────────────────────────────────────────────────────┘
```

**Regions:** Primary `ap-south-1` (Mumbai); CDN global.

---

## 4. CI/CD Architecture

```
┌──────────────┐     PR      ┌──────────────┐
│  Developer   │ ──────────► │   GitHub     │
│  (Flutter)   │             │   Actions    │
└──────────────┘             └──────┬───────┘
                                    │
                    ┌───────────────┼───────────────┐
                    ▼               ▼               ▼
              flutter analyze  flutter test   contract tests
                    │               │               │
                    └───────────────┼───────────────┘
                                    ▼
                           Merge to main (green)
                                    │
                    ┌───────────────┴───────────────┐
                    ▼                               ▼
            Supabase CLI deploy              Flutter web build
            (staging auto)                   (staging CDN)
                    │
                    ▼ (manual approval)
            Production deploy
```

| Pipeline | Trigger | Actions |
|----------|---------|---------|
| PR check | Pull request | analyze + test + contract |
| Staging deploy | Push to `main` | Supabase migrations + Edge Functions |
| Production deploy | Tagged release | Manual approval + deploy |
| Rollback | Incident | Redeploy previous tag; DB rollback via migration down |

**Future:** Separate backend repo CI when NestJS services extracted.

---

## 5. Backup Strategy

| Asset | Method | Frequency | Retention |
|-------|--------|-----------|-----------|
| PostgreSQL | Supabase automated backups + PITR | Continuous WAL | 30 days PITR |
| PostgreSQL | Manual snapshot before migrations | Per deploy | 90 days |
| R2 files | Cross-region replication | Continuous | Same as DB |
| Audit archive | Monthly export to cold storage | Monthly | 7 years |
| Redis | Not backed up (cache only) | — | — |

---

## 6. Disaster Recovery Overview

| Scenario | RTO | RPO | Procedure |
|----------|-----|-----|-----------|
| DB corruption | 1 hour | 5 min | PITR restore to new instance |
| Region outage | 4 hours | 15 min | Failover to replica region (future) |
| Supabase incident | 2 hours | 15 min | Restore from backup; status page comms |
| R2 bucket loss | 2 hours | 0 (replicated) | Failover to replica bucket |
| Auth service down | 30 min | 0 | Cached JWT valid 15 min; queue writes |

**DR drill:** Quarterly staging restore test.

---

## 7. Secrets Management

| Secret | Store |
|--------|-------|
| DB credentials | Supabase vault |
| JWT signing keys | Supabase Auth / rotation quarterly |
| SMS API keys | Supabase secrets |
| R2 credentials | Supabase secrets |
| Sentry/Datadog DSN | Environment variables |

No secrets in Flutter client except public anon key (Supabase) with RLS protection.

---

## 8. Scaling Considerations

| Load | Strategy |
|------|----------|
| 1–10 schools | Single Supabase project |
| 10–100 schools | Read replicas; connection pooling |
| 100+ schools | Evaluate dedicated DB per large org; NestJS extraction |
| Audit volume | Monthly partitioning; async ingestion queue |

---

## 9. Implementation Phases

| Sprint | Deliverable |
|--------|-------------|
| Sprint 2 | Staging Supabase project; CI staging deploy |
| Sprint 3 | Production project; backup verification |
| Sprint 4 | Monitoring dashboards; alerting |
| Sprint 5 | DR drill; production pilot |
| Sprint 6 | Multi-region evaluation |

No infrastructure code created in Sprint 1.
