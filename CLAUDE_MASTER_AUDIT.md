# CLAUDE Master Audit — ERP Hardening Execution Status

Single source of truth for the cross-domain authorization/correctness hardening.
Per-domain detail lives in code + tests; this file tracks **status only**.

Legend: ✅ done & certified · 🟡 in progress · ⬜ not started

## Batches

| # | Domain | Status | Certification |
|---|--------|--------|---------------|
| — | **Exams** (P1 granular perms + P2 teacher scoping, server) | ✅ | deno authz 5/5; flutter exam 70/70; analyze 0 err |
| 0 | **Cross-cutting safety net** | ✅ | full edge graph `deno check` 0 err; CI gate added; deno unit 491 pass (only live-DB self-test skipped locally) |
| 1 | Finance (invoices/collections/refunds/concessions) | ⬜ | |
| 2 | SIS & Attendance | ⬜ | (attendance handler type bugs already fixed in Batch 0) |
| 3 | Admissions | ⬜ | |
| 4 | HR / Staff | ⬜ | |
| 5 | Operations (transport/hostel/library/inventory) | ⬜ | |
| 6 | Governance & Intelligence | ⬜ | |

## Batch 0 — what was done
- **CI gate**: `deno check supabase/functions/api/index.ts` added to `backend_staging.yml` before unit tests — type-checks the entire wired edge graph (not just test-reachable files), so "wired but never compiled" modules can't recur.
- **Fixed pre-existing breakage surfaced by the gate** (53 errors across 18 files), all pre-existing, none caught before because no test imported these modules:
  - Approval: `claims.name` (nonexistent) → dropped; `ApprovalRequestRow` import moved to its canonical source.
  - Attendance handlers: same `withAuth`/`tenantIds`/`claims.userId→sub` bugs as exams.
  - 8 routers: route-lookup ternary typed `| undefined` (benign false-positive, now correct).
  - ~35 `body` null-guards added across memories / parent_experience / promotion / attendance / inventory_intelligence handlers.
  - inventory_intelligence: `jsonResponse(..., 201)` → `{ status: 201 }`; `readJson` null coalesce.
  - parent_experience services: two row/return shape mismatches corrected.

## Known carry-overs (tracked, not blocking)
- Exam **denormalized read-model** (`teacher_entities`) lacks `teacher_id` → teacher row-scoping needs a schema change (authoritative `exam_mark_entries` path IS scoped). Fold into Slice 5 / Batch 2.
- Exam **separation of duties** (approver ≠ verifier): verifier id now recorded; enforcement check pending. Batch 6 (governance).
- Live-DB tests (`tenant_isolation_test.ts`) require a tenant DB; run in CI/staging only.
