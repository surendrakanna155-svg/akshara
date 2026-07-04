# Akshara ERP — Project Instructions

## MANDATORY: EOS Automatic Engineering Gate

The **Engineering Operating System (EOS)** is the standing, **automatic** engineering
gate for this project. It must run **without the developer having to ask**.

- **Standard (the law):** `docs/engineering/AKSHARA_ENGINEERING_CONSTITUTION.md`
  (Part 7B — Certification Engine; Part 8 — EOS). *Frozen — never rewrite, move, or duplicate it.*
- **Policy:** `docs/engineering/ENGINEERING_GATE_POLICY.md`
- **Implementation:** `.claude/skills/eos/` (skill) · `.claude/commands/eos.md` (typed `/eos` command)

### When the gate fires automatically

Before you tell the developer that **any** of the following is
**complete / done / ready / finished / shipped**, you MUST first run the EOS gate
internally against the affected scope:

- implementing a feature or module
- fixing a bug
- completing a roadmap item / phase / wave
- finishing a QA wave or a certification wave
- preparing a release, production, or commercial launch
- any refactor or migration that touches a live path

### How it runs — invisible by default

1. **Internally** execute the EOS procedure in `.claude/skills/eos/SKILL.md`
   (anchored on the Constitution; reference it, never duplicate it), scoped to the
   work just completed. Do this as part of your own reasoning — do not announce it
   or paste a full report.
2. **Surface only a one-line verdict**, e.g.
   `EOS gate: PASS` ·
   `EOS gate: CONDITIONAL PASS — P1s tracked: <…>` ·
   `EOS gate: BLOCKED — <blocking item>`.
3. **Act on the verdict:**
   - **PASS** → you may declare the work complete.
   - **CONDITIONAL PASS** → declare complete only with the named P1s noted/tracked
     into a future wave.
   - **BLOCKED** (any open P0 or Part 7B automatic-failure condition) → the work is
     **NOT done**. State what is blocking and resolve it before claiming completion.

### When to produce a full report instead

Generate the standalone, evidence-based EOS report (per `.claude/skills/eos/USAGE.md`,
written to `docs/engineering/eos/`) **only** when the developer **explicitly** asks
for an EOS report, or runs the **`/eos`** command (`/eos`, `/eos <scope>`).

### One standard, one gate

Do not create competing "is it ready?" checklists. There is exactly one engineering
standard (the Constitution) and one engine that enforces it (the EOS). The focused
skills `/gap-check`, `/certify`, `/deploy`, `/release-review` are subordinate tools the
EOS orchestrates — not replacements for the gate.
