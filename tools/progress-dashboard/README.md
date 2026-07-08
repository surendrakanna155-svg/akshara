# Akshara ERP — Development Progress Dashboard

A **standalone, local developer productivity tool** that answers, at a glance and at any time:

> What are you doing? · Which phase? · Which roadmap item is running? · How much is done? ·
> Which agents are active? · Why are you waiting? · What's next?

**This is NOT part of the production application.** It never ships in any Flutter / backend build.
It exists only to give visibility into Claude's roadmap implementation work.

---

## Run it

Because the dashboard reads JSON files with `fetch()`, browsers block that over the `file://`
protocol. Serve the folder over a tiny local HTTP server:

```bash
cd tools/progress-dashboard
python3 -m http.server 8787
# then open http://localhost:8787
```

(Any static server works — `npx serve`, `php -S localhost:8787`, a VS Code Live Server, etc.)

The page **auto-refreshes the JSON every 30 seconds**. The HTML/CSS/JS are never regenerated —
only the three JSON files change as work progresses. There's a manual **⟳** refresh button and a
**☾ / ☀** light/dark toggle (dark by default) in the header.

---

## Files

| File | Role | Who edits it |
|---|---|---|
| `index.html` | Static structure (header, cards, chat panel) | **Never** after setup |
| `styles.css` | Dark-first theme, responsive layout | **Never** after setup |
| `app.js` | Loads JSON, renders, auto-refresh, prompt builder | **Never** after setup |
| `progress.json` | **Current** implementation state (the live snapshot) | Updated continuously |
| `activity.json` | **Append-only** historical activity log (newest kept ≤100) | Appended, never rewritten |
| `prompts.json` | Suggested prompt chips + templates for the chat panel | Rarely |
| `README.md` | This file | Rarely |

**Golden rule:** after initial setup, implementation work updates **only the JSON files**.
Never rewrite history in `activity.json` — only append.

---

## JSON schemas (stable, versioned via `schemaVersion`)

### `progress.json`
```jsonc
{
  "schemaVersion": 1,
  "meta": { "project", "branch", "commit", "commitMessage", "roadmapVersion",
            "session", "user", "lastUpdated" /*ISO*/, "overallProgress" /*0-100*/ },
  "currentStatus": { "phase", "wave", "task", "module", "directory", "file",
                     "status" /*running|completed|waiting|blocked|pending*/,
                     "runningSince" /*ISO — elapsed is computed live*/, "estimatedRemaining" },
  "roadmap": [ { "id", "label", "status", "detail?",
                 "children": [ { "id", "label", "status", "detail?" } ] } ],
  "agents": [ { "name", "task", "file", "progress" /*0-100*/, "status", "started" /*ISO*/ } ],
  "workspace": { "currentlyEditing", "workingDirectory",
                 "filesCreated": [], "filesModified": [], "filesDeleted": [],
                 "gitStatus", "lastCommit", "workspaceClean" /*bool*/ },
  "todaySummary": { "tasksCompleted", "commits", "filesCreated", "filesModified",
                    "testsPassed", "analyze", "failures" },
  "nextRoadmap": { "nextTask", "dependency", "reasonIfBlocked", "ownerGate", "estimatedStart" },
  "systemStatus": { "branch", "git", "workspace", "flutterAnalyze", "tests", "build", "currentMode" }
}
```

### `activity.json` (append-only, newest first is fine — the UI re-sorts by `timestamp`)
```jsonc
{ "schemaVersion": 1,
  "entries": [ { "time": "15:42", "timestamp": "2026-07-08T15:42:00+05:30",
                 "level": "start|done|commit|test|analyze|blocked|waiting|info|agent",
                 "message": "…" } ] }
```

### `prompts.json`
```jsonc
{ "schemaVersion": 1,
  "chips": [ "What are you doing now?", "..." ],
  "templates": [ { "id", "label", "text" } ],
  "contextTemplate": "…{phase}…{wave}…{task}…{status}…{next}…" }
```

**Status → colour** (per spec): `running`=green · `completed`=blue · `waiting`=orange ·
`blocked`=red · `pending`=grey.

---

## The chat panel (prompt builder — no API)

The bottom "Claude Assistant" panel **does not call any API**. It helps you compose a prompt:

1. Click a **suggested prompt chip** (or type your own) → fills the textbox.
2. **Ask** — prepares the final prompt (optionally appends a live context snapshot of the current
   phase / wave / task / next item — toggle "attach context").
3. **Copy Prompt** — copies it to the clipboard; paste it into Claude Code manually.
4. **Clear** — resets the textbox.

---

## When Claude updates the dashboard

Update `progress.json` and append to `activity.json` immediately whenever:
roadmap/task/agent **starts** or **stops**, a **commit** happens, **tests** or **analyze** finish,
or state goes **blocked / waiting / paused / completed**.

## Future-ready (add without redesign)

The schemas leave room for: timeline, charts, token usage, CPU/memory, recent commits, session
history, cost, build history, performance, repository & agent metrics, multiple projects.
Add new keys to the JSON and a new render function in `app.js` — existing sections are untouched.

## Isolation from production

Lives entirely under `tools/` — outside `lib/`, `apps/`, backend functions, and any build input.
Flutter (`pubspec`/`lib`), Deno edge functions, and release bundles never read `tools/`, so nothing
here can leak into a production build.
