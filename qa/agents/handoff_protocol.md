# Multi-Agent Handoff Protocol

**Version:** 1.0  
**Coordinator script:** `scripts/qa/agent_coordinator.py`  
**Manifest:** `qa/agents/work_manifest.json`  
**Live state:** `qa/agents/handoff_board.json`

---

## Roles

| Agent | Ownership (from AGENTS.md) |
|-------|----------------------------|
| **A** | `lib/core/repositories/`, contracts, integration |
| **B** | ERP features: admissions, finance, sis, … |
| **C** | HR, mobile teacher/parent/student, attendance |
| **D** | Auth, security, audit, inventory, transport guards |
| **E** | `test/`, Patrol, QA docs |
| **F** | `docs/` |
| **G** | Release gates, version, full regression |

**Parent agent (Coordinator)** does not edit feature files except `handoff_board.json` and progress docs. It launches subagents and merges handoffs.

---

## File lock rule (1:1)

1. Each task in the manifest lists **exclusive `files`**.
2. **Only one task** may be `in_progress` per file at a time.
3. Subagents **must not** edit files outside their task list.
4. Shared files (e.g. `qa_test_keys.dart`) — split into sequential tasks or assign one agent to add all keys in one task.

---

## Task states

| State | Meaning |
|-------|---------|
| `pending` | Not started; dependencies may be open |
| `in_progress` | Subagent claimed; files locked |
| `blocked` | Waiting on another task (optional) |
| `done` | Complete; handoff summary written |

---

## Handoff message format

When a subagent completes, the parent runs:

```bash
python3 scripts/qa/agent_coordinator.py complete TASK-C1 --summary "$(cat <<'EOF'
Implemented hr_mutations_provider createLeaveRequest.
Tests: test/features/hr/hr_write_tests.dart — pass.
Files touched: hr_mutations_provider.dart, hr_leave_screen.dart, qa_test_keys.dart.
Next: TASK-E1 may add Patrol; TASK-C2 unblocked.
EOF
)"
```

Subagents **read** dependency handoffs from `handoff_board.json` before starting:

```bash
python3 scripts/qa/agent_coordinator.py status | jq '.tasks["TASK-C1"].handoff'
```

---

## Coordinator loop (parent agent)

```
1. Read .cursor/skills/multi-agent-coordinator/SKILL.md
2. python3 scripts/qa/agent_coordinator.py init --run-id <timestamp>
3. LOOP:
     a. python3 scripts/qa/agent_coordinator.py runnable
     b. python3 scripts/qa/agent_coordinator.py validate
     c. Launch up to max_parallel Task subagents (one task each)
     d. Each subagent: claim → work → analyze → targeted tests → complete
     e. If no runnable and in_progress empty → break
     f. If blocked → wait for dependency done (re-check runnable)
4. Agent G task: full flutter test + full Patrol
5. Write overnight_summary.md
```

---

## Subagent prompt template

```
You are Agent {LETTER} for Akshara ERP.
Task ID: {TASK_ID}
Title: {TITLE}
Read AGENTS.md ownership for Agent {LETTER}.

ONLY edit these files:
{FILE_LIST}

Dependencies done — read handoff:
{HANDOFF_TEXT}

Acceptance:
{ACCEPTANCE}

Before finishing:
- flutter analyze (owned paths)
- run only tests you added/changed
- do NOT run full Patrol

Return: summary for coordinator complete command.
```

---

## Parallelism rules

| Rule | Value |
|------|-------|
| Max parallel subagents | 4 (manifest `max_parallel`) |
| Same file | Never parallel |
| Cross-module dependency | Later task `depends_on` earlier task id |
| Regression | Only Agent G / after 3 blockers / end of mission |

---

## Communication (wait)

Subagents **do not** message each other directly. They:

1. **Wait** until `runnable` includes their task (dependencies `done`).
2. **Publish** via `complete --summary`.
3. **Block** via coordinator if discovery needs another task first:

```bash
python3 scripts/qa/agent_coordinator.py block TASK-E2 --reason "Need transport QA keys" --waiting-on TASK-D2
```

Parent re-runs `runnable` after each `complete`.
