---
name: gap-check
description: >
  ERP Gap Finder for Akshara. Finds ONLY real implementation gaps in the
  Akshara ERP codebase — production bugs, UX issues, performance problems,
  mocks/stubs, partial implementations, missing persistence, and broken
  client↔backend contracts. Use whenever the user wants to know "what's
  left", "what's broken", "find gaps", "is X actually done", audit a module
  before certifying, or check completion-mode status. Does NOT invent
  features, change the roadmap, or re-audit areas already covered by an
  existing certification.
---

# ERP Gap Finder (`/gap-check`)

Akshara ERP is in **completion mode**. This skill finds the difference between
what is *claimed/shipped* and what *actually works in production*. It does not
expand scope.

## Operating rules (non-negotiable)

1. **Never invent features.** Only report gaps in functionality that the SRS,
   roadmap, or shipped UI already promises.
2. **Never change the roadmap.** Report against the existing plan; don't
   reorder, add, or drop roadmap items.
3. **Never repeat a completed audit.** Treat `docs/*_CERTIFICATION.md` as the
   source of truth. If an area is **PRODUCTION CERTIFIED** and its code is
   unchanged since the cert date, do not re-audit it — say "covered by
   <cert>" and move on.
4. **Real gaps only.** A gap qualifies only if it is one of: production bug,
   broken/missing persistence, mock/stub left in a live path, partial
   implementation, client↔backend contract mismatch (404/wrong-shape/silent
   mock fallback), RBAC/RLS hole, UX defect, or measurable performance
   problem. Speculation, "could be nicer", and net-new ideas are NOT gaps —
   if the user clearly wants a new idea captured, route it to
   `IDEAS_BACKLOG.md`, don't fold it into the gap report.

## How to run

1. **Scope it.** If the user named a module/batch, scope to that. Otherwise
   ask which module/batch, or sweep the live-wired surface.
2. **Anchor on truth.** Read the relevant `docs/*_CERTIFICATION.md` and the
   memory index first to learn what is already certified and how. Skip
   certified-and-unchanged areas.
3. **Hunt the real gaps:**
   - **Mocks/stubs in live paths** — grep for mock repos, `EVOLUTION_API`-style
     flags, hybrid repos that silently fall back to in-app mocks, `TODO`,
     `FIXME`, `stub`, `fake`, `hardcoded`, `NotImplemented`.
   - **Missing persistence** — writes that don't reach the backend, optimistic
     UI with no durable store, RETURNING values that aren't re-read under RLS.
   - **Contract mismatches** — Flutter repo/mapper expecting a shape the edge
     function doesn't return; routes that 404 or are mis-routed.
   - **RBAC/RLS holes** — routes missing from `rbac_route_inventory.ts`, cross-
     tenant/persona leakage, missing per-child/parent scoping.
   - **Partial implementations** — happy path only, error/empty states absent,
     unhandled failures.
   - **UX defects & perf** — broken navigation, dead buttons, jank, N+1 reads,
     unbounded lists.
4. **Verify before reporting.** Prefer reading the actual handler + the actual
   client mapper to confirm the gap is real, not assumed.

## Output

A prioritized gap report. For each gap:

- **Area / file:line** (clickable), **Severity** (Blocker / High / Medium / Low),
- **What's actually there now**, **What's missing/broken**, **Evidence**
  (the code or contract that proves it), and a **one-line fix direction** (not
  an implementation).

End with: which areas were **skipped because already certified**, and a short
"recommended next" — but do not start coding or certifying unless asked.

This skill **finds** gaps. Fixing → normal dev. Proving fixed → `/certify`.
Shipping → `/deploy`. Gate review → `/release-review`.
