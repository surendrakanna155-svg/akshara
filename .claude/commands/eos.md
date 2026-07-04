---
description: Run the Engineering Operating System gate — Constitution compliance, engineering health, release state, gate verdict. Optional scope.
argument-hint: "[scope: module | wave id | category | production | commercial | full | (empty = platform-wide)]"
---

Run the **Engineering Operating System (EOS)** — the standing engineering gate
for Akshara — and produce a **full standalone report**.

**Scope:** `$ARGUMENTS`  (empty = platform-wide sweep)

Examples this command supports: `/eos`, `/eos attendance`, `/eos finance`,
`/eos qw1`, `/eos phase0b`, `/eos production`, `/eos commercial`, `/eos full`.

Execute the project EOS skill exactly — **reference** the Constitution, never
duplicate it:

1. Read `.claude/skills/eos/SKILL.md` and `.claude/skills/eos/CONSTITUTION_MAP.md`.
2. Run the EOS procedure for the scope above, anchored on
   `docs/engineering/AKSHARA_ENGINEERING_CONSTITUTION.md` (Part 7B — Certification
   Engine; Part 8 — EOS) and the matching `*_CERTIFICATION.md` files (active in
   `docs/`, archived in `docs/archive/completed/`). Skip certified-and-unchanged
   areas.
3. Judge each in-scope certification category, check the Part 7B automatic-failure
   conditions, score engineering health, classify the release state.
4. Produce the evidence-based report per `.claude/skills/eos/USAGE.md`, write it to
   `docs/engineering/eos/`, append the run ledger, and render the gate verdict:
   **PASS / CONDITIONAL PASS / BLOCKED**.

This is the **explicit / manual** EOS entry point — it always emits the full
report. The **automatic, invisible** gate (run before work is declared complete,
surfacing only a one-line verdict) is defined in the project `CLAUDE.md`; see
`docs/engineering/ENGINEERING_GATE_POLICY.md`.
