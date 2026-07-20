# QIE Scale-Strategy Trial — 1,000-Candidate Experiment

**Date:** 2026-07-15 · **Status:** EVIDENCE COMPLETE — owner decision pending
**Question:** should QIE remain the primary manual/evidence-driven question CONSTRUCTION path, or become the
BRAIN / PLANNER / CONSTRAINT SYSTEM / JUDGE for an Opus-scale candidate factory?

Harness: `curriculum/scripts/intelligence/kie/qie/factory/` (committed).
Corpus: `curriculum/knowledge/kie/factory_corpus.db`, run `RUN_TRIAL1` (LOCAL-ONLY, gitignored).
The frozen QIE engine was **not edited**. The factory imports its gates; it never rewrites them.

---

## 1. Headline result

| | |
|---|---|
| Specs planned (Classes 6–12, 4 subjects, 18 archetypes, depth 1–5) | **1,000** |
| Generator refusals | **316 (31.6%)** |
| Complete candidates | **684** |
| Survived deterministic gates | **547** |
| Quarantined / rejected by gates | 113 / 24 |
| **Certifiable** (survived gates AND independently re-derived) | **152** |
| Structured-lane sympy agreement | **258 / 267 = 96.6%** |
| Gate pass wall-clock | **6.55 s for 684 items — zero model tokens** |
| Solutions constructed + verified against the locked key | **70 / 70 (0 disputes, 0 failures)** |
| **CERTIFIED** (full chain: gates + sympy + blind judge) | **15** — judge-sample-limited, see below |
| Cost per certified question | **$0.41** (band $0.23–$1.13) |
| Throughput | **~59 certified/hour on 2 workers** vs current method's ~40–60/**day** |

**The generator is not the bottleneck. The planner's evidence is.**

### Why "15 certified" is a floor, not a ceiling
Judge 0 never returned, so only **91 of 547 survivors (16.6%) were judged**. Of those 91: 63 judge-accepted
(69.2%), 22 were independently verifiable, and **15 satisfied both ⇒ certified**. The other 48 accepted items
were qualitative and parked as `awaiting_independent_evidence`.

- certification rate on the judged sample: **15/91 = 16.5%** → projected over 684 candidates: **~113 certified**
- on the *verifiable* subset the judge saw: **15/22 = 68% certify**

So the structured lane certifies at ~68%; the qualitative lane certifies at **0% — structurally**. That split,
not the raw count of 15, is the finding.

---

## 2. What the trial proved

### 2.1 The bridge works: structure makes a claim falsifiable
The QIE audit found its strong gates are REGISTRY-BOUND — of ~25 gates, only 4 function on free-form external
JSON, and `depth`, `difficulty`, and `concepts` have **zero** verification surface. The bridge tested here:
require the generator to emit `{givens, relation, solve_for}`. sympy then re-executes it, ignoring the prose
and the stated answer. **258/267 structured items (96.6%) reproduced their own keyed answer.**

sympy caught **1 genuinely wrong key** the model asserted was correct:
> Class-12 kinetics, k = 2.303×10⁻⁶ s⁻¹, C₀/Ct = 10 ⇒ t = (2.303/k)·log₁₀(10) = **10⁶ s**. Opus keyed **1000 s**.

At lakh scale a 0.4–0.6% key-error rate is 400–600 wrong answers per 100,000. Independent re-derivation is
what stops them, and no amount of fluent reasoning talks past it.

### 2.2 The deterministic gates are BLIND to a bad plan
The manifest ran two arms. `boundary_probe` specs are **known-suspect by construction** (drawn from
integrated-science books and exam papers where the subject tag is arbitrary).

| arm | GATES caught | GENERATOR refused |
|---|---|---|
| `evidenced` | 20.1% | 26.8% |
| `boundary_probe` | **20.0%** | **49.0%** |

Gate catch-rate on known-garbage is **identical** to legitimate specs. The `curriculum_boundary` gate **never
fired once in 684 candidates**. The only thing that detected bad plans was **the model choosing to refuse** —
a model judgement, not evidence. Curriculum boundaries held because Opus declined, not because anything
enforced them.

### 2.3 ~66% of refusals are the generator catching PLANNER defects
Of 316 refusals: **subject mismatch 49.7%**, bogus composition 11.6%, incoherent archetype×depth 2.2%, corpus
junk 2.2%. The generator's own words:
- *"the subject is Biology but the concept, the heating effect of electric current, is Physics"*
- *"'Answer for the above question' is not a Physics concept; it is corpus noise scraped from a textbook's solutions apparatus"*
- *"archetype 'direct_recall' with intended_depth 3 — direct recall is a single lookup and carries no dependent steps"* ← **the planner's bug**

### 2.4 The concept table is not a curriculum
Verified directly in `kie.db`:
- **`MAT_GAHE_TAVA_JAYA_GATHA | "Gahe tava jaya gatha" | Mathematics | grade 10 | active`** — a line of the
  **national anthem** is a live Class-10 Mathematics concept.
- `Contributors`, `Think and Reflect`, `Preamble`, `Pledge`, `Fundamental Duties`, `Chief Advisor`, `Artwork`,
  `Bibligraphy` — textbook front matter as concepts.
- `BIO_TELATELTELT`, `BIO_ANSWERANSWER`, `BIO_SCESCESCECECERT`, `BIO_LANGANAANANNGANNGAN` — OCR garbage, active.
- **Gauss's law exists three times** — `PHY_GAUSS_S_LAW`, `CHE_GAUSS_S_LAW`, `BIO_GAUSS_S_LAW`. Same for
  Huckel's rule. Each source document minted its own copy carrying that document's subject.
- `Stoke's law` → Chemistry. `Chatelier's principle` → Biology. `Reflection of Light` → Biology, grade 7.

**The existing title sanitizer rejects 0 of 923** "reliable" concepts — it passes `Gahe tava jaya gatha`,
`Contributors`, and `answeranswer` alike. **There is no concept-quality gate anywhere in the system.**

### 2.5 The blind judge confirms it independently
183-item stratified sample, judge blind to the generator's reasoning/structure/solution (91 verdicts returned):
**63 accept, 28 quarantine, 0 reject.**

| dimension | failed | note |
|---|---|---|
| `curriculum_ok` | **23/91 (25.3%)** | almost all **wrong CLASS TAG**, not wrong questions |
| `well_posed` | 5/91 (5.5%) | mostly *"the stem references a figure that is not supplied"* — the missing SVG renderer |
| `answer_correct` | 4/91 (4.4%) | |
| `concepts_real` | 1/91 (1.1%) | |
| `composition_real` | **0/91** | every `multi` claim held up |
| `distractors_plausible` | **0/91** | every distractor mapped to a real misconception |
| `unique_answer` | **0/91** | |

Representative: *"Physics is right (…key a) but Electric Charges and Fields is Class 12 NCERT; Class 11 tagged."*
*"Key b correct, but Principles of Biotechnology is Class 12, not Class 11 as tagged."*
**The questions are right. The class tags are wrong.**

### 2.6 The qualitative lane CANNOT be certified — and this is structural
417 of 684 candidates (61%) are qualitative. They are visibly excellent (a correct NEET-level recombinant-DNA
assertion–reason; a Mendelian error-analysis item whose distractors are blending-inheritance and 1:1-ratio
misconceptions). But **no non-model re-derivation exists for them**. Certifying on gates + judge alone means
certifying a same-family model's opinion of its own output — the self-confirmation the owner ruled out.
`certify.py` therefore parks them as `awaiting_independent_evidence`. This is the architecture telling the
truth about what it can prove.

---

## 3. Defects this trial found (and their status)

**In the frozen QIE engine — reported, NOT patched:**
- `notation.dimensions.parse_unit` **cannot parse any SI-prefixed unit**: `cm`, `mm`, `km`, `nm`, `kPa`, `mL`,
  `min`, `h`, `deg` all return "unparseable". It only ever saw base units (J, kg, m, N) from NCERT summary
  pages. It false-quarantined **107 items whose answers sympy had already confirmed**. The harness normalizes
  prefixed units to their base unit **for the dimensional check only** (cm and m are both lengths; magnitude is
  irrelevant to a dimensional check, and the numeric solve always uses raw values). Controls confirm the gate
  still catches a deliberately-broken relation. **The engine defect remains and should be fixed at source.**
- `archetypes.classify` disagrees with the claimed archetype **538/684 (79%)** of the time. Its default is a
  catch-all, so it assigns but cannot refute. It is not usable as an archetype judge.
- The `source: "template"` exemption in `qpgen/validate.py` is keyed on a string the producer writes about
  itself — a self-signed certificate.

**In my own harness — caught by controls before any yield number was trusted:**
1. `composition_backed` operator-precedence hole (`depth or (0>=2)`) — fake multi-concept passed.
2. sympy symbol collision: `parse_expr("N"/"S"/"E"/"Q"/"I")` resolves to builtins, not symbols.
3. `_num()` dropped scientific notation — read `"3e-06"` as `3`, manufacturing 3 fake "wrong answers".
4. `round(v, 9)` rounds to 9 **decimal places**, collapsing 5.27×10⁻¹⁰ → 1×10⁻⁹ — would corrupt every
   small-magnitude answer in atomic physics and chemistry.
5. Unbounded `sympy.solve` hung indefinitely on one pathological item.

Three of those five would have **falsely blamed the generator**. A validation harness is not automatically
more trustworthy than the model it judges — hence the three control suites (10 adversarial + 8 notation +
4 magnitude), all of which must pass before any candidate is judged.

---

## 4. Economics (measured; limits disclosed)

Provider input/output token split is **not exposed to this harness**. Two generator agents reported clean
harness aggregates: 133,607 and 109,855 tokens per 40-spec batch → **~121,731/batch ≈ 3,043 tokens/spec**.
Opus 4.8 = $5/1M input, $25/1M output.

All-in, measured across the three model stages (80/20 input/output assumption):

| stage | tokens | cost |
|---|---|---|
| generation (1,000 specs) | 3,645,452 | $32.81 |
| blind judge (91 measured → all 547 survivors) | 210,342 | $11.38 |
| solutions (70 measured → ~113 certified) | 128,438 | $1.87 |
| deterministic gates (684 items, 6.55 s) | **0** | **$0.00** |
| **TOTAL to certify ~113** | | **$46.05** |

**COST PER CERTIFIED QUESTION = $0.41** (band across the input/output split: **$0.23 – $1.13**).

At $0.41, 100,000 certified questions ≈ **$41,000 in model spend** — affordable. The blocker is not money.

The cheapest stage does the most filtering, which is why solutions are constructed for survivors only:
paying Opus to write a careful solution for an item a 6-second free check is about to reject is pure waste.

**Throughput:** the compact run produced 270 candidates from 405 specs in **45.6 min on 2 workers**
(≈355 candidates/hour) ⇒ **~59 certified/hour on 2 workers**. The audited current method yields **~40–60
certified questions per DAY**. Two workers do in an hour what the current method does in a day.

---

## 5. Method comparison

| | Current OCR/extraction method | QIE-planned AI factory |
|---|---|---|
| Output to date | 174 certified artifacts (128 facts, 41 relations, 5 chains) | 684 candidates / 152 certifiable in one session |
| Wall-clock | 0.68 calendar-days (~2.5 h active) | ~18 min generation (25 workers) + 6.55 s gates |
| Yield | 0.25 q/fact · 1.0 q/relation · 0.8 q/chain | 22.2% of candidates certifiable |
| Cost/unit | not instrumented (vision transcription per page) | ~$0.18/verified item |
| **Hard ceiling** | **~280–450 more questions — 5–11 agent-days exhausts the entire documented queue** | bounded by the concept universe, not the generator |
| Certifies qualitative? | **YES** — grounds each fact in an owned source | **NO** — no non-model re-derivation exists |
| Certifies structured? | yes, but 1 relation = depth-1 ⇒ can never fill a hard cell | **yes, at ~100× throughput** |

**The current method cannot reach lakhs by construction.** Its entire remaining queue is ~280–450 questions,
and its NEET hard-slot fill is 5/40 because a single relation is depth-1.

---

## 6. The real ceiling: the concept universe

| concepts | ×5 | ×10 | ×20 | ×40 |
|---|---|---|---|---|
| 923 reliable | 4,615 | 9,230 | 18,460 | 36,920 |
| 1,692 all-active (after subject re-derivation) | 8,460 | 16,920 | 33,840 | 67,680 |

**Lakhs requires ~5,000+ trustworthy concepts** — curriculum acquisition + per-chunk subject re-derivation.
That is data work, not generation.

⚠ **Untested variable:** the manifest planned ~1 spec per concept, so the trial did **not** measure how many
genuinely distinct questions one concept yields before near-duplicates set in. The ×20 column is an
assumption, not a measurement. This is the single most important follow-up.

---

## 7. Decision

**C — SPLIT STRATEGY BY LANE.**

- **STRUCTURED / NUMERIC (Maths 6–12, Physics, Chemistry computational) → the AI factory is the primary scale
  path, and it is certifiable today.** 96.6% sympy agreement, ~$0.18/verified item, ~100× the current
  method's throughput, with independent re-derivation catching the keys the model gets wrong.
- **QUALITATIVE / FACTUAL (Biology, definitions, recall) → the factory generates excellent candidates but
  CANNOT certify them.** Certification requires grounding the answer in an owned source — exactly what the
  existing OCR/extraction lane does. Keep that lane, but aim it at answer-key grounding for factory
  candidates rather than at building questions one family at a time.
- **QIE's new job = planner + constraint system + judge.** It cannot do that job yet: its curriculum boundary
  is 0/1692 populated, grade means "which PDF mentioned this", ~31% of subject tags are noise, and the concept
  table contains the national anthem. **Fix the planner's evidence and the factory works. Don't, and 25% of
  everything it produces is mis-tagged.**

Not A: the current method's ceiling (~280–450 questions, 5–11 days) makes lakhs impossible.
Not B: the qualitative lane — 61% of candidates — has no certification path, so the factory cannot be the
whole answer.
Not D: the trial was not inconclusive. It ran end-to-end and the blockers are named and measured.

---

## 8. What happens next (in order)

1. **Concept-quality gate + subject re-derivation.** Derive `subject_domain` from chunk/section content, not
   from `source_documents.subject` (integrated books make per-doc tagging structurally invalid). Add a
   concept-quality gate — nothing today rejects `Gahe tava jaya gatha`. Deduplicate the three Gauss's laws.
2. **Distinguish taught-at from mentioned-in.** `grade := doc.class_label` is provenance, not syllabus.
   Anchor at chapter level against an actual NCERT chapter→class table (not currently in the corpus).
3. **Measure questions-per-concept saturation.** Plan 40 specs on one concept and count survivors after
   near-duplicate detection. This sets the real path to lakhs.
4. **Fix `dimensions.parse_unit` at source** to accept SI-prefixed units.
5. **Then scale the structured lane.** It is ready; everything above is what stops it being trustworthy.
