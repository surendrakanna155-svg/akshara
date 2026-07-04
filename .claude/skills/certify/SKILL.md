---
name: certify
description: >
  ERP Certification for Akshara. Proves a module/batch actually works in
  production by running (or authoring) a live cert script against the VPS
  pilot with REAL auth, REAL DB, and REAL RBAC, then writing the standard
  docs/*_CERTIFICATION.md. Use when the user says "certify X", "is X
  production-ready", "prove it works live", "run the live cert", or wants to
  mark a batch PRODUCTION CERTIFIED. Certifications are the project's source
  of truth — do not re-certify an unchanged, already-certified area.
---

# ERP Certification (`/certify`)

Turns "we built it" into "it provably works in production." A certification is
only valid when it ran against the **live VPS pilot** — real auth, real DB,
real RBAC — not mocks.

## Operating rules

1. **Source of truth.** Existing `docs/*_CERTIFICATION.md` files define what is
   already certified and the format to follow. Match their structure exactly.
2. **No re-certifying unchanged work.** If the area is already PRODUCTION
   CERTIFIED and the code hasn't changed since, do not redo it — point at the
   existing cert. Re-certify only after a real change or a fixed gap.
3. **Never invent features or change the roadmap.** Certify what exists against
   what was promised. Found gaps belong to `/gap-check`, not new scope here.
4. **Real evidence only.** N/N must come from an actual run against the VPS,
   captured in the doc. No "should pass" — run it.

## How to run

1. **Locate or author the live cert script** under `scripts/qa/`, following the
   `live_cert_*.py` convention (real login → real API → assert real DB/RBAC
   effects). Reuse the existing scripts' auth + tenant-scope helpers; do not
   duplicate them.
2. **Run it against the VPS pilot** (real auth, real DB, real RBAC). If access
   needs the owner's SSH control socket / live env, confirm the channel is open
   before running. Capture the **N/N** result.
3. **Fix-and-rerun loop.** If a check fails, that's a real gap — fix it (or
   hand to dev), redeploy if needed (`/deploy`), and rerun until N/N is honest.
4. **Write `docs/<NAME>_CERTIFICATION.md`** in the house format:
   - `**Status:** ✅ PRODUCTION CERTIFIED (<date>)`
   - `**Roadmap:**` which item, and that it does not change the roadmap
   - `**Live cert:**` script path + **N/N** against the VPS pilot
   - `## Scope & gap` — what existed, what was actually missing/broken
   - `## What was built` — backend/UI, migrations (or "no migration")
   - **Persistence & constraints** — how state durably persists (note the
     `erp_tenant` no-DELETE constraint where relevant).
5. **Record it.** Update the relevant index/backlog doc and add/refresh the
   matching project memory so future sessions treat it as certified.

## Output

The certification doc + the live N/N result, plus a one-line statement of what
is now certified and what (if anything) remains. Deploying the change →
`/deploy`. Final gate sign-off across eng/QA/release → `/release-review`.
