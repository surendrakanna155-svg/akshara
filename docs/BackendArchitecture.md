# Akshara ERP — Backend Architecture

**Document ID:** `AKS-BE-ARCH-v1.1`  
**Status:** Architecture specification (no implementation)  
**Aligned with:** Flutter client v5.5 · `docs/TechnicalArchitecture.md` · 144 repository methods  
**Last updated:** June 2026 (v5.6 gap closure)

---

## 1. Purpose

Define the backend platform architecture for Akshara ERP — a multi-tenant school SaaS serving web ERP, mobile apps (Parent, Teacher, Student), and future AI/copilot services. This document is the **source of truth for backend design decisions** before Sprint 2 implementation.

---

## 2. Recommended Stack

| Layer | Recommendation | Rationale |
|-------|----------------|-----------|
| **Database** | PostgreSQL 15+ | RLS, JSONB, full-text, partitioning; aligns with SRS |
| **Platform** | Supabase (managed Postgres + Auth + Storage + Realtime) | Fast pilot; RLS-native; matches `TechnicalArchitecture.md` |
| **API surface** | PostgREST (auto REST) + Edge Functions (TypeScript/Deno) | CRUD at scale; complex workflows in functions |
| **Future services** | NestJS microservices (Node 20 LTS) | Complex domains: payments, AI copilots, report engine |
| **Object storage** | Cloudflare R2 (S3-compatible) | Documents, receipts, school memories media |
| **Cache** | Redis (Upstash or ElastiCache) | Sessions, permission cache, rate limits |
| **Queue** | PostgreSQL `pgmq` or Supabase Queues | Audit drain, async workflows, notifications |
| **Search** | PostgreSQL FTS → OpenSearch (future) | Student/parent search at scale |
| **Observability** | OpenTelemetry → Datadog/Sentry | Matches client v5.5 adapters |
| **API contract** | OpenAPI 3.1 (source of truth) | Aligns with 37 Flutter contract test files |

**Decision:** Start with **Supabase + Edge Functions** for Sprint 2–4; extract NestJS services when a domain exceeds Edge Function limits (AI inference, payment orchestration, report generation).

---

## 3. Service Boundaries

```
┌─────────────────────────────────────────────────────────────────────┐
│                         API GATEWAY LAYER                            │
│  Cloudflare / Supabase API Gateway · TLS · WAF · Rate limiting       │
│  Headers: Authorization · X-Tenant-Id · X-School-Id · X-Correlation-Id │
└───────────────────────────────┬─────────────────────────────────────┘
                                │
        ┌───────────────────────┼───────────────────────┐
        ▼                       ▼                       ▼
┌───────────────┐     ┌─────────────────┐     ┌─────────────────┐
│ Identity      │     │ ERP Core API    │     │ Platform API    │
│ Service       │     │ (PostgREST +    │     │ (Control Center │
│ Auth · OTP ·  │     │  Edge Functions)│     │  · CRM · Billing│
│ Sessions ·    │     │ Admissions ·    │     │  · White-label) │
│ RBAC sync     │     │ Finance · SIS · │     └─────────────────┘
└───────────────┘     │ 11 ERP modules  │
                      └────────┬────────┘
                               │
        ┌──────────────────────┼──────────────────────┐
        ▼                      ▼                      ▼
┌───────────────┐     ┌─────────────────┐     ┌─────────────────┐
│ Notification  │     │ Audit Ingestion │     │ File Service    │
│ FCM · SMS ·   │     │ Append-only log │     │ R2 presigned    │
│ Email         │     │ Correlation     │     │ uploads         │
└───────────────┘     └─────────────────┘     └─────────────────┘
                               │
        ┌──────────────────────┴──────────────────────┐
        ▼ (Future — Sprint 6+)                         ▼
┌───────────────┐                              ┌─────────────────┐
│ AI Copilot    │                              │ Payment Engine  │
│ Service       │                              │ Razorpay · UPI  │
│ OpenAI proxy  │                              │ reconciliation  │
└───────────────┘                              └─────────────────┘
```

### Domain ownership

| Service | Modules | Methods (client contract) |
|---------|---------|---------------------------|
| Identity | Auth, sessions, OTP, RBAC sync | 6 |
| Admissions | Leads, applications, approval, enrollment | 30 |
| Finance | Fees, collections, refunds, scholarships | 23 |
| SIS | Students, academic assignment | 10 |
| Operations | Transport, HR, Hostel, Library, Inventory | 44 |
| Engagement | Alumni, Management | 17 |
| Platform | Control Center, CRM, billing | 12 |
| Mobile | Parent, Teacher, Student aggregated reads | 29 |

---

## 4. API Gateway Architecture

### Request flow

1. Client attaches JWT access token + tenant headers (`ApiConfig` in Flutter).
2. Gateway validates TLS, rate limit, WAF rules.
3. JWT verified; claims extracted (`sub`, `tenant_id`, `school_id`, `role`, `permissions_version`).
4. Tenant context injected into request scope (never trust client body for tenant ID).
5. Route to PostgREST (read-heavy) or Edge Function (mutations, workflows).
6. Correlation ID propagated: `X-Correlation-Id` → logs → audit → traces.

### Versioning

- Header: `X-Api-Version: 1` (matches client `ApiConfig.apiVersion`).
- URL prefix: `/v1/` for Edge Functions; PostgREST uses schema versioning.
- Breaking changes require version bump + 6-month deprecation window.

### Response envelope (matches client DTOs)

```json
{
  "data": { },
  "meta": { "page": 1, "pageSize": 25, "total": 142, "hasMore": true },
  "error": null
}
```

Errors map to client `ApiFailure` types: `unauthorized`, `forbidden`, `notFound`, `validation`, `conflict`, `rateLimited`, `serverError`.

---

## 5. OpenAPI Strategy

| Rule | Detail |
|------|--------|
| **Source of truth** | `openapi/akshara-v1.yaml` (to be created Sprint 2) |
| **Generation** | PostgREST schema → partial OpenAPI; Edge Functions documented manually |
| **Validation** | CI: Spectral lint + contract diff against Flutter DTO tests |
| **Parity gate** | No backend deploy without passing client contract tests |
| **Pagination** | Standard `page`, `pageSize`, `sort`, `filter` query params on all list endpoints |

Existing Flutter contract tests (37 files) define the **minimum acceptable API surface** for Sprint 2.

---

## 6. Monitoring Architecture

| Signal | Collection | Destination |
|--------|------------|-------------|
| HTTP latency / status | Gateway + PostgREST middleware | Datadog APM |
| Error rates | Edge Function exception handler | Sentry |
| Auth failures | Identity service | Alert: >5% in 5 min |
| Permission denials | RBAC middleware | Audit + metric |
| DB query time | pg_stat_statements | Datadog |
| Queue depth | Audit ingestion queue | Alert: >1000 pending |

Dashboards: API health, auth health, per-tenant error rate, audit ingestion lag.

---

## 7. Observability Architecture

```
Client (Flutter v5.5)
  MonitoringService → Sentry/Datadog
  AnalyticsService  → product events
  AuditLogger       → local queue → POST /v1/audit/events
         │
         ▼
Backend
  OpenTelemetry SDK (Edge Functions + future NestJS)
  Correlation ID ↔ Trace ID mapping
  Structured JSON logs (tenant_id, school_id, user_id, correlation_id)
         │
         ▼
  Datadog / Sentry / log aggregation
```

**Trace propagation:** `X-Correlation-Id` header = W3C `traceparent` suffix or mapped 1:1.

---

## 8. Future Compatibility

Architecture supports these future products without schema redesign:

| Future product | Extension point |
|----------------|-----------------|
| Multi-School Organizations | `organizations` + `school_groups` tables; org-level RLS |
| Organization Admin | `organization_memberships` role scope |
| Communication Hub | Notification service + message threads table |
| Teacher/Principal Copilot | AI service; reads SIS/attendance via service account |
| Parent Guidance Assistant | Mobile AI endpoint; scoped to parent child IDs |
| Student Risk Engine | Analytics schema; batch scoring jobs |
| School Health Score | Aggregated metrics materialized views |
| Smart Timetable / Workload | Scheduling service; conflict engine |
| Universal Payment Engine | Payment service; ledger tables |
| Inventory-Finance Integration | Cross-module event bus |
| School Memories / Akshara Growth | Media service + engagement schema |
| Document & Report Engine | Template service + PDF generation |
| Akshara Business Suite / CRM | Platform service (Control Center extension) |

Detailed specifications: §10–§13. Client alignment: §14.

---

## 10. Domain Event Bus

> ⚠️ **IMPLEMENTATION STATUS (verified 2026-07-28): this section describes a
> DESIGN, not current behaviour.** `domain_events` is a durable, idempotency-keyed,
> RLS-hardened **log** — genuinely good, and worth keeping. It is **not a bus
> today**: every event is inserted in terminal `status='published'` while the drain
> selects `pending|failed` (empty by construction), the subscriber registry is
> empty, and no cron invokes the drain.
>
> Consequently the two propagation claims below are **not** what the code does:
> notifications are enqueued **inline** by the calling handler, and fee collection
> notifies the parent through a **direct** `sendTransactionalSms` call. Neither
> goes through an event. Treat every "publishes X → Y reacts" statement in this
> section as the target design.
>
> See `docs/engineering/DOMAIN_EVENTS_ARCHITECTURE.md` for the exact mechanism and
> the sequencing constraint (scheduler first, status second).


Cross-module integration uses a **transactional outbox** pattern:

```
Mutation handler → business tables (same TX) → domain_events row (pending)
        │
        ▼ (async worker)
Event router → Audit · Notification · Finance posting · Analytics
```

| Property | Rule |
|----------|------|
| Table | `domain_events (id, tenant_id, event_type, payload, correlation_id, created_at, published_at)` |
| Delivery | At-least-once; consumers idempotent on `event_id` |
| Correlation | Propagate `X-Correlation-Id` into every event |
| Sprint | Outbox schema Sprint 5; consumers phased v7.x |

**Replaces** ad-hoc cross-module calls for: Admissions→Finance handoff, Inventory→Finance posting, payment capture→ledger, message→notification.

---

## 11. Communication Hub Architecture

### Service boundaries

| Component | Owner | Responsibility |
|-----------|-------|----------------|
| **Communication Service** | Edge Functions + PostgREST | Threads, messages, broadcasts |
| **Notification Service** | Existing (FCM/SMS/Email) | Delivery only; no business logic |
| **Translation Service** | Edge Function | Message body translation (future locales) |
| **Audit Service** | Shared | All send/broadcast events |

Communication Service **does not** send push directly — publishes `notification.requested` domain event.

### Message architecture

| Type | Scope | Tables |
|------|-------|--------|
| Direct | Parent ↔ Teacher | `comm_threads` (type=direct) |
| Group | Class, staff group | `comm_threads` (type=group) |
| Channel | Persistent topic | `comm_channels` |

Messages stored in `comm_messages`; attachments via File Service (R2).

### Broadcast architecture

| Audience | Scope | Approval |
|----------|-------|----------|
| School-wide | `school_id` set | `sendBroadcast` + `manageCommunications` |
| Org-wide | `school_id` null | `organizationAdmin` + `sendBroadcast` |
| Group | Schools in group | `schoolGroupDirector` or org admin |

Broadcasts create `comm_broadcasts` + fan-out `comm_recipients`; delivery async via Notification Service.

### Notification architecture

```
comm_messages INSERT
  → domain_event: notification.requested
  → Notification Service
      → FCM (mobile)
      → SMS (optional, parent urgent)
      → Email (staff digest)
```

Deep links: `{module}/{entity}/{id}` per `Notifications.md` convention.

### Translation architecture

| Layer | Approach |
|-------|----------|
| Storage | Original in `comm_messages.body`; translations in `comm_message_translations` |
| Default locale | School setting `primary_locale` (e.g. `en`, `hi`, `te`) |
| On-read | Client requests locale; server returns translation or original |
| On-write (future) | Async translation job for broadcast messages |

### RBAC

See `RBACArchitecture.md`: `viewCommunications`, `manageCommunications`, `sendBroadcast`.

**Sprint plan:** Notification infra Sprint 5; full Hub v7.1.

---

## 12. Universal Payment Engine Architecture

### Payment request model

```
payment_requests (
  id, tenant_id, school_id,
  source_type,      -- fee_assignment | fine | event | adhoc
  source_id,        -- FK to finance entity
  payer_user_id,  -- parent
  amount, currency, due_date, status
)
```

Finance module creates `payment_requests`; Payment Engine owns gateway lifecycle.

### Payment intent lifecycle

```
pending → initiated → authorized → captured → settled
                  ↘ failed ↗ (retry)
                  ↘ cancelled
```

| State | Owner | Action |
|-------|-------|--------|
| `pending` | Finance | Request created |
| `initiated` | Payment Engine | Razorpay order created |
| `authorized` | Gateway | Customer authorized |
| `captured` | Payment Engine | Webhook confirmed |
| `settled` | Payment Engine | Reconciliation matched |
| `failed` / `cancelled` | Payment Engine | Terminal states |

### Gateway integration architecture

| Component | Detail |
|-----------|--------|
| Gateway | Razorpay (primary); UPI, cards, netbanking |
| Webhooks | `POST /v1/webhooks/razorpay` — signature verified |
| Idempotency | `Idempotency-Key` header + DB unique constraint |
| Refunds | Reverse flow via Finance `approveRefunds` + gateway refund API |

### Reconciliation architecture

Daily job compares:

1. Gateway settlement report (Razorpay)
2. `payment_transactions` sum
3. `ledger_entries` for cash account

Mismatches → `payment_reconciliations.status=discrepancy` + alert.

### Finance integration boundaries

| Owned by Finance module | Owned by Payment Engine | Shared |
|---------------------------|-------------------------|--------|
| `fee_structures`, `student_accounts`, `collections` | `payment_intents`, gateway IDs | `payment_requests` |
| Refund approval workflow | Capture/settlement | `ledger_entries` posting |
| Fee assignment logic | Razorpay orchestration | Reconciliation |

Payment capture publishes `payment.captured` → Finance updates `collections` via domain event (not direct cross-schema write from Payment service).

### Audit architecture

Events: `paymentRequested`, `paymentInitiated`, `paymentCaptured`, `paymentFailed`, `paymentReconciled`. See `AuditArchitecture.md` §5.

**Sprint plan:** v7.0 after Sprint 6 pilot.

---

## 13. Inventory-Finance Integration Architecture

### Event model

| Event type | Publisher | Consumer | Payload |
|------------|-----------|----------|---------|
| `procurement.approved` | Inventory | Finance | `procurement_id`, `vendor_id`, `amount`, `line_items[]` |
| `procurement.received` | Inventory | Finance | GRN → AP invoice draft |
| `vendor.created` | Inventory | Finance | `vendor_id`, master data |
| `vendor.updated` | Either | Both | Sync master fields |
| `finance.payment.scheduled` | Finance | Inventory | `procurement_id`, `payment_date` |

All events flow through `domain_events` outbox (§10).

### Ownership model

| Entity | System of record | Readers |
|--------|------------------|---------|
| `vendors` | Shared table (Finance owns GST/compliance fields) | Inventory, Finance |
| `procurement` | Inventory | Finance (read + post) |
| `finance_commitments` / AP | Finance | Inventory (status read) |
| `ledger_entries` | Finance | Audit, Management |

Inventory **never** writes ledger directly. Finance **never** mutates procurement status except via acknowledged events.

### Finance posting model

```
procurement.approved event
  → Finance consumer
  → CREATE finance_commitment (AP)
  → CREATE ledger_entries (debit expense, credit AP)
  → INSERT inventory_finance_postings (link)
  → audit: procurementFinancePosted
```

Capital assets (high-value inventory) may trigger additional capitalization entries (future).

### Audit model

| Event | Category | Metadata |
|-------|----------|----------|
| `procurementFinancePosted` | workflow | `procurement_id`, `commitment_id` |
| `vendorSynced` | workflow | `vendor_id`, `source_module` |
| `domainEventPublished` | system | `event_type`, `event_id` |

### Future implementation roadmap

| Phase | Deliverable | Dependency |
|-------|-------------|------------|
| Sprint 5 | `domain_events` outbox + router | Audit Sprint 5 |
| v7.2a | Shared `vendors` table + sync events | Sprint 4 Inventory + Finance APIs |
| v7.2b | `procurement.approved` → AP posting | v7.2a |
| v7.2c | Reconciliation UI in Finance | v7.2b |

See `archive/roadmap/BackendRoadmap.md` §8.

---

## 14. Client/Backend Alignment

See `docs/ClientBackendAlignment.md` for enum additions, JWT scope parsing, and dependency graph.

---

## 15. Non-Goals (Sprint 1)

- No NestJS project scaffolding
- No Docker/K8s manifests
- No database migrations
- No API endpoint implementations

See `archive/roadmap/BackendRoadmap.md` for implementation phases.
