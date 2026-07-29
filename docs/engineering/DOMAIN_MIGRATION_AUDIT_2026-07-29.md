# Domain Migration Audit — `akshara.veloraunisexsalon.com` → `nikshaos.in`

**Date:** 2026-07-29 · **Status:** AUDIT ONLY — no infrastructure, DNS, or code changed
**Requested by:** owner · **Goal:** clean migration, zero remaining dependencies on the old hostname

---

## 0. Method

Exhaustive search for `veloraunisexsalon` across: repo (all branches of interest), built
artifacts, VPS filesystem (`/opt/akshara`, `/etc/nginx`, `/etc/cron.d`, `/etc/letsencrypt`,
`/var/www`), live container env files, deployed edge functions, and a **full data-only
`pg_dump` of the live tenant database**. Plus targeted audits of the migration surfaces that
a plain grep misses: deep links, TLS pinning, CORS, storage URL generation, external
provider callbacks, and CI.

---

## 1. ★ Key finding — the old host is an **API host**, not a web-app host

`akshara.veloraunisexsalon.com` nginx `location /` proxies to `127.0.0.1:3000`, which
`docker-compose.akshara.yml` shows is the **`akshara-edge` Deno container** (Supabase edge
functions). There is **no production web-app deploy** on that host — only:

| Path | Backend | Purpose |
|---|---|---|
| `/` | `127.0.0.1:3000` (`akshara-edge`) | **Backend REST API** |
| `/storage/v1/` | `127.0.0.1:5000` (storage-api) | Supabase Storage |
| `/privacy` | `/var/www/akshara-public/privacy.html` | Static legal page |
| `/review/` | `/var/www/akshara-review` | Temporary UXR demo (see §6-R11 — **already broken**) |

**Consequence for the layout decision.** The Q1 answer selected a 2-host split
(root = landing, `app.` = ERP). The Q2 answer described a 3-host split. Because the old host
is API-only, the **3-host split is the correct one** and is what this plan recommends — a
straight `app.`-only mapping would rename an API host to "app", which would be misleading and
would have to be split again the moment the web ERP ships.

### Recommended final layout

| Host | Serves | Origin |
|---|---|---|
| `nikshaos.in` + `www.nikshaos.in` | **Product website** (new landing page, + `/privacy`, `/terms/*`) | New static site |
| `api.nikshaos.in` | **Backend API** → `:3000`, `/storage/v1/` → `:5000` | Direct replacement for old host |
| `app.nikshaos.in` | **Web ERP app** (`web/dist`) | New capability (today only the `/review/` demo exists) |

Legal pages move from the API host to the product website — `LegalLinks.policyHostBaseUrl`
becomes `https://nikshaos.in`, which is also the correct URL for the Play Console
"Privacy Policy" field.

---

## 2. Complete reference inventory — **128 repo hits + 9 VPS/live + 1 DB row**

### Tier 1 — BLOCKING (live production behaviour; must change at cutover)

| # | Location | Current value | New value |
|---|---|---|---|
| 1 | `lib/core/config/environment.dart:68` | `apiBaseUrl: 'https://akshara.veloraunisexsalon.com'` | `https://api.nikshaos.in` |
| 2 | `lib/core/legal/legal_links.dart:21` | `policyHostBaseUrl` | `https://nikshaos.in` |
| 3 | `config/live_release.json:4` | `API_BASE_URL` (drives every release APK/AAB) | `https://api.nikshaos.in` |
| 4 | `web/.env.example:11,13,17` | `VITE_API_BASE_URL` | `https://api.nikshaos.in/functions/v1/api` |
| 5 | `web/vite.config.ts:25` | dev-proxy `API_PROXY_TARGET` default | `https://api.nikshaos.in` |
| 6 | `supabase/functions/_shared/social/social_handlers.ts:43` | `META_REDIRECT_URI` fallback | `https://api.nikshaos.in/social/connect/callback` |
| 7 | **VPS** `/opt/akshara/.env.akshara:19` | `PUBLIC_STORAGE_BASE_URL` | `https://api.nikshaos.in` |
| 8 | **VPS** `/opt/akshara/monitoring/monitoring.env` | `PUBLIC_DOMAIN` + `CERT_PATH` | `api.nikshaos.in` + new cert path |
| 9 | **VPS** `/etc/nginx/sites-available/akshara` | `server_name` + cert paths | new vhosts |
| 10 | **LIVE DB** `public.library_entities` `id=default`, `entity_type=snapshot_digital_resources` | JSONB payload contains an absolute `resourceUrl` on the old host | one-row `jsonb` update |

### Tier 2 — Operational / deploy config (change with cutover)

| Location | Note |
|---|---|
| `deploy/akshara-vps/.env.akshara.example:43` | `PUBLIC_STORAGE_BASE_URL` template |
| `deploy/akshara-vps/monitoring/monitoring.env.example:5,6` | `PUBLIC_DOMAIN`, `CERT_PATH` templates |
| `deploy/akshara-vps/monitoring/akshara-watchdog.sh:21` | hardcoded default `PUBLIC_DOMAIN` |
| `deploy/akshara-vps/storage/README.md:64` | documented edge env |
| `scripts/uxr_review/uxr_review.sh:33` | `ORIGIN` for the UXR demo |
| `scripts/run_live.sh:5,22` | `LIVE_URL` |
| **VPS** `/opt/akshara/.env.akshara-test:19` | test-tenant env (UXR demo) |
| **VPS** `/etc/letsencrypt/renewal/akshara.veloraunisexsalon.com.conf` | retire only after cutover |

### Tier 3 — Test / QA harnesses (30 files; non-blocking but must not be left stale)

`scripts/qa/live_cert_*.py` (26 files, each `BASE = "https://akshara..."`),
`scripts/qa/live_journey_*.py` (2), `scripts/perf/qa_x_025_p95_latency_probe.js`,
`scripts/*_smoke.sh` (6, in usage comments), `web/scripts/*.mjs` (9),
`test/integration/first_time_student_onboarding_live_test.dart:12`.

Two of these already read from env (`live_cert_multi_school_concurrent.py`,
`live_cert_pilot_full_year.py` use `os.environ.get("API_BASE_URL", …)`). **Recommendation:**
convert all of them to the same env-with-default pattern rather than hardcoding a second
literal — this is the change that prevents a *third* migration from being this expensive.

### Tier 4 — Built artifacts (must be **rebuilt**, not reconfigured)

| Artifact | Note |
|---|---|
| `web/dist/assets/index-DoAaVTTV.js` | old host **baked into the bundle** |
| **VPS** `/var/www/akshara-review/review/assets/index-DoAaVTTV.js` | same bundle, deployed |
| Any already-distributed release APK/AAB | old host baked in via `config/live_release.json` — see §6-R9 |

### Tier 5 — Historical docs (~55 hits; **leave as-is**)

`docs/archive/**`, `docs/audits/**`, completed certifications, `docs/ProjectStatus.md`,
`docs/DEPLOYMENT_MODEL_AND_DR_PLAN.md`, `docs/engineering/eos/TRACK_B_INFRA_EVIDENCE.md`.

These are **dated evidence records of what was true at the time**. Rewriting the hostname
inside a signed-off certification would falsify the evidence. They stay. Only
`docs/legal/PLACEHOLDERS.md:29,41` (a *live* configuration pointer, not a historical record)
gets updated.

---

## 3. Surfaces audited and found CLEAN — no migration work needed

| Surface | Verdict | Evidence |
|---|---|---|
| **Android App Links / deep links** | ✅ none bound to the host | `AndroidManifest.xml` has one generic `<intent-filter>`, no `android:host`, no `autoVerify`, no `assetlinks.json` |
| **iOS associated domains** | ✅ none | no `.entitlements`, no `applinks:` in `ios/` |
| **TLS certificate pinning** | ✅ none | no `badCertificate`/`SecurityContext`/pinning in `lib/core/`; `requireTls: true` is scheme enforcement only |
| **CORS allowlist** | ✅ wildcard | `supabase/functions/api/app.ts:81` = `Access-Control-Allow-Origin: *`; auth is bearer-header (not cookie), so a cross-origin `app.` → `api.` split works unchanged |
| **Auth redirect allowlist** | ✅ N/A | custom edge auth — no GoTrue container in `docker-compose.akshara.yml`, so no `SITE_URL`/`ADDITIONAL_REDIRECT_URLS` |
| **Storage URLs persisted in DB** | ✅ generated per-request | `_shared/storage/storage_service.ts:91-98` rewrites the origin at response time from `PUBLIC_STORAGE_BASE_URL`. **No data backfill needed** — flipping the env var is sufficient |
| **CI / GitHub Actions** | ✅ no host refs | 6 workflows, 0 hits |
| **FCM / push** | ✅ no host dependency | no URLs in `_shared/notifications/` |
| **Full DB scan** | ✅ 1 row only | data-only `pg_dump` → exactly 1 occurrence (Tier 1 #10) |

---

## 4. External / out-of-band items — **owner must change these; I cannot**

| Item | Current state | Action |
|---|---|---|
| **Razorpay dashboard** webhook URL | **No `RAZORPAY_*` keys in live env → stub mode.** Not yet an active dependency | Set webhook to `https://api.nikshaos.in/...` when W3 Razorpay goes live |
| **Meta/Facebook app** redirect URI | **No `META_*` in live env → dormant** | Update if/when social is enabled |
| **Play Console** privacy-policy URL | No Play account yet (per project state) → nothing submitted | Use `https://nikshaos.in/privacy` at submission |
| **Hostinger DNS** | See §5 | I can change this via the Hostinger API once approved |

---

## 5. DNS starting state — `nikshaos.in`

Registered 2026-07-29, active, expires 2029-07-29. Current zone:

```
@       A       2.57.91.91          ttl 50      ← Hostinger parking; REPOINT to 46.28.44.46
www     CNAME   nikshaos.in.        ttl 300     ← keep
@       MX      5 mx1 / 10 mx2 .hostinger.com   ← ⚠ KEEP (email)
@       TXT     v=spf1 …hostinger…              ← ⚠ KEEP
_dmarc  TXT     v=DMARC1; p=none                ← ⚠ KEEP
hostingermail-{a,b,c}._domainkey  CNAME         ← ⚠ KEEP (DKIM)
autodiscover / autoconfig  CNAME                ← ⚠ KEEP
```

**Records to ADD:** `api` A → `46.28.44.46`, `app` A → `46.28.44.46`.
**Record to CHANGE:** `@` A → `46.28.44.46`.
**Do not use `overwrite: true` on the whole zone** — it would destroy the mail records.

`veloraunisexsalon.com` is **not in this Hostinger account** (API returns
`Customer does not own`), so its DNS is managed elsewhere and is out of reach from here.

---

## 6. Risks & blockers

| # | Risk | Severity | Mitigation |
|---|---|---|---|
| **R1** | `PUBLIC_STORAGE_BASE_URL` flip must be atomic with the vhost cutover, else every signed upload/download URL points at a dead origin | **P0** | Flip env + restart `akshara-edge` in the same step as nginx reload; verify with a real upload→signed-URL→download round trip |
| **R2** | One live DB row carries an absolute old-host URL | P1 | One-row `jsonb_set`; it is cert-run test data (`Cert Resource 1782498971`), not real school content |
| **R3** | 30 QA/cert harnesses hardcode the host — they will silently pass against a *retired* host or fail confusingly | P1 | Convert to `os.environ.get("API_BASE_URL", "https://api.nikshaos.in")` |
| **R4** | Built bundles have the host **compiled in** — config change alone is insufficient | P1 | Rebuild `web/dist` and re-deploy; rebuild any APK/AAB |
| **R5** | Certbot needs certs for 3 new names before nginx can serve TLS (chicken-and-egg) | P1 | Port-80 vhost + ACME webroot first, then `certbot`, then 443 — the exact pattern already proven in `sites-available/chotu-api` |
| **R6** | **Host constants exist identically on `feature/program-d-…` (current) AND `release/v1.0-playstore`.** The NIKSHA OS rename lives *only* on the release branch | **P0 — needs your decision** | See §8 |
| **R7** | Deleting the wrong DNS records kills `nikshaos.in` email | P1 | Additive `overwrite:false` updates only; validate before applying |
| **R8** | Shared VPS — `velora-salon`, `n8n`, `chotu-api`, `parental-monitor` all live in the same nginx | **P0** | New vhost in a **new file**; never edit existing site files; `nginx -t` before every reload |
| **R9** | Any already-distributed internal-testing APK has the old host baked in and **will break at retirement** | P1 — **needs your answer** | See §8 |
| **R10** | Old host retired before new host is verified → total pilot outage | P0 | Retirement is a **separate, final step** gated on verification (§7 Phase 5) |
| **R11** | The `/review/` UXR demo's API proxy targets `127.0.0.1:3001`, which is **not listening** — the demo is already broken today | P2 (pre-existing, not caused by this migration) | Decide: retire the demo with the old host, or repair it |

---

## 7. Proposed migration plan (execution order)

**Phase 0 — DNS (additive, zero risk to anything live)**
Add `api` + `app` A records → `46.28.44.46`. Leave `@` on parking for now. Mail records untouched.

**Phase 1 — Certificates**
New nginx file `sites-available/nikshaos` with port-80 + ACME webroot for all three names →
`nginx -t` → reload → `certbot` for `nikshaos.in`, `www`, `api`, `app`.

**Phase 2 — Serve the new hosts in parallel (old host still up)**
`api.nikshaos.in` mirrors the current akshara vhost (`/` → :3000, `/storage/v1/` → :5000).
Build + deploy the product website to `nikshaos.in` (landing page + `/privacy` + sign-in link
to `app.nikshaos.in`). Build + deploy `web/dist` to `app.nikshaos.in`.
*This is a temporary overlap purely to make verification possible — not a permanent parallel host.*

**Phase 3 — Code + config cutover**
All Tier 1–4 changes. Flip `PUBLIC_STORAGE_BASE_URL`, restart `akshara-edge`, update
`monitoring.env`. Fix the one DB row. Rebuild bundles.

**Phase 4 — Verification (the gate)**
Against `api.nikshaos.in` **only**: health · OTP auth (all 4 personas) · RBAC denial ·
money loop · **storage upload → signed URL → download** (proves R1) · notifications ·
a representative live-cert wave. Website + app hosts load, TLS valid, `/privacy` resolves,
sign-in link works. Watchdog green on the new domain. **Migration is not complete until this
phase passes.**

**Phase 5 — Retirement of `akshara.veloraunisexsalon.com`**
Only after Phase 4. Remove the nginx site symlink, remove the certbot renewal config,
re-point `@` for `nikshaos.in` off parking. Old DNS A record for `akshara.…` is managed
outside this Hostinger account — owner removes it at the registrar.

**Phase 6 — EOS gate** on the completed migration scope.

---

## 8. Blocking questions for the owner

1. **R6 — which branch carries the host migration?** The constants live on both the current
   branch and `release/v1.0-playstore` (which holds the NIKSHA OS rename). Doing it twice
   invites divergence. Recommendation: **land it on `release/v1.0-playstore`**, since the
   domain and the app rename are one product decision.
2. **R9 — has any APK/AAB been distributed to real testers?** If yes, they break at Phase 5
   and need a rebuilt binary shipped first. If no, Phase 5 is unconstrained.
3. **R11 — retire the `/review/` UXR demo with the old host, or carry it over?** It is
   currently non-functional.

---

## 9. Out of scope — do not touch

`velora-salon`, `n8n.veloraunisexsalon.com`, `chotu.veloraunisexsalon.com` (separate product),
`monitor.veloraunisexsalon.com`, shared Redis. These share the VPS and the old apex domain but
are **not part of this migration**.
