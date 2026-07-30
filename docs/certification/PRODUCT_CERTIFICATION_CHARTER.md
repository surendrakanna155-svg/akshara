# NIKSHA OS — Product Certification Charter

**Started:** 2026-07-29 · **Branch:** `release/v1.0-playstore`
**Precondition met:** RC Engineering closed, 0 open P0
(`docs/roadmap/RC_CLOSURE_REPORT.md`).

> **This is a certification phase, not a fix phase.** Defects are RECORDED, not
> repaired, until the whole product has been certified. Only production-safe,
> obviously-correct fixes may be taken inline. Everything else goes to the
> register and is scheduled in the remediation roadmap.

## The standard

Certify from the perspective of a **real school using this every day** — not
from the perspective of a green test suite. Engineering tests being green is
the precondition for this phase, not evidence of its outcome.

A feature is certified only when traced **end to end**: first user action →
UI → validation → API → database → audit → notifications → reports →
analytics → dashboards → related modules → final outcome.

## Scope (11 workstreams)

| # | Workstream | Output |
|---|---|---|
| 1 | Complete feature inventory | `FEATURE_INVENTORY.md` |
| 2 | End-to-end feature certification | `findings/CERT-*.md` |
| 3 | Complete role journeys (13 roles) | `findings/JOURNEY-*.md` |
| 3A | Real school simulation | `findings/SIM-*.md` |
| 4 | Cross-module synchronisation | `findings/XMOD-*.md` |
| 5 | DAI certification | `findings/DAI-*.md` |
| 6 | Dashboard & widget certification | `findings/WIDGET-*.md` |
| 7 | API certification | `findings/API-*.md` |
| 8 | AI certification suite (6 sub-suites) | `findings/AI-*.md` |
| 9 | Product polish | `findings/POLISH-*.md` |
| 10 | School-OS coherence | `findings/OS-*.md` |
| 11 | Defect register + remediation | `DEFECT_REGISTER.md` |

## Completion criteria — all four required

1. Complete Product Certification passes.
2. All approved remediation items implemented.
3. **Full certification repeated from the beginning** — previously certified
   modules are NOT assumed still correct after fixes.
4. The second cycle passes with no release-blocking issues.

## Honesty rules (carried from the RC phase, they earned their place)

- Never record a check as performed unless it actually ran.
- "I could not verify X, here is the boundary" is a valid and valuable finding.
- An empty finding list for a module is valid — say what was checked to reach it.
- A green test asserting a false premise is worse than a known gap. Report those.
- Distinguish *the code path exists* from *it runs on the live path*.

## Known verification boundaries (inherited, still true)

- **No Postgres lane** in this harness — backend tests prove spec shape and
  write-path against a spy DB, not live persistence.
- **SSH to the pilot VPS is owner-bound** — no live DB introspection.
- **Release binaries cannot run locally**: `guardForRelease` requires
  production + live API. Device work uses a profile build with demo data.
- **No live payment gateway** (Razorpay stubbed), **no live SMS/push** in dev.
