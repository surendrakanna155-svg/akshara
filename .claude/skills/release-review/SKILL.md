---
name: release-review
description: >
  GStack release gate for Akshara — Engineering, QA, and Release discipline
  ONLY (no product/design/planning scope). A pre-ship readiness review that
  checks engineering quality, QA evidence, and release safety in one pass
  before a batch or build goes out. Use when the user says "release review",
  "are we ready to ship", "gstack", "final check before release", or wants a
  go/no-go on a batch. Does not invent features or change the roadmap.
---

# GStack Release Review (`/release-review`)

A disciplined **go / no-go** gate covering three lanes only — **Engineering,
QA, Release**. It does not touch product, design, or planning. Output is a
verdict with evidence, not new work.

## Operating rules

1. **Scope = Eng / QA / Release only.** Ignore feature ideation, roadmap
   changes, and design debates here.
2. **Never invent features or change the roadmap.** Review readiness of what
   exists.
3. **Use certifications as truth.** A lane passes on real evidence (green
   gates, N/N live cert, clean deploy verify) — not assertion.
4. **No re-auditing.** Lean on existing `docs/*_CERTIFICATION.md`; don't redo
   certified-and-unchanged work.

## The three lanes

### 1. Engineering
- `flutter analyze` → **0 issues**; `flutter test` → all green.
- Reuse over duplication (`TokenStorage`, `AuditLogger`, `RbacService`,
  `TenantContext`, `RouteGuards`, `Dio` — extend, don't fork).
- No mocks/stubs/TODOs left in live paths; no contract mismatches.
- New routes registered in `rbac_route_inventory.ts`; mutations audited.

### 2. QA
- Relevant `scripts/qa/live_cert_*.py` / `scripts/*_smoke.sh` run **against the
  VPS pilot** with real auth/DB/RBAC → honest **N/N**.
- A current `docs/*_CERTIFICATION.md` exists for the batch (or `/certify` it).
- Edge/empty/error states and persistence checked, not just happy path.

### 3. Release
- Deploy recipe is sound (edge `--no-deps`, `docker start akshara-edge`,
  `--env-file`/secrets present, migration ledgered) — see `/deploy`.
- Post-deploy smoke/live verify is green on the live VPS.
- Rollback/known-risk noted; anything owner-gated (Meta App Review, store
  submission, secrets) called out explicitly.

## How to run

1. Determine what's under review (batch/commit/build).
2. Walk each lane, gathering **real evidence** (run gates, read the cert, check
   the deploy verify). Cite file:line and N/N results.
3. Produce a **verdict per lane** (✅ pass / ⚠️ risk / ❌ blocker) and an overall
   **GO / NO-GO**, with the specific blockers and their fix routes
   (`/gap-check`, `/certify`, `/deploy`).

## Output

A short scorecard: per-lane verdict + evidence, the blocker list, and a clear
GO/NO-GO. This skill **reviews** — it doesn't fix, certify, or deploy; it
points at those skills.
