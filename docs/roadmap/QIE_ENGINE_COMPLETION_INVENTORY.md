# QIE Engine — Completion Inventory (offline, no-API path)

**Purpose:** consolidate *exactly what we already have*, mark **COMPLETE / PARTIAL / MISSING**, and name the
**minimum glue** to generate **one high-quality certified question completely offline** — using the existing
engine plus **Claude (in VS Code)** and **ChatGPT Max** as the interactive LLM steps. **No redesign. No new
infrastructure. No API. No cloud. Reuse everything.**

---

## 0. The premise correction that changes everything

The engine is **worksheet-in / verdicts-out**. Every place an LLM is needed, the engine writes a prompt file and
reads back a JSON file. The `execution/` layer (OpenAI/Anthropic/OpenRouter) is an **optional automation** of
that file exchange — **not a dependency.** `run_generation.py` says so in its own comment: *"thin file helpers
so an external generator/judge agent can round-trip via the scratchpad … the manual fallback."*

**So the LLM is us:** Claude and ChatGPT Max fill the worksheets by hand. **No API, no dollars, no cloud.**

## 1. The full pipeline — every stage, and who does it

```
STAGE                         FUNCTION (exists)                         WHO / COST
─────────────────────────────────────────────────────────────────────────────────────────
1 plan concepts→specs         run_planner.plan(subject,classes)         deterministic · $0
2 write generator brief       run_generation.write_brief                deterministic · $0
3 GENERATE candidates         (fill brief)                              ← Claude (LLM) · $0
4 ingest candidates           run_generation.ingest_candidates          deterministic · $0
5 gates + sympy solve         run_generation.verify → validate_run.run  deterministic · $0  ← kills most defects free
6 write solution worksheet    solutions.write_worksheet (survivors)     deterministic · $0
7 CONSTRUCT solutions+distr.   (fill worksheet)                         ← Claude (LLM) · $0
8 verify solution+distractor  solutions.ingest (sympy re-executes)      deterministic · $0
9 write judge worksheet       judge.write_worksheet (blind, +controls)  deterministic · $0
10 JUDGE (examine)            (fill worksheet)                          ← ChatGPT Max (LLM) · $0
11 ingest verdicts            run_generation.ingest_judgements          deterministic · $0
12 CERTIFY                    run_generation.certify → certify_run      deterministic · $0
13 report certified           run_generation.report                     deterministic · $0
```

**Three LLM touchpoints (3, 7, 10). Everything else is deterministic and free.** The heavy correctness work —
sympy re-derivation of the answer, solution-terminates-on-locked-key, every distractor's mis-relation
re-executed, dedup, dimensional/depth/grounding gates — is **all in the deterministic stages**.

## 2. Inventory — COMPLETE / PARTIAL / MISSING

### ✅ COMPLETE (built, tested, reusable as-is)
| # | Component | Where |
|---|---|---|
| 1 | Certified concept substrate — 2,009 concepts w/ `boundary` (in/out-of-scope) + prerequisites + class + subject | frozen `knowledge_index.db` |
| 2 | Generator contract/brief — demands falsifiable `structure` (givens/relation/solve_for), forbidden-terms boundary, depth≠difficulty | `factory/plan.py` (`brief`/`compact_brief`) |
| 3 | Candidate ingest, provenance-gated (rejects placeholders) | `run_generation.ingest_candidates` + `corpus.ingest` |
| 4 | Deterministic gate battery + controls + **sympy independent solve** (rel_tol 0.02) + cross-run dedup | `validate_run.run` + `gates.py` |
| 5 | Solution stage — key **locked first**, then solution constructed; deterministic `solution_verified` + `distractor_verified` (each mis-relation re-executed) | `factory/solutions.py` |
| 6 | Blind cross-family **judge** — student-view worksheet, seeded known-bad controls, independence COMPUTED | `factory/judge.py` |
| 7 | **Certify decision** — gates AND sympy-agree AND solution AND distractor AND cross-family judge-accept | `certify.certify_run` |
| 8 | Store — one product bank, guarded transitions, dedup UNIQUE, provenance/telemetry (RI-6/8/9) | `factory/corpus.py` |
| 9 | Manual file round-trip helpers (`write_brief`, `load_json_array`, `solutions.write_worksheet`, `judge.write_worksheet`) | across the factory |
| 10 | Exam-path planner (JEE/NEET, Exam-DNA-driven, deterministic) | `run_planner.plan_blueprints` |

### 🟡 PARTIAL (exists, but a seam for the offline/cohort path)
- **P1 — subject/class spec persistence.** `run_planner.plan(subject, classes)` *produces* specs for a
  hand-picked cohort (e.g. Class-6 Mathematics), but only the **exam** path persists to `generation_spec`
  (via `blueprint_store.save_blueprints`). The subject path's `build_specs` output needs the **same one-step
  insert**, mapped to the `generation_spec` columns. *(Small field-map, reuses the existing table + pipeline.)*
- **P2 — provenance bundle for a manual (Claude / ChatGPT Max) actor.** `ingest_candidates` / `ingest_judgements`
  require `{model, model_version, prompt_sha256, actor, contract_version}` and reject placeholders. Filling it
  **honestly** (Claude *is* a real model; `prompt_sha256 = plan.brief_sha256(brief)`) is a few lines — the
  executor produces this automatically, the manual path needs a tiny honest-fill helper.

### 🔧 MISSING (the true minimum — all thin glue over existing functions, no new infra)
1. **A subject-path spec persister** (P1) — map `build_specs` specs → `generation_spec` insert. ~1 small function.
2. **An honest manual-provenance helper** (P2) — assemble the Claude/ChatGPT-Max bundle. ~a few lines.
3. **A manual-run driver** — sequences the existing functions (steps 1–13 above), dropping the three worksheet
   files to the scratchpad and reading back the three JSON files we fill. **Glue only** — it calls existing
   functions in order; it invents nothing. (The API executor already chains these; this is the file version.)

**That is the entire gap.** No API, no cloud, no schema change, no gate change, no redesign. The engine is
~90% built; the missing ~10% is offline glue + honest provenance.

## 3. The cross-family unlock — real certification, offline, $0

Certification requires the judge's model family ≠ the generator's family (`certify.py` independence, R2-1). We
have two *different* families available as interactive tools:

- **Claude (anthropic family)** → generator (step 3) + solution author (step 7)
- **ChatGPT Max (openai family)** → blind judge (step 10)

`certify_run` computes `cross_family = judge_family != generator_family` → **TRUE** → a genuine, product-visible
**`certified`** row — **with zero paid inference.** (Roles can swap.) This is why no API is needed: *the two
independent families are already sitting in the owner's editor.*

## 4. The offline loop to certify ONE question (all existing functions)

1. `plan("Mathematics", run_id, classes=[6])` → specs (simplest-first) → **persist to `generation_spec`** (P1).
2. `write_brief(specs, "brief.txt")` → **Claude** returns `candidates.json` (structure mandatory).
3. `ingest_candidates(candidates, prov=Claude-honest)` (P2).
4. `verify(run)` — controls + gates + sympy independent solve. Survivors only continue. *(deterministic)*
5. `solutions.write_worksheet(survivors)` → **Claude** returns `solutions.json` → `solutions.ingest` (sympy
   verifies solution + every distractor's mis-relation). *(deterministic verification)*
6. `judge.write_worksheet(survivors)` → **ChatGPT Max** (cross-family) returns `verdicts.json` →
   `ingest_judgements(prov=ChatGPT-honest)`.
7. `certify(run)` → `report(run)` → **the certified question, with its full evidence chain.**

Inspect everything at every step (the whole point of E1): the store keeps each candidate's gate results,
independent-solve verdict, solution/distractor gates, and judge verdict — content-bound and readable.

## 5. Guardrails honored

No redesign · no new infrastructure · no API · no cloud · **certification law untouched** (we *use* `certify_run`,
we do not change it) · gates never weakened · fixes (when iterating) go into the **generator/prompt/planner**,
never the oracle. The engine is *finished*, not rebuilt.
