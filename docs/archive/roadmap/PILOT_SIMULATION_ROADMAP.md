# Pilot Simulation — Findings Roadmap

**Created:** 2026-06-27
**Source:** `docs/PILOT_SCHOOL_SIMULATION.md` (live VPS pilot simulation)
**Scope rule:** genuine production issues only — no new features, no roadmap
changes, no re-audit of certified-and-unchanged areas.

The simulation produced **one** genuine production finding. It was fixed,
deployed and re-verified live in the same pass. There are no open items.

---

## Wave 1 — Empty-state correctness (✅ DONE, deployed + live-verified)

### PSIM-1 · Snapshot dashboards 404 for every non-pilot school

- **Severity:** High (customer-facing). Every real school beyond the seeded demo
  pilot saw an **error screen** instead of an empty dashboard for Transport,
  Inventory and Hostel; the same root cause affected the Management and
  Control-Center / Director dashboards.
- **Root cause:** these dashboards read a derived "snapshot" entity row
  (`entity_type = 'snapshot_dashboard'`). That row is only seeded by migrations
  hardcoded to the pilot org/school (`a1000000…001` / `a2000000…001`); go-live
  and module-enable do **not** create one per school. When absent, the read
  threw `SnapshotNotFoundError` → `404 NOT_FOUND`. The client read path has no
  fallback, so the 404 propagated to the UI as an error. (Library/HR/Alumni were
  already correct — Journey Wave 3 modernized them to compute dashboards live.)
- **Fix (no migration):** the snapshot read handlers now return an empty `{}`
  payload at **200** when the snapshot row is absent — a proper empty-state
  contract. The Flutter mappers are fully null-tolerant (every field defaults to
  `[]`/`0`/`''`), so this renders a zero-state dashboard instead of an error.
  Files:
  - `supabase/functions/_shared/entity_read/module_read_handlers.ts` (Inventory, Hostel, + any module using the shared read factory)
  - `supabase/functions/_shared/transport/transport_handlers.ts` (Transport: dashboard, tracking, reports, settings, occupancy)
  - `supabase/functions/_shared/entity_read/management_read_handlers.ts` (Management portal)
  - `supabase/functions/_shared/entity_read/control_center_read_handlers.ts` (Control-Center / Director)
- **Verification:** deployed to the VPS (edge recreated, no migration);
  `scripts/qa/live_cert_pilot_simulation.py` → all six module dashboards return
  **200** on enable (was 404). Backend suite **857/0** unchanged; analyze 0;
  flutter 2440/0.
- **Status:** ✅ FIXED · DEPLOYED · LIVE-VERIFIED.

---

## Areas confirmed healthy (no action)

These were exercised live and behaved correctly — recorded so future runs don't
re-investigate:

- Multi-board onboarding (Small Private / CBSE / ICSE / State) — go-live
  provisions board-appropriate subjects + capabilities; founder's module choice
  reaches the runtime gate.
- Organization topology — single-school org reports not-chain; 2-school trust
  reports chain; Director multi-branch entitlement-gated correctly.
- Dynamic module lifecycle — disable hides + blocks (403), enable reactivates
  (200), **disable never deletes data**, re-enable restores data — all 6 modules.
- Marketing plan-entitlement upgrade path — trial org → 402 PLAN_UPGRADE_REQUIRED.
- Full month lifecycle — onboarding → attendance → exams → fees → receipts →
  results-to-parent → import preview/commit/rollback (live 25/25).
- RBAC (teacher denied admin route, unauth 401), persistence under RLS, and the
  AI-available path (prefill returns a proposal, never 500).

---

*No open items. Simulation complete; see `docs/PILOT_SCHOOL_SIMULATION.md`.*
