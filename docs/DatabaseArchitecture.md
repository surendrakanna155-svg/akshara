# Akshara ERP — Database Architecture

**Document ID:** `AKS-DB-ARCH-v1.1`  
**Status:** Architecture specification (no migrations)  
**Engine:** PostgreSQL 15+ · Supabase-managed  
**Last updated:** June 2026 (v5.6 gap closure)

---

## 1. Design Principles

| Principle | Rule |
|-----------|------|
| Tenant isolation | Every business table includes `tenant_id`; RLS enforced |
| School scoping | Operational data includes `school_id` where applicable |
| Soft deletes | `deleted_at` timestamp; no hard delete on PII |
| Audit trail | Mutations emit append-only audit events |
| UUID primary keys | `gen_random_uuid()` for all entities |
| Timestamps | `created_at`, `updated_at` on all tables; UTC |
| Snake_case | Column names match Flutter DTO `snake_case` JSON |

---

## 2. Organization Hierarchy

```
Platform (Akshara SaaS)
└── Organization (tenant boundary — billing, branding, CRM)
    ├── School Group (optional — chain/regional cluster)
    │   └── School (operational unit — admissions, finance, SIS)
    │       └── Branch (optional — large campuses)
    └── School (direct under org, no group)
```

### Entity relationships

| Entity | Description | Key fields |
|--------|-------------|------------|
| `organizations` | Top-level tenant; billing entity | `id`, `name`, `slug`, `plan`, `status` |
| `school_groups` | Optional grouping of schools | `id`, `organization_id`, `name`, `description` |
| `school_group_memberships` | **Canonical** school ↔ group | `school_group_id`, `school_id` |
| `schools` | Individual school | `id`, `organization_id`, `name`, `code` |
| `branches` | Campus within school | `id`, `school_id`, `name` |

**Tenant ID mapping:** `tenant_id` = `organizations.id` (matches client `TenantContext.tenantId`).

---

## 3. Multi-School Groups — Canonical Model

**Decision:** Use `school_group_memberships` junction table only. Schools are not tagged with a single `school_group_id`.

```
school_groups (id, organization_id, name)
school_group_memberships (school_group_id, school_id)  -- UNIQUE(school_group_id, school_id)
school_group_user_memberships (school_group_id, user_id, role)  -- directors
```

| Rule | Detail |
|------|--------|
| A school may belong to multiple groups | ✅ via junction rows |
| A group belongs to one organization | FK constraint |
| RLS | Filter via `school_id IN (SELECT … FROM school_group_memberships WHERE group_id = app.school_group_id)` |

Supports Organization Admin and School Group Director dashboards (see `TenantArchitecture.md` §6).

---

## 4. Tenant Model

```
organizations (tenant_id)
    │
    ├── organization_memberships (user_id, role, permissions_version)
    │
    ├── schools
    │   └── school_memberships (user_id, role, permissions_version)
    │
    └── organization_settings (branding, features, limits)
```

| Table | Purpose |
|-------|---------|
| `users` | Global identity (phone, email, profile) |
| `organization_memberships` | User ↔ org; org-level roles |
| `school_memberships` | User ↔ school; school-level roles |
| `membership_permissions` | Explicit permission grants (override role defaults) |

**RLS policy pattern (future Sprint 3):**

```sql
-- Every query automatically filtered:
tenant_id = current_setting('app.tenant_id')::uuid
AND (school_id IS NULL OR school_id = current_setting('app.school_id')::uuid)
```

---

## 5. Core Entity Groups

### Identity & access

`users`, `sessions`, `refresh_tokens`, `otp_requests`, `role_definitions`, `permission_definitions`, `role_permissions`, `membership_permissions`

### Admissions (30 API methods)

`leads`, `lead_notes`, `lead_followups`, `applications`, `application_documents`, `approval_queue`, `enrollments`, `fee_handoffs`

### Finance (23 API methods)

`fee_structures`, `fee_assignments`, `student_accounts`, `collections`, `refunds`, `scholarships`, `installment_plans`, `academic_years`

### SIS (10 API methods)

`students`, `student_guardians`, `academic_assignments`, `class_sections`, `admissions_conversions`

### Operations modules

| Module | Core tables |
|--------|-------------|
| Transport | `routes`, `vehicles`, `drivers`, `allocations`, `attendance_records` |
| HR | `employees`, `departments`, `payroll_runs` |
| Hostel | `rooms`, `hostel_students`, `leave_requests`, `visitors` |
| Library | `catalog`, `members`, `issues`, `returns`, `fines` |
| Inventory | `assets`, `categories`, `vendors`, `procurement`, `maintenance` |
| Alumni | `alumni_registry`, `campaigns`, `donations`, `events`, `mentorship` |
| Management | `management_reports`, `kpis` |

### Platform

`control_center_schools`, `crm_leads`, `support_tickets`, `white_label_configs`, `feature_flags`

### Cross-cutting

`audit_events`, `notifications`, `file_metadata`, `correlation_traces`

---

## 6. Indexing Strategy

| Pattern | Index | Tables |
|---------|-------|--------|
| Tenant filter | `(tenant_id)` | All business tables |
| School filter | `(tenant_id, school_id)` | Operational tables |
| List pagination | `(tenant_id, school_id, created_at DESC)` | All paginated lists |
| Foreign keys | `(foreign_key_id)` | All FK columns |
| Status filters | `(tenant_id, status)` | workflows (applications, refunds) |
| Phone lookup | `(phone) UNIQUE` | `users` |
| Full-text | `GIN(to_tsvector(...))` | `students`, `leads`, `catalog` |

**Partial indexes:** Active records only: `WHERE deleted_at IS NULL`.

**Partitioning (future):** `audit_events` by month; `collections` by academic year.

---

## 7. Audit Storage Strategy

| Store | Purpose | Retention |
|-------|---------|-----------|
| `audit_events` (hot) | Recent events; queryable | 90 days |
| `audit_events_archive` | Compressed monthly partitions | 7 years |
| Object storage | Compliance export (JSONL) | 7 years |

### Schema (conceptual)

```
audit_events (
  id UUID PK,
  tenant_id UUID NOT NULL,
  school_id UUID,
  user_id UUID,
  correlation_id TEXT,
  event_type TEXT NOT NULL,      -- maps to client AuditEventType
  category TEXT NOT NULL,        -- security | auth | workflow | system
  entity_type TEXT,
  entity_id TEXT,
  metadata JSONB,
  ip_address INET,
  user_agent TEXT,
  created_at TIMESTAMPTZ NOT NULL
)
```

**Immutability:** INSERT-only; no UPDATE/DELETE. Tamper detection via hash chain (future Sprint 5).

---

### Cross-cutting

`audit_events`, `notifications`, `file_metadata`, `correlation_traces`, `domain_events` (outbox)

### Shared vendor master (Inventory-Finance)

`vendors` — canonical vendor entity shared by Inventory and Finance modules:

```
vendors (id, tenant_id, school_id, name, gstin, contact, source_module, finance_vendor_id?)
```

Inventory procurement references `vendors.id`; Finance AP references same row. Sync via domain events (see `BackendArchitecture.md` §13).

---

## 8. Domain Schema Extensions

### 8a. Communication Hub (v7.1)

| Table | Key fields |
|-------|------------|
| `comm_channels` | `id`, `tenant_id`, `school_id?`, `type` (direct/group/broadcast), `name` |
| `comm_threads` | `id`, `channel_id`, `subject`, `scope` |
| `comm_messages` | `id`, `thread_id`, `sender_id`, `body`, `locale`, `translated_body?` |
| `comm_message_translations` | `message_id`, `locale`, `body` |
| `comm_broadcasts` | `id`, `tenant_id`, `school_id?`, `audience`, `scheduled_at` |
| `comm_recipients` | `broadcast_id`, `user_id`, `delivery_status` |
| `comm_device_tokens` | `user_id`, `platform`, `token` (FCM) |

### 8b. Universal Payment Engine (v7.0)

| Table | Key fields |
|-------|------------|
| `payment_requests` | `id`, `tenant_id`, `school_id`, `source` (fee/fine/event), `amount`, `currency`, `status` |
| `payment_intents` | `id`, `request_id`, `gateway` (razorpay), `gateway_intent_id`, `status` |
| `payment_transactions` | `id`, `intent_id`, `amount`, `method`, `captured_at` |
| `ledger_accounts` | `id`, `tenant_id`, `code`, `name`, `type` |
| `ledger_entries` | `id`, `account_id`, `debit`, `credit`, `reference_type`, `reference_id` |
| `payment_reconciliations` | `id`, `period`, `gateway_total`, `ledger_total`, `status` |

**Finance boundary:** `student_accounts` / `collections` remain Finance module tables; Payment Engine writes `ledger_entries` and updates `collections` via posting events.

### 8c. Inventory-Finance Integration (v7.2)

| Table | Key fields |
|-------|------------|
| `domain_events` | Outbox: `id`, `tenant_id`, `event_type`, `payload`, `published_at` |
| `procurement_finance_links` | `procurement_id`, `finance_commitment_id`, `posted_at` |
| `inventory_finance_postings` | `id`, `procurement_id`, `ledger_entry_ids[]`, `status` |

### 8d. Other future products

| Future product | Tables / approach |
|----------------|-------------------|
| Copilot services | `ai_sessions`, `ai_prompts` |
| Student Risk Engine | `risk_scores`, `risk_signals` |
| School Health Score | `health_score_snapshots` |
| Smart Timetable | `timetable_slots`, `constraints` |
| School Memories | `media_assets`, `memory_albums` |
| CRM / Business Suite | `crm_contacts`, `deals`, `renewals` |

All extensions inherit `tenant_id` + RLS pattern.

---

## 9. Migration Strategy (future sprints)

1. Sprint 2: Core schema (organizations, schools, users, auth, memberships)
2. Sprint 3: Admissions + Finance + SIS + RLS + org admin roles
3. Sprint 4: Remaining ERP modules + school groups junction
4. Sprint 5: Audit ingestion + `domain_events` outbox
5. Sprint 6: Pilot validation
6. v7.0+: Payment Engine schema
7. v7.1+: Communication Hub schema
8. v7.2+: Inventory-Finance posting tables

No migrations created in Sprint 1.
