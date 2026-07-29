# Repository Hygiene & Information Architecture — Cleanup Plan

**Status:** Tier 0 **APPLIED & KEPT** (owner-approved 2026-07-20). Tier 1 & Tier 2 **FROZEN — DO NOT EXECUTE** until the owner explicitly approves after the UI/UX audit (see gating below).
**Date:** 2026-07-20
**Scope:** Whole repository (`/Users/surendrakanna/Documents/Akshara_ERP`), read-only analysis. Tier 0 applied; Tiers 1–2 not executed.
**Method:** 6 parallel read-only region agents + orchestrator cross-region verification (git dates, inbound-reference grep, byte-diffs, supersession banners).
**Prime directive:** *Archive, never delete.* No source, migration, test, golden test, certified dataset, QIE knowledge, roadmap history, owner decision, or legal material is proposed for deletion. Every action below is reversible.

> ## ⛔ EXECUTION GATING — OWNER-LOCKED (2026-07-20)
>
> The product is **mid-implementation and not yet feature-complete** (roadmap recently expanded:
> Smart OMR, Paper Intelligence, AI Copilot improvements, and other approved items). Cleanup that
> relocates files now would churn an actively-changing tree. The owner has locked this order:
>
> 1. **Keep Tier 0** (already applied — navigation/gitignore fixes, banners, QIE README). ✅
> 2. **Complete all approved ERP/QIE roadmap features.**
> 3. **Comprehensive Android + iOS + Web UI/UX + workflow audit** (advanced AI review) once feature-complete.
> 4. **Convert approved audit findings → roadmap items → implement.**
> 5. **Only after the product reaches its feature-complete state:** execute **Tier 1** repository cleanup,
>    then code hardening, security/performance audits, pilot, production.
>
> **Tier 1 and Tier 2 below are kept intact and ready, but MUST NOT be executed** until the owner
> explicitly approves — which happens after step 3 (the UI/UX audit), not before. Any AI session
> reading this plan: do not run `git mv`/dedup/relocation actions from §3 or §6 without that explicit
> approval. Tier 0 is the only tier authorized to date.

---

## 0. Headline verdict

The repository is **hygienically strong at the code layer** (no committed build output, no `.g.dart`, no backup/temp files, no experimental dirs, comprehensive `.gitignore`) and **already has a well-run documentation archive** (`docs/archive/`, 646 files, README-indexed, `git mv` provenance, dormant since 2026-07-04).

The real issues are **navigation/currency drift**, not filesystem cruft:

1. **The canonical forward roadmap is undiscoverable.** `docs/roadmap/AKSHARA_CONSTITUTION_ALIGNED_MASTER_ROADMAP.md` (the current SSOT) has **zero inbound links** from `docs/README.md`, `PROJECT_INDEX.md`, `PROJECT_CONTEXT.md`, `CLAUDE.md`, or `AGENTS.md`. The two entry-point files each point at a *different, superseded* roadmap.
2. **Two `reports/` trees with opposite tracking policies** and a large set of point-in-time snapshots still living in the active tree.
3. **9 byte-identical duplicate design docs** exist in both `docs/design/` and `docs/archive/design/`.
4. **88 transient golden-diff PNGs (6.6 MB) are tracked** despite the repo's own rule to never commit them.
5. **QIE (133 files) has no index**, mixing 5 current docs with ~18 done-snapshots, ~22 reference specs, and 88 evidence artifacts.

Fixing #1 and the indexes is the single highest-value, lowest-risk action — it is what makes *future* audits cheap.

---

## 1. Repository Inventory

**Total tracked files: 5,854.** Working tree also carries ~27 untracked (not-ignored) curriculum files (intentional local-only data — see §5) and 1 uncommitted test.

| Region | Tracked | Primary classification | Notes |
|---|---:|---|---|
| `lib/` | 1,739 | **ACTIVE** (Flutter source) | Clean — no cruft, no tracked `.g.dart` |
| `docs/` | 1,133 | mixed | 646 already ARCHIVE; 487 active (see §1a) |
| `supabase/` | 980 | **ACTIVE** (migrations + edge functions) | Migrations = protected |
| `test/` | 878 | **ACTIVE** (test + golden suites) | ⚠ 88 tracked golden-diff PNGs to untrack (§5) |
| `curriculum/` | 368 (+~27 untracked) | **ACTIVE** engine + **REFERENCE** + local-only GENERATED | Certified v1.4 dataset is local-only/gitignored — protected |
| `web/` | 191 | **ACTIVE** | Clean — no committed `dist/`/`node_modules` |
| `qa/` | 165 | **ACTIVE** (harness) | A few GENERATED manifests + 7 one-off rerun scripts |
| `patrol_test/` | 134 | **ACTIVE** | — |
| `scripts/` | 95 | **ACTIVE** tooling + ~30 one-off **ARCHIVE** candidates | CI wires only `scripts/qa/*` |
| `ios/` `android/` | 44 / 37 | **ACTIVE** (platform) | — |
| `reports/` (root) | 30 | **GENERATED** (run artifacts) | Untouched since 2026-06-13 → archive/relocate |
| `deploy/` | 25 | **ACTIVE** (VPS ops infra) | — |
| `.claude/` `.github/` | 11 / 5 | **ACTIVE** (skills/commands, CI) | — |
| `openapi/` `backend/` `config/` | 2 / 2 / 1 | **ACTIVE** | — |
| Root files | ~10 | ACTIVE governance + GENERATED strays | See §1b |

### 1a. `docs/` breakdown (1,133)

| Sub-tree | Files | Classification |
|---|---:|---|
| `docs/archive/` | 646 | **ARCHIVE** (already parked; model hygiene) |
| Loose top-level `docs/*` | 101 (75 md + 26 txt) | mixed — 24-part SRS (REFERENCE), ~15 QW/QA certs (REFERENCE), module specs (ACTIVE_DOC), point-in-time reports (ARCHIVE candidates) |
| `docs/question-intelligence-quality/` | 133 | **ACTIVE_DOC ~5 / REFERENCE ~22 / ARCHIVE-snapshot ~18 / GENERATED 88** |
| `docs/engineering/` | 42 | Constitution + policy (FROZEN/CANONICAL) + eos/ evidence sink (REFERENCE) |
| `docs/Operations/` | 37 | Runbooks (ACTIVE_DOC) + 3 readiness reports (ARCHIVE) |
| `docs/curriculum-intelligence/` | 32 | Frozen program baseline (ACTIVE_DOC/REFERENCE) — clean |
| `docs/Testing/` | 28 | ~18 evergreen guides (ACTIVE) + ~10 version-tagged reports (ARCHIVE) |
| `docs/design/` | 27 | Design SSOT + companions (ACTIVE_DOC) + fragmentation (see §2) |
| `docs/audits/` | 18 | Fable 00–11 audit corpus + ledger (REFERENCE) + 4 ARCHIVE candidates |
| `docs/Vision/` | 16 | Active vision tracks (ACTIVE_DOC) |
| `docs/legal/` | 15 | **ACTIVE_DOC — protected, do not touch** |
| `docs/roadmap/` | 13 | Canonical roadmap + companions (ACTIVE) + 2 ARCHIVE candidates |
| `docs/knowledge-intelligence-engine/` | 9 | Certs for a **retired** engine (REFERENCE; owner-review to archive) |
| `docs/strategy/` `docs/execution/` `docs/owner/` | 7 / 6 / 2 | Strategy inputs + execution journal + owner Product Constitution |

### 1b. Root files

| File | Class | Action |
|---|---|---|
| `CLAUDE.md`, `AGENTS.md` | ACTIVE (governance) | keep |
| `PROJECT_INDEX.md` | ACTIVE_DOC — **stale** | refresh (§7) — canonical AI entry point |
| `PROJECT_CONTEXT.md` | ACTIVE_DOC — **stale** | refresh; defer roadmap pointer to PROJECT_INDEX |
| `IDEAS_BACKLOG.md` | ACTIVE_DOC | keep |
| `CLEANUP_REVIEW.md` | **ARCHIVE** | prior cleanup audit, all concerns resolved → `docs/archive/audit/` |
| `pubspec.*`, `analysis_options.yaml`, `.metadata`, `.gitignore` | ACTIVE (config) | keep |
| `flutter_01.log`, `.DS_Store`, `akshara_erp.iml`, `.flutter-plugins-dependencies`, `qie.db` | GENERATED strays | already gitignored; optional local `rm` only |

---

## 2. Duplicate Analysis

### 2a. Byte-identical duplicates — `docs/design/` ↔ `docs/archive/design/` (9 pairs, CONFIRMED)

All 9 verified `diff`-identical, both copies present. Inbound references (from non-archive docs) all resolve to the **active** copy → the **archive copy is the redundant one**. Deduping loses no content (identical bytes + git history retain everything).

| Basename | Active inbound refs | Recommended keep |
|---|---:|---|
| `DesignSystem.md` | 27 | **active** (heavily load-bearing) |
| `ACADEMIC_ASSESSMENT_PLATFORM_DESIGN.md` | 5 | active (header: DEFERRED) |
| `DESIGN_SYSTEM_V1.md` | 4 | active |
| `FigmaDesignSystemBuildGuide.md` | 4 | active |
| `Finance_Module_Specification.md` | 3 | active |
| `EXAM_WORKSPACE_DESIGN.md` | 2 | active |
| `FUTURE_VISION_AI_SCHOOL_BUILDER.md` | 2 | active |
| `M15_THEME_MODERNIZATION_READINESS.md` | 2 | active |
| `M15.5_PREMIUM_TRANSFORMATION_REPORT.md` | 1 | active |

**Resolution:** remove the 9 redundant `docs/archive/design/*` copies (Tier 1). *This is dedup, not history loss.* (A separate, optional consolidation question — whether the superseded specs should instead live only in archive — is Tier 2 and needs ref-repointing; see §6.)

> Divergent (NOT identical) pairs — leave as-is: `FUTURE_VISION_MASTER_INDEX.md`, `FUTURE_VISION_PRESERVATION_AUDIT.md`, `PILOT_READINESS_REPORT.md`, `BACKUP_RESTORE_RUNBOOK.md`. Active copy is newer/authoritative; archive copy is a correctly-parked older snapshot.

### 2b. Roadmap supersession chain (banner-disambiguated — NOT silent dups)

`AKSHARA_CONSTITUTION_ALIGNED_MASTER_ROADMAP.md` (CANONICAL, 2026-07-20)
→ `FINAL_EXECUTION_MASTER_ROADMAP.md` (REFERENCE — still the PRA-register/journal authority; **missing a "superseded-as-forward-plan" banner** — add one)
→ `docs/audits/MASTER_EXECUTION_ROADMAP.md` (SUPERSEDED banner → archive)
→ `docs/audits/FABLE_FINAL_ROADMAP.md` (SUPERSEDED/FOLDED banner → archive)
→ `docs/FINAL_QA_ROADMAP.md` (frozen QA-wave history → keep REFERENCE).

### 2c. Design-system authority fragmentation (7 overlapping docs)

Three files each self-claim "single source of truth" (`PRODUCT_EXCELLENCE_MASTER_PLAN.md`, `PREMIUM_DESIGN_SYSTEM_GUIDE.md`, `VISUAL_DESIGN_SYSTEM.md`). **Canonical = `PRODUCT_EXCELLENCE_MASTER_PLAN.md`** (self-declared Phase-5 SSOT that combines the others). Fix by adding one-line pointer headers to the companions; archive only `DESIGN_SYSTEM_V1.md`. Consolidation is Tier 2.

### 2d. Name-collisions in archive (45, low priority)

`docs/archive/audit/architecture-review/vX.md` vs `docs/archive/completed/releases/vX.md` share version-number filenames but are **different doc types** (arch review vs release note) — a navigability smell, not content duplication. Optional: add a `-arch`/`-release` suffix note in the archive README. No action required.

### 2e. QP-engine cert chain (5 docs, `docs/knowledge-intelligence-engine/`)

Linear same-day supersession (`AUDIT → REAUDIT → CERTIFICATION → PRODUCTION_READINESS → FEATURE_FREEZE`), all superseded as a group by the engine's retirement (commit `02d7e1d0` repointed the planner onto frozen v1.4). Canonical = the `FEATURE_FREEZE` cert. **Owner-review before archiving** (formal certifications).

---

## 3. Archive Plan

Extend the **existing** `docs/archive/` taxonomy (`roadmap/ audit/ completed/ qa/ design/ planning/ temporary/ migration/`) — do not invent a new scheme. All moves via `git mv` (preserves history); repoint the handful of live inbound links on move.

### 3a. Docs → `docs/archive/` (28 files, Tier 1)

| From | To | Evidence |
|---|---|---|
| `docs/audits/MASTER_EXECUTION_ROADMAP.md` | `archive/roadmap/` | SUPERSEDED banner |
| `docs/audits/FABLE_FINAL_ROADMAP.md` | `archive/roadmap/` | SUPERSEDED/FOLDED banner |
| `docs/roadmap/FINAL_ROADMAP_REVIEW.md` | `archive/roadmap/` | inbound=0, point-in-time |
| `docs/roadmap/ROADMAP_FINALIZATION_REPORT.md` | `archive/roadmap/` | "PLANNING FROZEN" report |
| `docs/audits/P1_FINAL_REVIEW.md` | `archive/audit/` | inbound=0 |
| `docs/audits/FABLE_FINAL_INDEPENDENT_AUDIT_CHARTER.md` | `archive/audit/` | frozen charter, inbound=0 |
| `docs/ADAPTIVE_AI_W2_READINESS_REPORT.md` | `archive/completed/` | inbound=0 snapshot |
| `docs/PILOT_READINESS_REPORT.md` | `archive/completed/` | snapshot (refs only from archive) |
| `docs/execution/SESSION_HANDOFF.md` | `archive/temporary/` | dated handoff, superseded |
| `docs/execution/GAP_REMEDIATION_WAVE.md` | `archive/completed/` | "ALL P0+P1 CLOSED" |
| `CLEANUP_REVIEW.md` (root) | `archive/audit/` | prior cleanup audit, resolved |
| `docs/Testing/` — 10 version-tagged reports* | `archive/qa/` | build tags v16–v18, deleted staging |
| `docs/Operations/` — 3 readiness reports** | `archive/completed/` | dated 2026-06-10 snapshots |
| `docs/design/DESIGN_SYSTEM_V1.md` | `archive/design/` | superseded by v2 guide |

\* `Final-Release-Audit`, `Release-Go-Live-Audit`, `Final-Device-Readiness`, `Apple-Distribution-Audit`, `Release-Asset-Audit`, `Device-Auth-Validation-Report`, `v18.0-Autonomous-QA-Report`, `Real-User-Journeys`, `Demo-Accounts`, `Demo-School-Validation`.
\** `Customer-Readiness-Report`, `Operational-Readiness-Report`, `Production-Validation-Report`.

### 3b. Scripts → `scripts/archive/` (30 files, Tier 1)

New `scripts/archive/` for already-executed one-offs (self-labeling `*_bN_smoke.sh`, `phaseN_*`, `sprintN_*`, `pilot_v14_*`, `migrate_*.py`, `fix_providers*.py`, `backfill_*`). None are CI/Makefile-referenced (CI wires only `scripts/qa/*`). Plus 7 `qa/patrol/rerun_*.sh` → `qa/patrol/archive/`. Full list in agent evidence; keep all reusable ops/build/deploy/demo tooling at root.

### 3c. Root `reports/` (30 files) → relocate/exclude (Tier 1)

Point-in-time ERP deploy/QA run artifacts, untouched since 2026-06-13, regenerable. Options: move under `docs/archive/reports/` or add to a "generated artifacts" exclusion (§7). Resolves the confusing root-`reports/` vs `curriculum/reports/` naming collision.

### 3d. QIE internal `phase-history/` (Tier 2, within the QIE lane)

Move ~18 done-snapshots (Phase A/B yield reports, generation pilots, governed-conversion checkpoints) into `docs/question-intelligence-quality/phase-history/` — separates closed history from the ~5 live docs without leaving the lane. Do **after** adding the QIE README (§7).

### 3e. KIE engine certs (9 files) — **OWNER DECISION** before archiving

`docs/knowledge-intelligence-engine/*` cert a retired engine. Default: keep REFERENCE; archive to `docs/archive/completed/kie-qpgen/` only on owner sign-off.

---

## 4. Canonical Document Map

The one-true-version per concern (for humans and AI entry). **This map should be embedded into `PROJECT_INDEX.md`.**

| Concern | Canonical document | Status |
|---|---|---|
| Engineering standard (law) | `docs/engineering/AKSHARA_ENGINEERING_CONSTITUTION.md` | FROZEN |
| Engineering gate policy | `docs/engineering/ENGINEERING_GATE_POLICY.md` | ACTIVE |
| EOS evidence index | `docs/engineering/eos/README.md` + `EOS_RUN_LEDGER.md` | ACTIVE |
| **Forward roadmap** | `docs/roadmap/AKSHARA_CONSTITUTION_ALIGNED_MASTER_ROADMAP.md` | CANONICAL ⚠ undiscoverable |
| PRA register (execution authority) | `docs/roadmap/FINAL_EXECUTION_MASTER_ROADMAP.md` | REFERENCE (needs banner) |
| Supreme product authority | `docs/owner/AKSHARA_MASTER_PRODUCT_CONSTITUTION_v2.0.md` | CANONICAL |
| Execution "now" + journal | `docs/roadmap/NEXT_ACTIVE_WAVE.md` + `docs/execution/IMPLEMENTATION_PROGRESS.md` | ACTIVE |
| PRA authority | `docs/AKSHARA_PRODUCT_REALITY_AND_CORRECTNESS_CERTIFICATION.md` (frozen) + `docs/roadmap/PRODUCT_REALITY_CORRECTNESS_PROGRAM_TRACKER.md` | ACTIVE |
| QA program (frozen history) | `docs/FINAL_QA_MASTER_TRACKER.md` | REFERENCE |
| Design / UI-UX SSOT | `docs/design/PRODUCT_EXCELLENCE_MASTER_PLAN.md` (visual authority `VISUAL_DESIGN_SYSTEM.md`) | ACTIVE |
| Adaptive-AI design suite | `docs/design/adaptive-ai/00…10` | ACTIVE (LOCKED) |
| Curriculum-Intelligence baseline | `docs/curriculum-intelligence/README.md` + `OPUS_IMPLEMENTATION_HANDOFF.md` | FROZEN v1.0 + A1 |
| QIE (current) | `docs/question-intelligence-quality/QUESTION_PLANNING_LAYER_ROADMAP.md` (+ resume `QIE_SESSION_HANDOFF.md`) | ACTIVE (needs README + banner) |
| Product backlogs | `docs/PRODUCT_ENHANCEMENT_BACKLOG.md` (rev 5) + `docs/PRODUCT_COMMERCIAL_BACKLOG.md` | ACTIVE |
| SRS | `docs/Akshara_ERP_Master_Index_Guide.txt` + 24-part `Akshara_ERP_Master_SRS_Part_*.txt` | REFERENCE |
| Legal/compliance | all 15 in `docs/legal/` (index `README.md`) | ACTIVE — protected |
| Active-docs index | `docs/README.md` | ⚠ stale — refresh |
| Repo/AI entry point | `PROJECT_INDEX.md` | ⚠ stale — refresh (§7) |

---

## 5. Delete Candidates (with justification)

**True deletions: essentially none.** Per the "archive never delete" rule and the DO-NOT-DELETE list, the only *removals* proposed are pure duplicates and generated artifacts already covered by gitignore. Everything else is `git mv` (archive), not `rm`.

| Item | Count | Justification | Action |
|---|---:|---|---|
| Redundant `docs/archive/design/*` copies (§2a) | 9 | Byte-identical to the referenced active copies; content + history fully retained | `git rm` archive copy (dedup) |
| Tracked golden-diff PNGs `test/**/failures/*` | ~88 (6.6 MB) | Transient regenerable diffs; repo's own `.gitignore` (`test/**/failures/`) says never commit; predate the rule | `git rm --cached` (untrack, keep on disk) — already gitignore-covered |
| OS/IDE/log strays (`.DS_Store` ×3+, `flutter_01.log`, `akshara_erp.iml`, `.flutter-plugins-dependencies`) | — | Already **untracked + gitignored** | optional local `rm` only; no git action |
| `qie.db` (root, 0 bytes) | 1 | Empty residue of the retired kie.db path (commit `02d7e1d0`); already gitignored | leave (or optional local `rm`) |

**No source, test, migration, config, cert, dataset, or doc is a delete candidate.**

> Correction to interim findings: the `qdi_controls.py` / `qdi_link.py` engine files are **now tracked** (earlier flagged as at-risk — resolved). The only genuinely uncommitted code is one test, `curriculum/scripts/intelligence/kie/tests/test_qpl_certification.py` — recommend committing it with the current QPL work (owner/branch action, not a hygiene move).

---

## 6. Folder Restructuring Recommendations

1. **Introduce `scripts/archive/`** (and optionally `scripts/ops/`, `scripts/build/`, `scripts/migrations/`) — the 95-file flat `scripts/` root mixes reusable tooling with 30 consumed one-offs. Naming already signals lifecycle (`*_bN_smoke`, `phaseN_*`).
2. **Resolve the dual-`reports/` collision** — root `reports/` (committed ERP run artifacts) vs `curriculum/reports/` (local-only knowledge reports) share a name with opposite policies. Relocate root `reports/` under `docs/archive/reports/`.
3. **Add a QIE landing README** + `phase-history/` subfolder (§3d) — 133 files with no index is the biggest per-lane navigation cost.
4. **Keep `docs/archive/` as-is** — it is a model; only remove the 9 leaked design duplicates and refresh its "current roadmap" pointer.
5. **Design docs:** name `PRODUCT_EXCELLENCE_MASTER_PLAN.md` as the sole SSOT; add pointer headers to the 6 companions; archive `DESIGN_SYSTEM_V1.md`. (Tier 2 — needs ref-repointing.)
6. **Owner-decision cluster (do not auto-act):** consolidate the 4 overlapping readiness checklists (`ProductionReadinessChecklist`, `PILOT_DEPLOYMENT_CHECKLIST`, `PilotSchoolChecklist`, `StagingValidationChecklist`) + 2 deployment docs; currency-review the 4 reference inventories (`MobileScreenInventory`, `RouteInventory`, `PermissionCoverageInventory`, `SharedWidgetInventory`); confirm SRS working draft `Akshara_School_ERP_SRS_v1.txt` vs the 24-part set; decide KIE-cert archival (§3e).

---

## 7. AI Audit Optimization Recommendations

Goal: make future whole-repo audits cheaper and correct-by-default.

1. **Fix the entry-point roadmap divergence (highest ROI).** `PROJECT_INDEX.md` says `FINAL_QA_ROADMAP.md`; `PROJECT_CONTEXT.md` says `FINAL_EXECUTION_MASTER_ROADMAP.md`; the *actual* canonical is `AKSHARA_CONSTITUTION_ALIGNED_MASTER_ROADMAP.md` — linked by neither. Point both entry files at it and have `PROJECT_CONTEXT` defer to `PROJECT_INDEX`. An AI is otherwise mis-routed on hop #1.
2. **Refresh the two stale indexes.** `PROJECT_INDEX.md` (branch/date wrong; cites ~204 docs vs 399 actual active) and `docs/README.md` (zero references to the `roadmap/ strategy/ execution/ owner/` governance cluster). Embed the §4 canonical map into `PROJECT_INDEX.md`.
3. **Add supersession/redirect banners** to `FINAL_EXECUTION_MASTER_ROADMAP.md` (superseded-as-forward-plan) and `QIE_SESSION_HANDOFF.md` (points to the newer QPL roadmap) so a reader never restarts on a superseded plan.
4. **Separate GENERATED from the audit surface.** Declare these regenerable and exclude from future hygiene passes: `build/`, `node_modules/`, `coverage/`, `.venv-deploy/`, `.dart_tool/`, `tools/progress-dashboard/` (all already gitignored); plus **untrack** the 88 golden-diff PNGs and relocate root `reports/`. Tighten `curriculum/.gitignore` so the ~27 derived local-only files (`reports/*.json`, `discovery/**/*.json`, `acquisition/*.json`, `acquisition/CHECKPOINT_*.md`) stop surfacing as untracked noise (matches the owner's local-storage policy — zero data change). Add `**/.DS_Store` and `.venv-deploy/` explicitly to root `.gitignore`.
5. **Archiving shrinks the active surface.** Of ~9.2 MB of doc text, ~4.4 MB is already archived; the §3 moves park more point-in-time material, leaving a lean active-docs core an AI can load cheaply. A future full audit can then scope to *active* trees + skip the declared GENERATED/ARCHIVE set.
6. **One landing page per lane.** The archive and legal dirs have READMEs and are cheap to navigate; QIE (133 files) and the roadmap/execution governance cluster do not. Adding indexes there is where token-cost reduction concentrates.

---

## 8. Execution Tiers (Tier 1 & 2 gated per the owner-lock above)

| Tier | Status | Risk | Contents | Reversible |
|---|---|---|---|---|
| **Tier 0** | ✅ **APPLIED & KEPT** (2026-07-20) | zero (non-destructive) | index/pointer refresh (`PROJECT_INDEX`, `PROJECT_CONTEXT`, `docs/README`), supersession banners, QIE README, `.gitignore` tightening, `git rm --cached` the 88 golden diffs | yes |
| **Tier 1** | ⛔ **FROZEN** — run only after the UI/UX audit + explicit owner approval | low (relocation) | all §3a–3c `git mv` archival + remove 9 identical design dups + `scripts/archive/` + relocate root `reports/` | yes (git history) |
| **Tier 2** | ⛔ **FROZEN** — after Tier 1 | medium (needs repointing) | design-SSOT consolidation, QIE `phase-history/`, checklist consolidation | yes |
| **Owner** | ⏸ decision pending (post feature-complete) | decision required | KIE-cert archival, reference-inventory currency, SRS working-draft status, checklist merges | — |

> The 1 uncommitted test (`curriculum/.../test_qpl_certification.py`) is part of active QIE work — commit it with that lane, not as a hygiene action.

**Protected (never touched by any tier):** `docs/engineering/AKSHARA_ENGINEERING_CONSTITUTION.md`, all `supabase/migrations/*`, all `test/**` suites + golden masters, `docs/legal/*`, `docs/owner/*`, curriculum certified v1.4 dataset (local-only), all QIE knowledge/decision/evidence, roadmap history, `.github/` CI.

---

*Prepared by the Repository Hygiene & IA workstream (6-agent parallel review + orchestrator verification). Evidence artifacts: per-region agent reports. No file was modified in producing this plan.*
