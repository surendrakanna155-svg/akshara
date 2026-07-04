# Akshara Engineering Gate Policy

**Status:** ACTIVE · in force from 2026-06-27 until commercial launch
**Authority:** [AKSHARA_ENGINEERING_CONSTITUTION.md](AKSHARA_ENGINEERING_CONSTITUTION.md)
(Part 7B — *Engineering Gates*; Part 8 — *Final Engineering Law*)
**Enforced by:** the Engineering Operating System skill — `/eos`
(`.claude/skills/eos/`)

---

## One standard, one gate

There is **exactly one engineering standard** for Akshara going forward: the
**Engineering Constitution**. There is **exactly one engine** that enforces it:
the **EOS skill (`/eos`)**.

All earlier ad-hoc engineering checks, bespoke per-wave checklists, and
hand-rolled "is it ready?" reviews are **superseded** by the EOS gate. Do not
create new competing checklists. If a check matters, it belongs in the
Constitution and is applied by `/eos`.

## The mandatory gate

> **Nothing in Akshara is "complete" until the EOS has evaluated it and returned
> PASS.** (Part 8 — *Final Engineering Law*; Part 7B — *Engineering Gates*.)

This applies to **every remaining unit of work**:

- Every roadmap phase / wave
- Every QA wave and certification wave
- Every bug fix, refactor, enhancement, and migration
- Every new feature or module
- Every release decision (merge → QA → staging → pilot → production → commercial)

A unit of work is **done** only when `/eos <scope>` returns **PASS** (or
CONDITIONAL PASS with the named P1s tracked into a future wave) and no Part 7B
*Automatic Failure Condition* is live. Any open **P0** ⇒ **BLOCKED**, not done.

## How it runs alongside the focused skills

`/eos` is the umbrella gate; it orchestrates and does not replace:

| Skill | Role |
|-------|------|
| `/eos` | **The gate.** Evaluates all Constitution categories, scores health, classifies release state, blocks violations. |
| `/gap-check` | Deep code-level gap hunting (the EOS's detection arm). |
| `/certify` | Live N/N proof on the VPS + writes `*_CERTIFICATION.md` (the EOS's evidence arm). |
| `/deploy` | Ships verified changes to the VPS pilot. |
| `/release-review` | Narrow Eng/QA/Release go-no-go for a single batch/build. |

Standard lifecycle for any work item:

```
build → /eos <scope> → fix blockers → /certify → /deploy → /release-review → /eos (re-check) → done
```

## What this policy does NOT change

- It does **not** change the Constitution (that is the source of truth).
- It does **not** invent features or rewrite committed roadmap scope. The EOS
  *recommends* roadmap waves for gaps it finds; it does not reorder shipped plans.
- It does **not** re-open or re-audit completed, certified, unchanged work.
  Existing `docs/*_CERTIFICATION.md` remain valid as-is.

## The EOS-gate clause (paste into new/active roadmap & QA docs)

Every **active and future** roadmap, QA wave, or engineering-plan document must
carry this clause near the top. Completed/historical docs are left untouched.

```markdown
> **Engineering gate:** This plan is governed by the Engineering Operating
> System (`/eos`) per docs/engineering/ENGINEERING_GATE_POLICY.md. No phase,
> wave, or item here is "complete" until `/eos <scope>` returns PASS against the
> Engineering Constitution. The EOS is the only engineering standard for this
> work — do not add bespoke checklists.
```

## Where EOS evidence lives

- Reports: `docs/engineering/eos/EOS_<SCOPE>_<TYPE>_REPORT.md`
- Run ledger: `docs/engineering/eos/EOS_RUN_LEDGER.md`
- Existing live certs: `docs/*_CERTIFICATION.md` (unchanged; still valid)
