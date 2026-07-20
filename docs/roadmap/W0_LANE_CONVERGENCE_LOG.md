# W0 — Lane Convergence & Repository Integrity — EXECUTION LOG

**Wave:** W0 (Constitution-Aligned Master Roadmap §5) · 🔴 CRITICAL — gates every later wave.
**Branch:** `feature/qp-content-readiness` (the roadmap-defined "full ERP + QIE + web" line).
**Started:** 2026-07-20 · Autonomous Execution Mode.
**Governing rule:** current source code is the authority; extend before replace; nothing lost; EOS gate per commit.

---

## STATUS SUMMARY

| Sub-wave | Scope | State |
|---|---|---|
| **W0.1 — QIE/continuity preservation** | Commit uncommitted code; fix `.gitignore` code-vs-data bug; back up frozen foundation off-repo | ✅ **code-preservation DONE** · ⏳ off-repo backup **owner-gated** |
| **W0.2 — Trunk reconciliation** | Merge PRA + DRP/red-team/security + QIE into ONE trunk; reconcile migration series | 👤 **owner-gated** (deployed-head confirm + merge authorization) — analysis done |
| **W0.3 — Baseline + prune** | Re-point `main`/`production`; triage `worktree-agent-*` | 👤 **owner-gated** (prune decisions) — analysis done |

---

## W0.1 — CONTINUITY PRESERVATION ✅ (code) — COMPLETE

**Problem (worse than the roadmap documented).** A repository-integrity audit of the working tree found that a *large* body of genuine, non-regenerable work existed **only on local disk** — untracked or silently git-ignored — and would have been **irreversibly destroyed by a single `git clean`** in this shared worktree:

| At-risk work | Before | Root cause |
|---|---|---|
| QIE Decision-C code (`kie/qie/knowledge/`, 13 files) | silently git-ignored | unanchored `knowledge/` rule matched the ENGINE dir |
| QIE Decision-C code (`kie/qie/factory/`, 12 files) + tests | untracked | never committed |
| **Entire web ERP lane** (`web/`, 190 files) | **untracked on _every_ ref, 0 commits in history** | never committed anywhere |
| **The Product Constitution** (`docs/owner/…CONSTITUTION_v2.0.md`) | untracked | never committed |
| **The Constitution-Aligned Roadmap** itself | untracked | never committed |
| Curriculum acquisition/discovery/reports ENGINE code (44 files) | untracked | never committed |
| 15 further authoritative docs (PRA/PRC/SOP/audits/QIE) | untracked | never committed |

**Fix — 6 surgical commits (`c5be286d`..`733a892a`), 294 files, +50,194 lines.** Code / schemas / tests / docs only; **zero derived data**, honoring the LOCKED curriculum local-storage decision (*Git = engine/tests/code; derived data + databases = LOCAL ONLY*).

| Commit | Content |
|---|---|
| `c5be286d` | `.gitignore` hardening: anchor `knowledge/`→`/knowledge/` (data dir only); ignore `node_modules/`, `*.db`, `*.tsbuildinfo` |
| `b80adf67` | QIE Decision-C code (`knowledge/`+`factory/`+SQL schemas), 30 files, +6,052 |
| `7e689ef2` | Web ERP lane (React+Vite+TS source), 190 files, +19,149 — first commit to history |
| `f51ce554` | Curriculum acquisition/discovery/reports/staging engine code, 44 files, +10,022 |
| `689ac68c` | Authoritative docs incl. **Constitution + this Roadmap**, 26 files, +14,798 |
| `733a892a` | Last QIE test |

**Evidence:**
- ✅ **Zero genuine code untracked** after preservation (`git status` shows only local-only derived data: `curriculum/discovery/*.json`, `curriculum/reports/*.json`, acquisition checkpoints, `*.db` — all correctly local).
- ✅ **QIE suite green on the committed state: 696 tests OK** (`python -m unittest discover -s kie/tests`, 47s; only benign sqlite ResourceWarnings).
- ✅ Decision-C code compiles clean (`py_compile`); its direct tests pass (44).
- ✅ **Security:** no `.env`/keys/PEM/hardcoded secrets committed (only `web/.env.example`, a placeholder template).
- ✅ **Foundation untouched:** KIE v1.4 (2,023 concepts, `e3a146f3…`) not mutated; `kie.db`/`qie.db` stay LOCAL.

**Remaining W0.1 item (owner-gated):** back up the frozen `kie.db` + v1.4 freeze package to an **owner-approved off-repo location** (3-2-1). Until then the frozen foundation is *not reproducible from git alone* — the databases are deliberately local, so a git commit does NOT protect them. **This is the only open continuity risk.**

---

## W0.2 / W0.3 — CONVERGENCE ANALYSIS (read-only; awaiting owner authorization)

Divergence measured from current code (not memory), 2026-07-20:

| Branch | vs current trunk | Role | Migration head |
|---|---|---|---|
| `feature/qp-content-readiness` *(current)* | — (base) | full ERP + QIE + web | `…20260876` (AI) |
| `feature/erp-pra-remediation` | +14 (disjoint areas → **clean merge**) | 117 PRA fixes (all 24 P0s) | `…20260900000015–019` |
| `feature/data-reliability-platform` | **+136 / diverged** (overlapping backend) | red-team R1–7 + P5 security + auth-RLS lockdown — **DEPLOYED TO LIVE PILOT** | `…20260877–897` |
| `main` | **+738 behind** | stale | — |
| `production` | **+830 behind** | stale | — |
| `worktree-agent-*` ×4 | +1 each | UX-refactor / education-CI single commits | — |

**Findings that shape the merge:**
1. Migration ranges **do not numerically collide** (`≤876` < `877–897` < `900000015–019`) → orderable into one monotonic head, but DRP and PRA both touch backend files → **content conflicts expected**.
2. The **deployed branch is `data-reliability-platform`, not the current trunk** → the direction of convergence (which line becomes canonical base) is a genuine architectural choice, not a mechanical one.
3. A bad DRP reconciliation could **resurrect a fixed P0 or drop a security fix** (roadmap risk) → must merge under worktree isolation + full regression + per-P0 re-verification, and requires the **owner-confirmed live deployed head** to reconcile safely.

**Recommended convergence approach (for owner approval):** reconcile in an **isolated worktree**; (a) merge `erp-pra-remediation` (clean); (b) reconcile-merge `data-reliability-platform` resolving backend/migration conflicts with a per-P0 + per-security-fix verification table; (c) run full regression (deno + flutter + goldens + this QIE suite) before declaring canonical; (d) only then re-point `main`/`production` (or cut a fresh `release/*`).

---

## OWNER DECISION BATCH #1 (roadmap §7 — "highest priority; unblocks everything")

1. **Off-repo backup location** for `kie.db` + v1.4 freeze package (closes the last W0.1 continuity risk).
2. **Confirm the live deployed VPS head** (which commit is actually serving the pilot) — required before any DRP reconciliation.
3. **Authorize the W0.2 reconciliation merge** and its **direction** (base = current trunk, or the deployed DRP line?) — high-blast-radius; to run under worktree isolation with full regression.
4. **W0.3 prune decisions:** keep/cherry-pick vs. prune the 4 `worktree-agent-*` branches and the stale `codex-wave5`/`m15-theme`/`scope-trim`/`wip-b7` lines — each needs a recorded decision.

*Until #2–#4 are decided, W0.2/W0.3 do not proceed. W0.1 code-preservation is complete and needs no further owner input; #1 closes its off-repo tail.*
