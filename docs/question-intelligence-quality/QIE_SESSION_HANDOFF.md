# QIE — fresh-session handoff (authoritative resume point)

**Date:** 2026-07-15 · **Branch:** `feature/qp-content-readiness` · **Tip:** `b79a785e` · **Working tree:** clean
on the QIE lanes · **Tests:** 621 green (`python -m unittest discover -s kie/tests`)

**Read this instead of re-auditing.** Everything below is committed and verified. Do NOT re-derive it.

---

## 1. Environment (exact)
- Python venv: `curriculum/.venv/bin/python` (3.14). Run modules from `curriculum/scripts/intelligence/`
  (so `import kie` resolves), e.g. `cd curriculum/scripts/intelligence && ../../.venv/bin/python -m unittest discover -s kie/tests`.
- Deps present: PyMuPDF 1.28, sympy 1.14, PIL. No network needed.
- Lanes: this worktree = **K (QIE) lane**. The ERP lane lives in a *separate* worktree (`Akshara_ERP-drp`) —
  do not touch it. Check `git branch --show-current` before every commit.
- ⚠ Other lanes leave files dirty in `curriculum/` (`PROVENANCE_MANIFEST.json`, `configs/`, `discovery/`,
  `reports/`, `scripts/download/`). They are **not yours** — stage QIE paths explicitly, never `git add -A`.

## 2. Locked scope (unchanged)
**In scope:** JEE Main, JEE Advanced, NEET, NCERT/CBSE 6–10 Math & Science, NCERT/CBSE 11–12 Math/Physics/
Chemistry/Biology. English only.
**HELD (do not start):** Classes 1–5, AP/TS/ICSE/other state boards, broader school-exam work, broad new
acquisition, Question-Bank promotion/materialization.
**Frozen:** `kie/qpgen/` internals (integrate only through `kie/qie/qp_bridge.py`), `kie.db` (read-only),
the pilot bank (not promoted).

## 3. Owner decisions (locked — do not re-litigate)
- **Decision A (RESOLVED):** verified **governed-fact chapters** and **certified relations** are *first-class
  in-scope concepts* for the qpgen boundary, guarded by the deterministic subject gate + the same
  `qpgen/sanitize.is_clean_concept` gate as every other concept. Extended (`996d65db`) to **certified chains**,
  which compose already-certified relations and so assert no new knowledge.
- **Decision A/notation (RESOLVED):** a governed **math-capable notation recovery** layer over already-owned
  source PDFs/page-images. Reusable layer, not a one-off.
- **Standing law:** wrong knowledge is worse than missing knowledge. Never weaken a gate to raise yield. LLM
  **proposes**; deterministic checks **certify**. No source-question cloning.

## 4. Measured state — the REAL denominator (seed 7, `boundary_ok`, 0 violations, 0 forced fills)

| exam | blueprint | qie-servable | **filled** | % | **hard filled** |
|---|---|---|---|---|---|
| NEET | 180 | 180 | **61** | 33% | **4 / 40** |
| JEE Main | 75 | 75 | **49** | 65% | **6 / 15** |
| JEE Advanced | 33 | 30 (3 = `match`, left to authoring) | **24** | 80% | **6 / 12** |

Trajectory this session: NEET 38 → 52 → 56 → **61** · JEE Main 29 → 43 → 47 → **49** · JEE Adv 17 → 20 → **24**.

```python
from kie.qie import qp_bridge as QB; from kie.qpgen.models import PaperRequest
paper, report = QB.generate_paper(PaperRequest(exam="NEET", seed=7), per=18)
filled = [s for s in paper.slots if s.status == "filled"]        # paper.warnings names every shortfall
```
⚠ **`per` is inert.** qpgen dedups by `(concept, question_type)`, so exactly ONE item lands per concept per
type: `per=18`, `30` and `60` give identical papers. **Coverage scales with DISTINCT CONCEPTS, nothing else.**
Read `paper.warnings` — it names the exact shortfall per section. That is the only honest progress metric.

## 5. What exists (committed, working)

### Canonical evidence registry
`curriculum/EVIDENCE_REGISTRY.{json,md}` + `EVIDENCE_MIGRATION_MAP.md`. Store-level source of truth: **23
stores / 59.4 GB**, lifecycle-stated. Regenerate: `python -m kie.evidence.registry` (read-only; do NOT pass a
backdated `REGISTRY_NOW` — it makes the stamp go backwards). No files were moved; the migration map holds the
deferred layout.

### Governed qualitative conversion — `kie/qie/convert/`
`docmeta` → `candidates` (1,774 clean non-numeric queued) → `examiner` (cached by item_hash) → `register` →
`kvs_compose`. **92 verified facts / 20 rejected.** Subjects: Biology 54 · Chemistry 27 · Physics 11.

### Notation recovery — `kie/qie/convert/notation/`
`sources` → `targets` → *(vision transcription — PROPOSES ONLY)* → `dimensions` → `verify` → `register` →
`relation_compose`. **Locked hierarchy (mandatory):** PROVENANCE · SYMBOLIC · DIMENSIONAL · DOMAIN ·
ROUND-TRIP. **ANSWER-KEY is CORROBORATION ONLY — never sufficient.**
**28 relations certified / 5 rejected** — Physics 14, **Chemistry 14** (thermodynamics ×8, kinetics ×2,
electrochemistry ×3, solutions ×1). Chemistry went from 3-per-paper to parity with Physics/Biology.

### ⭐ Reproducible BATCHES — `kie/qie/convert/notation/batches/`
`qie.db` is a **gitignored derived store**, so a batch file is the ONLY reproducible record of an admission.
The earlier batch scripts lived in a session scratchpad and are **GONE** — that gap is now closed:
```
python -m kie.qie.convert.notation.batches                  # list
python -m kie.qie.convert.notation.batches chem_batch3      # dry run (certify only)
python -m kie.qie.convert.notation.batches chem_batch3 --register
```
`phys_batch1_2.json` (14 + 2 controls) · `chem_batch3.json` (14 + 3 controls). The lane **rebuilds from the
repo alone into an empty store: 28 certified / 5 controls held / 4-of-4 chains certifying.**
Control discipline is **mechanical**: `run()` certifies controls FIRST and raises `ControlBreach` rather than
admit anything if a damaged control ever passes.

### ⭐ Depth-4/5 CHAINS — `kie/qie/convert/notation/{chains.py, chain_compose.py}` (the HARD lane)
A single relation is ONE operator application (depth 1) → can only ever be MEDIUM. Every blueprint reserves
its hard cells for multi-concept work, so **more single relations can never fill one**. A chain feeds one
certified relation's solved symbol into the next; depth is earned from the DAG by `compose.reasoning_depth`,
never asserted. Gates (all mandatory): **STEPS_CERTIFIED · SOLVABLE (unique real branch; ambiguous ± rejected)
· JUNCTION (base-dimension compatibility at every hand-off) · CLOSURE · DEPTH**.
**4 chains certified at depth 4** (`batches/depth4_chains.json`) / 3 mis-wired controls rejected.

## 6. Hard-won lessons — DO NOT REPEAT THESE MISTAKES
1. **⛔ NEVER retry blind arithmetic relation-induction.** ~90% false positives; `V=IR` is just `a×b` so it
   matched *Waves, Calorimetry, Motion*. Nothing was registered from it — correctly.
2. **Answer-key can never certify alone.** A *damaged* control (`½kx`, lost square) scored answer-key
   corroboration **5/15** — real questions "confirmed" wrong physics — and the dimensional gate overruled it.
   Pinned by `test_answer_key_alone_cannot_certify`; the control itself is preserved in `phys_batch1_2.json`.
3. **The dimensional gate outranks the source.** NCERT's unit column says conductivity is "S" but its own
   dimensions column gives S m⁻¹; the verbatim transcription was rejected.
4. **A gate that rejects truth is also a defect.** Fixed: like-unit cancellation; `positive=True` vs `real=True`;
   a **missing unit** silently rejecting a correct relation → extend `dimensions.UNITS` when adding a subject.
5. **qpgen dedups by (concept, question_type)** → bind at **relation granularity**, never chapter.
6. **Governed concept titles must pass `sanitize.is_clean_concept`** (MAX_WORDS=5). Note `pH`-style names are
   rejected as OCR-garbage (`[a-z][A-Z]`), so a pH relation would certify but never bind.
7. **NCERT class labels are SWAPPED:** `NCERT_Class11_lech1dd.zip` = Class **XII** Chemistry Part I;
   `NCERT_Class12_kech1dd.zip` = Class **XI**. Trust `sources.entry_title()`. (`lech2dd.zip` is a corrupt zip.)
8. `kie.db` concepts are noisy. Never bind by naive title substring.
9. Don't print the formula/route in a generated stem — author from recovered **meanings**.
10. Never trust a piped exit code — read the `Ran N tests / OK` tally.
11. **A chain junction can be arithmetically fine and physically nonsense.** Feeding an extensive enthalpy (J)
    into a molar reaction-enthalpy slot (J/mol) — *an error this session designed in and the JUNCTION gate
    caught*. No answer-check would ever notice. Same shape as lesson 2.
12. **Correct arithmetic ≠ a realistic quantity.** The first chain items computed j ≈ 1.3×10⁸ A/m² (would
    vaporise copper). The physics was right; the instance ranges weren't. Tune `value_ranges`/`givens`.
13. **A symbol's ROLE changes once composed.** `V` in the Wheatstone chain is the drop across the unknown arm,
    not "across the conductor" as the standalone Ohm's-law record words it → per-chain `meaning_overrides`.
14. **Options print VERBATIM to a student.** Real distractors are authentic misconception evidence but they are
    OCR text — a string can be damaged even when the fact is sound. Drop damaged strings; skip the fact if <3
    clean distractors remain (honest shortfall, never junk).
15. **Verify the handoff's own diagnosis against the data** — §7.3's assertion-direction diagnosis was wrong
    (see §8).

## 7. Remaining work — ordered by measured value
1. **Biology Section A: 20 of 70 — the single largest gap** (plus Biology hard 0/20, which chains cannot serve:
   Biology has no relations). Path = **qualitative batch 3+**: ~1,660 clean candidates queued at 76–88% yield.
   `examiner.select_batch(cands, conn, n=..., lanes=..., prioritize_subjects=["Biology"])` → worksheet →
   examine → `ingest_verdicts`. This is the only lane that moves Biology.
2. **More depth-4/5 chains** (`batches/depth4_chains.json`). The lane is OPEN and each certified chain = +1 hard
   slot in every paper. NEET's 40 hard slots are the largest structural headroom (4 filled). Chemistry
   electrochemistry (E_cell → ΔG → K) is depth 3 — needs one more certified link to qualify.
3. **Notation breadth** — all Maths and most NCERT Physics chapters are still untouched; each SUMMARY page
   ≈ 5–8 relations, and each new relation is also new chain material. Copy `batches/chem_batch3.json`; always
   include ≥1 deliberately damaged adversarial control and confirm it is REJECTED.
4. **Prefixed/non-SI units** are still absent from `dimensions.UNITS` (`kJ`, `bar`, `atm`, `dm³`, `cm`, `mL`).
   Batch 3 didn't need them (SI declared throughout). Add from sympy's own definitions — never hand-rolled
   factors, and avoid a generic prefix splitter (`cd` = candela, not centi-day).

## 8. Correction to the previous handoff (verified against the data)
The old §7.3 claimed 42/52 assertions failed because the source asked *term→definition* and the fix was to
re-author slots at **examiner** time. **That was wrong.** The slots were already in the source's direction.
Measured: 33 DIRECTION / 10 OK / 7 list-answer / 2 giveaway — and in the DIRECTION failures the answer
corresponds to the **object_term**, with the real distractors parallel to the **object**. `_assert_usable` only
supported "what is X?" (answer≈subject_term). The fix was a second template authoring the stem in the source's
own direction (`"{subject_term} {predicate}:"`) — **no examiner call, no new evidence, no token spend.**
Of the 33, only 17 are truly object-direction; 10 survive the quality gates (7 dropped by the new
option-quality gate as OCR-damaged — honestly, rather than shipping junk).
**Known residue:** a pronounceable OCR typo (`tmpredictable` for "unpredictable") still passes the
dictionary-free option gate. One cosmetic distractor; stem and key are correct. Inventing a heuristic to catch
it risks rejecting real terms (mRNA, sp3d2).

## 9. Safety constraints (non-negotiable)
- Register **only** certified/verified records; persist rejects (never re-examine refuted evidence).
- LLM proposes; **sympy/deterministic gates certify**. Never certify by model agreement.
- Every admitted record keeps provenance (owned source page / doc+question) **and** per-gate verification.
- Every batch ships ≥1 **deliberately damaged adversarial control**, and it must be REJECTED.
- `qpgen` internals frozen; `kie.db` read-only; bank not promoted; HELD scopes stay held.
- Raw/derived bulk stays **gitignored/local** (`knowledge/`, `resources/`, `staging/`). Commit only code,
  schema, tests, compact governance JSON/MD. Never commit `qie.db`/`kie.db`/page renders.
- Token discipline: deterministic first; reserve model reasoning for genuinely ambiguous extraction/examiner
  calls; batch; cache. **No agent swarms.**

## 10. Genuine blockers
**None.** No owner decision is outstanding. Everything in §7 is known, scoped work.

## 11. Key file map
```
curriculum/EVIDENCE_REGISTRY.{json,md}, EVIDENCE_MIGRATION_MAP.md   # canonical inventory + deferred moves
curriculum/scripts/intelligence/kie/
  evidence/{lifecycle,registry}.py
  qie/convert/{docmeta,candidates,examiner,register,kvs_compose}.py  # kvs_compose: BOTH assertion directions
  qie/convert/notation/{sources,targets,dimensions,verify,register,relation_compose}.py
  qie/convert/notation/{chains,chain_compose}.py                     # depth-4/5 HARD lane
  qie/convert/notation/batches/                                      # REPRODUCIBLE admissions + chain defs
    __init__.py __main__.py phys_batch1_2.json chem_batch3.json depth4_chains.json
  qie/store_schema.sql · qie/qp_bridge.py                            # ONLY qpgen integration point
  tests/{test_governed_conversion,test_notation_recovery,test_notation_chains}.py
docs/question-intelligence-quality/
  EVIDENCE_RECONCILIATION.md · GOVERNED_CONVERSION_CHECKPOINT.md
  GOVERNED_CONVERSION_BATCH1_AND_STORAGE_GOVERNANCE.md
  GOVERNED_CONVERSION_BATCH2_AND_NOTATION_FINDING.md · NOTATION_RECOVERY_CAPABILITY.md
  QIE_SESSION_HANDOFF.md                                             # this file
```
