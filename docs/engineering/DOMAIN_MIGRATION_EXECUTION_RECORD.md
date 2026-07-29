# Domain Migration — Execution Record

**`akshara.veloraunisexsalon.com` → `nikshaos.in` (NIKSHA OS)**
**Date:** 2026-07-29 · **Branch:** `release/v1.0-playstore` · **Audit:** [DOMAIN_MIGRATION_AUDIT_2026-07-29.md](DOMAIN_MIGRATION_AUDIT_2026-07-29.md)

---

## ⚠️ Read this first — commit `8050eda2` is mislabelled

The entire domain migration was **swept into commit `8050eda2`** by a
concurrently-running session that issued a catch-all `git add`. That commit is
titled *"SECURITY: live pilot findings CONFIRMED — program paused for owner
review"* and its body states *"no infra touched"*.

**Both statements are wrong about that commit's contents.** Of its 101 files:

| Files | Owner | What they are |
|---|---|---|
| 2 | security lane | `docs/certification/CRITICAL_SECURITY_FINDING_LIVE.md`, `docs/certification/PROGRAM_STATE.md` |
| **99** | **domain migration** | everything else — client config, edge functions, web app, brand assets, deploy config, 34 QA harnesses, the whole `deploy/nikshaos/` site |

Owner ruled (2026-07-29) **not** to rewrite history, because the other session was
still committing and a rebase under it could destroy in-flight work. This file is
the record instead. Nothing was lost; only the commit message is misleading.

---

## Final architecture

| Host | Serves | Backend |
|---|---|---|
| `nikshaos.in` (+ `www` → 301) | Product website + hosted legal documents | static `/var/www/nikshaos-site` |
| `app.nikshaos.in` | Web ERP (SPA) | static `/var/www/nikshaos-app` |
| `api.nikshaos.in` | Backend API + Storage | `127.0.0.1:3000` (deno edge) · `/storage/v1/` → `:5000` |

The audit established the old host was an **API host, not a web-app host**, which
is why the 3-host split was used rather than a 2-host `app.`-only mapping.

**nginx:** one isolated file, `deploy/nikshaos/nginx/nikshaos.conf` →
`/etc/nginx/sites-available/nikshaos`. The `akshara`, `chotu-api`,
`velora-salon` and `parental-monitor` site files were never edited.

**TLS:** single certificate, cert-name `nikshaos.in`, 4 SANs
(`nikshaos.in`, `www`, `api`, `app`). Expires 2026-10-27, certbot auto-renews.

---

## What changed

### Client / code (99 files)
| Area | Change |
|---|---|
| `lib/core/config/environment.dart` | `apiBaseUrl` → `https://api.nikshaos.in` |
| `lib/core/legal/legal_links.dart` | `policyHostBaseUrl` → `https://nikshaos.in` (legal now lives on the website, not the API host) |
| `config/live_release.json` | `API_BASE_URL` → `https://api.nikshaos.in` — this is what every release APK bakes in |
| `supabase/functions/_shared/social/social_handlers.ts` | `META_REDIRECT_URI` fallback → new host |
| `supabase/functions/_shared/legal/legal_catalog.ts` | user-visible string "your school and Akshara" → "NIKSHA OS" |
| `web/` | API base, vite proxy, `index.html` title/favicon/theme-color, `Logo`, login page, loading screen, support console |
| 34 QA harnesses | `BASE = os.environ.get("API_BASE_URL", "https://api.nikshaos.in")` — **env-with-default, so the next rename is one variable, not 34 edits** |

### Live infrastructure
- `/opt/akshara/.env.akshara` → `PUBLIC_STORAGE_BASE_URL=https://api.nikshaos.in`
- `/opt/akshara/monitoring/monitoring.env` → `PUBLIC_DOMAIN=api.nikshaos.in`, `CERT_PATH=/etc/letsencrypt/live/nikshaos.in/fullchain.pem`
- **3 edge files copied surgically.** The release branch has 581 function files vs 519 deployed — deploying the branch wholesale would have shipped ~62 files of unreleased work. Each of the 3 was diffed against production first and differed *only* by the migration edit.

### Database
Two `library_entities` rows (cert-run artifacts, `resourceUrl` → old host) rewritten.
Backup: `/opt/akshara/library_entities_snapshot.bak.<ts>.json`.
**A full `pg_dump --data-only | grep` now returns 0 occurrences of the old host.**

### Deliberately NOT changed
~46 files under `docs/` — dated certifications, audits and evidence records.
Rewriting a hostname inside a signed-off certification falsifies the evidence.

---

## ★ Two traps caught during execution

**1. `docker compose restart` does not re-read `env_file`.**
After the restart the container reported healthy and served traffic, but
`printenv PUBLIC_STORAGE_BASE_URL` still returned the **old** host — the bind-mounted
`.ts` sources had reloaded while the environment had not. `up -d --force-recreate`
was required. Undetected, every signed storage URL would have pointed at a dead
origin the moment the old host was retired. **This is why the storage round-trip is
verified by a real upload+download, not by a health check.**

**2. `sed 's|old|new|g'` on `monitoring.env` produced a cert path that does not exist.**
It rewrote `CERT_PATH` to `/etc/letsencrypt/live/api.nikshaos.in/...`, but the
certificate is stored under the cert-**name** `nikshaos.in`. The watchdog's cert-expiry
check would have failed silently against a missing file.

---

## Verification

### Behaviour-neutrality gate — the core method
Every harness was run against **both hosts** and the scores compared. A difference
would be a migration regression; an equal score below 100% is a pre-existing defect
this migration did not cause.

| Harness | new host | old host | verdict |
|---|---|---|---|
| `live_cert_red_team_wave1` (money integrity, RLS, constraints) | 26/26 | 26/26 | PARITY |
| `live_cert_journey_wave2` | 28/28 | — | PASS |
| `live_cert_journey_wave4` (incl. **storage round-trip**) | 17/28 | 17/28 | PARITY |
| `live_cert_journey_wave1` | 5/16 | 5/16 | PARITY |
| `live_cert_fcm_push` (notifications) | 7P/6F | 7P/6F | PARITY |
| `live_cert_completion_wave1` | 0/2 | 0/2 | PARITY |

**The 11 wave-4 and 11 wave-1 failures reproduce identically on the old host** —
hostel/alumni 403s, org-builder 500, homework 422. They are pre-existing production
defects, unrelated to this migration, and are covered by the systemic remediation
roadmap.

### R1 proof — storage
`MJ-M7` end-to-end against `api.nikshaos.in`: presign → PUT bytes → confirm →
listed `hasFile=true` → **download URL served the file, HTTP 200, 45 bytes.**

### Suites
- Flutter: **4473 passed**, exit 0
- Deno backend: **4165 passed, 0 failed**, 3 ignored
- `py_compile` across all 34 migrated harnesses: PASS

### Surfaces confirmed clean (no work needed)
Deep links / App Links (none bound to any host, no `assetlinks.json`, no iOS AASA) ·
TLS pinning (none) · CORS (wildcard; bearer-header auth, so the cross-origin
`app.` → `api.` split needs no change) · auth redirect allowlist (custom edge, no
GoTrue) · CI (no host refs) · storage URLs generated per-request (no data backfill).

---

## Open items for the owner

| # | Item | Why it needs you |
|---|---|---|
| 1 | **`/health/*` unauthenticated exposure** on `api.nikshaos.in` — `/health/backup` returns backup age/size/SHA256/offsite, `/health/tenant-access` returns DB role, `bypassRls` and `isolation.pass=false` | **Pre-existing**, not caused by this migration, but publishing the new host widened it from one public hostname to two. Retiring the old host narrows it back to one; it does not fix it. Escalated separately by the security lane. |
| 2 | **`applicationId = "com.akshara.erp"`** unchanged | The Android package ID is **immutable once published to Play**. This is the last moment it can become a NIKSHA identifier. Changing it also touches signing and `google-services.json`. |
| 3 | **No horizontal/vertical lockup master** in `brand/niksha-os/svg/` | BRAND_GUIDELINES §6 mandates a lockup for website headers and §3 assigns it a 120px minimum, but no such file exists. `wordmark`/`suffix`/`tagline` are declared at `build_assets.js:28-30` and **never rendered**, so every generated marketing asset — including `og-image-1200x630.png` — is symbol-only and nameless. Owner authorised typesetting to the §5 spec (Inter 700 / +0.14em) as an interim, isolated in `.wordmark`/`.suffix` (web) and `LogoPlaceholder.tsx` for a one-edit swap. |
| 4 | **5 legal placeholders** rendered as visible `pending` chips | Registered address, Grievance Officer name + designation, governing-law city + state are legal facts and were not invented. `support@nikshaos.in` was substituted where authorised. Required before public launch under the DPDP Act. |
| 5 | Two `library_entities` cert artifacts | Host was rewritten, but they are test junk ("Cert Resource …" pointing at `/health`) that may warrant purging from production. |

---

## Rollback

| Layer | How |
|---|---|
| nginx | `rm /etc/nginx/sites-enabled/nikshaos && nginx -t && systemctl reload nginx` |
| edge env | `cp /opt/akshara/.env.akshara.bak.domainmig.<ts> /opt/akshara/.env.akshara` then `docker compose up -d --force-recreate akshara-edge` (**not** `restart`) |
| edge sources | `/opt/akshara/.domainmig_bak.<ts>/` holds the 3 originals |
| monitoring | `/opt/akshara/monitoring/monitoring.env.bak.domainmig.<ts>` |
| database | `/opt/akshara/library_entities_snapshot.bak.<ts>.json` |
| DNS | unchanged by rollback; the old host's records live outside this Hostinger account |
