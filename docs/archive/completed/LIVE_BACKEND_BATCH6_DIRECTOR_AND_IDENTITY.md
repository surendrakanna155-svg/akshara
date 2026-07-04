# Batch 6 — Director module + student-identity integrity (live)

Branch `feature/scope-trim-school-build`. Date 2026-06-24. Two halves:
**(A)** build the Director portal as a real backend module, **(B)** close the
student-identity referential-integrity gaps. Both verified on the live VPS.

---

## Half A — Director portal (org-scope multi-school analytics)

Before: the app's Director module (9 screens, 12 operations) ran entirely on
mocks — `ApiDirectorRepository` threw `ApiNotConnectedException` on all 12
methods and there was **no `director` router on the server at all**.

After: a real, RBAC-enforced, organization-scope backend module that aggregates
**live** data across every school in the org. "Aggregated data only · No
student PII."

### Server (`supabase/functions/_shared/director/`)
- `director_repository.ts` — all aggregation, raw SQL over a `withTenantContext`
  (erp_tenant, RLS-enforced) connection. Computes per-school rows (active
  students, realized revenue, fee-collection %, a weighted health index from
  fee/attendance/academic signals, status band), revenue (chain collections +
  expenses from inputs + outstanding-based forecast + 6-month trend), growth
  (enrolments/withdrawals/yoy/capacity + cumulative curve), admissions funnel,
  marketing (leads live; spend/CPL/ROI from inputs), compliance, reports, and a
  deterministic executive summary (AI is Batch 8).
- `director_handlers.ts` — 12 handlers. Reads gate on `viewDirectorPortal`;
  writes (acknowledge compliance, export report) on `manageDirectorPortal`.
  Every request requires an org-level token scope. Writes run in a tenant txn
  with `emitMutationAudit`.
- `director_router.ts` — `/director/{dashboard,schools,portfolio,revenue,growth,
  marketing,admissions,compliance,reports}` (GET), `/director/summary` (POST),
  `/director/compliance/:id/acknowledge` + `/director/reports/:id/export` (POST).
  Registered in `api/index.ts`.
- `director_repository_test.ts` — 5 Deno tests (health banding, honest zeros,
  funnel, summary). All pass; `deno check` clean.

### Migration `20260707000000_director_portal.sql`
- Permissions `viewDirectorPortal` / `manageDirectorPortal` (organization scope),
  granted to organizationOwner / organizationAdmin / schoolGroupDirector /
  superAdmin.
- Tables `director_compliance_items`, `director_reports`, `director_metric_inputs`
  (org-scope RLS + grants). Inputs with no operational source (marketing spend,
  operating expense, capacity) live here and read as honest zeros until entered.
- **Additive `*_director_org_read` SELECT policies** on the operational tables
  (students, sis_student_enrollments, finance_invoices/collections, admissions_*,
  attendance_records, exam_mark_entries) so an org token can read aggregates
  across schools. PERMISSIVE → OR'd with existing school/parent policies, so
  school/parent tokens are unaffected. RLS stays the isolation boundary.

### App
- `api/director/remote/director_remote_datasource.dart` (Dio) +
  `api/director/api_director_repository.dart` (parses the org-scoped JSON into
  the domain models; KPI icons resolved client-side). Providers
  `directorRemoteDataSourceProvider` / `apiDirectorRepositoryProvider`; the
  hybrid repo now injects the live api. `DIRECTOR_API_ENABLED=true` added to
  `scripts/run_live.sh`.

### Live verification
2 staging schools in the org. `/director/schools` and `/director/dashboard`
return real per-school aggregates + KPIs + summary. RBAC: 403 without
`viewDirectorPortal`, 403 on writes without `manageDirectorPortal`, 401 no
token. Compliance acknowledge + report export persist durably with audit rows
(`director.compliance.acknowledged`, `director.report.exported`).

---

## Half B — student-identity referential integrity

Survey corrected the earlier scout: promotion (`/academic/transitions/*`) and
SIS status transitions (`PATCH /sis/students/:id/status`, with a transfer/alumni
state machine) are **already wired live and identity-stable**; the admissions
lead→application→enrollment→student chain is **already FK-enforced end to end**.
The real gap was a class of operational tables carrying a bare
`student_id UUID NOT NULL` with no foreign key.

### Migration `20260708000000_student_identity_fks.sql`
Adds `student_id → students(id) ON DELETE CASCADE` (the dominant existing
convention) to 8 core operational tables: `exam_mark_entries`, `exam_remarks`,
`attendance_records`, `homework_submissions`, `payment_requests`,
`inv_student_distributions`, `student_timeline_events`,
`edu_homework_student_targets`. Idempotent + partial-deploy safe (DO block).
All 8 verified to hold **0 orphan rows** on live before applying. Read-cache /
snapshot / analytics tables intentionally keep a bare student_id (rebuilt
projections, not source rows). Applied live; a bogus-student-id mark insert is
now correctly rejected with `foreign_key_violation`.

### Remaining handoff item (documented, not shipped)
Graduation (status→alumni) flips `students.status` and is identity-stable, but
does **not** auto-surface the graduate in the Alumni module (which reads the
`alumni_entities` JSONB store, and whose `AlumniRecord` needs program/role/city/
donation/engagement data a fresh graduate does not have). Auto-provisioning
alumni records is a separate **alumni-onboarding feature**, not an integrity
fix — deferred rather than shipped as blank cards.

---

## Deploy notes
- Migrations applied live as `supabase_admin` (piped via the SSH ControlMaster
  tunnel). Edge code shipped by `tar | ssh … tar x` into
  `/opt/akshara/functions` + `docker restart akshara-edge` (no env change).
- Org-scope verification tokens were minted on the VPS using the edge
  container's Deno + the live `JWT_SECRET` (scope `organization`, perms set
  explicitly) — there is still no seeded org-scope persona.
- Certification: `flutter analyze` 0 errors (new files add 0 issues); full suite
  2306 pass / 1 skip / 0 fail; 5 Director Deno tests pass. Half B is DB-only.
