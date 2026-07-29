# QIE — Capability Dependency Map

**Date:** 2026-07-29 · **Purpose:** identify which work unlocks the highest number of downstream
capabilities. **Optimised for long-run capability gain, not engineering effort.**
**Evidence base:** repository inventory audit + the integration proof-of-impact experiment.

---

## 1. The dependency graph

```
                          ┌──────────────────────────────────┐
                          │  OPERATORS  (9 today)            │
                          │  polynomial calculus only        │
                          └───────────────┬──────────────────┘
                                          │ HARD BLOCK
                    ┌─────────────────────┴─────────────────────┐
                    ▼                                           ▼
        ┌───────────────────────┐                  ┌────────────────────────┐
        │ SENIOR MATHS BINDINGS │                  │ MULTI-STEP CHAINS      │
        │ (0 today)             │                  │ beyond depth 3         │
        └───────────┬───────────┘                  └───────────┬────────────┘
                    │                                          │
                    ▼                                          ▼
        ┌───────────────────────┐                  ┌────────────────────────┐
        │ JEE MAIN MATHS (33%)  │                  │ HARD DIFFICULTY BAND   │
        │ JEE ADV MATHS         │                  │ (0 items today)        │
        └───────────────────────┘                  └────────────────────────┘


                          ┌──────────────────────────────────┐
                          │  FORMULAS / RELATIONS            │
                          │  41 certified + 86 code          │
                          │  317 names WITHOUT expressions   │
                          └───────────────┬──────────────────┘
                                          │ HARD BLOCK
                    ┌─────────────────────┼─────────────────────┐
                    ▼                     ▼                     ▼
        ┌───────────────────┐  ┌────────────────────┐  ┌──────────────────┐
        │ NUMERIC BINDINGS  │  │ CONCEPTUAL MCQ     │  │ MATCH / AR       │
        │ (relation-backed) │  │ (falsification)    │  │ (relation pairs) │
        └─────────┬─────────┘  └─────────┬──────────┘  └────────┬─────────┘
                  └──────────────────────┼──────────────────────┘
                                         ▼
                          ┌──────────────────────────────────┐
                          │  BINDINGS  (36 today)            │
                          │  THE OUTPUT BOTTLENECK           │
                          └───────────────┬──────────────────┘
                                          │
        ┌─────────────────┬───────────────┼───────────────┬─────────────────┐
        ▼                 ▼               ▼               ▼                 ▼
  ┌───────────┐   ┌─────────────┐  ┌───────────┐  ┌────────────┐  ┌──────────────┐
  │ CONCEPT   │   │ QUESTION    │  │ BENCHMARK │  │ QUESTION   │  │ PAPER        │
  │ COVERAGE  │   │ VOLUME      │  │ %         │  │ DIVERSITY  │  │ ASSEMBLY     │
  └───────────┘   └─────────────┘  └───────────┘  └────────────┘  └──────────────┘


   ══════════ INTEGRATION LAYER — MULTIPLIERS, NOT SOURCES ══════════
   (proved by experiment: moves 0 output metrics on its own)

   PREREQ GRAPH ──────► composition legality ──► coherent multi-concept questions
     [DONE]              (−23.4% bad pairs)      (pays off as bindings scale)
        │
        └──────────────► prerequisite depth ───► principled difficulty driver
                                                 (needs difficulty-model change)

   GOVERNED FACTS ────► distractor grounding ──► conceptual-MCQ quality
   (1,424 KC-native)    scenario context         (quality, not volume)

   PYQ FREQUENCY ─────► concept selection ─────► authenticity of WHICH concepts
                        weighting                (needs bindings to reorder)

   EXAM WEIGHTS ──────► paper proportions ─────► exam-authentic assembly

   WRITE-BACK ────────► cross-run dedup ───────► cumulative bank
                        reuse, coverage report   (compounding, not immediate)


   ══════════ QUESTION-TYPE LAYER — INDEPENDENT OF THE ABOVE ══════════

   INTEGER/NUMERIC-ENTRY ──► JEE Main 5/25 per subject · JEE Adv
   MULTI-CORRECT ──────────► JEE Advanced core format
   PARAGRAPH ──────────────► JEE Advanced · comprehension
   MATRIX MATCH ───────────► JEE Advanced
   STATEMENT-BASED ────────► JEE Main staple

   ══════════ REASONING ENGINE — GATES THE HARD BAND ══════════

   INDIRECT / HIDDEN / TWISTED ──► hard difficulty ──► JEE Advanced credibility
        (nothing exists today)
```

---

## 2. Unlock scoring

**Downstream count** = how many distinct capabilities become possible or materially better.
**Blocking** = whether other work is *impossible* without it.

| Rank | Work item | Downstream unlocks | Blocking? | Evidence |
|---|---|---|---|---|
| **1** | **Operator registry expansion** (9 → trig, log/exp, vectors, matrices, probability, limits) | **7** — senior Maths bindings · JEE Main Maths (33% of paper) · JEE Adv Maths · depth-4+ chains · hard band · multi-concept Maths composition · Maths conceptual MCQ | **YES — hard block** | 0 senior-Maths bindings exist and none can be authored with 9 polynomial operators |
| **2** | **Bindings** (36 → several hundred) | **6** — concept coverage · question volume · benchmark % · diversity · paper assembly · makes every integration pay | Partially — gated by #1 and #3 | Experiment proved output moves *only* with bindings |
| **3** | **Formula/relation expansion** (41+86 → 300+) | **5** — numeric bindings · conceptual MCQ · match · AR · Physics/Chemistry breadth | **YES for Phys/Chem** | 317 formulas carry no expressions; must be re-derived |
| **4** | **Reasoning engine** (indirect / hidden / twisted) | **3** — hard band · JEE Advanced credibility · question diversity | **YES for JEE Adv** | 0 hard items ever produced; depth ≠ difficulty |
| **5** | **Question types** (integer, multi-correct, paragraph, matrix, statement) | **3** — JEE Main format completeness · JEE Adv format · NEET unaffected | Independent | 8 of 15 types missing; 5 unmodelled in `QuestionType` |
| **6** | **Write-back** | **3** — cross-run dedup · cumulative bank · coverage reporting | No | Compounding value; nothing exists today |
| **7** | **Governed facts bridge** | **2** — distractor grounding · scenario richness | No | Quality, not volume (pre-registered) |
| **8** | **Prereq graph** ✅ DONE | **2** — composition legality · difficulty driver | No | **Measured: 0 output change, −23.4% bad pairs** |
| **9** | **PYQ frequency / exam weights** | **2** — concept selection · paper proportions | No | Needs bindings to have anything to reorder |
| **10** | **Figures / diagrams / chem structures** | **3** — figure questions · organic chemistry · biology diagrams | **YES for those forms** | `figure_element`/`figure_link` empty; XL effort |

---

## 3. The critical path

```
OPERATORS ──► SENIOR MATHS BINDINGS ──► JEE MAIN MATHS (33% of the paper)
    │
    └──► DEPTH-4+ CHAINS ──► HARD BAND ──► JEE ADVANCED credibility
```

**The operator registry is the single highest-leverage item in the entire programme.** It is a hard
block on the largest identified gap (senior Mathematics at absolute zero), and simultaneously on the
depth needed to reach the hard band. Nothing downstream of it can proceed, and no amount of authoring
effort substitutes for it.

Second path, independent and parallelisable:

```
FORMULA RE-EXTRACTION ──► PHYSICS + CHEMISTRY BINDINGS ──► NEET content
```

---

## 4. What integration does and does not buy — now measured

| | |
|---|---|
| **Proved** | Integration moves **zero** output metrics. Generated items, concepts used, depth, difficulty, and both benchmark percentages were unchanged to the digit. |
| **Also proved** | Integration removed **2,608 incoherent concept pairs (−23.4%)** the planner would previously have accepted. Real, and invisible in today's output because today's output is 36 hand-made bindings. |
| **Conclusion** | Integration is **insurance on future authoring**. Its value scales with binding count. At 36 bindings it is worth almost nothing; at 500 it is worth a great deal. |

---

## 5. Recommended sequence

| Phase | Work | Why here |
|---|---|---|
| **Phase 1** | **Operator registry expansion** | Hard block on the highest-value gap. Nothing else unblocks senior Maths. |
| **Phase 2** | **Senior Maths bindings** + **formula re-extraction** (parallel) | Directly moves the benchmark; formula work unblocks Phys/Chem authoring in parallel |
| **Phase 3** | **Bindings at scale**, with **write-back** shipped alongside | Write-back must exist before volume, or the volume is not cumulative |
| **Phase 4** | Question types (integer → statement → multi-correct → paragraph → matrix) | Format completeness; integer-entry first (cheapest, JEE Main requires it) |
| **Phase 5** | Reasoning engine (indirect / hidden / twisted) | The only route to a credible hard band |
| **Deferred** | Figures, chem structures, biology diagrams, psychometrics | XL effort, and gated on authorisation or data that does not exist |
| **Opportunistic** | Remaining integrations (facts, PYQ, exam weights) | Each ships with its own proof-of-impact run |

---

## 6. Honest note on this map

The experiment changed one thing about my earlier advice and confirmed the rest.

**Confirmed:** authoring is the bottleneck; integration is a multiplier.
**Changed:** I had ranked the prerequisite graph as "the highest-value quick win". Measured, it is a
**quality guard**, not a capability unlock — genuinely useful, correctly sequenced early because it is
cheap and safe, but it moved no output metric and was never going to.

**The item I under-weighted throughout is the operator registry.** It appears in no earlier report as a
top-line blocker, yet it is the only item that hard-blocks both the largest coverage gap (senior
Mathematics, 0 bindings) and the hardest capability gap (depth-4+ chains → hard band). It should have
been P0-1 from the beginning.
