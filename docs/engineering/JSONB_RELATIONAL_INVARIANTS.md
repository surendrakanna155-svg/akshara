# JSONB ↔ Relational Persistence — Soft Cross-Module Reference Invariants

**Status:** ICA-F5 (P2, Architecture) · defense-in-depth documentation + reconciliation detector
**Detector:** `supabase/migrations/20260920000180_soft_cross_module_ref_reconciliation.sql`
→ `detect_orphan_cross_module_refs()`

## The two-tier persistence model

The backend persists domain state in **two tiers**:

- **Relational tier** — Finance, Admissions, SIS, Academic. Real tables, real
  columns, real foreign keys. Postgres enforces referential integrity.
- **JSONB tier** — ~11 operational modules (transport, hostel, library,
  inventory, alumni, parent, teacher, hr, leave, management, control_center)
  persist their entities as opaque JSONB in a shared `{module}_entities` table
  `(id TEXT, organization_id UUID, school_id UUID, entity_type TEXT, payload JSONB)`
  via `entity_write_store.ts` / `entity_read_store`.

When a JSONB-tier module must reference a relational-tier row, it stores the
target's key **as a string inside the JSONB payload** — a **soft** cross-module
reference. Postgres cannot enforce a FK on a value inside `payload`, so integrity
is upheld by application code, not the database.

## Why this is safe today (not a live bug)

The audit's High severity was corrected to **Low** by the verifier: no path can
orphan these refs on the certified trunk.

1. **No hard-delete of targets.** `erp_tenant` (the edge role) has only
   `SELECT/INSERT/UPDATE` on `finance_invoices`, `finance_fee_assignments`,
   `finance_student_accounts` and `students` — **no DELETE**. Finance cancels an
   invoice by status (`invoice_status → 'cancelled'`), never by removing the row,
   so a soft ref keeps resolving after a cancel.
2. **RESTRICT-protected identity.** The one student hard-delete path
   (`onboarding_rollback_student`, import rollback) is blocked by the default
   `NO ACTION`/RESTRICT FKs on `finance_*`.`student_id` the moment any transport
   demand (and its finance rows) exists for that student.
3. **Single-transaction lockstep.** Raise (`handleRaiseTransportDemand`) and
   revoke (`stopStudentTransport`) write the JSONB demand and its Finance rows in
   one `withTenantContext` transaction — no partial-commit window.

The durable fix (promote high-integrity JSONB modules to relational tables + FKs)
is a multi-module rewrite, out of scope for a P2. Instead we **document the
invariant** and ship a **reconciliation detector** so any future regression is
caught operationally.

## The invariant table (one row per soft cross-module reference)

| Source (JSONB payload field) | Target (relational key) | Owner / why soft | Kind |
|---|---|---|---|
| `transport_entities[demand].invoiceId` | `finance_invoices.id` | Finance owns the invoice; transport points at it | **money** |
| `transport_entities[demand].assignmentId` | `finance_fee_assignments.id` | Finance owns the assignment | **money** |
| `transport_entities[demand].accountId` | `finance_student_accounts.id` | Finance owns the account | **money** |
| `transport_entities[demand].studentUuid` | `students.id` | SIS owns identity (transport stores display code + resolved UUID) | identity |
| `library_entities[fine\|issue].sisStudentId` | `students.student_code` **OR** `student_profiles.admission_number` | Library ledger is JSONB keyed by the SIS display code; the SIS no-dues gate reads it to block a TC | no-dues |

**Invariant:** every source above must resolve to exactly one target **within the
same `(organization_id, school_id)`**. `detect_orphan_cross_module_refs()`
returns any row that does not.

### Not in the detector (lower-stakes, monitored by documentation)

Read-side display associations keyed by the SIS display code — e.g.
`transport_entities[allocation].sisStudentId`, `hostel_entities[allocation].sisStudentId`,
`alumni_entities[*].sisStudentId` — resolve fail-safe on read (an unmatched code
shows no linkage rather than mis-stating money or no-dues). They can be
reconciled with the same `student_code | admission_number` join as branch 5 if a
future need arises; they are intentionally excluded to keep the detector focused
on the money and no-dues references whose failure has an integrity consequence.

## Ops usage

No `pg_cron` in this DB. Run on the existing privileged ops-cron lane
(`deploy/akshara-vps/backup/install-ops-cron.sh`), same as the ICA-E2 detector /
ICA-D3 reaper:

```sh
docker exec <akshara-postgres> psql -U <admin> -d <db> \
  -c "SELECT * FROM detect_orphan_cross_module_refs();"
```

**Zero rows on a healthy DB** (the seed writes no runtime `demand`/`fine`/`issue`
rows). Any returned row is a real regression — a broken raise/revoke lockstep or
a new hard-delete path — and must be reconciled before trusting the affected
money/no-dues downstream. The function is `SECURITY DEFINER` + pinned
`search_path` + `REVOKE ALL … FROM PUBLIC`, so it sweeps across tenants past
FORCE RLS and is never reachable from the `erp_tenant` edge role.
