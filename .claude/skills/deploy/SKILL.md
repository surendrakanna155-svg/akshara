---
name: deploy
description: >
  Production Deployment for Akshara. Ships backend (Supabase edge functions +
  migrations) and release builds to the live VPS pilot using the established,
  battle-tested recipe, then verifies with a post-deploy smoke/live check.
  Use when the user says "deploy", "ship it", "push to VPS/prod/pilot",
  "apply the migration live", or "release build". Confirms a deploy is wanted
  and the change is gated before touching production.
---

# Production Deployment (`/deploy`)

Ships verified changes to the live VPS pilot safely. Production is real and
serves the pilot — confirm intent and gate the change before deploying.

## Operating rules

1. **Confirm before shipping.** Deploying to the VPS is an outward-facing,
   hard-to-reverse action. Confirm the user wants it live, unless they've
   already said "deploy now".
2. **Gate first.** Do not deploy red code. Require `flutter analyze` (0 issues)
   and `flutter test` green, and the relevant smoke/live cert passing. If the
   change isn't certified yet, say so and offer `/certify` first.
3. **Never invent features or change the roadmap** in the act of deploying.
   Deploy only what's already built and verified.
4. **Migrations are forward-only and ledgered.** Apply via the established
   migration path; record what was applied. Respect the live `erp_tenant`
   no-DELETE constraint (destructive ops need SECURITY DEFINER functions).

## How to run

1. **Pre-flight.** Confirm what's being deployed (commit/branch), that gates +
   cert are green, and that the access channel is open (owner's SSH
   control-master socket — my key alone isn't authorized).
2. **Backend / edge functions** — use the proven recipe from prior batches:
   - Bring up edge with `docker compose ... --no-deps` to dodge the
     pre-existing broken postgres healthcheck; `docker start akshara-edge`
     if it won't come up cleanly.
   - Mind the `compose --env-file` gotcha and ensure required secrets/env
     (e.g. `ANTHROPIC_API_KEY`, `SOCIAL_TOKEN_ENC_KEY`,
     `FCM_SERVICE_ACCOUNT_JSON`) are present on the VPS before recreate —
     env is not re-read unless the container is recreated.
   - Apply any new migration to the live DB and confirm it's ledgered.
   - Reuse `scripts/deploy_staging.sh` / `scripts/pilot_deploy_v14.sh` /
     `scripts/phase21_deploy_verify.sh` where they fit; don't hand-roll.
3. **Release build (when asked)** — use `scripts/build_release.sh` /
   `scripts/qa/build_qa_apk.sh`. Android is the supported target; iOS needs
   plist/APNs setup.
4. **Post-deploy verify (required).** Run the relevant `scripts/*_smoke.sh` or
   `scripts/qa/live_cert_*.py` against the now-live VPS and confirm N/N. A
   deploy isn't done until it's verified live.

## Output

State plainly: what was deployed, migration applied (or none), the post-deploy
N/N, and anything still owner-gated (Meta App Review, store release, secrets).
Report failures with the real output — never claim "deployed" without the
live verification. Final cross-cutting sign-off → `/release-review`.
