---
name: eos
description: >
  Engineering Operating System (EOS) for Akshara ERP — the execution layer of
  the Engineering Constitution. Evaluates the project (code, architecture,
  database, tests, QA, coverage, security, RBAC, reliability, offline/sync,
  performance, localization, accessibility, communication, white-label, docs,
  CI/CD, production readiness) against the Constitution, produces evidence-based
  gap / readiness / certification reports, scores engineering health, classifies
  release state, and enforces the Constitution as a hard gate. Use whenever the
  user wants to evaluate engineering completeness or readiness, run an "EOS" or
  engineering audit, check Constitution compliance, score engineering health,
  decide if something is production/commercial ready, or before ANY feature,
  wave, batch, refactor, migration, or release is considered complete. This is
  the mandatory engineering gate for all remaining Akshara work. Does NOT
  rewrite or duplicate the Constitution, invent features, or change roadmap scope.
---

# Engineering Operating System (`/eos`)

The **Constitution defines the engineering laws. The EOS executes them.**

The single source of truth is the Engineering Constitution at
[docs/engineering/AKSHARA_ENGINEERING_CONSTITUTION.md](../../../docs/engineering/AKSHARA_ENGINEERING_CONSTITUTION.md)
(Part 8 *is* the EOS specification; Part 7B is the Certification Engine). This
skill is the lightweight runner for it — it **references** the Constitution by
Part and section name; it never copies, summarizes, or restates the rules. When
the Constitution changes, this skill keeps working unchanged.

## Operating rules (non-negotiable)

1. **The Constitution is the law; never duplicate it.** Read the relevant
   Part(s) and apply their *Acceptance Criteria* and *Failure Conditions*
   verbatim. Cite the rule (e.g. "Part 4A — RBAC Certification"); don't paraphrase
   it into a competing standard. There is only **one** engineering standard.
2. **Evidence over opinion.** Every verdict cites real evidence — `file:line`,
   a gate result, an N/N live cert, a coverage number, a log. "Should work" /
   "looks fine" is not evidence and is itself a failure condition (Part 7B —
   *Failure Conditions*).
3. **Never invent features or change roadmap scope.** The EOS *recommends*
   roadmap waves for the gaps it finds (Part 8 — *Automatic Roadmap*), but it
   evaluates against what the SRS / roadmap / shipped UI already promises. New
   ideas → `IDEAS_BACKLOG.md`.
4. **Never re-audit certified-and-unchanged work.** Treat the
   `*_CERTIFICATION.md` files (active in `docs/`, archived in
   `docs/archive/completed/`) as truth. If an area is PRODUCTION CERTIFIED and
   its code is unchanged since the cert, say "covered by <cert>" and move on
   (mirrors `/gap-check`, `/certify`).
5. **Orchestrate; don't reimplement.** The EOS is the umbrella gate. It routes
   detail work to the focused skills (below) instead of duplicating them.

## What the EOS does on every run

Driven by the Constitution: **Part 8** (*Inputs*, *Continuous Analysis*,
*Automatic Detection*, *Engineering Health*, *Gap Discovery*, *Prioritization*,
*Automatic Roadmap*, *Release Decision*, *Engineering Reports*) and **Part 7B**
(*Certification Categories*, *Evidence Requirements*, *Pass / Automatic-Failure
Conditions*, *Severity*, *Engineering Gates*).

1. **Analyze the inputs** named in Part 8 — *Inputs*: source code, architecture,
   database, tests, QA reports, coverage, security/perf reports, localization,
   assets, docs, roadmap, logs, feature flags, config, CI/CD, monitoring.
2. **Detect** everything in Part 8 — *Continuous Analysis* + *Automatic
   Detection*: missing/incomplete features, broken/untested workflows, missing
   tests/widget/RBAC/localization/accessibility/communication/white-label/
   offline/sync/reliability/security validation, missing production
   requirements, technical debt, duplicate/dead code, obsolete docs, config
   problems.
3. **Evaluate against the 20 certification categories** (Part 7B — *Certification
   Categories*). Each category maps to the Part that owns it — see
   [CONSTITUTION_MAP.md](CONSTITUTION_MAP.md). For each, apply that Part's
   *Acceptance Criteria* and *Failure Conditions*.
4. **Score engineering health** (Part 8 — *Engineering Health*). Scores guide
   improvement; per Part 7B — *Engineering Score*, **scores alone never approve a
   release**.
5. **Classify the release state** (Part 8 — *Release Decision*): Not Ready /
   Development Ready / QA Ready / Pilot Ready / Production Ready / Commercial
   Ready / Blocked — with evidence. Apply Part 7B — *Automatic Failure
   Conditions* and *Release Rules* (any open P0 ⇒ Blocked).
6. **Produce evidence-based reports** and **enforce the gate** (below).

## How to run

1. **Scope it.** If the user named a feature / module / batch / wave / release,
   scope to that. Otherwise ask, or run the platform-wide sweep. Resolve the
   certification *scope* level from Part 7B — *Certification Scope* (function →
   widget → screen → feature → module → API → migration → release → commercial).
2. **Anchor on truth first.** Read the relevant Constitution Part(s) via
   [CONSTITUTION_MAP.md](CONSTITUTION_MAP.md), the matching
   `*_CERTIFICATION.md` files (active in `docs/`, archived in
   `docs/archive/completed/`), and the memory index. Skip
   certified-and-unchanged areas.
3. **Gather evidence, don't assume.** Run / read the gates and artifacts that
   Part 7B — *Evidence Requirements* demands: `flutter analyze`, `flutter test`,
   widget/integration/Patrol tests, coverage, `scripts/qa/live_cert_*.py` /
   `scripts/*_smoke.sh` results, RBAC route inventory, security/perf evidence,
   live VPS results. For deep gap-hunting delegate to `/gap-check`; for live
   proof delegate to `/certify`.
4. **Judge each category** against its Part's criteria. Record PASS / FAIL /
   BLOCKED / N/A with the evidence that proves it.
5. **Check the automatic-failure list** (Part 7B): data loss, security breach,
   permission escalation, tenant-isolation failure, critical crash, duplicate
   financial transaction, broken auth/sync, critical regression, missing backup
   verification, production blocker → instant FAIL regardless of scores.
6. **Write the report(s)** and **render the gate verdict.**

## Enforcement — the gate

When a feature violates the Constitution, the EOS blocks it and states, for each
violation:

- **Rule failed** — the exact Constitution Part + section (e.g. "Part 4B —
  *Sync Engine*").
- **Why it failed** — the specific acceptance criterion not met / failure
  condition triggered.
- **Evidence** — `file:line`, gate output, missing test, failed N/N, log.
- **Severity** — P0 / P1 / P2 / P3 (Part 7B — *Certification Severity*).
- **Recommended fix** — direction, not a full implementation.
- **Suggested roadmap wave** — where it belongs (Part 8 — *Automatic Roadmap*;
  never recommend work in an unsafe order).

**Gate result** (Part 7B — *Engineering Gates*, *Release Rules*): the change may
not pass `Merge → QA → Staging → Pilot → Production → Commercial` while any
**P0** is open, required certification is incomplete, or security / reliability /
production-readiness certification fails. State the gate plainly: **PASS /
CONDITIONAL PASS / BLOCKED**, with the blocking items.

## Reports (evidence, not opinions)

Generate the report(s) the request calls for (Part 8 — *Engineering Reports*;
Part 7B — *Certification Reports*). Each is **evidence-based**:

- Engineering Health Report · Engineering Gap Report · Architecture Report
- Security Gap Report · Reliability Gap Report · QA Gap Report · Testing Report
- Production Readiness Report · Commercial Readiness Report
- Feature / Module Certification Report · Release Report
- Roadmap Update Recommendations · Executive Engineering Summary

Write reports to **`docs/engineering/eos/`** (e.g.
`docs/engineering/eos/EOS_<SCOPE>_<TYPE>_REPORT.md`) and append a one-line entry
to the run ledger `docs/engineering/eos/EOS_RUN_LEDGER.md` (date · scope · gate
verdict · open P0/P1 · report path). Follow the structure in
[USAGE.md](USAGE.md). Do not restate Constitution text in the report — cite it.

## Relationship to the focused skills

The EOS is the **umbrella engineering gate**; it delegates execution and never
duplicates these:

- **`/gap-check`** — deep gap hunting inside a module (the EOS's *detection* arm
  for code-level gaps).
- **`/certify`** — proves a module works live on the VPS and writes the
  `*_CERTIFICATION.md` (the EOS's *evidence* arm for live behaviour).
- **`/deploy`** — ships verified changes to the VPS pilot.
- **`/release-review`** — narrow Eng/QA/Release go-no-go for a single batch/build.

Rule of thumb: `/release-review` checks 3 lanes for one build; **the EOS
evaluates all 20 Constitution categories, scores health, classifies the release
state, and is the standing gate for the whole project.** When the EOS needs
gap detail it invokes `/gap-check`; for live proof, `/certify`; to ship,
`/deploy`.

## Mandatory gate

Per Part 8 — *Final Engineering Law* and Part 7B — *Engineering Gates*: **nothing
in Akshara is "complete" until the EOS has evaluated it.** Every remaining
roadmap phase, QA wave, certification wave, bug fix, refactor, migration, and new
feature must pass the EOS gate before it is considered done. See the standing
policy in
[docs/engineering/ENGINEERING_GATE_POLICY.md](../../../docs/engineering/ENGINEERING_GATE_POLICY.md).

### Two ways the gate runs

1. **Automatic (invisible) — the default.** Per the project
   [CLAUDE.md](../../../CLAUDE.md), before Claude declares any feature, bug fix,
   roadmap item, QA/certification wave, or release/production/commercial step
   **complete**, it runs this gate internally against that scope and surfaces only a
   **one-line verdict** (`EOS gate: PASS | CONDITIONAL PASS | BLOCKED — <blocker>`).
   Developers never have to remember to invoke it; **BLOCKED ⇒ not done.**
2. **Explicit (full report) — on request.** The typed project command **`/eos`**
   (or `/eos <scope>`), registered at
   [.claude/commands/eos.md](../../commands/eos.md), or an explicit ask for an EOS
   report, produces the standalone evidence-based report per [USAGE.md](USAGE.md)
   in `docs/engineering/eos/`.
