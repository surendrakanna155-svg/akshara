# Domain Standardization — permanent record

**Date:** 2026-07-29 · **Status:** ✅ COMPLETE

## Canonical production identity

| Host | Purpose |
|---|---|
| `nikshaos.in` | Root / marketing / legal policy host |
| `app.nikshaos.in` | Web application |
| `api.nikshaos.in` | Backend edge API (proxies `127.0.0.1:3000`) |

**`akshara.veloraunisexsalon.com` is retired.** Its nginx vhost is no longer in
`sites-enabled` (confirmed on the VPS: `chotu-api`, `nikshaos`, `velora-salon`).

## Verification

```
app code   (lib/ supabase/ config/ android/ web/src/) : 0 references
operational (deploy/ scripts/ docs/legal/ docs/release/
             docs/Operations/ ProjectStatus DR plan)  : 0 references
```

The application code was already clean before this pass — the owner had
migrated `legal_links.dart` and the nginx vhost. This pass closed the
documentation, deployment and script surface.

## Files changed (7)

| File | Change |
|---|---|
| `deploy/nikshaos/nginx/nikshaos.conf` | Comment no longer names the retired host |
| `docs/release/PLAY_STORE_LISTING_V1.md` | Policy host → `nikshaos.in`; removed the now-false "must move before submission" warning; "buy the domain" is no longer an owner action |
| `docs/legal/PLACEHOLDERS.md` | Prose matched to the already-migrated value; domain purchase marked done |
| `docs/DEPLOYMENT_MODEL_AND_DR_PLAN.md` | Golden-image reference → `api.nikshaos.in` |
| `docs/ProjectStatus.md` | Live pilot host → `api.nikshaos.in` |
| `scripts/uxr_review/README.md` | → `app.nikshaos.in/review/`, flagged for re-provisioning |
| `web/PRODUCT_AUDIT.md` | Probe result annotated as pre-migration historical evidence |

## Intentionally retained — 46 files

The old host remains **only** as dated historical evidence, never as an
operational reference:

- `docs/archive/**` — sealed record of past certifications and deploy runbooks
- `docs/audits/**`, `docs/*_CERTIFICATION.md` — dated attestations. A
  certification records what was true of a named artifact at a point in time;
  rewriting one is evidence tampering.
- `docs/certification/**` — Cycle 1 findings, including live probes performed
  against that host while it was serving. Rewriting them would invalidate the
  evidence.
- `docs/engineering/DOMAIN_MIGRATION_*` — the migration records themselves
- `web/PRODUCT_AUDIT.md` — one probe result, explicitly annotated

## Follow-up flagged, not silently assumed

`scripts/uxr_review/README.md` now points at `app.nikshaos.in/review/`. That
`/review/` location was served by the retired vhost and has **not** been
confirmed to exist on the `nikshaos` vhost. The README says so rather than
implying the URL works.

## Why this should be the last migration

The application code holds no hardcoded host: the client resolves its API base
from `Environment` / `--dart-define`, and the policy host from a single constant
in `legal_links.dart`. Any future change is those two places plus nginx — not a
repository sweep.
