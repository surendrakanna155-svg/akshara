# Akshara ERP — Multi-Agent System

**Version:** 1.0  
**Date:** June 2026  
**Status:** Active — use with Cursor parent agent + Task subagents

---

## What this is

A **coordinator pattern** for Cursor: one parent agent runs a loop, launches **parallel subagents** (Task tool), assigns **exclusive files per task**, and uses a **handoff board** so agents wait on dependencies before starting.

This is **not** a separate runtime service. It works while Cursor is open and the parent session is running.

---

## Components

| Artifact | Purpose |
|----------|---------|
| [`AGENTS.md`](../../AGENTS.md) | Role ownership (A–G) |
| [`qa/agents/work_manifest.json`](work_manifest.json) | Task queue: agent, files, deps, acceptance |
| [`qa/agents/handoff_board.json`](handoff_board.json) | Live status + handoff messages |
| [`qa/agents/handoff_protocol.md`](handoff_protocol.md) | Wait/communicate rules |
| [`scripts/qa/agent_coordinator.py`](../../scripts/qa/agent_coordinator.py) | init / claim / complete / runnable / validate |
| [`.cursor/skills/multi-agent-coordinator/SKILL.md`](../../.cursor/skills/multi-agent-coordinator/SKILL.md) | Parent agent instructions |

---

## Quick start

**User says:** “Run multi-agent overnight mission” or “let’s start”

**Parent agent:**

```bash
# 1. Init
python3 scripts/qa/agent_coordinator.py init --run-id "$(date +%Y%m%d_%H%M%S)_overnight"

# 2. See what can run in parallel
python3 scripts/qa/agent_coordinator.py runnable

# 3. For each parallel batch — launch Task subagents, then:
python3 scripts/qa/agent_coordinator.py claim TASK-C1 --agent C
# ... subagent work ...
python3 scripts/qa/agent_coordinator.py complete TASK-C1 --summary "…"

# 4. Repeat until done; final gate:
flutter analyze && flutter test
ERP_COVERAGE_MODE=full qa/patrol/run_erp_coverage.sh
```

---

## How agents “communicate”

Subagents **do not chat with each other**. They:

1. **Wait** — task not in `runnable` until `depends_on` tasks are `done`.
2. **Read** — prior agent’s `handoff` string on the board.
3. **Write** — parent calls `complete --summary` for the next agent.

Example: **TASK-C2** (parent attendance sync) waits for **TASK-C1** (HR mutations) if manifest says so; **TASK-E1** waits for **TASK-C1** before Patrol.

---

## File ownership (1:1)

Each manifest task lists explicit paths. Coordinator **validate** rejects two `in_progress` tasks touching the same file.

To add a mission: edit `work_manifest.json` — do not duplicate file paths across parallel tasks.

---

## Default overnight manifest

The bundled manifest targets:

- **C** — HR leave mutation MVP + teacher→parent attendance sync  
- **D** — Inventory PO + transport route mutation MVP  
- **E** — Patrol + RBAC tests (after C/D)  
- **G** — Full regression + summary docs  

Customize tasks per sprint; keep Agent letters aligned with `AGENTS.md`.

---

## Limits (honest)

| Possible | Not possible |
|----------|--------------|
| 4 parallel subagents, disjoint files | Autonomous run with laptop asleep / Cursor closed |
| Dependency waits via board | Subagents merging git branches automatically |
| Targeted test gates per task | Auto-crawl + auto-fix every screen without Patrol |
| Full Patrol at mission end | Full Patrol after every micro-change (too slow) |

---

## Related docs

- [`../../docs/archive/temporary/MULTI_AGENT_SYSTEM.md`](../../docs/archive/temporary/MULTI_AGENT_SYSTEM.md) — architecture diagram  
- [`../../docs/archive/temporary/CURSOR_WORKFLOW.md`](../../docs/archive/temporary/CURSOR_WORKFLOW.md) — single-agent session flow  
- [`../../docs/archive/qa/v18.8_readiness_assessment.md`](../../docs/archive/qa/v18.8_readiness_assessment.md) — blocker priorities
