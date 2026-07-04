# Akshara ERP — Documentation & Roadmap Integrity Audit

**Auditor:** Fable (independent) · **Date:** 2026-07-03 · **HEAD:** `68f15cb`
**Scope:** documentation drift, roadmap drift, the uncommitted cleanup, source-of-truth coherence.
**Confidence:** High.

---

## 1. Executive summary

1. **Documentation is unusually voluminous and, in places, unusually honest** — the QW certs and backlogs candidly flag what is *not* done. This is a real cultural strength. But the sheer volume (~204 active + 645 archived docs) has produced measurable drift between the docs and the code.
2. **`docs/ProjectStatus.md` is materially STALE and misleading.** It is dated "June 2026," pinned to HEAD `42b7018`, and lists Admissions/Finance/HR/Transport/SIS/etc. as "**not started in Flutter**" — yet the repo is at `68f15cb` (2026-07-03) with dozens of *completed* module client+backend waves for exactly those modules. A reader trusting ProjectStatus would badly misjudge the project.
3. **A large documentation cleanup sits UNCOMMITTED in the working tree** — **602 doc deletions (moves to archive) + 208 untracked new files + 31 renames**, none committed (HEAD is "identity cluster complete," unrelated). The repo is in a half-reorganized state where PROJECT_INDEX.md, docs/README.md, and CLAUDE.md themselves are untracked. This is fragile: a stray `git checkout`/`git clean` could lose the reorg, and the "single start-here" files aren't yet in version control.
4. **The active roadmap (`FINAL_QA_ROADMAP.md`) no longer matches the actual execution order.** It sequences Phase B (live-VPS → GA) *before* Phase C (product enhancements). But the recent commits + the owner's re-ordering (memory: "roadmap gaps → Fable UI/UX audit → UI improvements → Adaptive AI → ONE Global Red Team → fix → Pilot → Prod Cert") show Phase-C-style module work happening **pre-GA**, and GA/pilot pushed later. The document wasn't updated to reflect the verbal re-order.
5. **`TD-P0-01-RLS-Enforcement.md` is stale** (says Finance/SIS RLS not started; actually enforced across 124 files — DB-9).
6. **Several "universal/complete/certified" claims overstate reality** (idempotency, row_version, 237 Verified, GA-readiness) — catalogued in the Engineering, Reliability, and QA-integrity audits. The pattern is *linguistic optimism*, not fabrication.

---

## 2. Findings

| ID | Sev | Finding | Evidence | Recommendation |
|---|---|---|---|---|
| DOC-1 | **P1** | `ProjectStatus.md` is stale (June 2026 / HEAD `42b7018`) and says core modules are "not started" though they're shipped | `docs/ProjectStatus.md:3-5,174-192` vs git log | Rewrite to reflect HEAD `68f15cb`: modules built, QA local-complete, GA blocked on Track B. It is a source-of-truth doc — staleness here is high-impact. |
| DOC-2 | **P1** | ~600-file documentation cleanup + the start-here files (PROJECT_INDEX/README/CLAUDE) are uncommitted/untracked | `git status` (602 D + 208 ?? + 31 R) | Commit the cleanup as one reviewed change (or revert it) so the repo has a coherent, version-controlled doc tree. Do not leave the map uncommitted. |
| DOC-3 | **P1** | The active roadmap's Phase B→C→D sequence contradicts the actual (owner-re-ordered) execution order | `FINAL_QA_ROADMAP.md` §"NEXT-GENERATION ROADMAP" vs recent commits + owner memory | Update the roadmap to the real sequence (this audit's rebuilt roadmap does that) — a roadmap that doesn't match execution can't govern it. |
| DOC-4 | **P1** | "Universal idempotency" / "universal row_version conflict" / "237 Verified" / "PRODUCTION CERTIFIED" overstate the shipped reality | Reliability REL-1, Engineering ENG-1, QA-integrity §2/§5 | Re-scope the claims to match evidence; add an evidence-grade column to the tracker (QA-1). |
| DOC-5 | **P2** | `TD-P0-01-RLS-Enforcement.md` understates shipped RLS | DB-9 | Update the debt doc; re-scope residual to auth plumbing. |
| DOC-6 | **P2** | `AuditArchitecture.md` documents retention/partitioning/hash-chain that isn't implemented | DB-6 | Correct the doc or build the capability; don't let architecture docs describe unbuilt features as present. |
| DOC-7 | **P2** | Backup-runbook duplication (`BACKUP_RESTORE_RUNBOOK.md` vs `Operations/Backup-Runbook.md` + `Restore-Runbook.md`) flagged as a "pending owner decision" and still unresolved | `docs/README.md:66` | Consolidate to one canonical runbook. |
| DOC-8 | **P3** | 14 overlapping product surfaces catalogued but the Consolidation wave is still "owner-review, not scheduled" | `PRODUCT_COMMERCIAL_BACKLOG.md` Consolidation | Owner go/no-go on QW-Consolidation (see master report §strategy). |

---

## 3. Source-of-truth coherence

The intended hierarchy (Frozen Owner Decisions → Constitution → PROJECT_INDEX → Roadmaps → Product docs → Implementation → Tests → Archive) is well-designed and mostly followed. The breaks are:
- **ProjectStatus (a top-of-hierarchy status doc) contradicts the implementation** (DOC-1).
- **The roadmap (hierarchy #4) contradicts the actual execution order** (DOC-3).
- **Two architecture/debt docs contradict the implementation** (DB-6/DB-9).
- **The hierarchy's entry points are uncommitted** (DOC-2).

None of these are fatal, but together they mean a new engineer or an investor doing diligence would draw materially wrong conclusions from the top-level docs — which is exactly what documentation is supposed to prevent.

## 4. Genuine strengths

- **Radical honesty in the QA certs and backlogs** — the project documents its own gaps (staged legs, "won't-build," English-first pivot, deferred items) rather than hiding them. Rare and valuable.
- **A coherent, well-indexed doc architecture** with a clear active/archive split and a single-source-of-truth discipline (when followed).
- **Frozen owner decisions are clearly marked and traceable** (O1–O10, identity freeze, attendance-auth decision).
- **The EOS gate + Constitution give the project a real engineering standard** — the enforcement is imperfect (QA audit), but the *standard* is genuinely strong.

## 5. Recommendation

Before pilot, spend a short, focused **"documentation truth" pass**: (1) rewrite ProjectStatus to reality, (2) commit the cleanup, (3) reconcile the roadmap to the real sequence, (4) fix the 3 stale architecture/debt docs, (5) add the tracker evidence-grade column. This is low-effort, high-trust work — it makes every downstream decision (and this audit) rest on docs that match the code.
