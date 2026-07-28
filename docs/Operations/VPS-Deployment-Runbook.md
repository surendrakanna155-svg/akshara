# NIKSHA OS — VPS Deployment Runbook

**Status:** Authoritative for the self-hosted VPS pilot.
**Last updated:** 2026-07-28 (release/v1.0-playstore)

> **Why this document exists.** Before it, no document in `docs/` described how to
> deploy this system. `docs/DeploymentArchitecture.md` describes a Cloudflare +
> multi-AZ hosted-Supabase + Datadog stack that is **not deployed and never was**.
> `docs/Operations/Deployment-Guide.md` and `scripts/pilot_deploy_v14.sh` target a
> **hosted Supabase project (`oeicxjpewrumkfgyqnnj`) that is not in the production
> path** — `supabase db push` cannot reach the VPS database at all. The only
> accurate deployment knowledge lived in an agent skill file
> (`.claude/skills/deploy/SKILL.md`), which is not indexed in `docs/README.md` and
> which no operator would think to read. This runbook lifts it into the operator
> documentation and reconciles it with what is actually in the repo.

> **Verification status — read this before trusting a step.**
> Everything below is derived from files in this repository and cross-checked
> against them: `deploy/akshara-vps/docker-compose.akshara.yml`,
> `deploy/akshara-vps/.env.akshara.example`, `deploy/akshara-vps/gateway.conf`,
> `lib/core/config/environment.dart`, and the `Deno.env.get(...)` call sites under
> `supabase/functions/`. It has **NOT** been executed end-to-end against the live
> VPS during this release cycle, because SSH access is owner-bound (see §0). Steps
> are written to be safe to re-run, but the first operator to run this should
> treat it as a draft to be confirmed, and correct anything that differs.

---

## 0. Access — the first genuine blocker

| Item | Value |
|---|---|
| Host | `46.28.44.46` |
| Access | SSH as `root`, via the owner's SSH control-master socket |
| Command form | `ssh -S ~/.ssh/akshara-cm.sock root@46.28.44.46` |

**Access is owner-bound.** The control-master socket belongs to the owner's
session; a fresh key is not authorised on the box. Nobody else can deploy without
the owner either opening the socket or adding an authorised key. This is a real
operational single point of failure and should be resolved before the pilot
grows — record it as a risk, not as a step.

> ⚠️ **The VPS is shared.** It also runs unrelated production workloads
> (a salon business, n8n, redis). Never run host-wide commands
> (`docker system prune`, `docker stop $(docker ps -q)`, host package upgrades).
> Scope every command to the `akshara` compose project or the named
> `akshara-*` containers.

---

## 1. What actually runs in production

One VPS, all ports bound to `127.0.0.1`, fronted by a public nginx vhost with
Let's Encrypt TLS.

| Container | Image | Port (host) | Role |
|---|---|---|---|
| `akshara-postgres` | `supabase/postgres:17.6.1.127` | `127.0.0.1:5433` | Tenant database (`akshara_db`) |
| `akshara-postgrest` | `supabase/postgrest:v14.5` | internal only | REST over Postgres |
| `akshara-rest-gateway` | `nginx:alpine` | internal only | Maps `/rest/v1/*`, `/storage/v1/*` |
| `akshara-edge` | `denoland/deno:alpine` | `127.0.0.1:3000` | The API (`functions/api/index.ts`) |
| `akshara-storage` | `supabase/storage-api:v1.19.3` | `127.0.0.1:5000` | Media/object storage |

Compose project name is `akshara`; network `akshara-net`; volumes
`akshara_pgdata`, `akshara_deno_cache`, `akshara_storage_data`.

**The client talks to the edge API at the ROOT of the public host** — there is no
`/v1` and no `/functions/v1` prefix. See `lib/core/config/environment.dart`
(`Environment.production.apiBaseUrl`). Any document telling you to register a
webhook at `https://<project>.supabase.co/functions/v1/...` is stale.

**Secrets live only on the VPS**, at `deploy/akshara-vps/.env.akshara` and
`postgrest.env`, `storage.env`, all `chmod 600`, none committed. The templates in
the repo (`*.example`) are the authoritative list of variable names.

---

## 2. Pre-flight gates — do not deploy red code

Run these locally, on the exact commit you intend to ship:

```bash
flutter analyze                 # must report: No issues found!
flutter test                    # must be green; record the +N -M
node scripts/legal/build_legal_site.js   # exits non-zero while legal placeholders remain
```

Then confirm:

- [ ] The commit is on the intended branch and pushed (or its SHA recorded).
- [ ] Any new migration has been reviewed — migrations are **forward-only**.
- [ ] `erp_tenant` has a live no-DELETE constraint. Destructive operations must go
      through a `SECURITY DEFINER` function; a bare `DELETE` will be refused.
- [ ] You know whether the change needs an **env change** — if so, §4 applies and a
      restart is NOT sufficient.

---

## 3. Deploy the edge API (functions)

The edge container mounts `./functions` read-only from the VPS working copy, so
"deploying code" means updating those files on the box and recreating the
container.

```bash
# 1. Sync the functions tree to the VPS working copy
rsync -av --delete supabase/functions/ root@46.28.44.46:/opt/akshara/deploy/akshara-vps/functions/

# 2. Recreate ONLY the edge service.
#    --no-deps is required: the postgres healthcheck has a known-broken history and
#    without it compose will wait on / restart dependencies you did not intend to
#    touch. Scope strictly to akshara-edge.
cd /opt/akshara/deploy/akshara-vps
docker compose -f docker-compose.akshara.yml --env-file .env.akshara up -d --no-deps --force-recreate akshara-edge

# 3. If it does not come up cleanly
docker start akshara-edge
docker logs --tail 100 akshara-edge
```

> **`--env-file` gotcha.** `docker compose` does not read `.env.akshara`
> automatically — the compose project has no `.env`. Pass `--env-file .env.akshara`
> explicitly or `${POSTGRES_DB}` and friends interpolate to empty strings.

---

## 4. Environment / secret changes

**Environment variables are only read when a container is CREATED.**
`docker restart` does **not** re-read `.env.akshara`. This has caused silent
no-op deploys before: the operator sets a key, restarts, and the feature stays
stubbed with no error anywhere.

```bash
vi /opt/akshara/deploy/akshara-vps/.env.akshara     # chmod 600, never commit
docker compose -f docker-compose.akshara.yml --env-file .env.akshara up -d --no-deps --force-recreate akshara-edge
```

Variable names are verified against `Deno.env.get(...)` call sites in
`supabase/functions/`. The ones most often got wrong:

| Feature | Correct variable | Commonly written (WRONG — read by nothing) |
|---|---|---|
| Push | `FCM_SERVICE_ACCOUNT_JSON` | `FCM_SERVER_KEY` (retired legacy API) |
| AI copilot | `AI_PROVIDER` + `ANTHROPIC_API_KEY` (or `OPENROUTER_API_KEY`) | `OPENAI_API_KEY` / `OPENAI_MODEL` |
| Payments | `RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET`, `RAZORPAY_WEBHOOK_SECRET`, `RAZORPAY_STUB_MODE=false` | — |

Every one of those wrong names fails **silently**: the feature falls back to its
stub, which is safe, but nothing tells you the key was ignored. After any secret
change, verify the feature end-to-end (§7) rather than trusting the absence of an
error.

---

## 5. Database migrations

There are **258** migration files in `supabase/migrations/` as of this release.
Any document citing 98 is describing the Stage-1 checkpoint and will leave you
with roughly a 40%-complete schema.

> **`supabase db push` does NOT work here.** It targets a hosted Supabase project.
> The production database is a container bound to `127.0.0.1:5433` on the VPS and
> is unreachable from the CLI. `scripts/pilot_deploy_v14.sh` and
> `scripts/deploy_staging.sh` both default to project ref `oeicxjpewrumkfgyqnnj`,
> which is the legacy hosted **staging** project — useful for staging, never for
> the VPS.

Apply forward-only, one file at a time, newest last:

```bash
# Copy the migration to the box
scp supabase/migrations/<timestamp>_<name>.sql root@46.28.44.46:/tmp/

# Apply inside the postgres container, in a transaction
docker exec -i akshara-postgres psql -U supabase_admin -d akshara_db -v ON_ERROR_STOP=1 -1 < /tmp/<timestamp>_<name>.sql

# Confirm
docker exec -i akshara-postgres psql -U supabase_admin -d akshara_db -c "\dt" | tail -20
```

Rules:

- **Take a backup first** (§8) — migrations are forward-only, there is no down path.
- Apply in filename (timestamp) order. Never re-order or back-date a migration.
- Record what was applied, with the SHA, in the deploy log for this release.
- New migrations must be numbered **above** the current maximum. Concurrent lanes
  have collided here before; check the highest applied timestamp before choosing a
  number.

---

## 6. Public vhost — API, storage, and the legal pages

The legal pack is a Play Store submission requirement and must be reachable.
Generate it before deploying (it is fail-closed on unfilled owner placeholders):

```bash
node scripts/legal/build_legal_site.js          # exits non-zero if blocked
scp -r deploy/akshara-vps/public/ root@46.28.44.46:/opt/akshara/legal-site/
scp deploy/akshara-vps/legal-site.conf root@46.28.44.46:/etc/nginx/sites-available/niksha-legal
ssh root@46.28.44.46 'ln -sf /etc/nginx/sites-available/niksha-legal /etc/nginx/sites-enabled/ && nginx -t && systemctl reload nginx'
```

Do **not** publish while `deploy/akshara-vps/public/_PUBLISH_GATE.json` reports
`PUBLISH_BLOCKED` — Google Play requires a working privacy contact and the DPDP
Act requires a named Grievance Officer. See `docs/legal/PLACEHOLDERS.md`.

---

## 7. Post-deploy verification — a deploy is not done until it is verified

```bash
# Gateway and edge health
ssh root@46.28.44.46 'curl -s localhost:8080/health'      # expect: gateway-ok
ssh root@46.28.44.46 'curl -s localhost:3000/health'

# Public surface
curl -sI https://<public-host>/privacy | head -1          # expect: 200
curl -sI https://<public-host>/terms/user | head -1       # expect: 200

# Backup freshness (503 once the newest backup is older than BACKUP_MAX_AGE_HOURS)
ssh root@46.28.44.46 'curl -s localhost:3000/health/backup'
```

Then run the smoke/live check relevant to what you shipped, from
`scripts/*_smoke.sh` or `scripts/qa/live_cert_*.py`, against the live host and
confirm N/N. Record the actual output. **Never report "deployed" without the live
verification** — the whole point of the gate is that a green build says nothing
about a green deploy.

---

## 8. Backup and restore

Full procedure: `docs/BACKUP_RESTORE_RUNBOOK.md` — that document is accurate and
current, and is the one to follow. In short:

- Scripts live in `deploy/akshara-vps/backup/`.
- **Take a backup before every migration.**
- **RPO is approximately 24 hours.** Nightly logical backup; WAL archiving / PITR
  is *not* enabled. Any document promising a 5-minute RPO or 30-day PITR
  (e.g. `docs/DeploymentArchitecture.md`) is describing an architecture that does
  not exist.

---

## 9. Android release build

The release build is fail-closed on signing (SEC-2): with no
`android/key.properties` a release assembly is **refused** rather than
debug-signed.

```bash
cp android/key.properties.example android/key.properties   # then fill in — never commit
flutter build appbundle --release
```

The AAB is written to `build/app/outputs/bundle/release/app-release.aab`.

Measured on this release (2026-07-28): AAB 132.1 MB — but that is dominated by
`BUNDLE-METADATA` (debug symbols + a ~42 MB ProGuard map) which Play strips from
user downloads. The real per-device artifact is **57.9 MB (arm64-v8a)** /
50.0 MB (armeabi-v7a), measured via `flutter build apk --split-per-abi`.

Release builds also refuse to start unless `APP_ENV=production` **and**
`ENABLE_API_MODE=true` (`lib/core/config/environment.dart` →
`guardForRelease`). A release binary therefore cannot run against mock data or
demo auth — by design. Use `config/live_release.json` /
`scripts/build_release.sh` for the configured build.

---

## 10. Rollback

- **Edge code:** re-sync the previous commit's `supabase/functions/` and recreate
  the container (§3). Fast and safe.
- **Environment:** restore the previous `.env.akshara` and recreate (§4).
- **Database:** there is **no** migration down-path. Rollback means restoring the
  pre-migration backup (§8), which costs up to the full ~24h RPO of writes since
  that backup. This asymmetry is the single strongest argument for taking a fresh
  backup immediately before every migration.

---

## 11. Known-stale documents — do not follow

| Document | Problem |
|---|---|
| `docs/DeploymentArchitecture.md` | Describes Cloudflare / hosted-Supabase multi-AZ / read replicas / Datadog / 5-min RPO PITR. None deployed. Aspirational spec, not a guide. |
| `docs/Operations/Deployment-Guide.md` | Hardcodes hosted Supabase ref `oeicxjpewrumkfgyqnnj`; `supabase db push` cannot reach the VPS; cites 58 migrations. |
| `deploy/akshara-vps/DEPLOYMENT.md` | Stage checkpoint, not a guide. Cites 98 migrations; has two contradictory "Stage 4" headings; claims public exposure is not done when TLS has been live for some time. |
| `docs/PILOT_DEPLOYMENT_CHECKLIST.md` | Names branch `release/v1.0-preprod` (actual: `release/v1.0-playstore`) and 1688 tests (actual: 4316). It is a persona readiness matrix, not a deployment checklist. |
| `docs/ReleaseGovernance.md` | Describes an agent-era process ("Agent G validates gates"); references `docs/Releases/`, which does not exist; says nothing about the Play Store, signing, or staged rollout. |

These are left in place as historical record. This runbook supersedes them for
deployment.
