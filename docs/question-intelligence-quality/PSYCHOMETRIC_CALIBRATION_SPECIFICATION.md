# Psychometric Calibration Specification

**Date:** 2026-07-11 · **Status:** SPEC (proposal — not implemented)
**Principle:** Rigorously separate **predicted** difficulty (from item structure, available now) from
**empirically calibrated** difficulty (from real student responses, Phase 2). Never present one as the
other. **No LLM ever fabricates an empirical statistic.**
**Aligns with:** Assessment-Intelligence-Platform D1 (response-centric), D6 (`edu_item_statistics` schema,
already locked), D2 (**no per-student answer-sheet OCR/OMR** — calibration uses the per-question marks
grid). This spec **fills** the locked-but-dormant D6 schema; it does not invent a parallel one.

---

## 1. Two quantities, never conflated

```
predicted_difficulty     — deterministic function of measured difficulty drivers (available at generation)
empirical_difficulty     — derived from real responses (available only after data exists; Phase 2)
calibration_status       — predicted_only | probation | trusted | flagged
```
A generated item ships with `predicted_difficulty` and `calibration_status = predicted_only`. It becomes
`probation` when it starts collecting responses and `trusted` only after it meets the D6 promotion
thresholds. **The paper never claims empirical difficulty for an uncalibrated item.**

---

## 2. Why the current label is not difficulty

Current difficulty is `text>600 chars OR contains 'derive/prove' ⇒ hard` (`phase7_questions.py:75-81`),
inherited onto slots and never verified. Measured result: difficulty-met ~40%, compute items labeled
`bloom=remember, difficulty=hard` simultaneously. This is neither predicted nor empirical difficulty — it
is a heuristic tag. It is replaced by §3.

---

## 3. Predicted difficulty (available now, deterministic)

`predicted_difficulty = f(difficulty_driver_vector)` where the drivers are those measured in
`QUESTION_DNA_SPECIFICATION.md` §7 (reasoning_steps, concept_count, prerequisite_depth,
representation_shifts, calculation_load, algebraic_manipulation, misconception_pressure, option_similarity,
visual_interpretation_load, abstraction_level, context_novelty, irrelevant_information).

Properties:
- **Deterministic and versioned.** The weight function has a version id; changing it re-versions all
  predicted difficulties. Initial weights are set from expert judgment + the gold benchmark, then refined
  against empirical data once it exists (§5).
- **Verifiable.** GATE 9 recomputes drivers on the generated instance and rejects/re-bands mismatches — so
  a "hard" prediction actually corresponds to structurally harder items.
- **Honest.** It is labeled `predicted`, with the driver vector attached, so a teacher can see *why* it is
  predicted hard. It is explicitly **not** a psychometric statistic.

---

## 4. Empirical calibration (Phase 2, response-fed)

Depends on the response spine (D1 `edu_student_item_responses`) captured via the **per-question marks
grid** — teachers enter per-question marks; **no per-student answer-sheet scanning** (D2). The spine must
be **seeded from day one** because response data cannot be backfilled (D11 note).

### 4.1 Classical Test Theory (first, minimal assumptions)
Per item, once response volume permits:
```
p_value               // item facility = fraction correct        [marks grid: SUPPORTED]
discrimination        // upper-lower group difference             [marks grid: SUPPORTED]
point_biserial        // correlation of item score with total     [marks grid: SUPPORTED]
blank_rate            // attempted vs blank                       [marks grid: SUPPORTED]
distractor_selection_frequency  // per option                     [DIGITAL-PRACTICE ONLY — see below]
distractor_efficiency // are wrong options attracting mis-informed? [DIGITAL-PRACTICE ONLY — see below]
```
**Correction (2026-07-12):** the D2 per-question **marks grid captures marks per question, NOT the chosen
option** (AIP §6.4, line 178). `p_value`, `discrimination`, `point_biserial`, `blank_rate` are derivable
from the marks grid; **`distractor_selection_frequency` and `distractor_efficiency` are NOT** — they require
`edu_student_item_responses.chosen_option`, which AIP §6.4 populates **only from digital attempts** (in-app
DPP/practice, Phase 2+). No schema extension is needed (the `chosen_option` field already exists, AIP §10.1);
the constraint is the data *channel*. The supported metrics map onto the locked D6 `edu_item_statistics`
schema. See the Reconciliation Amendment for the full SUPPORTED_NOW / FUTURE_ONLY classification.

### 4.2 Item Response Theory (when volume + assumptions justify)
```
Rasch / 1PL   — difficulty only (start here; robust at lower N)
2PL           — difficulty + discrimination (when N and fit support it)
3PL           — + guessing (only where a guessing parameter is justified, e.g. 4-option MCQ at scale)
```
IRT is applied **only** when sample size, dimensionality, and fit diagnostics justify it — never by
default, never on thin data. Model choice and fit are reported.

### 4.3 Stored per item
```
predicted_difficulty, observed_difficulty, discrimination, calibration_status,
response_count, confidence_interval (where applicable), distractor_statistics, exposure_count
```

---

## 5. Closing the loop (predicted → empirical)

Once trusted empirical difficulty exists for enough items, **regress observed difficulty on the driver
vector** to refine the predicted-difficulty weights (§3). This makes the *predicted* model progressively
more accurate for new items that have no responses yet — the engine learns to predict difficulty from
structure because reality taught it which drivers matter. This is the only sanctioned use of empirical
data to touch the predicted model, and it is a deterministic regression, not an LLM.

Broken-item and drift detection (D6): an item whose observed difficulty diverges sharply from predicted,
or whose discrimination is negative, is `flagged` for teacher review — a first-class quality signal.

---

## 6. Promotion thresholds (from D6, quoted intent)

`probation → trusted` requires: ≥ N responses (e.g. 100), p-value within the band declared for its
difficulty label, discrimination above threshold, zero unresolved teacher flags. These are the D6 rules —
we adopt them verbatim rather than invent new ones.

---

## 7. Hard rules

- No LLM output is ever written to an empirical statistic field.
- `predicted` and `empirical` are separate fields with separate provenance; UI/reporting must label which
  is shown.
- Empirical calibration is Phase 2 and requires the response spine; until then, only `predicted` exists and
  is labeled as such.
- Marks-grid capture only; per-student answer-sheet OCR/OMR is out of scope (D2).

---

## 8. Acceptance criteria

- Every generated item carries a `predicted_difficulty` with its driver vector and `calibration_status`.
- The response spine is seeded before Phase 2 so data accrues from first use.
- CTT statistics compute correctly against a synthetic response set (validation) and align to the D6 schema.
- IRT is gated on volume/fit and reports model choice; it is never run on thin data.
- No empirical field is ever populated by a model; audit confirms zero LLM writes to statistics.

---

## Reconciliation Amendment (2026-07-12, post-Fable-5)

Governed by `OPUS_FABLE_RECONCILIATION_RECORD.md` §5. Metric classification (respecting D1/D2/D6):

| Metric | Class | Source |
|---|---|---|
| p-value, blank_rate, discrimination, point-biserial | **SUPPORTED_NOW** (once the marks-grid spine is seeded, Phase F) | D2 marks grid |
| IRT (Rasch→2PL→3PL) | **SUPPORTED_NOW, volume/fit-gated** | marks-grid dichotomous data |
| distractor_selection_frequency, distractor_efficiency, response-time/speededness | **FUTURE_ONLY** | `chosen_option`/`time_spent_ms` — **digital-practice channel only** (AIP §6.4), never the marks grid |

**REQUIRES_RESPONSE_SCHEMA_EXTENSION: none** — `edu_student_item_responses.chosen_option` already exists in
the canonical AIP §10.1 schema; the gap is the digital-practice data channel (Phase 2+), not the schema. The
spec must never present a distractor-level statistic derived from marks-grid data. Difficulty drivers feeding
**predicted** difficulty are per-profile and map to ordinal bands first; `prerequisite_depth` is near-unusable
today (prerequisite `concept_edges` = 10); `information_density`/`abstraction_level`/`context_novelty` are
deferred until a measurement procedure exists.
