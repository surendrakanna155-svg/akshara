# Akshara Engineering Operating System (EOS) Skill

> The Constitution defines the engineering laws. **This skill executes them.**

The EOS is the standing engineering gate for the Akshara ERP project. It runs
**automatically** before any work is called complete (via the project
[CLAUDE.md](../../../CLAUDE.md), surfacing only a one-line verdict), and can be
invoked **explicitly** with the **`/eos`** command
([.claude/commands/eos.md](../../commands/eos.md)) for a full report. It evaluates
the project against the
[Engineering Constitution](../../../docs/engineering/AKSHARA_ENGINEERING_CONSTITUTION.md),
produces **evidence-based** reports, scores engineering health, classifies the
release state, and **blocks** anything that violates the Constitution.

## Why it exists

Akshara has 16 Parts of engineering law and 300+ planning/audit/certification
docs. Without one enforcement engine, standards drift and "done" means different
things in different places. The EOS makes there be **exactly one engineering
standard going forward** — the Constitution — and one runner that applies it.

It is deliberately **lightweight**: it *references* the Constitution by Part and
section name and never copies it. When the Constitution evolves, the skill keeps
working with little or no change (see [MAINTENANCE.md](MAINTENANCE.md)).

## Files in this skill

| File | Purpose |
|------|---------|
| [SKILL.md](SKILL.md) | The skill itself — operating rules, run procedure, enforcement, gate. |
| [CONSTITUTION_MAP.md](CONSTITUTION_MAP.md) | Thin index: each EOS check → the Constitution Part/section that owns the rule. The only file to touch when the Constitution is restructured. |
| [README.md](README.md) | This overview. |
| [USAGE.md](USAGE.md) | Usage guide — when/how to run, report templates, output locations, gate workflow. |
| [EXAMPLES.md](EXAMPLES.md) | Concrete invocation examples. |
| [MAINTENANCE.md](MAINTENANCE.md) | How to keep the skill in sync with the Constitution (without duplicating it). |

## How it fits with the other skills

The EOS is the **umbrella gate**. It orchestrates — never duplicates — the
focused skills:

- **`/gap-check`** — deep code-level gap hunting in a module.
- **`/certify`** — proves a module works live on the VPS; writes `*_CERTIFICATION.md`.
- **`/deploy`** — ships verified changes to the VPS pilot.
- **`/release-review`** — narrow Eng/QA/Release go-no-go for one batch/build.

`/release-review` checks 3 lanes for a single build. **The EOS evaluates all 20
Constitution categories, scores health, classifies the release state, and is the
mandatory gate for the entire project.**

## The promise it enforces

Per Part 8 — *Final Engineering Law*: **nothing in Akshara is complete until the
EOS has evaluated it.** Every remaining roadmap phase, QA wave, certification
wave, bug fix, refactor, migration, and new feature passes through this gate
before it counts as done. The standing policy is
[docs/engineering/ENGINEERING_GATE_POLICY.md](../../../docs/engineering/ENGINEERING_GATE_POLICY.md).

## Quick start

```
/eos                       # platform-wide sweep + gate verdict
/eos finance               # scope to the finance module
/eos production-readiness  # produce the Production Readiness Report
/eos QW1                   # gate a QA wave before it's marked complete
```

Reports land in `docs/engineering/eos/`; every run is logged in
`docs/engineering/eos/EOS_RUN_LEDGER.md`.
