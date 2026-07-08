# Agent Registry (standing — consult BEFORE spawning; recovery-first)

**Policy (owner 2026-07-08):** on every resume after a session limit / model restart / context
reset / manual interruption / app restart, the **FIRST action is agent recovery** — discover
existing agents/worktrees/tasks, determine state, **resume/reconnect a recoverable one rather
than spawning a duplicate.** Only create a new agent when recovery is impossible or the prior one
permanently terminated. **Always prefer recovery over recreation.** Consult this registry first.

**Worktree policy (owner 2026-07-08):** every worktree implementation agent MUST create the
worktree from the **current feature-branch tip** (`feature/data-reliability-platform`), NEVER from
`main`, and **verify the base commit before implementation starts**. (CI-C8's agent reset onto the
tip → clean integrate; the ERP AsyncValue agent used `main` → un-integrable → discarded.)

**Model policy:** smallest capable model per task ([[model-tier-selection-preference]]) — haiku
(downloads/verify/monitor/dashboard/manifest/deterministic) · sonnet (additive impl / mechanical
refactor / analysis) · opus (deep/complex/architecture/debug).

**Agent Context Preservation (owner 2026-07-08):** when an agent finishes successfully, do NOT
immediately destroy its execution context. Keep it available until (a) its work is integrated,
(b) verification is complete, and (c) no follow-up is required. If a completed agent can answer
questions about its own work (or fix a review finding) more efficiently than spawning a new one,
**reuse it** (SendMessage its ID). Destroy/clean up (e.g. `git worktree remove`) only after it is
no longer useful.

**Resume From Existing State (owner 2026-07-08):** on every resume, NEVER rebuild state from
memory alone. Inspect and treat as source of truth: this Registry · the acquisition dashboard/
manifests (`curriculum/acquisition/*`) · progress/activity artifacts · existing worktrees
(`git worktree list`) · local artifacts (`curriculum/resources/**`) · previous agent reports.
Reconcile against them FIRST, then continue.

---

## Active / recoverable

| Agent ID | Model | Task | Scope (files) | State | Recovery |
|---|---|---|---|---|---|
| `a43dce4a0f7db7ade` | sonnet | Build acquisition crawler | `curriculum/scripts/crawler/**` + `scripts/tests/` | 🟢 running (5 modules created; crawl.py + tests pending) | monitor; do NOT re-spawn |

## Terminal this session (2026-07-08) — for provenance / no-duplicate

| Agent ID | Model | Task | State | Notes |
|---|---|---|---|---|
| `ad5c0e1bce1b48e56` | (opus) | P2-UX-5 dark-theme | ✅ done | integrated → `dd471f2e` |
| `ac127f7a08aebe921` | (opus) | CI-C1 solver | ✅ done | `31d22f96` |
| `a4c04feb735185b73` | (opus) | CI-C3 multi-set/export | ✅ done | `fab2807f` |
| `a49f746b4eec46087` | (opus) | CI-C7 profile engine | ✅ done | `2379a529` |
| `ad1eb998529c4c7f9` | (opus) | CI-C8 rotation/reason (worktree) | ✅ done | reset-onto-tip → clean cherry-pick → `e62c367c`; worktree removed |
| `a049e77b10cd5d826` | (opus) | ERP AsyncValue (worktree) | ❌ discarded | based on `main` → conflicts → reverted; RE-RUN on correct base |
| `ad1b8b14b90cf2c74` | (opus) | CBSE+NCERT acquisition | ❌ failed | Anthropic session limit mid-finalization; SUPERSEDED by crawler (do not resume — crawler owns CBSE+NCERT as P0) |
| `aed86d3e87bdf23e7` | (opus) | AP SCERT acquisition | ⚠ partial | ~20 PDFs on disk, no manifest; crawler re-does as P1 |
| `ad479eeaf0dbff762` | (opus) | TS SCERT acquisition | ⚠ partial | ~7 PDFs on disk, no manifest; crawler re-does as P2 |
| `a66ca488dbde617cc` | (opus) | CISCE acquisition | ✅ clean | 42/42 verified + `cisce_manifest.json`; crawler folds in as P3 |

---

## Update rules
- Append a row when an agent is spawned (ID · model · task · scope · state); flip state on
  completion. Keep it lightweight.
- On resume: read this table, reconnect any 🟢 running / recoverable agent, and only spawn new
  work that has no live/recoverable owner.
