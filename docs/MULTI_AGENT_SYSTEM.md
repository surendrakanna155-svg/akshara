# Akshara ERP — Multi-Agent System Architecture

**Version:** 1.0 · **June 2026**

---

## Overview

Akshara ERP uses a **coordinated multi-agent workflow inside Cursor**: one **parent coordinator** and up to **four parallel subagents**, each bound to an **Agent A–G role** from `AGENTS.md`.

```
                    ┌─────────────────────────┐
                    │   Parent Coordinator    │
                    │  (reads SKILL + board)  │
                    └───────────┬─────────────┘
                                │
          ┌─────────────────────┼─────────────────────┐
          │                     │                     │
          ▼                     ▼                     ▼
   ┌─────────────┐       ┌─────────────┐       ┌─────────────┐
   │  Subagent C │       │  Subagent D │       │  Subagent E │
   │  HR + Attnd │       │ Inv + Trans │       │ Tests/Patrol│
   │  files: …   │       │  files: …   │       │  files: …   │
   └──────┬──────┘       └──────┬──────┘       └──────┬──────┘
          │                     │                     │
          └─────────────────────┼─────────────────────┘
                                ▼
                    ┌─────────────────────────┐
                    │   handoff_board.json    │
                    │  pending → done + text  │
                    └─────────────────────────┘
                                │
                                ▼
                    ┌─────────────────────────┐
                    │ agent_coordinator.py    │
                    │ runnable · validate     │
                    └─────────────────────────┘
```

---

## vs “real” multi-agent platforms

| Feature | Akshara Cursor system | AutoGPT / custom swarm |
|---------|----------------------|-------------------------|
| Parallel workers | ✅ Task subagents | ✅ |
| File-level locks | ✅ manifest + validate | Varies |
| Inter-agent messaging | ✅ handoff board | ✅ message bus |
| Runs without IDE | ❌ | ✅ |
| Auto-merge / CI | ❌ manual git | Varies |

---

## Agent responsibilities (parallel tracks)

| Agent | Parallel track | Typical overnight tasks |
|-------|----------------|-------------------------|
| **A** | Admissions + SIS repos | Mock sync, contracts, API paths |
| **B** | Finance | Collection, export stubs, journey providers |
| **C** | HR + attendance | `hr_mutations_provider`, parent KPI sync |
| **D** | Inventory + transport | Mutation MVPs, route/PO writes |
| **E** | QA coordinator | Patrol, RBAC tests, progress docs |
| **F** | Documentation | Release notes (optional parallel) |
| **G** | Release gate | Full analyze + test + Patrol |

**E** is both subagent (tests) and meta-coordinator helper; **parent** always owns the loop.

---

## Communication protocol

1. **Dependency wait** — Task stays `pending` until `depends_on` ids are `done`.
2. **Claim** — `claim TASK --agent X` sets `in_progress` and locks files.
3. **Handoff** — `complete TASK --summary "…"` publishes notes for downstream tasks.
4. **Block** — `block TASK --waiting-on OTHER` when discovery requires reordering.

Subagents read summaries from:

```bash
python3 scripts/qa/agent_coordinator.py status
```

---

## Enforcement

| Rule | Enforcement |
|------|-------------|
| One editor per file | `validate` + manifest file lists |
| Role ownership | Subagent prompt + AGENTS.md |
| No full Patrol every change | SKILL.md cadence |
| Green main branch | targeted tests per task; full gate at end |

---

## Activating a mission

**User prompt:**

> Run multi-agent overnight mission. Use work_manifest.json. Parallel subagents. Update overnight_progress.md.

**Parent must:**

1. Load `.cursor/skills/multi-agent-coordinator/SKILL.md`
2. `init` board
3. Loop `runnable` → parallel Task → `complete`
4. Final G gate + `overnight_summary.md`

---

## Extending

Add tasks to `qa/agents/work_manifest.json`:

```json
{
  "id": "TASK-X1",
  "agent": "D",
  "title": "…",
  "depends_on": ["TASK-Y1"],
  "files": ["lib/features/…/only_these_files.dart"],
  "acceptance": "…"
}
```

Run `python3 scripts/qa/agent_coordinator.py validate` before launching parallel batch.

---

## References

- `qa/agents/README.md`
- `qa/agents/handoff_protocol.md`
- `.cursor/skills/multi-agent-coordinator/SKILL.md`
- `AGENTS.md` § Multi-Agent Orchestration
