# Akshara ERP — Documentation Cleanup Review

**Type:** Audit & reconciliation only — **no files were moved, renamed, deleted, or committed.**
**Reviewed:** working tree at branch `feature/data-reliability-platform` (HEAD `68f15cb`).
**Purpose:** Verify the previously-executed documentation cleanup and determine what remains
to be done before a final independent Fable audit. This report is an input for the owner;
**no cleanup action has been taken. Awaiting explicit authorization.**

---

## 0. Executive verdict

| Question asked | Verdict |
|---|---|
| 1. Is the previous cleanup correct & complete? | **Correct, high-quality — but NOT finalized.** The reorg is sound and intact *in the working tree*, but it was **never committed**, and ~2 weeks of new docs have drifted in un-indexed. |
| 2. Which post-cleanup docs stay active? | The certifications (live QA evidence), the frozen decision/backlog SoT docs, and the Data-Reliability platform cluster. **18 files** — see §3. |
| 3. Which post-cleanup docs move to archive? | `still_pending.md`, the prior Fable UI/UX audit set, old UIUX mockups, m15 visual-gap screenshots, root screenshot artifacts. **~6 items/dirs** — see §6. |
| 4. Any active duplicates / obsolete docs? | One real duplicate cluster (`BACKUP_RESTORE_RUNBOOK.md` vs the Operations split runbooks); `still_pending.md` obsolete; prior Fable audits obsolete-for-active. No H1-title collisions otherwise. See §4–§5. |
| 5. Do `README.md` / `DOCUMENTATION_CLEANUP_REPORT.md` need updating? | **Yes, both.** The index omits ~18 current docs; the report's counts are stale and predate the newcomers. See §5. |
| 6. Is the structure optimal for a Fable audit? | **Not yet.** It becomes optimal only after (a) the work is **committed**, (b) the index is refreshed, (c) a single root `PROJECT_INDEX.md` is added, and (d) root clutter is archived. See §7. |

> 🔴 **The single most important finding is a git-state risk, not a filing risk** — see [§8, Risk R1](#r1--critical-the-entire-cleanup--governance-layer-is-uncommitted). The cleanup, the Engineering Constitution, the EOS gate, `CLAUDE.md`, and the archive **exist only in the uncommitted working tree.** A fresh clone for the audit would see the *old* flat structure and would be **missing the Constitution and EOS entirely.**

---

## 1. Current documentation structure

### 1a. What the prior cleanup produced (verified intact)
The previous pass (dated **2026-06-27**, per `docs/DOCUMENTATION_CLEANUP_REPORT.md`) relocated
**592 documents** into a structured `docs/archive/` and left **~185** active. I independently
verified the archive: **593 files, 0 empty, bucket counts exactly match the report's claims.**

```
docs/archive/                      593 files total (integrity: OK, 0 empty)
├── audit/         195   (incl. architecture-review/ = 153 per-version API/arch audits)
├── completed/     257   (incl. releases/ = 143 per-version release notes; certs, closures)
├── planning/       39   (completed execution/build plans, shipped specs)
├── qa/             36   (historical QA run reports, coverage/patrol artifacts)
├── temporary/      24   (handoffs, progress snapshots, orchestration notes)
├── design/         20   (superseded design-system versions, figma-era notes)
├── roadmap/        16   (superseded roadmaps & reconciliations)
├── migration/       5   (F1–F5 per-phase migration notes)
└── README.md            (28 KB manifest: 296 per-file `_was_` annotations + bulk-set summaries)
```

### 1b. Current ACTIVE tree (what an auditor would read)
```
<repo root>
├── CLAUDE.md ⚠untracked      AGENTS.md      PROJECT_CONTEXT.md   IDEAS_BACKLOG.md
├── still_pending.md (66 KB, superseded)     + 5 root screenshot PNGs, flutter_01.log
└── docs/                     209 active .md/.txt (excl. archive)
    ├── (root)                69 .md + 26 .txt SRS parts
    ├── engineering/          13   ⚠ Constitution + EOS + gate policy = UNTRACKED
    ├── Operations/           35   runbooks, pilot guides, workflows
    ├── Testing/              28   device/release testing guides
    ├── Vision/               16   forward product tracks (Assessment-Intelligence ⚠untracked)
    ├── legal/                15   compliance suite
    ├── design/                6   VISUAL_DESIGN_SYSTEM + 5 prior-Fable-audit files
    ├── TechnicalDebt/         1   TD-P0-01
    ├── UIUX/                 21 PNG dashboard mockups (Jun 12, unreferenced)
    └── audit/m15-visual-gap/ 17 screenshot files (historical visual-gap audit)
```

---

## 2. Source of Truth (SoT) documents

These are the authoritative, current documents. **All must stay active and be committed.**

| Domain | Source of Truth | Tracked? |
|---|---|---|
| Engineering law | `docs/engineering/AKSHARA_ENGINEERING_CONSTITUTION.md` | 🔴 **UNTRACKED** |
| Engineering gate | `docs/engineering/ENGINEERING_GATE_POLICY.md`, `docs/engineering/eos/*` | 🔴 **UNTRACKED** |
| AI/agent instructions | `CLAUDE.md`, `AGENTS.md`, `PROJECT_CONTEXT.md` | `CLAUDE.md` 🔴 untracked; other two tracked |
| Active doc index | `docs/README.md` | 🔴 **UNTRACKED** |
| Current roadmap | `docs/FINAL_QA_ROADMAP.md` | tracked |
| Current QA program | `docs/FINAL_QA_MASTER_TRACKER.md`, `docs/FINAL_QA_AUDIT.md` | tracked |
| Product backlog (commercial) | `docs/PRODUCT_COMMERCIAL_BACKLOG.md` | tracked |
| Product backlog (enhancement, 🔒 rev 5) | `docs/PRODUCT_ENHANCEMENT_BACKLOG.md` | tracked |
| Architecture canon | `docs/*Architecture.md` (Auth, Backend, Database, RBAC, Tenant, Audit, Technical, Deployment) + `ClientBackendAlignment.md` + `DEPLOYMENT_MODEL_AND_DR_PLAN.md` | tracked |
| Attendance-auth decision (frozen) | `docs/ATTENDANCE_AUTH_DESIGN_DECISION.md` | tracked |
| Assessment Intelligence (🔒 v3.0) | `docs/Vision/design/Assessment-Intelligence-Platform.md` | 🔴 **UNTRACKED** |
| Current-phase platform | `docs/DATA_RELIABILITY_PLATFORM_DESIGN.md` + `_PHASE0_PROGRESS.md` + `_CERTIFICATION.md` | tracked |
| Module/role specs | `docs/{Academic,Admissions,finance,HR,Parent,Teacher,Student,StudentSIS,Transport,…}.md` | tracked |
| Design system | `docs/FlutterDesignSystem.md`, `docs/design/VISUAL_DESIGN_SYSTEM.md` | tracked |
| SRS (source of truth) | `docs/Akshara_ERP_Master_SRS_Part_*.txt` (26 parts) | tracked |
| Legal/compliance | `docs/legal/*` (15) | tracked |
| Certifications (live evidence) | `docs/QW{1..8}_*_CERTIFICATION.md`, `QA_R_008_*`, `STAFF_FACE_ID_*` | tracked |

---

## 3. New documents since the previous cleanup (2026-06-28 → 07-01)

Twenty `docs/`-root files exist that are **not** listed in the active `docs/README.md` index
(the index predates them). Classified below. **All are legitimately active** except where noted.

### 3a. Certifications — KEEP ACTIVE, add to index
These are QA-wave / security / feature certifications created 06-28 → 07-01. **Critically, they
are cross-referenced as current evidence by the live roadmap, QA tracker, and EOS ledger**
(verified: `FINAL_QA_ROADMAP.md`, `FINAL_QA_MASTER_TRACKER.md`, `engineering/eos/EOS_RUN_LEDGER.md`,
`PRODUCT_COMMERCIAL_BACKLOG.md` all link to them). **Archiving them would break roadmap/tracker
links** — so they must remain active and simply be indexed.

- `QW1_CI_ENFORCEMENT_CERTIFICATION.md`
- `QW1_COMPLETION_CERTIFICATION.md`
- `QW1_PERSONA_RBAC_MONEY_CERTIFICATION.md`
- `QW2_COMPLETION_CERTIFICATION.md`
- `QW3_COMPLETION_CERTIFICATION.md`
- `QW4_BACKEND_API_CERTIFICATION.md`
- `QW5_COMPLETION_CERTIFICATION.md`
- `QW6_COMPLETION_CERTIFICATION.md`
- `QW7_COMPLETION_CERTIFICATION.md`
- `QW8_COMPLETION_CERTIFICATION.md`
- `QA_R_008_SECURITY_CERTIFICATION.md`
- `STAFF_FACE_ID_ATTENDANCE_CERTIFICATION.md`
- `DATA_RELIABILITY_PLATFORM_CERTIFICATION.md` *(current working-branch cluster)*

> Note: the prior cleanup's own rule #4 ("certifications are born archived") argues for moving
> these to `archive/completed/`. **I recommend against it for this set** — they are wired into the
> live roadmap/tracker as active evidence, and the owner rule "certifications are the project's
> source of truth" applies. Archiving them now would either break roadmap links or force edits to
> the roadmap (which is explicitly out of scope). Keep active; index them; apply "born-archived"
> only to *future* closures.

### 3b. Decision records & backlogs — KEEP ACTIVE, add to index
- `ATTENDANCE_AUTH_DESIGN_DECISION.md` — FINAL frozen SSOT (GPS + anti-mock + live-camera face auth).
- `PRODUCT_COMMERCIAL_BACKLOG.md` — reconciled SoT (5 queues; supersedes `still_pending.md`).
- `PRODUCT_ENHANCEMENT_BACKLOG.md` — 🔒 FROZEN rev 5, single source of truth (~142 IDs).
- `PERFORMANCE_TARGETS.md` — performance budget reference.
- `DATA_RELIABILITY_PLATFORM_DESIGN.md`, `_PHASE0_PROGRESS.md` — already indexed; keep.

### 3c. Ambiguous — see Duplicates (§4)
- `BACKUP_RESTORE_RUNBOOK.md` (06-30, 127 lines) — overlaps the Operations split runbooks.

### 3d. Cleanup artifacts (keep)
- `docs/README.md`, `docs/DOCUMENTATION_CLEANUP_REPORT.md` — the prior cleanup's index & report.

---

## 4. Duplicates

### 4a. New, unresolved duplicate cluster
| Cluster | Candidates | Assessment |
|---|---|---|
| **Backup/Restore runbook** | `docs/BACKUP_RESTORE_RUNBOOK.md` (root, 127 ln, 06-30) **vs** `docs/Operations/Backup-Runbook.md` (49 ln) + `docs/Operations/Restore-Runbook.md` (61 ln) | Overlapping scope (operator DR procedure). Not byte-identical. The prior cleanup had archived an *older* `BACKUP_RESTORE_RUNBOOK.md` to `archive/planning/` and declared the Operations split "the live procedures"; a **newer, longer** consolidated file then reappeared at root. **Owner decision needed:** keep the consolidated root runbook *or* the Operations split as canonical — not both. **Do not auto-merge** (would be rewriting a runbook, out of scope). |

### 4b. Already-resolved duplicates (from the prior pass — still valid)
Documented in `DOCUMENTATION_CLEANUP_REPORT.md §4` and confirmed still correct: `finance.md`
(kept) vs `Finance_Module_Specification.md` (archived); Org-Builder v2 (kept) vs v1 (archived);
design-system v-current (kept) vs `DesignSystem.md`/`DESIGN_SYSTEM_V1.md`/figma-build-guide
(archived); one current roadmap vs 16 archived; the `CLAUDE_MASTER_AUDIT.md` name-clash (both
archived under distinct names).

### 4c. No H1-title collisions
A scan of all 209 active docs for duplicate top-level (`# `) headings found **none**.

---

## 5. Obsolete documents (in the active tree)

| Doc | Why obsolete | Referenced by (active)? |
|---|---|---|
| `still_pending.md` (root, 66 KB) | Self-declared **"RECONCILED 2026-06-30 → `PRODUCT_COMMERCIAL_BACKLOG.md` … read-only INPUT, do not re-file."** Superseded. | Yes — `FINAL_QA_ROADMAP.md` (1 history link), `PRODUCT_COMMERCIAL_BACKLOG.md`, 2 QW certs. Archive **with** the history link preserved/repointed. |
| `docs/design/audit_by_fable_phase{1..4}.md` + `final_ui_ux_master_report.md` | A **completed prior Fable UI/UX audit round**. Historical; only self-referencing. Superseded by the *upcoming* independent Fable audit. | Only each other. Safe to archive to `archive/audit/`. |
| `docs/UIUX/*.png` (21) | Figma-era dashboard mockups (Jun 12). Unreferenced by any active doc. | No. Low token cost (images) but clutters active tree. |
| `docs/audit/m15-visual-gap/` (17 screenshots) | Point-in-time visual-gap audit artifact. | No. Historical. |
| `docs/design/mockups/` (parent_home html/png ×4) | Design mockup artifacts. | Verify before moving; likely archivable with design. |
| Root: `flutter_01.log`, `launch_*.png`, `smoke_*.png` (1 log + 5 PNG) | Transient build/smoke artifacts sitting at repo root. | No. `flutter_01.log` is untracked (gitignore/remove); PNGs are tracked (move to an artifacts/archive dir). |

### Stale-index / report drift (needs updating, per Q5)
- **`docs/README.md`** — lists **185** active docs; **omits ~18 current docs** (§3a/§3b) and the
  design-system/decision newcomers. An auditor using it as the map would miss current
  certs/decisions. **Must be refreshed** (add the 18; note the new duplicate cluster).
- **`docs/DOCUMENTATION_CLEANUP_REPORT.md`** — dated 2026-06-27; counts (592 archived / 185 active
  / 84 links) predate all newcomers and the commit gap. **Update the counts and add a "post-06-27
  drift reconciled" note**, or supersede it with the new `CLEANUP_REPORT.md` produced by the
  authorized cleanup (recommended: keep the historical report, add a short addendum + point to the
  new report).

---

## 6. Recommended archive actions *(proposals only — awaiting authorization)*

Ordered by priority. Nothing below has been executed.

**P0 — finalize what exists (prerequisite for everything):**
1. **Commit the uncommitted reorg + governance layer** (see Risk R1). Use `git add -A` so git
   records the 585 doc moves as renames (history preserved) *and* captures the currently-untracked
   Constitution, EOS, `CLAUDE.md`, `docs/README.md`, archive, and `Assessment-Intelligence-Platform.md`.
   *Recommend a single, well-messaged commit — but only on your explicit go-ahead.*

**P1 — reconcile the index (no file moves):**
2. Add the 18 active newcomers (§3a/§3b) to `docs/README.md` under a new
   **"Certifications (current QA evidence)"** section + the decision/backlog entries.
3. Refresh `DOCUMENTATION_CLEANUP_REPORT.md` counts / add drift addendum (Q5).

**P2 — archive the genuinely-historical newcomers (link-safe moves):**
4. `still_pending.md` → `archive/audit/` (or `planning/`); repoint the 3 non-roadmap links; annotate
   the single `FINAL_QA_ROADMAP.md` reference as a history link (**flag:** touches a roadmap file's
   link text only — no scope/decision change).
5. `docs/design/audit_by_fable_*.md` + `final_ui_ux_master_report.md` → `archive/audit/`.
6. `docs/UIUX/` (21 PNG) → `archive/design/mockups-uiux/`.
7. `docs/audit/m15-visual-gap/` → `archive/audit/`.
8. `docs/design/mockups/` → `archive/design/` (after confirming no active reference).
9. Root artifacts: `git rm --cached`/gitignore `flutter_01.log`; move `launch_*.png`/`smoke_*.png`
   to `archive/` (or a `reports/screenshots/` dir).

**P3 — owner decision, then act:**
10. Resolve the `BACKUP_RESTORE_RUNBOOK` duplicate (§4a): pick canonical, archive the other.

**P4 — deliverables the cleanup phase called for:**
11. Create root **`PROJECT_INDEX.md`** (project structure + SoT + roadmaps + design + engineering
    standards + decision records + archive map) as the auditor's single "start here".
12. Create **`CLEANUP_REPORT.md`** documenting what the authorized pass actually did.

---

## 7. Recommended active structure

For the audit, the current **flat-but-indexed** `docs/` + segregated `docs/archive/` split is
**adequate** — *provided* it is committed and re-indexed. The prior report's §5 target
(`status/`, `architecture/`, `specs/`, `design-system/`, `reference/` subfolders) is a good
long-term goal but is a **link-heavy migration**; do it deliberately *after* the audit, not as
part of audit prep (moving 60+ root docs now risks new broken links for marginal benefit).

Minimal audit-ready target:
```
<root>
├── PROJECT_INDEX.md          ← NEW: single start-here (code + docs + SoT + archive map)
├── CLEANUP_REPORT.md         ← NEW: record of the authorized cleanup
├── CLAUDE.md  AGENTS.md  PROJECT_CONTEXT.md  IDEAS_BACKLOG.md   (governance/context; commit CLAUDE.md)
└── docs/
    ├── README.md             ← refreshed active index (185 → ~203)
    ├── engineering/          ← Constitution + EOS (COMMIT — highest authority)
    ├── (root specs, architecture, certs, decisions, backlogs, SRS)   ← current SoT, kept in place
    ├── Operations/ Testing/ Vision/ legal/ design/ TechnicalDebt/     ← cohesive, kept
    └── archive/              ← all historical material (593 files), never read for current work
```
Root clutter (`still_pending.md`, PNG/log artifacts, `UIUX/`, `m15-visual-gap/`) archived per §6.

---

## 8. Risks

### R1 — 🔴 CRITICAL: the entire cleanup + governance layer is UNCOMMITTED
- **Fact:** HEAD still tracks the **old flat structure** (root doc copies + old `CLAUDE_MASTER_AUDIT.md`).
  The 2026-06-27 reorg lives **only in the working tree** as **585 unstaged deletions + 592 untracked
  archive files**. Additionally, these high-value files are **untracked (never committed):**
  `docs/engineering/AKSHARA_ENGINEERING_CONSTITUTION.md`, `ENGINEERING_GATE_POLICY.md`, the whole
  `docs/engineering/eos/` set, `CLAUDE.md`, `docs/README.md`, `docs/DOCUMENTATION_CLEANUP_REPORT.md`,
  `docs/archive/README.md`, `docs/Vision/design/Assessment-Intelligence-Platform.md`, the `.claude/`
  skills/commands, and the prior Fable-audit design files.
- **Impact:** A fresh clone / `git checkout .` / `git reset --hard` / CI checkout for the **independent
  Fable audit would show the OLD messy flat `docs/` and would be MISSING the Engineering Constitution,
  the EOS gate, `CLAUDE.md`, and the archive entirely.** The cleanup is invisible until committed, and
  a single stray reset destroys ~1,200 files of uncommitted work.
- **Mitigation:** Commit before the audit (P0 above). This is the top priority; everything else is
  cosmetic by comparison.

### R2 — 🟠 Index drift misleads the auditor
`docs/README.md` (the declared "authoritative entry point") omits ~18 current docs, including every
QW/security/Face-ID certification. An auditor trusting the index as the map under-samples current
evidence. Mitigate via P1.

### R3 — 🟠 Archiving roadmap-referenced files can break the roadmap
The QW certs, `QA_R_008`, `STAFF_FACE_ID`, and `still_pending.md` are linked from
`FINAL_QA_ROADMAP.md` / `FINAL_QA_MASTER_TRACKER.md` / `EOS_RUN_LEDGER.md`. Per the "do not change
any roadmap" rule: **keep the certs active** (do not archive), and for `still_pending.md` repoint only
non-roadmap links + annotate (don't remove) the single roadmap history reference.

### R4 — 🟡 Unresolved backup/restore duplication (§4a) — needs an owner call.

### R5 — 🟡 Root-level clutter inflates AI context/token load
`still_pending.md` (66 KB, superseded), plus PNG/log artifacts, sit at repo root where sessions and
the auditor pick them up first — the exact overhead this cleanup phase aims to cut. Archive per §6.

### R6 — 🟢 Archive integrity: verified good
593 files, 0 empty, bucket counts match the report, sampled moves confirmed present in the archive.
The archive `README.md` annotates 296 files individually and **summarizes** (does not per-file list)
the two bulk sets `architecture-review/` (153) and `releases/` (143) — acceptable, but note it if a
per-file archive manifest is expected.

---

## 9. What I did NOT do (as instructed)
No files were **moved, renamed, deleted, or committed.** No roadmap, report, or spec was edited.
The only file created is **this review** (`CLEANUP_REVIEW.md`). All actions in §6 are proposals held
for your explicit authorization.

**On your go-ahead, the recommended order is:** P0 (commit) → P1 (re-index) → P2 (archive historical)
→ P3 (backup-runbook decision) → P4 (`PROJECT_INDEX.md` + `CLEANUP_REPORT.md`).
