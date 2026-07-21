# QIE — fresh-session handoff (authoritative resume point)

> ✅ **R1 CERTIFICATION HALT LIFTED (2026-07-21).** Phase **R1** of the remediation roadmap is
> COMPLETE — the 4 P0s (C0/C1/C2/C3) + the freeze P0 (C6) are closed, adversarially verified,
> and live on the newly-promoted **v1.5** index (certified 2023→2009; 14 broken-evidence
> concepts quarantined). A single controlled certification run is now permissible on the
> repaired machinery. **⛔ SCALING generation still gates on Phase R2** (independence +
> mandatory solution stage). Recall of the 22+7 (R0-2) + re-certification remain owner/model
> steps. See [`QIE_REMEDIATION_EXECUTION_LOG.md`](QIE_REMEDIATION_EXECUTION_LOG.md) and
> [`QIE_REMEDIATION_ROADMAP.md`](QIE_REMEDIATION_ROADMAP.md). §7 below is pre-remediation.

> ⏭ **PARTIALLY SUPERSEDED (2026-07-20).** This handoff (2026-07-15) reflects the pre-pivot state
> (Decisions A/B). The QIE lane has since pivoted to **Owner Decision C / the Question Planning Layer** —
> read [`QUESTION_PLANNING_LAYER_ROADMAP.md`](QUESTION_PLANNING_LAYER_ROADMAP.md) and
> [`CERTIFIED_KNOWLEDGE_INDEX_AND_QDI.md`](CERTIFIED_KNOWLEDGE_INDEX_AND_QDI.md) **first**, then use the
> environment/lineage detail below. See [`README.md`](README.md) for the full lane map.

**Date:** 2026-07-15 · **Branch:** `feature/qp-content-readiness` · **Tip:** `94b74162` · **Working tree:** clean
on the QIE lanes · **Tests:** 645 green (`python -m unittest discover -s kie/tests`)

**Read this instead of re-auditing.** Everything below is committed and verified. Do NOT re-derive it.

---

## 1. Environment (exact)
- Python venv: `curriculum/.venv/bin/python` (3.14). Run modules from `curriculum/scripts/intelligence/`
  (so `import kie` resolves), e.g. `cd curriculum/scripts/intelligence && ../../.venv/bin/python -m unittest discover -s kie/tests`.
- Deps present: PyMuPDF 1.28, sympy 1.14, PIL. No network needed.
- Lanes: this worktree = **K (QIE) lane**. The ERP lane is a *separate* worktree (`Akshara_ERP-drp`) — do not
  touch it. Check `git branch --show-current` before every commit.
- ⚠ Other lanes leave files dirty in `curriculum/` and `docs/` (`PROVENANCE_MANIFEST.json`, `configs/`,
  `discovery/`, `reports/`, `scripts/download/`, `docs/roadmap/`, `docs/execution/`). They are **not yours** —
  stage QIE paths explicitly, **never `git add -A`**.

## 2. Locked scope (unchanged)
**In scope:** JEE Main, JEE Advanced, NEET, NCERT/CBSE 6–10 Math & Science, NCERT/CBSE 11–12 Math/Physics/
Chemistry/Biology. English only.
**HELD (do not start):** Classes 1–5, AP/TS/ICSE/other state boards, broader school-exam work, broad new
acquisition, Question-Bank promotion/materialization.
**Frozen:** `kie/qpgen/` internals (integrate only through `kie/qie/qp_bridge.py`), `kie.db` (read-only),
the pilot bank (not promoted).

## 3. Owner decisions (locked — do not re-litigate)
- **Decision A (RESOLVED):** verified governed facts and certified relations are *first-class in-scope
  concepts* for the qpgen boundary, guarded by the deterministic subject gate + `sanitize.is_clean_concept`.
  Extended to **certified chains** (`996d65db`), which compose already-certified relations and assert no new
  knowledge.
- **Decision B (RESOLVED + IMPLEMENTED `15feaea2`):** the qualitative lane binds at **TOPIC** granularity —
  the smallest genuine curriculum concept the verified evidence supports (`Biology :: Uricotelism`) — with
  **short authored** topic names, the same subject + sanitizer guards, and a **chapter fallback**. Owner's two
  prohibitions are enforced *mechanically*, not by convention (§5, `kie/qie/convert/topics.py`).
- **Standing law:** wrong knowledge is worse than missing knowledge. Never weaken a gate for yield. LLM
  **proposes**; deterministic checks **certify**. No source-question cloning.

## 4. Measured state (seed 7, `boundary_ok`, 0 violations, 0 forced fills)

| exam | qie-servable | **filled** | % | **hard filled** |
|---|---|---|---|---|
| NEET | 180 | **103** | 57% | **5 / 40** |
| JEE Main | 75 | **53** | 70% | **7 / 15** |
| JEE Advanced | 30 (+3 `match` → authoring) | **25** | 83% | **7 / 12** |

NEET by subject: Physics **33**/45 · Chemistry **22**/45 · Biology **48**/90.
Session trajectory: NEET **38 → 103** · JEE Main **29 → 53** · JEE Advanced **17 → 25**.

```python
from kie.qie import qp_bridge as QB; from kie.qpgen.models import PaperRequest
paper, report = QB.generate_paper(PaperRequest(exam="NEET", seed=7), per=18)
filled = [s for s in paper.slots if s.status == "filled"]     # paper.warnings names every shortfall
```
⚠ **`per` is inert.** qpgen dedups by `(concept, question_type)` and `used_ct` is **global across the paper**,
so exactly ONE item lands per concept per type: `per=18/30/60` give identical papers. **Coverage scales with
DISTINCT CONCEPTS, nothing else.** `paper.warnings` is the only honest progress metric.

## 5. What exists (committed, working)

### Governed TOPIC layer — `kie/qie/convert/topics.py` (decision B)
`python -m kie.qie.convert.topics [set] [--apply] [--coverage]`. The LLM proposes a topic; deterministic gates
certify it: **PRESENT · NOT_TRUNCATED · SANITIZER · SUBJECT · GROUNDING · NOT_CHAPTER**.
- **GROUNDING** = every significant topic word must occur in *that fact's own verified evidence*. This is what
  forbids inventing a name to buy a dedup slot ("Nitrogen excretion strategy", "VSEPR theory" → REFUSED).
- **NOT_TRUNCATED** = every significant word must survive `_clean_title`, so prose cut to 5 words is refused.
- Refused topic → the fact keeps its **chapter** binding (strictly additive; coverage can never drop).
Committed sets: `topic_sets/backfill_v1.json` (92) · `topic_sets/bio_batch3.json` (36).
Wired into the admission path (`register._certify_topic`) + `examiner.TOPIC_BRIEF`, so **new** facts carry
topics from the start. **Bindable concepts: Biology 89 · Chemistry 27 · Physics 11** (was 27/20/11 chapters).

### Governed qualitative conversion — `kie/qie/convert/`
`docmeta` → `candidates` → `examiner` (cached by item_hash) → `register` → `kvs_compose` (BOTH assertion
directions + option-quality gate). **128 verified facts** (Biology 90 · Chemistry 27 · Physics 11).
Examiner verdicts are committed: `fact_batches/bio_batch3_verdicts.json`.

### Notation recovery — `kie/qie/convert/notation/`
Locked hierarchy (mandatory): PROVENANCE · SYMBOLIC · DIMENSIONAL · DOMAIN · ROUND-TRIP.
**ANSWER-KEY is CORROBORATION ONLY — never sufficient.**
**41 relations certified / 8 controls** — Physics 27 (mechanics, gravitation, electrostatics, current
electricity, **oscillations**, **laws of motion**), Chemistry 14 (thermo, kinetics, electrochem, solutions).

### Reproducible BATCHES + CHAINS
```
python -m kie.qie.convert.notation.batches                 # list relation batches
python -m kie.qie.convert.notation.batches chem_batch3     # dry run · --register to admit
```
`phys_batch1_2` · `chem_batch3` · `phys_batch4` · chain set `depth4_chains`.
**The lane rebuilds from the repo alone into an empty store: 41 certified / 8 controls held / 5-of-5 chains**
— pinned by `test_the_whole_lane_rebuilds_from_the_repo_alone`. Control discipline is MECHANICAL: `run()`
certifies controls FIRST and raises `ControlBreach` rather than admit anything.

### Depth-4/5 CHAINS — `notation/{chains,chain_compose}.py` (the HARD lane)
A single relation is ONE operator application (depth 1) → only ever MEDIUM, so **more single relations can
never fill a hard cell**. Gates: **STEPS_CERTIFIED · SOLVABLE (unique real branch; ambiguous ± refused) ·
JUNCTION (base-dimension compatibility at every hand-off) · CLOSURE · DEPTH**. Depth is earned from the DAG by
`compose.reasoning_depth`, never asserted. **5 chains certified at depth 4 / 3 mis-wired controls rejected.**

## 6. Hard-won lessons — DO NOT REPEAT THESE MISTAKES
1. **⛔ NEVER retry blind arithmetic relation-induction.** ~90% false positives.
2. **Answer-key can never certify alone.** A *damaged* control scored answer-key corroboration **5/15** and the
   dimensional gate overruled it. The control is preserved in `phys_batch1_2.json`.
3. **The dimensional gate outranks the source** (it overruled NCERT's own unit column).
4. **A gate that rejects truth is also a defect** — as much as one that admits junk. Seen repeatedly:
   like-unit cancellation; `positive=True` vs `real=True`; a missing unit; the option gate below.
5. **qpgen dedups by (concept, question_type), globally per paper** → bind at the smallest genuine concept.
   Chapter binding capped NEET Biology at **42% forever**; that is what decision B fixed.
6. **Concept titles must pass `sanitize.is_clean_concept`** (MAX_WORDS=5). ⚠ Its anagram heuristic (a letter at
   ≥45% of a ≥5-letter word) false-positives on **"Mosses"**, **"mirror"**, **"Arcata"** — author around it;
   **qpgen stays frozen**. `pH`-style names are rejected too ([a-z][A-Z]).
7. **NCERT class labels are SWAPPED:** `NCERT_Class11_lech1dd.zip` = Class **XII** Chemistry;
   `NCERT_Class12_keph1dd.zip` = Class **XI** Physics. Trust `sources.entry_title()`. (`lech2dd.zip` is corrupt.)
8. `kie.db` concepts are noisy. Never bind by naive title substring.
9. Don't print the formula/route in a stem — author from recovered **meanings**.
10. Never trust a piped exit code — read the `Ran N tests / OK` tally.
11. **A chain junction can be arithmetically fine and physically nonsense** — feeding J into a J/mol slot. *This
    session designed that in and the JUNCTION gate caught it.* Now a pinned control.
12. **Correct arithmetic ≠ a realistic quantity** (first chain items computed j ≈ 1.3×10⁸ A/m²). Tune ranges.
13. **A symbol's ROLE changes once composed** → per-chain `meaning_overrides`.
14. **Options print VERBATIM to students, and the ANSWER is an option too.** Use `sanitize.stem_quality_ok`
    (the PROSE gate) — **NOT** `_looks_like_ocr_garbage`, which is the *concept-title* gate and rejects real
    biochemistry (`Acetyl CoA`, `mRNA`, `NaOH`, `pH`). Length is a runaway bound (130), not a quality proxy.
15. **Verify the handoff's own diagnosis against the data** — a previous §7.3 was wrong and a previous §7.1
    priority was invalidated by measurement.
16. **Concept titles are NOT printed to students** (only stem + options are; titles appear in the teacher's
    marking scheme + JSON). So prefer an accurate topic name over a contorted one.

## 7. Remaining work — ordered by measured value
1. **Biology: 48 of 90.** 89 concepts are bindable but only 48 generate — the limiter is now item generation,
   not binding. Measured breakdown of the 39 non-generating facts: **18 are NEGATIVE/"EXCEPT" items** ("Which
   is NOT a function of ANF?") where the answer is the FALSE statement and the real distractors are the TRUE
   ones. No existing direction fits them; they need a **negative lane** + an examiner-time `negation` slot
   (inferring negativity from a mismatch would be a guess — do not). Remainder: 7 giveaway, 6 <3 distractors,
   5 no slots (all correct refusals).
2. **More qualitative batches** — ~860 Biology + ~240 Chemistry candidates remain at ~90% survival. Now
   genuinely additive (decision B). ~25% of admitted facts currently generate, so budget accordingly.
3. **More depth-4/5 chains.** Each certified chain = +1 hard slot in EVERY paper; NEET's 40 hard slots are the
   largest structural headroom (5 filled). Chains are limited by the relation set, so notation breadth feeds
   this lane. Electrochemistry (E_cell → ΔG → K) is depth 3 — needs one more certified link.
4. **Notation breadth** — still untouched: Motion, Rotational Motion, Thermal, Kinetic Theory, Waves,
   Magnetism, EMI, AC, Optics, Modern Physics; **all of Maths**. Each SUMMARY page ≈ 5–13 relations. Copy
   `batches/phys_batch4.json`; always ship ≥1 deliberately damaged control and confirm it is REJECTED.
5. **Prefixed/non-SI units** absent from `dimensions.UNITS` (`kJ`, `bar`, `atm`, `dm³`, `cm`, `mL`). Add from
   sympy's own definitions — never hand-rolled factors, and avoid a generic prefix splitter (`cd` = candela).

## 8. Safety constraints (non-negotiable)
- Register **only** certified/verified records; persist rejects (never re-examine refuted evidence).
- LLM proposes; **deterministic gates certify**. Never certify by model agreement.
- Every admitted record keeps provenance **and** per-gate verification.
- Every batch ships ≥1 **deliberately damaged adversarial control**, and it must be REJECTED.
- `qpgen` internals frozen; `kie.db` read-only; bank not promoted; HELD scopes stay held.
- Raw/derived bulk stays **gitignored/local** (`knowledge/`, `resources/`, `staging/`). Commit only code,
  schema, tests, compact governance JSON/MD. Never commit `qie.db`/`kie.db`/page renders.
- Token discipline: deterministic first; reserve model reasoning for genuinely ambiguous extraction/examiner
  calls; batch; cache. **No agent swarms.**

## 9. Genuine blockers
**None.** No owner decision is outstanding (B is resolved and implemented). Everything in §7 is known, scoped,
unblocked work.

## 10. Key file map
```
curriculum/EVIDENCE_REGISTRY.{json,md}, EVIDENCE_MIGRATION_MAP.md
curriculum/scripts/intelligence/kie/
  evidence/{lifecycle,registry}.py
  qie/convert/{docmeta,candidates,examiner,register,kvs_compose}.py
  qie/convert/topics.py · topic_sets/{backfill_v1,bio_batch3}.json      # decision B
  qie/convert/fact_batches/bio_batch3_verdicts.json                     # examiner judgment record
  qie/convert/notation/{sources,targets,dimensions,verify,register,relation_compose}.py
  qie/convert/notation/{chains,chain_compose}.py                        # depth-4/5 HARD lane
  qie/convert/notation/batches/                                         # reproducible admissions + chain defs
    __init__.py __main__.py phys_batch1_2.json chem_batch3.json phys_batch4.json depth4_chains.json
  qie/store_schema.sql · qie/store.py · qie/qp_bridge.py                # ONLY qpgen integration point
  tests/{test_governed_conversion,test_governed_topics,test_notation_recovery,test_notation_chains}.py
docs/question-intelligence-quality/
  DECISION_B_CONCEPT_GRANULARITY.md                                     # RESOLVED — implemented 15feaea2
  NOTATION_RECOVERY_CAPABILITY.md · GOVERNED_CONVERSION_*.md
  QIE_SESSION_HANDOFF.md                                                # this file
```
