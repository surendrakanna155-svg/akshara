# EOS Maintenance Guide

The EOS skill is intentionally **lightweight** so that the Constitution can grow
without dragging the skill along. This guide explains how to keep them in sync
while preserving the core constraint: **the Constitution is the single source of
truth; the skill never duplicates it.**

## The golden rule

> The skill **references** the Constitution by **Part + section name**. It must
> never copy, summarize, or restate Constitution rules. If you find yourself
> pasting a rule into the skill, stop — link to the section instead.

This is what keeps token usage low and maintenance cheap: there is one place a
rule lives, and changing it there changes the behaviour everywhere.

## What to update when the Constitution changes

| Constitution change | What to touch in the skill |
|---------------------|----------------------------|
| Edit text **within** an existing section | **Nothing.** The skill reads the live text at run time. |
| **Rename** a section | Update that section's name in [CONSTITUTION_MAP.md](CONSTITUTION_MAP.md) only. |
| **Add a new section** to an existing Part | Add a row/pointer in [CONSTITUTION_MAP.md](CONSTITUTION_MAP.md) if it introduces a new check. |
| **Add a new Part** | Add it to the parts table in [CONSTITUTION_MAP.md](CONSTITUTION_MAP.md); if it defines a new certification category, add a row to the categories table. |
| **Add a new certification category** (Part 7B) | Add one row to the categories table in [CONSTITUTION_MAP.md](CONSTITUTION_MAP.md). The skill body already iterates "all categories". |
| **Reorder / renumber Parts** | Update the parts table in [CONSTITUTION_MAP.md](CONSTITUTION_MAP.md). Because the skill cites by **name**, prose references survive renumbering. |

In almost every case the **only** file that changes is `CONSTITUTION_MAP.md`.
`SKILL.md`, `README.md`, `USAGE.md`, and `EXAMPLES.md` should rarely need edits.

## Never do this

- ❌ Copy Acceptance Criteria / Failure Conditions into the skill.
- ❌ Cite the Constitution by **line number** (lines shift on every edit) — cite
  by **Part + section heading**, which is stable.
- ❌ Introduce a second, competing standard or checklist. There is **one**
  engineering standard (the Constitution). If the skill and the Constitution
  ever disagree, the Constitution wins and the skill is the bug.
- ❌ Let the skill invent features or rewrite committed roadmap scope. It may
  *recommend* waves (Part 8 — *Automatic Roadmap*); it does not change the plan.

## Keeping the skill discoverable & enforced

- The skill is registered at `.claude/skills/eos/SKILL.md`; its frontmatter
  `description` is what makes `/eos` trigger. Keep that description broad enough
  to fire on "is X complete/ready", "engineering health", "Constitution
  compliance", and "production/commercial ready".
- The standing mandate lives in
  [docs/engineering/ENGINEERING_GATE_POLICY.md](../../../docs/engineering/ENGINEERING_GATE_POLICY.md).
  Active roadmap/QA docs point at it. When a new roadmap or QA wave doc is
  created, add the one-line EOS-gate clause (see the policy doc for the exact
  line) — don't re-derive a bespoke checklist.

## Health check for the skill itself

Once in a while, verify the skill still maps cleanly to the Constitution:

1. `grep -nE '^# (PART|.* Certification|Acceptance|Failure)' docs/engineering/AKSHARA_ENGINEERING_CONSTITUTION.md`
   to list the current Parts/sections.
2. Confirm every Part 7B *Certification Category* has a row in
   `CONSTITUTION_MAP.md`.
3. Confirm no section referenced by the map has been renamed/removed.
4. Confirm `SKILL.md` still contains **no** copied Constitution text.

If all four hold, the EOS is in sync. The Constitution can keep evolving; the
skill keeps executing it.
