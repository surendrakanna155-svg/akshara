# Question Paper Generation Engine — Production-Readiness Certification

**Date:** 2026-07-10 · **Scope:** `curriculum/scripts/intelligence/kie/qpgen/` (the QP engine) as the
gate for promoting the local certified KIE (`kie.db`) into the production `edu_*` knowledge base ·
**Method:** *independent external certification* — trust no prior report; re-derive every guarantee
empirically against the **raw** `kie.db` with an oracle that does **not** use the engine's own scope
logic · **Stance:** adversarial; try to break it.

## Verdict: ✅ GO — the engine is production-ready. 0 P0 · 0 P1 open.

Two quality defects (both **P2**) were discovered during this validation, **fixed**, and
**re-verified**; nothing is left open. The certified `kie.db` was opened **read-only** throughout and
is **byte-identical** before and after (SHA-256 unchanged). This certifies the **engine**; the
mechanical `edu_*` migration (schema mapping, tenancy/RLS, promotion cutover) remains a separate,
owner-gated step (see *Scope of this GO*).

---

## 1. What was tested, and how independently

- **Independent oracle.** A separate module reads `kie.db` directly and builds a ground-truth map
  `concept_code → (subject_domain, evidencing-doc class_label, exam, grade)`. Every generated paper
  was checked against **this raw-DB oracle**, so a grade/subject leak is caught **regardless of what
  the engine believed**. The grade rule (parse `Class N`; competitive-exam papers are grade 11–12) is
  a domain fact applied to raw data, not the engine's code.
- **Volume.** **> 6,700 paper generations** across the campaign: a 504-paper invariant matrix
  (5 profiles × subject combos × 3 blueprints × 8 seeds), 126 blueprint-conformance checks, uniqueness
  suites, 540 concurrent generations, a **5,000-paper** endurance loop, and a 500-paper exhaustion
  series.
- **Baseline.** `kie.db` SHA-256 `bf39247415d0f39e31095e940282a770de7e3d09c7ae0782f09d668768ab6540`,
  152,047,616 bytes, **362 docs / 2,548 concepts / 33,870 chunks** — unchanged at end of run.
- **Regression.** Full KIE suite **196/196 green** (qpgen **78/78**, incl. 3 new hardening tests).

---

## 2. Results by objective (all against the independent oracle)

| Objective | Evidence | Result |
|---|---|---|
| **Grade isolation** | 504 papers, **9,000 questions**, checked vs raw-DB evidencing-doc grade. NEET scope grade distribution = **{11: 230, 12: 99}** — **0** Class ≤10 concepts | ✅ **0 leaks** |
| **Syllabus / subject boundary** | Every slot's concept exists, is `active`, its `subject_domain` matches the slot **and** the profile; sanitizer re-run on every title | ✅ **0 breaches** |
| **Blueprint compliance** | 126 conformance checks: no section/type **overfilled**; every under-fill **honestly reported** in warnings; `total_marks` == Σ slot marks | ✅ **0 defects** |
| **Chapter coverage** | NEET spans 18 chapters, FOUNDATION 26; selection balances chapter usage. *Coarse map* (~70% land in "General \<Subject\>") — see §5 | ✅ balanced (coarse map) |
| **Concept coverage** | Each concept used ≤ once per paper (max spread); de-dup enforced and independently reverified | ✅ no repeats |
| **Bloom / difficulty honesty** | `*_met` flags reconciled with actual labels on every slot; **no stamping** (labels equal the candidate's real value; relaxations reported) | ✅ consistent |
| **Cross-paper uniqueness (seeds)** | 20 seeds/config → mean pairwise Jaccard **0.24–0.65** (not identical) | ✅ varied |
| **Cross-paper uniqueness (series)** | `generate_series` overlap = **0** across every config, incl. a 500-paper series | ✅ **0 overlap** |
| **Deterministic reproducibility** | Same `(request, seed)` → identical fingerprint across **fresh instances** and **warm cache**; cache reuse never corrupts output | ✅ reproducible |
| **AI OFF (default)** | Default path attempts **zero** AI calls; objective items stay validated specs | ✅ zero-AI |
| **AI ON (gated)** | Authorized + wired provider: specs filled, **cached by spec-hash** (0 extra calls on identical re-run), every AI item re-passes the gate | ✅ gated + cached |
| **Every AI question re-validated** | AI output re-runs the full gate; off-topic content now rejected (see finding **PR-2**) | ✅ enforced |
| **Concurrency** | 180 jobs, per-instance **and** shared-instance, vs single-thread baseline | ✅ **0 mismatches, 0 errors** |
| **Read-only KB** | SHA-256 identical before/after | ✅ never mutated |

---

## 3. Performance, scalability, stability (measured)

- **Throughput:** 5,000 papers in a continuous loop, **0 crashes**. Batch latency **p50 ≈ 6–9 ms**,
  p90 ≈ 16–23 ms, p99 ≈ 45–73 ms (cold-cache spikes at scope/pool build).
- **Memory:** peak process **RSS ≈ 90 MB**; Python heap peak **≈ 9.4 MB** — **flat** across 5,000
  papers (no leak; the per-instance scope/pool cache is bounded by distinct scope keys).
- **Scalability:** `generate_series` of 10/50/100 papers completes in 0.16 / 0.70 / 0.72 s; the pool
  drains **honestly** (100-paper Physics×Chem×Bio×Math series exhausts the 779-concept universe and
  later papers shrink to 0 questions **without duplicating or fabricating**).
- **Endurance:** invariant spot-checks every 500th paper across the 5,000-run — **0 breaks**.

---

## 4. Adversarial / red-team (fail-closed everywhere)

Unknown exam, unknown blueprint, subject-not-in-profile, empty request, SQL-injection-style subject,
unicode look-alike subject, unknown class label, chapters matching nothing → **all refused cleanly**
(`ScopeError` / `QpGenError`, never a traceback, never fabrication). Case-insensitive exam/board
aliases resolve; case-sensitive subjects are refused (documented). Negative and 2⁶³-scale seeds,
200-term chapter filters, and a **500-paper exhaustion series** (overlap stayed **0**; tail papers
emptied honestly) → **no crash**.

---

## 5. Findings — 2 discovered, 2 fixed, 0 open

### PR-1 (P2, fixed) · Truncated definitions shipped as authoritative model answers
**Evidence:** 11 of the 43 concept definitions in `kie.db` are extraction fragments
(`"the amount of"`, `"below :"`, `"the energy required to"`, `"autonomous elements,"` …). The
descriptive renderer presented any non-empty definition as the answer key, so e.g. *"Describe Primary
production."* answered **"the amount of"** — misleading to a teacher. This is in the **deterministic**
path that gets promoted.
**Fix:** `materialize.usable_definition()` — a conservative deterministic quality floor (min length,
no terminal mid-clause punctuation, no dangling function-word / truncated final token). A definition
that fails it falls back to the existing **honest marking guideline** (same safe path as a missing
definition). **Re-verified:** across 780 sampled answers, **0** fragment answers now ship; valid
definitions (e.g. *"the force per unit area"*) are preserved. Locked by `test_qpgen_hardening`.

### PR-2 (P2, fixed) · Gated-AI objective items lacked a stem-grounding check
**Evidence:** the validation gate's grounding check (stem must name its concept) applied only to
**descriptive** items. An AI provider returning **off-topic content for an in-scope objective concept**
(e.g. an "income-tax" MCQ stem bound to an in-scope Physics concept) **passed** the gate — concept
binding, subject and grade are enforced, but stem relevance was not. The prior "rogue AI rejected"
test only covered an *out-of-scope* concept. (AI is **off by default** and not part of the promoted
deterministic path, hence P2 — but it contradicts the stated "every AI question passes the same
validation gate" guarantee.)
**Fix:** the grounding requirement now also applies to **FILLED AI-authored objective** items
(`provenance.source == "ai"`); solver-verified **templates** stay exempt (a numeric problem needn't
name the concept and is machine-checked). The AI authoring contract (`spec_of`) now instructs the
provider that the stem must reference the concept by name. **Re-verified:** good provider → 15/15
filled; rogue off-topic → **15/15 rejected** (`UNGROUNDED_STEM`), nothing off-topic ships. Locked by
`test_qpgen_hardening`.

Both fixes are **additive**, within `qpgen/` only; KIE Phases 1–7, the Intake Center, and the schema
are untouched; full suite stayed green.

---

## 6. Honest limitations (corpus/concept-layer realities — **not** engine defects, transparently bounded)

1. **Deterministic objective output is specifications, not answerable questions.** The certified
   template registry is deliberately conservative (5 families) and matches only **10 of 1,558**
   in-scope (concept × objective-type) slots (~0.6%). So with **AI OFF**, objective papers ship as
   syllabus-validated **SPECs** for an author; **fully-answerable deterministic papers are
   descriptive**. This is the no-fabrication design — the owner must accept that objective auto-fill
   needs either broadening the certified template registry or enabling the gated AI author.
2. **Chapter map is coarse.** ~70% of concepts fall into "General \<Subject\>" because concept titles
   rarely contain chapter keywords. Chapter *balancing* and *filtering* work for the mapped ~30%;
   refining `chapters.py` is additive reference-data work.
3. **Answer richness is bounded by definitions.** Only 43/2,548 concepts carry a definition; most
   descriptive answers are honest **marking guidelines** (never fabricated). Post-PR-1, fragmentary
   definitions also fall back to guidelines.
4. **Difficulty skews hard.** The corpus is 88% "hard"; `easy`/`medium` requests **honestly relax**
   and report the shortfall rather than mislabel.

A future KIE reprocess (richer definitions, cleaner concept names, more templates) lifts all four
without any engine change.

---

## 7. Scope of this GO

This certifies the **QP engine and the local KIE as its knowledge source** are production-ready:
boundary-safe, grade-isolated, deterministic, reproducible, concurrency-safe, resource-flat, and
fail-closed. It does **not** itself perform the `edu_*` promotion, which is a separate owner-gated
migration (schema/field mapping into `edu_*`, multi-tenant RLS, promotion cutover + live smoke). Those
mechanics inherit the project's standing live-lane gating and should be certified on the VPS at
promotion time.

**Recommendation:** **GO** to proceed with promotion planning. The engine has no open P0/P1/P2; the
four limitations above are accepted, transparent, and non-blocking for a descriptive-first launch
with objective items authored via the gated AI seam or the (extensible) template registry.

---

## 8. Reproduce

```
# full engine + KIE regression (196 tests)
PYTHONPATH=curriculum/scripts/intelligence \
  curriculum/.venv/bin/python3 -m unittest discover \
  -s curriculum/scripts/intelligence/kie/tests -p 'test_*.py'
```

The independent harness (`pr_validate.py` + `pr_oracle.py`) and its machine report (`pr_report.json`)
plus five sampled papers were produced in the session scratchpad; the harness re-generates from the
read-only `kie.db` and asserts every invariant in §2 against the raw-DB oracle.

**EOS gate:** PASS — additive fixes, reuse-first, boundary/grade/determinism independently re-verified,
regression-safe (196/196), KB unmutated (SHA identical). No open P0/P1.
