# Curriculum Acquisition — Continuous Crawler Spec

**Owner directive (2026-07-08):** stop treating acquisition as a fixed URL list. Build a
**continuous, resumable web-acquisition crawler** that builds the MOST COMPLETE official
curriculum repository. Goal = **completeness, not speed.**

## Targets
Official domains only, Classes **6–10**:
- **CBSE** — `cbseacademic.nic.in`, `cbse.gov.in`
- **NCERT** — `ncert.nic.in` (textbooks: `ncert.nic.in/textbook.php`)
- **AP SCERT** — `bse.ap.gov.in`, `cse.ap.gov.in`, `apscert.gov.in`
- **Telangana SCERT** — `scert.telangana.gov.in`
- **CISCE / ICSE** — `cisce.org` (static assets under `/wp-content/uploads/…`)

Sections to search per domain: Publications · Downloads · Curriculum · Syllabus · Textbooks ·
Teacher Resources · Sample Papers · Marking Schemes · Circulars · Manuals · Archive pages ·
PDF repositories · **Sitemaps** (`/sitemap.xml`, `/wp-sitemap.xml`) · search-indexed PDFs ·
document libraries.

## Discovery (multi-strategy, per domain)
1. **Sitemaps** — fetch + parse `sitemap.xml` / `wp-sitemap*.xml`; enqueue all PDF + section URLs.
2. **Section link-following** — BFS from known section landing pages, same-domain, depth-bounded,
   collecting `<a href *.pdf>` + sub-section pages. Respect `robots.txt`.
3. **Direct-PDF probing** — for known asset path patterns (e.g. CISCE `/wp-content/uploads/YYYY/MM/…`),
   probe candidate URLs with HEAD before GET.
4. **Search-page / search-engine discovery** — when directory crawling is blocked (e.g. Cloudflare
   managed-challenge on HTML), use the domain's official search page and/or web-search for
   `site:<domain> filetype:pdf <topic>`; only enqueue verified same-official-domain URLs.

## Per-resource pipeline
For every discovered URL: **record in manifest → download → verify (full V1–V11) → sha256 →
auto-retry failures (backoff) → mark unavailable WITH EVIDENCE (http code / block reason) →
never download the same resource twice** (dedup by normalized URL AND by sha256 across the archive).

## Verification gate (owner-locked)
A resource counts as **acquired only after full V1–V11**: `%PDF` magic · non-empty · min-size
(not an error/challenge page) · **PDF-parseable** (pypdf) · sha256 recorded · not duplicate/
corrupt/incomplete/invalid. Failures re-enter retry until VERIFIED or `NOT_PUBLICLY_AVAILABLE`
(with evidence). **Dashboard reports Downloaded AND Verified separately; only Verified counts %.**

## Manifest (single source of truth, resumable)
`curriculum/acquisition/crawler_manifest.json` — one record per resource, columns:
**Resource · Board · Class · Subject · URL · Status · Verification · Last-checked · Retry-count**
(+ sha256, bytes, local_path, discovered_via, evidence). Plus a `crawler_state.json` frontier
(queued/visited URLs) so a re-run **resumes** and skips done work. Fold in the existing ~138-PDF
archive (dedup — do not re-fetch).

## Constraints
- **Per-domain rate limits** (polite delay per host; parallelize ACROSS domains, not within).
  `robots.txt` respected. Official sources only; never bypass auth/paywalls/Cloudflare login.
- **Storage lock:** raw PDFs + derived data = LOCAL only (gitignored). Git commits the crawler
  **code** (`curriculum/scripts/crawler/`) + the provenance **manifest** only. No DB / VPS.
- **Resumable + idempotent:** safe to stop/restart; continues until no new official resources appear.
- **Model:** build with Sonnet (code); run with Haiku (deterministic execution/monitoring).

## Locked execution rules (owner amendment, 2026-07-08)

**Build gate — ALL must pass before the full crawl launches:**
1. Unit verification (crawler unit tests green).
2. Dry-run verification (`crawl.py --dry-run` clean on a fixture).
3. Small live discovery test (one real sitemap → real URLs parsed).
4. Verification-pipeline validation (V1–V11 proven on a real downloaded PDF).

**Crawl priority (process boards in this order; within each: Discover → Download → Verify →
Archive → Retry):**
- **P0 — CBSE, NCERT**
- **P1 — Andhra Pradesh SCERT**
- **P2 — Telangana SCERT**
- **P3 — CISCE / ICSE**

**Completion criteria (crawler NEVER stops after one pass — continue until ALL true):**
- No new official resources discovered for **3 consecutive** crawl passes.
- Retry queue is **empty**.
- **Every** downloaded resource has completed verification.
- All remaining resources are explicitly recorded **Not Published / Not Available with evidence**.

**Dashboard metrics (always shown, separately):** Resources **Discovered** · **Downloaded** ·
**Verified** · **Failed** · **Retry Queue** · **Archived** · **Overall Coverage %** · **Per-board
Coverage %**. Downloaded and Verified are ALWAYS separate counts; **overall progress = Verified**
(not Downloaded).

**Run model:** launch the full crawl with the **lightweight model** (Haiku). Continue Curriculum
implementation in parallel — never wait for acquisition to finish, never block it on implementation.

## Deliverable shape
`curriculum/scripts/crawler/` — a small package: `frontier.py` (resumable queue + dedup),
`discovery.py` (sitemap/link/probe/search strategies, per-domain adapters), `fetch.py` (polite
download + retry), `verify.py` (reuse `verification_engine` V1–V11 per file), `manifest.py`
(the columns above), `crawl.py` (CLI orchestrator: `--board`, `--resume`, `--max-pages`,
`--allow-network`), + tests on a dry-run fixture. Reuse existing `curriculum/scripts/` verify
logic; do not duplicate it.
