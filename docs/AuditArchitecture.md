# Akshara ERP — Audit Architecture

**Document ID:** `AKS-AUDIT-ARCH-v1.1`  
**Status:** Architecture specification (no implementation)  
**Aligned with:** Client `AuditLogger` · `AuditEventType` · `AuditUploadQueue`  
**Resolves:** TD-P0-02 (upon Sprint 5 implementation)  
**Last updated:** June 2026 (v5.6 gap closure)

---

## 1. Overview

Audit architecture provides a **tamper-evident, queryable trail** of security, auth, workflow, and system events across all tenants. Client events queue locally and drain to server; server events written directly.

```
┌─────────────┐  batch upload   ┌─────────────┐  append-only  ┌─────────────┐
│ Flutter     │ ──────────────► │ Audit       │ ────────────► │ PostgreSQL  │
│ AuditQueue  │                 │ Ingestion   │               │ audit_events│
└─────────────┘                 │ Service     │               └─────────────┘
                                └──────▲──────┘
                                       │ direct write
                                ┌──────┴──────┐
                                │ All backend │
                                │ mutations   │
                                └─────────────┘
```

---

## 2. Audit Ingestion

### Client upload

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/v1/audit/events` | POST | Batch upload from client queue |
| `/v1/audit/events` | GET | Query (admin only) |

**Batch payload:**

```json
{
  "events": [
    {
      "id": "client-uuid",
      "type": "leadCreated",
      "timestamp": "2026-06-07T10:00:00Z",
      "userId": "uuid",
      "tenantId": "uuid",
      "schoolId": "uuid",
      "correlationId": "uuid",
      "category": "workflow",
      "metadata": { "leadId": "L-001" }
    }
  ]
}
```

### Ingestion rules

1. Validate JWT; reject cross-tenant events.
2. Idempotent on client `id` (dedupe table).
3. Enrich: server IP, user agent, ingestion timestamp.
4. Append to `audit_events`; never update.
5. Return `{ "accepted": 5, "duplicates": 0, "rejected": 0 }`.

### Server-side emission

All mutation handlers emit audit events **after** successful commit (same transaction or outbox pattern).

---

## 3. Audit Storage

| Tier | Store | Retention | Query |
|------|-------|-----------|-------|
| Hot | `audit_events` (partitioned monthly) | 90 days | Real-time admin UI |
| Warm | `audit_events_archive` | 1 year | Compliance reports |
| Cold | R2 JSONL exports | 7 years | Legal hold |

### Partitioning

```sql
-- Monthly partitions on created_at
audit_events_2026_06 PARTITION OF audit_events
  FOR VALUES FROM ('2026-06-01') TO ('2026-07-01');
```

### Indexing

- `(tenant_id, created_at DESC)`
- `(tenant_id, event_type, created_at DESC)`
- `(correlation_id)`
- `(user_id, created_at DESC)`
- `(entity_type, entity_id)` — workflow traceability

---

## 4. Correlation IDs

| Source | Header | Usage |
|--------|--------|-------|
| Client | `X-Correlation-Id` | End-to-end request trace |
| Server | Generated if missing | Propagate to logs + audit |
| Audit event | `correlation_id` column | Link client + server events |

**Trace chain example:**

```
User clicks "Approve" → correlation_id=abc
  → Client audit: admissionApproved (abc)
  → API request header: X-Correlation-Id: abc
  → Server audit: admissionApproved (abc)
  → DB mutation: applications.status = approved
  → Notification job: correlation_id=abc
```

Client `CorrelationIdInterceptor` and `AuditEvent.correlationIdFromMetadata` already implement client side.

---

## 5. Event Types

### Client-aligned events (24 today)

| Category | Events |
|----------|--------|
| **auth** | login, logout, tokenRefresh |
| **security** | accessDenied, roleChange, tenantChange, sessionRevoked, logoutAllSessions, permissionSync, permissionDenied, auditUploadFailed |
| **workflow** | leadCreated, leadUpdated, leadAssigned, leadStageChanged, followupAdded, applicationSubmitted, enrollmentSubmitted, documentApproved, documentRejected, admissionApproved, admissionRejected, financeHandoffSent |
| **system** | errorReported |

### Server workflow events (Sprint 3+)

| Event | Category | When emitted |
|-------|----------|--------------|
| `apiMutation` | workflow | Any server-side write |
| `dataExport` | security | Bulk export/download |
| `configChange` | security | Org/school settings change |

### Communication Hub events (v7.1 — future client enum)

| Event | Category | Metadata |
|-------|----------|----------|
| `messageSent` | workflow | `thread_id`, `message_id`, `channel_type` |
| `messageRead` | workflow | `message_id`, `reader_id` |
| `broadcastSent` | workflow | `broadcast_id`, `audience`, `recipient_count` |
| `broadcastScheduled` | workflow | `broadcast_id`, `scheduled_at` |

### Payment Engine events (v7.0 — future client enum)

| Event | Category | Metadata |
|-------|----------|----------|
| `paymentRequested` | workflow | `request_id`, `amount`, `source_type` |
| `paymentInitiated` | workflow | `intent_id`, `gateway` |
| `paymentCaptured` | workflow | `transaction_id`, `amount` |
| `paymentFailed` | workflow | `intent_id`, `failure_code` |
| `paymentReconciled` | workflow | `reconciliation_id`, `period` |

### Inventory-Finance events (v7.2 — future client enum)

| Event | Category | Metadata |
|-------|----------|----------|
| `procurementFinancePosted` | workflow | `procurement_id`, `commitment_id` |
| `vendorSynced` | workflow | `vendor_id`, `source_module` |
| `domainEventPublished` | system | `event_type`, `event_id` |

Server accepts unknown event types in ingestion (stored as-is) for forward compatibility. Client enum additions tracked in `ClientBackendAlignment.md`.

---

## 6. Traceability

| Question | Query path |
|----------|------------|
| Who approved admission X? | `event_type=admissionApproved AND metadata->>'approvalId'=X` |
| All actions by user Y today? | `user_id=Y AND created_at > today` |
| Full request chain? | `correlation_id=abc` |
| Permission denials for tenant? | `event_type=permissionDenied AND tenant_id=Z` |

Admin UI: Control Center audit viewer (future); API query with pagination.

---

## 7. Compliance Considerations

| Requirement | Approach |
|-------------|----------|
| Immutability | INSERT-only tables; no UPDATE/DELETE grants |
| Tamper detection | Hash chain per partition (Sprint 5) |
| Data residency | Tenant-configurable region (future) |
| PII in metadata | Minimize; reference entity IDs only |
| Retention policy | Configurable per plan; minimum 1 year |
| Export | JSONL/CSV for legal discovery |
| Access control | `viewControlCenter` + audit-specific permission |

Indian context: Align with school data protection best practices; support CBSE/state audit requests via export.

---

## 8. Client Queue Integration

Existing client components (no changes in Sprint 1):

| Component | Role |
|-----------|------|
| `AuditLogger` | Local ring buffer (200 events) |
| `AuditUploadQueue` | Batches pending events |
| `AuditRetentionPolicy` | Local cap before upload |
| Upload on: app resume, interval, mutation success | |

Server ingestion resolves queue drain failures (`auditUploadFailed` events).

---

## 9. Implementation Phases

| Sprint | Deliverable |
|--------|-------------|
| Sprint 2 | `audit_events` schema |
| Sprint 3 | Ingestion endpoint; client queue drain |
| Sprint 4 | Server-side mutation audit middleware |
| Sprint 5 | Partitioning, archive, hash chain |
| Sprint 6 | v5.7 end-to-end validation |

No audit code created in Sprint 1.
