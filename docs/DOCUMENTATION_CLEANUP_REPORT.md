# Akshara ERP — Documentation Cleanup Report

**Date:** 2026-06-27
**Type:** Safe, non-destructive documentation archive & reorganisation
**Scope:** Every Markdown (`.md`) and text (`.txt`) document in the repository (excluding vendored/build/`.venv`/Pods/coverage trees and one Flutter asset-placeholder README).

> **Guarantee: nothing was deleted.** Every archived file was relocated with `git mv` (history preserved). Recover any file with `git log --follow <path>` or `git mv` it back. The four untracked QA run-reports were moved with `mv` (still on disk, in the archive).

---

> ## ⟳ Addendum — 2026-07-03 reconciliation (this report is historical below this line)
>
> The 2026-06-27 cleanup below was **correct and intact but never committed**, and ~2 weeks of new
> docs drifted into the active tree afterward. On **2026-07-03** the cleanup was **finalized** (see
> the working `CLEANUP_REVIEW.md` / `CLEANUP_COMPLETION_REPORT.md` at the repo root and the new
> repo-wide index [`../PROJECT_INDEX.md`](../PROJECT_INDEX.md)). Deltas since 2026-06-27:
>
> **Kept active + newly indexed** (referenced by the live roadmap / QA tracker / EOS ledger, so
> archiving would break those links): the 12 QW/QA-R/Face-ID certifications, the Data-Reliability
> platform certification, `ATTENDANCE_AUTH_DESIGN_DECISION.md`, `PRODUCT_COMMERCIAL_BACKLOG.md`,
> `PRODUCT_ENHANCEMENT_BACKLOG.md`, `PERFORMANCE_TARGETS.md`, `BACKUP_RESTORE_RUNBOOK.md`.
>
> **Newly archived (53 items):** `still_pending.md` (superseded product audit → `archive/audit/`),
> the prior Fable UI/UX audit `audit_by_fable_phase1–4` + `final_ui_ux_master_report`
> (→ `archive/audit/fable-ui-ux-audit/`), 21 figma-era dashboard mockups (`docs/UIUX/*` →
> `archive/design/mockups-uiux/`), 4 parent-home mockups (`docs/design/mockups/` →
> `archive/design/mockups/`), the M15 visual-gap screenshots reunited with their report
> (→ `archive/audit/m15-visual-gap/`), and 5 root launch/smoke screenshots (→ `archive/qa/screenshots/`).
>
> **Counts now:** active docs 185 → **~204**; archived files 592 → **645** (see
> [`archive/README.md`](archive/README.md) § Post-2026-06-27 additions). One real link repointed
> (`PRODUCT_COMMERCIAL_BACKLOG.md` → archived `still_pending.md`); **0 broken links introduced**.
>
> **Still open (owner decision):** consolidate the `BACKUP_RESTORE_RUNBOOK.md` vs
> `Operations/Backup-Runbook.md` + `Restore-Runbook.md` overlap into one canonical runbook.

---

## 1. Documentation Cleanup Report

### What the project looked like before
`docs/` had grown to ~775 documents. **298 of them sat loose in the `docs/` root** — a flat pile mixing the current architecture/spec set with hundreds of one-time certifications, milestone/wave/batch closures, completion reports, superseded roadmaps, execution plans, audits, progress snapshots and handoffs. `PROJECT_CONTEXT.md` literally instructed every AI assistant to *"Read all documents inside the docs folder before making any decision"* — so each session loaded the entire history as if it were current. There was also an older `docs/_archive/` (178 files) whose own README pointed at roadmaps that had themselves since been superseded.

### What was done
| Action | Count |
|---|---:|
| Documents reviewed | ~775 |
| **Archived** (moved into `docs/archive/`, history preserved) | **592** |
| **Kept active** (left in place) | **~185** |
| References repointed in active docs (broken-link repair) | 84 |
| Active docs with prose updated (`AGENTS.md`, `PROJECT_CONTEXT.md`) | 2 |
| Files **deleted** | **0** |
| Broken links **introduced** by the cleanup | **0** |

A structured archive was created at **`docs/archive/`** with eight logical buckets:

| Bucket | Files | What lives here |
|---|---:|---|
| `roadmap/` | 16 | Superseded roadmaps & reconciliation snapshots |
| `qa/` | 36 | Historical QA run reports, coverage inventories, patrol artifacts |
| `audit/` | 195 | One-time audits, gap/truth/readiness reports, Red-Team records, + `architecture-review/` (153 per-version API/architecture audits) |
| `planning/` | 39 | Completed execution/build plans, strategy, backlogs, shipped specs, F-phase API plans |
| `design/` | 20 | Design notes, figma-era mockups, superseded design-system versions |
| `migration/` | 5 | F1–F5 per-phase migration notes |
| `completed/` | 257 | Certifications, completion reports, milestone/wave/batch closures, live-backend logs, + `releases/` (143 per-version release notes) |
| `temporary/` | 24 | Handoffs, weekly/overnight/cycle progress, process/orchestration notes, status snapshots |

The previous `docs/_archive/` was folded into this single archive root (its `ArchitectureReview/` set → `archive/audit/architecture-review/`; its old README preserved as `archive/completed/PRIOR_ARCHIVE_NOTE.md`). Emptied directories (`docs/Releases/`, `docs/QA/`, `docs/plans/`, `docs/figma-screens/`, `docs/_archive/`) were removed once empty.

### Classification method
Each document was classified by a combination of (a) strong filename signals (`*_CERTIFICATION`, `*_COMPLETION_REPORT`, `MILESTONE_*`, `WAVE*`, `BATCH_*`/`B<n>_*`, `LIVE_BACKEND_*`, `*_EXECUTION_PLAN`, `WEEK<n>_*`, `*_AUDIT`, `*ROADMAP*`, `F<n>_*_MIGRATION`, etc.), (b) git last-commit date, and (c) cross-checking against the current project state (`ProjectStatus.md`, the active QA program, and the Engineering Constitution). The full machine-generated move manifest and keep-list were verified for **zero destination collisions** and **zero missing sources** before execution.

### Cross-reference repair
After moving, every active document was scanned for links to relocated files. **84 references were repointed** to their new archive locations (preserving relative-path depth), e.g. `docs/Releases/v1.0-Release-Candidate.md` → `docs/archive/completed/releases/...`, `docs/Roadmap.md` → `docs/archive/roadmap/Roadmap.md`. A full broken-link sweep of all 185 active docs afterward found **0 breaks introduced by this cleanup**. The 20 remaining active→archive links are intentional history references (and now resolve correctly).

Two active docs needed prose (not just link) fixes:
- **`PROJECT_CONTEXT.md`** — the *"read all documents"* instruction was replaced with an ordered pointer to the authoritative active set (Constitution → ProjectStatus → current QA program → relevant spec) and an explicit "do not read `docs/archive/` for current decisions."
- **`AGENTS.md`** — the "Read first / create release docs / completion workflow" rules referenced now-frozen paths (`Roadmap.md`, `Releases/`, `ArchitectureReview/`, `CURSOR_WORKFLOW.md`). Updated to point at the Engineering Constitution + EOS and the current QA roadmap, with a banner noting the file is subordinate to the Constitution and that the old release process is frozen under `docs/archive/`.

### Known pre-existing issue (not introduced here, not fixed)
- `qa/agents/README.md:26` links to `../../.cursor/skills/multi-agent-coordinator/SKILL.md`, which does not exist. This is a pre-existing reference to a Cursor tooling skill (outside `docs/`), unrelated to this cleanup. Flagged for the owner; left untouched.

### Judgment calls worth knowing
- **Operations/ and Testing/ kept whole.** A few point-in-time reports inside them (e.g. `Operational-Readiness-Report.md`) are historical, but these folders are cohesive, namespaced operational runbooks/guides; splitting them for ~9 files added risk without real noise reduction.
- **Vision/ kept active.** Several "future" designs have since shipped, but `Vision/` is the forward-looking product track and reads as a roadmap, so it stays active (the one duplicate, see §4, was archived).
- **`docs/Releases/` (143) archived.** These are per-version build notes from the dev process — historical records, not day-to-day reading. Recommend a single consolidated `CHANGELOG.md` going forward (see §5).
- **Reference set kept generously.** When a doc was a *reference/spec/architecture/runbook* and its currency was uncertain, it was **kept active** rather than risk hiding a source-of-truth doc. Some of these (e.g. `AKSHARA_MASTER_FEATURE_REGISTRY` was archived as a point-in-time registry; `MobileScreenInventory`/`SharedWidgetInventory` were kept) are worth a future currency review.

---

## 2. Active Documentation Index

The authoritative entry point is now **[`docs/README.md`](README.md)** — ~185 current documents grouped into: Engineering governance, Project context, Current-phase QA program, Architecture (canonical), Governance/charter/checklists, Design system, Module/role specs, Reference inventories, SRS (source of truth), Operations runbooks, Testing guides, Product vision, Legal & compliance, Deployment/infra, and QA harness.

**Special docs kept active per requirement:** `docs/engineering/AKSHARA_ENGINEERING_CONSTITUTION.md`, the current roadmap (`docs/FINAL_QA_ROADMAP.md`), current QA (`docs/FINAL_QA_MASTER_TRACKER.md`, `docs/FINAL_QA_AUDIT.md`), all `*Architecture.md`, deployment docs (`docs/Operations/Deployment-Guide.md`, `docs/DeploymentArchitecture.md`, `deploy/akshara-vps/DEPLOYMENT.md`), and the active API/contract material.

---

## 3. Archive Index

The archive is fully indexed at **[`docs/archive/README.md`](archive/README.md)** — every bucket, its purpose, and the original path (`_was_ …`) of each relocated file. Nothing in the archive should be used for current decisions.

---

## 4. Duplicate Documents Report

| Cluster | Kept active (authoritative) | Archived | Basis |
|---|---|---|---|
| **Finance module spec** | `docs/finance.md` | `Finance_Module_Specification.md` → `archive/design/` | Overlapping near-duplicates with an identical header. `finance.md` is the **newer superset** — it adds the *AI Finance Copilot* and *Dashboard Tier* sections. The archived version only uniquely retains figma-build-era appendices (Responsive Rules / Figma File Organization / Build Checklist), which are now historical. *(Not byte-identical.)* |
| **Org Builder design** | `docs/Vision/design/Universal-Organization-Builder-v2.md` | `Universal-Organization-Builder.md` → `archive/design/` | v2 supersedes v1. |
| **Design system** | `docs/FlutterDesignSystem.md` + `docs/design/VISUAL_DESIGN_SYSTEM.md` | `DesignSystem.md`, `DESIGN_SYSTEM_V1.md`, `FigmaDesignSystemBuildGuide.md` → `archive/design/` | The implementation reference + the approved "Premium School OS" visual system are current; the v1 / figma-build-guide variants are superseded. |
| **Roadmaps** | `docs/FINAL_QA_ROADMAP.md` | 16 older roadmaps / reconciliations → `archive/roadmap/` | One current roadmap; the rest are point-in-time and closed (Module-Journey, Red-Team, Onboarding, Pilot-Sim, etc. waves all certified complete). |
| **Backup/restore** | `docs/Operations/Backup-Runbook.md` + `docs/Operations/Restore-Runbook.md` | `BACKUP_RECOVERY_ARCHITECTURE.md`, `BACKUP_RESTORE_ARCHITECTURE.md`, `BACKUP_RESTORE_RUNBOOK.md` → `archive/planning/` | The Operations runbooks are the live procedures; the docs-root variants are earlier architecture-notes. |
| **`CLAUDE_MASTER_AUDIT.md` name clash** | — (both historical) | root `CLAUDE_MASTER_AUDIT.md` → `archive/audit/CLAUDE_MASTER_AUDIT_ROOT_hardening-status.md`; `docs/CLAUDE_MASTER_AUDIT.md` → `archive/audit/CLAUDE_MASTER_AUDIT.md` | **Same name, different content** (not a true duplicate). Both archived under distinct names to preserve both. |
| **Prior `_archive/`** | new `docs/archive/` | 178 pre-existing files folded in | Single archive root; its README preserved as `archive/completed/PRIOR_ARCHIVE_NOTE.md`. |

---

## 5. Recommended Documentation Structure

The cleanup is intentionally conservative — active docs were **left in their existing locations** so no links break. The recommended long-term target below is for *future* adoption (do it as a deliberate, link-aware migration, not ad hoc).

```
docs/
├── README.md                      # Active index — the only "read me first" (✅ created)
├── engineering/                   # Constitution + EOS = highest authority (✅ exists)
│   ├── AKSHARA_ENGINEERING_CONSTITUTION.md
│   └── ENGINEERING_GATE_POLICY.md
├── status/                        # ← move ProjectStatus.md, current QA program, CHANGELOG.md
├── architecture/                  # ← move the *Architecture.md set + ClientBackendAlignment + DR plan
├── specs/                         # ← move module/role specs (HR.md, finance.md, …) + SRS/ subfolder
├── design-system/                 # ← FlutterDesignSystem.md + VISUAL_DESIGN_SYSTEM.md
├── operations/                    # (already cohesive) runbooks, pilot guides, deployment
├── testing/                       # (already cohesive) device/release testing guides
├── legal/                         # (already cohesive) compliance suite
├── vision/                        # forward-looking product tracks
├── reference/                     # RouteInventory, PermissionCoverageInventory, etc.
└── archive/                       # ✅ all historical material (this cleanup)
    ├── roadmap/  qa/  audit/  planning/  design/  migration/  completed/  temporary/
```

**Operating rules to keep it clean (and keep AI focused on current docs):**
1. **`docs/README.md` is the single entry point.** `PROJECT_CONTEXT.md` and `AGENTS.md` now point here; keep it current.
2. **AI/agents read the active tree only.** Never load `docs/archive/` for current decisions (now stated in `PROJECT_CONTEXT.md`). Consider adding `docs/archive/` to any AI-context ignore config.
3. **One living document per concern** — one roadmap (`FINAL_QA_ROADMAP.md`), one status (`ProjectStatus.md`), one tracker, one `CHANGELOG.md`. Supersede in place; don't spawn dated copies.
4. **Certifications/completions/audits are born archived.** New milestone closures go straight to `docs/archive/completed/` (or `/audit/`) — they are records, not active docs.
5. **Replace `docs/Releases/` with a single `CHANGELOG.md`** for ongoing release notes.
6. **Archive, never delete.** Use `git mv` so history follows the file.
7. **Quarterly sweep:** anything completed/superseded moves to the matching archive bucket; update both indexes.
