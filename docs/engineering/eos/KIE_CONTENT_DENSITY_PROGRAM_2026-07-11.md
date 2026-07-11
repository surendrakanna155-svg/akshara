# KIE Content Density Program — AI OFF

**Date:** 2026-07-11
**Goal:** Raise deterministic content density so a real teacher can generate a supported paper and
give it to students **without writing missing questions or answer keys** — the explicit exit target,
measured honestly. Engine architecture frozen; governed content lanes; no fabrication; AI off.
**Branch:** `feature/qp-content-readiness` (commits `21c…`→ this report). Full KIE suite green throughout.

---

## Honest bottom line (measured)

**Full teacher-ready papers on the current certified corpus: still 0 of 57.** Printed deterministic
content rose from 69 → **74 blueprint positions (5.0% of 1480)**; 37 scopes print a clean-but-short
paper; all output-integrity gates remain 0. **The exit target is NOT met, and it cannot be met on the
current corpus** — because the certified corpus is JEE/NEET *problem-oriented* material, and full papers
need *definitional* content (for descriptive answers) and *conceptual distractors* (for MCQs), neither
of which this corpus contains.

This program did everything achievable on the existing corpus (Phases 1–3, near their ceiling) and
**proved, with measurements, the exact remaining lever: ingesting definitional board/NCERT Class-X
textbooks (Phase 4) + a conceptual-MCQ mechanism.** Those are scoped efforts that mutate the certified
corpus and require sanctioned engine capabilities — flagged below for a deliberate go-ahead rather than
run hastily (which would violate *governed / never-fabricate / recovery-first*).

---

## Per-phase results (measured, committed)

### Phase 1 — Grounded definition backfill ✅ (improved; corpus-capped)
Rebuilt the definition miner (`kie/curate/enrich.py`, content lane, provenance preserved) with
precision-first recall gains: subject after a leading article ("**The** refraction is …"), the common
textbook copula "is/are a/an/the **<definitional-head-noun>**" (rejects usage/example sentences),
evidence-backed aliases, and a **fix** to a latent bug — the title-oriented OCR heuristic
(`sanitize._looks_like_ocr_garbage`) false-positived on ordinary words like "**passes**"/"assess"
(repeated-letter ratio) and was silently killing valid definitions per sentence.

- **Usable definitions on the current corpus: 15 → 21 (+40%).** Small in absolute terms **because the
  corpus is problem-oriented** (measured: only ~2% of definition-needing concepts have a clean "X is …"
  sentence in these dense JEE/NEET PDFs).
- **Decisive experiment:** the same miner on a **definitional textbook** (TS Class 10 Physical Science,
  306 pp) surfaces **~15–18 clean concept definitions** ("Resistance is the opposition that a substance
  offers to the motion of electrons", "Electric power is the product of potential difference and the
  current", "Light is an electromagnetic wave"). The miner is now the tool that converts definitional
  content into descriptive answer keys — it just needs that content (Phase 4).

### Phase 2 — Distractor / misconception bank ⛔ corpus-blocked (reported honestly, nothing fabricated)
Audited every deterministic source for conceptual-MCQ distractors:
- `concept_edges`: **0** `confused_with` edges (only related/parent_child/prerequisite).
- `common_misconceptions` column: **0** populated. `distractors` table: **0** rows.
- `question_patterns`: store a stem *skeleton*, **no** answer options / marked-correct.
- chunks with explicit misconception language ("common misconception", "often confused with", …):
  **~14 total** across 33,870 chunks — not a usable source.

**Conclusion:** the substrate is ready, but the current corpus has **no mineable distractor evidence**.
Building a conceptual-MCQ bank deterministically would require fabrication (forbidden) or new content.
**A grounded mechanism that WOULD work** (and is the recommended path): a *definition-match* MCQ —
"Which of the following is defined as: `<grounded definition>`?" with the correct option = the concept
and 3 distractors = **sibling concepts from the same chapter/graph** (plausible, distinct, verifiably
wrong). This converts every defined concept into a valid MCQ using only grounded data — but it needs a
sanctioned objective-materializer capability (definition + graph siblings passed to MCQ construction),
which is an engine change deferred here to respect the freeze.

### Phase 3 — Computable coverage expansion ✅ (near-exhausted)
Added, in measured batches, solver-verified families for the corpus's real computable concepts
(`kie/curate/templates_ext.py`): earlier batch of 10 (Equilibrium Kc, Probability, Integers, Magnetic
Flux, Circles, gravitational force, Perimeter, Triangle, Parallelogram, Median) + this program's 4
(Magnetic Force F=BIL, Electric Current I=Q/t, Force of Friction f=μN, Cuboid Volume). **Family library
80 → 94.** Objective fill 2.2% → **4.7%**; printed positions 69 → **74**. This **near-exhausts the
cleanly-computable concept set** — the remaining uncovered objective concepts are conceptual, not
formula-computable, and correctly stay specs (per the directive: optimise filled positions, not count).

### Phase 4 — Board corpus readiness ✅ AUDIT done · ⏸ full ingest = scoped go-ahead
**Corpus support audit (measured):** the certified KIE holds **only** JEE/NEET/NCERT-foundation content
(`concept_board_mappings` 100% FOUNDATION; source_documents all NEET/JEE/NCERT). So the current
Class-X board fail-closed (from the prior remediation) is correct.

**Verified board source ON DISK, not yet ingested** (`resources/curriculum/`):
- **Telangana SCERT Class 10:** Physical Science, Biological Science, Mathematics textbooks (direct PDFs, parse-clean, definitional).
- **CBSE / NCERT Class 10:** NCERT textbooks + CBSE sample papers & marking schemes.
- **AP SCERT:** mostly Class 6–8 (limited Class-10 science).
- CBSE Class-X blueprint JSONs already present (`knowledge/blueprints/cbse_classX_*`).

**Feasibility proven** (PDF parse works; miner yields ~15–18 defs/textbook). **Why the full ingest is
flagged, not executed here:** it (a) mutates the **certified corpus** via the Intake Center (governed,
semi-irreversible), (b) re-invokes the noisy Phase-5 concept extractor (needs the same cleanup cycle),
(c) requires **new board exam profiles in the engine** (`presets.py`/`engine.py`, frozen) to make board
scopes generable, and (d) even then, **board MCQ sections still need the Phase-2 definition-match
mechanism** to be full. Running it hastily would violate *governed / never-fabricate-mappings /
recovery-first*. It is the right next effort — done deliberately, with the engine-capability decisions
below.

### Phase 5 — Output re-certification ✅ (honest)
Same 57-paper / AI-OFF audit (`scripts/reports/qp_output_audit.py`):

| Metric | Prior remediation | This program |
|---|---|---|
| Printed deterministic positions | 69 | **74** (5.0%) |
| Papers that print clean (0 rewrite of what's printed) | 36 | **37** |
| Full teacher-ready papers (≥90% blueprint) | 0 | **0** |
| Student-facing specs / optionless MCQ / OCR artifacts / junk / board-misuse | 0 | **0** |

Full-paper completion **by exam/subject/blueprint = 0 across the board** — the descriptive sections lack
definitions, the MCQ sections lack distractors. Honest and unfabricated.

---

## What it will take to reach FULL teacher-ready papers (the real roadmap)

The exit target requires BOTH halves of a paper to fill. Neither is possible on the current corpus:

1. **Descriptive sections → definitions.** Ingest the definitional board/NCERT Class-X science & math
   textbooks (on disk) via the governed Intake Center; the improved Phase-1 miner then yields the keys.
   *Board blueprints are descriptive-heavy, so this fills a large fraction.* — **scoped data ingestion.**
2. **Objective (MCQ) sections → grounded distractors.** Implement the **definition-match MCQ**
   mechanism (concept + grounded definition + 3 graph-sibling distractors). This is the single highest-
   leverage capability: it turns every defined concept into a valid MCQ with zero fabrication. — **needs
   a sanctioned objective-materializer capability (engine).**
3. **Board scopes → engine profiles.** Add real CBSE/AP/TS board exam profiles + board/class/subject
   mappings, and lift the Class-X fail-closed for boards that have certified corpus. — **engine config.**

With (1)+(2)+(3), a **CBSE/TS Class-X Science** paper (descriptive-heavy + definition-match MCQs) is the
first realistic **full** teacher-ready target. All-MCQ **NEET/JEE** remain the hardest (no descriptive
sections; every item is a conceptual MCQ) and depend entirely on (2) at scale.

**Owner decisions needed before the next execution round:**
- Authorize mutating the certified corpus via the Intake Center to ingest board/NCERT Class-X content.
- Authorize the two sanctioned engine capabilities: board exam profiles, and the definition-match MCQ
  materializer (both are additive, not a redesign of the deterministic pipeline).

---

## Branch reconciliation (verified — no work lost)

`feature/qp-content-readiness` and `feature/data-reliability-platform` have **zero overlapping changed
files** (merge-base `b43a2db9`): this lane touches only `curriculum/scripts/intelligence/kie/**`,
`curriculum/scripts/reports/**`, `curriculum/reports/**`, `docs/engineering/eos/**`; the other lane
touches `lib/**`, `supabase/**`, `test/golden/**`. A merge is **conflict-free**. Both branches are
preserved. Because the other lane is actively worked (HEAD has bounced between branches this session),
run the reconciliation at a clean point:

```
git checkout feature/data-reliability-platform      # ensure its worktree is clean/committed first
git merge --no-ff feature/qp-content-readiness       # conflict-free (disjoint files)
```

Nothing is force-pushed or overwritten; `feature/qp-content-readiness` stays intact as the record.

---

## Bottom line

Phases 1–3 extracted everything the current corpus deterministically allows (definitions 15→21,
families 80→94, printed 69→74) and Phase 5 measured the result honestly: **still 0 full teacher-ready
papers**, because the corpus is problem-oriented, not definitional, and has no distractor evidence. The
program **proved the exact path** to full papers — ingest definitional board/NCERT Class-X content
(Phase 4) + a definition-match MCQ capability + board engine profiles — and teed it up with measured
evidence. Per the directive, completion is **not declared**: the full-paper target is measured (0) and
its blockers and roadmap are documented for a deliberate, owner-authorized next round. Engine remains
frozen; nothing fabricated.
