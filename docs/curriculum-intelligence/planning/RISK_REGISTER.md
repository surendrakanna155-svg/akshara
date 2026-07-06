# Curriculum Intelligence — Risk Register

**Date:** 2026-07-06 · Severity = Impact × Likelihood (H/M/L). Owner = who must act. Reviewed at every milestone boundary.

---

| # | Risk | Sev | Likelihood | Mitigation | Trigger/monitor | Owner |
|---|---|---|---|---|---|---|
| **R1** | **Legal/copyright violation** — question or content ingestion crosses D8 / v2.0 §25 guardrails (esp. CISCE/publisher material, "trusted repositories" drift) | **H** | M | **D-3 ruling received (2026-07-07): three-layer model** — L1 official corpus (repository-side) · L2 PYQ Intelligence (analysis/reference only) · L3 Certified Question Bank (sole production source by default); zero automatic L1/L2→L3 flow; license status mandatory on every resource; LICENSE_REPORT audited at every board exit (AT-D6); prohibited-practice list in every acquisition config | Any resource without license status; any L3 item sourced from L1/L2 without explicit license + teacher validation | Owner + CI-DATA |
| **R2** | **Source availability** — government portals down, moved, or fragmented (known: NTA pre-2020 fragmentation) | M | **H** | Spec failure ladder (retry → alternates → documented MISSING); never stall pipeline on one resource; discovery caches URLs + snapshots dates | FAILED_DOWNLOADS growth rate; per-board missing-count | CI-DATA |
| **R3** | **Solver regression breaks the certified pilot engine** | **H** | M | Golden-test pinning before refactor (mandatory CI-C1 step); template-absent = legacy path; live-cert original 20 per wave; one-commit waves = clean revert | Any golden diff; live-cert red | CI-BE/CI-QA |
| **R4** | **Scope explosion** — 4 boards × 5 classes × ~10 subjects × ~30 categories ≈ thousands of artifacts swamp the program | **H** | **H** | Priority-A-first discipline (Part 07); board-sequential; per-board exit gates; Priority-B capped at 95% target; Priority-C best-effort only; coverage % tracked continuously | Board wave exceeding its estimate by >50%; TODO backlog growth | CI-DATA |
| **R5** | **Governance drift — a second roadmap emerges** (this program vs frozen FINAL_EXECUTION_MASTER_ROADMAP) | **H** | M | D-1 owner sequencing decision; program tracker explicitly subordinate; code waves ride standard EOS machinery; no master-roadmap file edits from this program | Any reference conflict; EOS run flags | Owner |
| **R6** | **Owner-decision latency** (D-1..D-4 + future batch) stalls both lanes | M | M | Decisions batched with recommendations; program idles at zero cost pre-approval; per standing rule, decisions never pause unrelated pipeline work | M0 age > 1 week | Owner |
| **R7** | **Data-quality poisoning** — wrong chapter trees / mis-transcribed blueprints flow into `subject_templates`/solver and generate wrong papers at scale | **H** | M | Adversarial CI-REVIEW verification (AT-K1/K3) before any code wave consumes a dataset; verbatim+source-traced extraction; expansion migration per board (bounded blast radius); wizard regression | Teacher-reported wrong chapter; template mismatch vs specimen | CI-QA |
| **R8** | **OCR/extraction quality** below the ≥80% bar on real school papers (CI-C6) | M | M | OCR-first doctrine limits blast radius (AI residue only); moderation gate means bad extraction costs review time, never bank quality; test corpus spans digital/scan/Word | AT-C6.1 failure | CI-BE |
| **R9** | **AI cost creep** — validation engine + ingestion assist grow token spend | M | L–M | D3 token rules (residue-only, batched, fingerprint-first); call logging with token counts (existing pattern); T0–T2-first ladder from the adaptive-AI suite; validation batched per paper | Call-log monthly trend | CI-BE |
| **R10** | **Storage bloat** — corpus (GBs of PDFs) lands in the app repo or bloats backups | M | M | D-2 decision; `.gitignore` guard from CI-A0; binary trees never committed; metadata/indexes (text) size-monitored | `git status` showing resource files; repo size delta | CI-DATA |
| **R11** | **Upstream curriculum churn** — NEP-driven revisions, new editions mid-program | M | M | Version columns + archive-never-overwrite (Part 04); continuous-sync (CI-C9) designed for exactly this; historical editions retained | Board circulars in acquisition sweep | CI-DATA |
| **R12** | **Bandwidth collision** with the active master-roadmap waves (same maintainer) | M | **H** | Data lane is checkpoint-resumable (interruption is free); code lane = one wave at a time, schedulable into roadmap gaps; D-1 sets the priority explicitly | Sprint slippage in either program | Owner |
| **R13** | **Live-lane unavailability** (VPS/CI access owner-deferred) blocks live certification of code waves | M | M | Stage live-cert extensions locally (same harness pattern as QW8); mark waves CONDITIONAL until the live lane opens; nothing ships to pilot without the deploy recipe anyway | Live-lane status in master dashboard | Owner |
| **R14** | **English-medium assumption breaks** for AP/TS resources (many official docs are Telugu-first) | M | M | Scope stays English-medium (C5); where an official English version doesn't exist → `NOT_PUBLICLY_AVAILABLE (English)`; multilingual content remains owner decision O-A — never improvised | AP/TS coverage gaps concentrated on language | CI-DATA |

## Standing risk-review rules

1. Every milestone boundary: re-score all rows; add new risks discovered by waves.
2. Any **H×H** cell halts the affected lane until mitigated or owner-accepted.
3. Legal risks (R1) are never accepted by default — always owner-ruled.
