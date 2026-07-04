# EOS Usage Guide

How to drive the Engineering Operating System. The full operating contract is in
[SKILL.md](SKILL.md); this guide covers *when* to run it, *how* to scope it, the
*report templates*, and the *gate workflow*.

## When to run the EOS

The EOS runs **automatically and invisibly** before Claude declares work complete
(see the project [CLAUDE.md](../../../CLAUDE.md) and
[ENGINEERING_GATE_POLICY.md](../../../docs/engineering/ENGINEERING_GATE_POLICY.md)) —
developers do not invoke it by hand. Type **`/eos`** (or `/eos <scope>`) only when
you want a **full standalone report**.

It is **mandatory** (not optional) at every one of these moments:

- Before a **feature / module** is called "done".
- Before a **QA wave** or **certification wave** is marked complete.
- After a **bug fix, refactor, migration, or dependency change** that touches a
  live path.
- Before a **release decision** (merge / QA / staging / pilot / production /
  commercial) — see Part 7B *Engineering Gates*.
- Whenever someone asks "is X ready / complete / Constitution-compliant?",
  "what's our engineering health?", or "are we production / commercial ready?".

It is also safe to run anytime as a **read-only health check** — by default it
analyzes and reports; it does not change code.

## Scoping a run

Pass a scope so the EOS reads only what it needs (Part 7B — *Certification
Scope*):

| Scope you type | EOS evaluates |
|----------------|---------------|
| *(nothing)* | Platform-wide sweep across all 20 categories |
| a module name (`finance`, `attendance`) | That module: behaviour, RBAC, reliability, tests, docs… |
| a batch/wave id (`B12`, `QW1`, `Wave 3`) | That unit of work before it's marked complete |
| a category (`security`, `performance`, `localization`) | Just that Constitution category, platform-wide |
| a report name (`production-readiness`, `commercial-readiness`) | That specific report |
| a commit/branch | The diff's blast radius + affected categories |

If the scope is ambiguous, the EOS asks once, then proceeds.

## The run procedure (what happens)

1. **Anchor on truth** — read the relevant Constitution Part(s) via
   [CONSTITUTION_MAP.md](CONSTITUTION_MAP.md) and the matching
   `*_CERTIFICATION.md` files (active in `docs/`, archived in
   `docs/archive/completed/`). Certified-and-unchanged areas are skipped.
2. **Gather evidence** — gates (`flutter analyze`, `flutter test`), coverage,
   widget/integration/Patrol tests, `scripts/qa/live_cert_*.py` /
   `scripts/*_smoke.sh`, RBAC route inventory, security/perf artifacts, live VPS
   results. Delegates to `/gap-check` (code gaps) and `/certify` (live proof).
3. **Judge each category** against its Part's Acceptance Criteria + Failure
   Conditions → PASS / FAIL / BLOCKED / N/A with evidence.
4. **Apply automatic-failure conditions** (Part 7B) — any one = instant FAIL.
5. **Score health + classify release state** (Part 8).
6. **Write the report + render the gate verdict.**

## Report template

Every EOS report is **evidence-based** and follows this shape. Cite the
Constitution — never paste its text in.

```markdown
# EOS <Report Type> — <Scope>
**Date:** <YYYY-MM-DD>  ·  **Scope:** <feature/module/wave/release>
**Release state:** <Not Ready | Development | QA | Pilot | Production | Commercial | Blocked>
**Gate verdict:** <PASS | CONDITIONAL PASS | BLOCKED>

## Engineering health (scores guide; they never approve a release)
| Category | Score | Verdict | Evidence |
|----------|-------|---------|----------|
| Architecture (Part 2A) | n/100 | PASS | <file:line / gate> |
| … (the 20 categories) | | | |
| **Overall** | n/100 | | |

## Findings (each follows Part 8 — Gap Discovery fields)
### [P0] <title>
- **Rule failed:** Part <X> — <section>
- **Why:** <criterion not met / failure condition triggered>
- **Evidence:** <file:line / gate output / failed N/N / log>
- **Business impact / Engineering impact:** <…>
- **Recommended fix:** <direction, not full implementation>
- **Estimated effort · Dependencies · Suggested owner:** <…>
- **Suggested roadmap wave:** <where it belongs, safe order>

## Automatic-failure check (Part 7B)
<none triggered | which one + evidence>

## Gate result (Part 7B — Engineering Gates / Release Rules)
<PASS/BLOCKED + the specific blocking items; open P0 count>

## Skipped (already certified + unchanged)
<area → cert doc>
```

Tailor the section emphasis to the report type requested:

- **Engineering Gap Report / QA Gap / Security Gap / Reliability Gap** — lead
  with findings for that category.
- **Production Readiness / Commercial Readiness** — lead with the release-state
  classification + the blocking P0/P1 list.
- **Feature / Module Certification Report** — judge every category for the
  scope; only "CERTIFIED" when all mandatory gates pass.
- **Roadmap Update Recommendations** — group findings into safe-ordered waves
  (Part 8 — *Automatic Roadmap*); do not change existing committed scope.
- **Executive Engineering Summary** — one page: health scores, release state,
  top blockers, recommended next wave.

## Output locations

- Reports → `docs/engineering/eos/EOS_<SCOPE>_<TYPE>_REPORT.md`
- Run ledger (one line per run) → `docs/engineering/eos/EOS_RUN_LEDGER.md`
  (date · scope · gate verdict · open P0/P1 · report path)

## The gate workflow (how a thing gets to "done")

```
build it → /eos (gate) → fix blockers → /certify (live proof) → /deploy → /release-review → done
              ↑                                                                        |
              └──────────────── re-run /eos on any change (continuous) ───────────────┘
```

- **EOS BLOCKED** ⇒ not done. Fix the P0s, re-run.
- **EOS CONDITIONAL PASS** ⇒ proceed only with the named P1s tracked into a
  roadmap wave.
- **EOS PASS** ⇒ eligible for the next gate (QA / staging / pilot / production /
  commercial per Part 7B).

See [EXAMPLES.md](EXAMPLES.md) for concrete invocations.
