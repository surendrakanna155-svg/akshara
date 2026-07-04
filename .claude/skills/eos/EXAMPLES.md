# EOS Invocation Examples

Concrete ways to invoke `/eos` and what each produces. All output is
evidence-based and lands in `docs/engineering/eos/`.

## 1. Platform-wide health + gate

```
/eos
```
Sweeps all 20 Constitution categories, scores engineering health, classifies the
release state, lists open P0/P1, renders a gate verdict. Use for a periodic
"where do we actually stand" snapshot.

## 2. Scope to a module before calling it done

```
/eos finance
```
Judges the finance module across behaviour, RBAC, reliability, performance,
tests, and docs against its owning Parts. Skips anything already covered by a
`*_CERTIFICATION.md` (in `docs/` or `docs/archive/completed/`) if unchanged.
Produces a **Module Certification Report** + gate verdict.

## 3. Gate a QA / certification wave

```
/eos QW1
/eos "Wave 3"
/eos B12
```
Evaluates that wave's deliverables before it may be marked complete. Wave is not
"done" unless the EOS returns PASS (Part 8 — *Final Engineering Law*).

## 4. Single-category deep check

```
/eos security
/eos performance
/eos localization
/eos accessibility
/eos rbac
```
Runs just that category platform-wide against its Part's Acceptance Criteria +
Failure Conditions. Produces the matching **Gap Report** (Security Gap,
Reliability Gap, etc.).

## 5. Readiness decisions

```
/eos production-readiness
/eos commercial-readiness
```
Leads with the release-state classification (Part 8 — *Release Decision*) and the
blocking P0/P1 list. "Production Ready" / "Commercial Ready" is only returned
when the relevant Part 7B gates pass and no automatic-failure condition is live.

## 6. After a change (continuous certification)

```
/eos --diff
/eos attendance      # the module you just touched
```
Re-evaluates the blast radius of a fix/refactor/migration. Part 7B — *Continuous
Certification*: every change should re-certify affected areas.

## 7. Roadmap recommendations from current gaps

```
/eos roadmap
```
Turns open findings into **safe-ordered** roadmap waves (Part 8 — *Automatic
Roadmap*): groups related work, respects dependencies, never proposes an unsafe
order. It *recommends*; it does not rewrite committed scope.

## 8. Enforcement example (what a BLOCK looks like)

> User: "Mark the new export feature complete."
>
> `/eos export`
>
> EOS verdict — **BLOCKED**:
> - **[P0] Tenant isolation not verified** — Rule failed: Part 4A — *Tenant
>   Isolation*. Why: export handler reads without a tenant filter. Evidence:
>   `supabase/functions/.../export.ts:88`. Fix: scope query to
>   `tenant_id`; add RLS regression. Wave: Security hardening.
> - **[P0] No live evidence** — Rule failed: Part 7B — *Evidence Requirements*.
>   Why: no `live_cert_export.py` N/N. Fix: author + run via `/certify`.
>
> → Not complete. Resolve both P0s, re-run `/eos`, then `/certify` → `/deploy`.

## Typical full lifecycle

```
build feature
  → /eos <feature>        # gate; fix anything BLOCKED
  → /certify <feature>    # live N/N proof on the VPS
  → /deploy               # ship to the pilot
  → /release-review       # narrow Eng/QA/Release sign-off
  → /eos <feature>        # final continuous re-check → PASS = done
```
