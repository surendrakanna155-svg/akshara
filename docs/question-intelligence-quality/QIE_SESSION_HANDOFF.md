# QIE — fresh-session handoff (authoritative resume point)

**Date:** 2026-07-15 · **Branch:** `feature/qp-content-readiness` · **Tip:** `b8658084` · **Working tree:** clean
on the QIE lanes · **Tests:** 585 green (`python -m unittest discover -s kie/tests`)

**Read this instead of re-auditing.** Everything below is committed and verified. Do NOT re-derive it.

---

## 1. Environment (exact)
- Python venv: `curriculum/.venv/bin/python` (3.14). Run modules from `curriculum/scripts/intelligence/`
  (so `import kie` resolves), e.g. `cd curriculum/scripts/intelligence && ../../.venv/bin/python -m unittest discover -s kie/tests`.
- Deps present: PyMuPDF 1.28, sympy 1.14, PIL. No network needed.
- Lanes: this worktree = **K (QIE) lane**. The ERP lane lives in a *separate* worktree (`Akshara_ERP-drp`) —
  do not touch it. Check `git branch --show-current` before every commit.

## 2. Locked scope (unchanged)
**In scope:** JEE Main, JEE Advanced, NEET, NCERT/CBSE 6–10 Math & Science, NCERT/CBSE 11–12 Math/Physics/
Chemistry/Biology. English only.
**HELD (do not start):** Classes 1–5, AP/TS/ICSE/other state boards, broader school-exam work, broad new
acquisition, Question-Bank promotion/materialization.
**Frozen:** `kie/qpgen/` internals (integrate only through `kie/qie/qp_bridge.py`), `kie.db` (read-only),
the pilot bank (not promoted).

## 3. Owner decisions (locked — do not re-litigate)
- **Decision A (RESOLVED, implemented `c2dc071d`, hardened `0af09076`):** verified **governed-fact chapters** and
  **certified relations** are *first-class in-scope concepts* for the qpgen boundary, guarded by (a) the
  deterministic subject gate and (b) the same `qpgen/sanitize.is_clean_concept` gate as every other concept.
- **Decision A/notation (RESOLVED, implemented `4c18a5d5`, scaled `b8658084`):** build a governed **math-capable
  notation recovery** layer over already-owned source PDFs/page-images. Reusable layer, not a one-off.
- **Standing law:** wrong knowledge is worse than missing knowledge. Never weaken a gate to raise yield. LLM
  **proposes**; deterministic checks **certify**. No source-question cloning.

## 4. What exists (committed, working)

### Canonical evidence registry (governance correction)
`curriculum/EVIDENCE_REGISTRY.{json,md}` + `EVIDENCE_MIGRATION_MAP.md`. Store-level source of truth: **23
stores / 59.4 GB**, each with a lifecycle state `1_raw → 2_ocr → 3_extracted → 4_recovered → 5_verified →
6_concept_bound → 7_qie_available` (`q_quarantine`). Regenerate: `python -m kie.evidence.registry`
(read-only; `REGISTRY_NOW=<iso>` for a deterministic stamp).
**No files were moved** — active code hard-references current paths; the migration map holds the deferred
old→canonical layout + safe per-store procedure. Detail layers (`PROVENANCE_MANIFEST.json`, `indexes/`,
`reports/`, qcorpus manifests) are *referenced, never duplicated*.

### Governed qualitative conversion — `kie/qie/convert/`
`docmeta` (deterministic per-doc **subject hard gate** + exam + chapter from rel_path/priority/filename; 863
docs → 797 subject-confident) → `candidates` (OCR-quality funnel: 6,558 answer-keyed MCQs → **1,774 clean
non-numeric** + 3,606 numeric) → `examiner` (bounded, **cached by item_hash** — refuted evidence is never
re-sent) → `register` (single admission path → `governed_fact` + typed KVS + `distractor_dna`) → `kvs_compose`
(fresh questions through the same engine).

**Admitted: 92 verified facts / 20 rejected** (batches 1–2, 76–88% survival) — `kvs_structure_function` 14,
`kvs_sequence` 17, `kvs_comparison` 8, governed `kvs_assertion` 53, **`distractor_dna` 274**.
Subjects: Biology 54 · Chemistry 27 · Physics 11.

### Notation recovery — `kie/qie/convert/notation/` (the new capability)
| module | role |
|---|---|
| `sources` | render ANY owned source page (plain PDF **or chapter PDF inside a textbook .zip**), cached; `math_damage_score` |
| `targets` | pick pages: damage score + **SUMMARY / POINTS-TO-PONDER / quantity-table** pages (highest relations-per-read) |
| *(vision)* | transcribes exact equation/symbols/meanings/units/sub+superscripts/constants — **PROPOSES ONLY** |
| `dimensions` | unit→SI parsing + **base-dimension reduction** (`A·ohm == V`) |
| `verify` | **LOCKED hierarchy** (below) |
| `register` | `governed_relation` + provenance + per-gate evidence |
| `relation_compose` | fresh numeric items from CERTIFIED relations → engine → qpgen |

**Locked hierarchy — mandatory:** `PROVENANCE` (read from a real owned page) · `SYMBOLIC` (parses, no
undeclared symbol) · `DIMENSIONAL` · `DOMAIN` (subject-gated) · `ROUND-TRIP`.
**ANSWER-KEY is CORROBORATION ONLY — never sufficient.**

**14 relations certified / 2 rejected.** Physics: work-energy theorem, `V=mgx`, `V=½kx²`, elastic collision,
`V=−Gm₁m₂/r`, Kepler `T²=K_S R³`, Coulomb `F=(1/4πε₀)q₁q₂/r²`, `R=V/I`, `R=ρl/Ar`, `v_d=q_e Eτ/m`, `μ=v_d/E`,
`j=I/Ar`, Wheatstone `R1=R2R3/R4`, `σ=1/ρ`.

## 5. Hard-won lessons — DO NOT REPEAT THESE MISTAKES
1. **⛔ NEVER retry blind arithmetic relation-induction.** Measured: 1,044 Physics items "verify" a library
   relation, only 101 chapter-consistent, **ZERO** ≥2-doc corroborated → ~90% false positives. `V=IR` is just
   `a×b` so it matched *Waves, Calorimetry, Motion*. A relation name is meaningless without the symbol/unit
   binding OCR destroyed. Nothing was registered from it — correctly.
2. **Answer-key can never certify alone.** A *damaged* control (`½kx`, lost square) scored answer-key
   corroboration **5/15** — real questions "confirmed" wrong physics — and the dimensional gate overruled it.
   Pinned by `test_answer_key_alone_cannot_certify`.
3. **The dimensional gate outranks the source.** NCERT's unit column says conductivity is "S" but its own
   dimensions column `[M⁻¹L⁻³T³A²]` gives S m⁻¹; the verbatim transcription was rejected.
4. **A gate that rejects truth is also a defect.** Three fixed: like-unit substitution *cancels*
   (`joule−joule=0` killed `W=K_f−K_i`) → scale each symbol's unit by a distinct coefficient; `positive=True`
   made the legitimately-negative `V=−Gm₁m₂/r` unsolvable → use `real=True`; a **missing unit** (siemens)
   silently rejected a correct relation — extend `dimensions.UNITS` when adding a subject.
5. **qpgen dedups by (concept, question_type)** → bind at **relation granularity** (`Physics :: Ohm's law`),
   never chapter. Chapter-level binding made 7 new relations buy **+1** slot; relation-level gave **+8**.
   **Coverage scales with DISTINCT CONCEPTS, not relations per chapter.**
6. **Governed concept titles must pass `sanitize.is_clean_concept`** (MAX_WORDS=5) or you get
   `UNCLEAN_CONCEPT` boundary breaches — `qp_bridge._clean_title` handles it; uncleanable → honest shortfall.
7. **NCERT class labels are swapped:** `NCERT_Class12_keph1dd.zip` actually contains the **Class XI** book;
   `NCERT_Class11_leph1dd.zip` contains **Class XII**. Trust `sources.entry_title()`, not the filename.
8. **kie.db concepts are noisy** ("Gauss's law" tagged Biology). Never bind by naive title substring.
9. Don't print the formula in a generated stem (giveaway) — author from recovered **meanings**.
10. `flutter`-style pipelines aside: read the `+N −M` tally; never trust a piped exit code.

## 6. Measured balance (real QIE → qpgen, seed 7, `boundary_ok`, 0 forced fills)
| exam | baseline | **now** | composition |
|---|---|---|---|
| NEET | 5 | **38** | Physics 18 · Biology 17 · Chemistry 3 · 38 distinct concepts |
| JEE Main | — | **29** | Physics 18 · Maths 8 · Chemistry 3 |
| JEE Advanced | — | **17** | Physics 6 · Maths 8 · Chemistry 3 |

Reproduce:
```python
from kie.qie import qp_bridge as QB; from kie.qpgen.models import PaperRequest
paper, report = QB.generate_paper(PaperRequest(exam="NEET", seed=7), per=18)
```

## 7. Remaining work — scale, not capability (no owner decision needed)
**Ordered by value:**
1. **Notation recovery breadth (highest value).** Most NCERT Physics chapters + **all Chemistry and Maths** are
   untouched. Each SUMMARY/quantity-table page ≈ 5–8 relations. Loop:
   `targets.select(store, subject)` → `sources.render` → **read the image** → transcribe → `register.register`
   (certifies). Pattern to copy: `scratchpad/recover_batch1.py` / `recover_batch2.py` (see §8).
   Always include ≥1 **deliberately damaged adversarial control** per batch and confirm it is rejected.
2. **Qualitative batch 3+.** ~1,660 clean candidates queued (mostly `CONCEPTUAL_GENERIC`) at 76–88% yield.
   `examiner.select_batch(cands, conn, n=..., lanes=..., prioritize_subjects=...)` → worksheet → examine →
   `ingest_verdicts`.
3. **Assertion-direction fix.** 42/52 assertions don't generate: the source asked *term→definition*, so the
   stored real distractors aren't parallel to an inverted authored stem. Fix at **examiner time** — author
   `subject_term`/`predicate`/`object_term` in the SOURCE's direction (so `answer_text` ≈ `subject_term`), which
   `kvs_compose._assert_usable` already requires. Unlocks ~42 verified facts with authentic distractors.
4. **JEE Advanced depth-4/5 (the one structural gap).** It sits at 17 and will NOT move on more single
   relations: its blueprint demands HARD multi-concept items, and `relation_compose` emits MEDIUM (depth-3).
   Needed: compositional **chains over certified relations** (feed one relation's output into another, as
   `compositions.py` `_T3`/`_T5` do for Maths) so `qp_bridge._difficulty(depth>=4) == HARD`.

## 8. Exact next execution point
Start with (1) **notation breadth on Chemistry** (Chemistry is at 3 in every paper — the weakest subject):
```
cd curriculum/scripts/intelligence
../../.venv/bin/python -c "
from kie.qie.convert.notation import targets as T, sources as S
Z='resources/foundation/NCERT/Class_11/Textbooks/NCERT_Class11_lech1dd.zip'   # verify with S.entry_title()
for t in T.select(Z,'Chemistry',per_chapter=1)[:4]:
    print(t.chapter_title, t.page.page, t.damage, t.is_summary, S.render(t.page, dpi=160))"
```
then Read each PNG, transcribe → build records like `recover_batch2.py` → `register.register(...)` →
re-measure §6 → commit. Extend `dimensions.UNITS` for any chemistry unit that fails to parse (do not guess).

## 9. Safety constraints (non-negotiable)
- Register **only** certified/verified records; persist rejects (never re-examine refuted evidence).
- LLM proposes; **sympy/deterministic gates certify**. Never certify by model agreement.
- Every admitted record keeps provenance (owned source page / doc+question) **and** per-gate verification.
- `qpgen` internals frozen; `kie.db` read-only; bank not promoted; HELD scopes stay held.
- Raw/derived bulk stays **gitignored/local** (`knowledge/`, `resources/`, `staging/`). Commit only code,
  schema, tests, compact governance JSON/MD. Never commit `qie.db`/`kie.db`/page renders.
- Token discipline: deterministic first; reserve model reasoning for genuinely ambiguous extraction/examiner
  calls; batch; cache. **No agent swarms.**

## 10. Genuine blockers
**None blocking.** The prior notation blocker is resolved (capability built). JEE Advanced's depth-4/5 gap is
*known work*, not a blocker. No owner decision is outstanding.

## 11. Key file map
```
curriculum/EVIDENCE_REGISTRY.{json,md}, EVIDENCE_MIGRATION_MAP.md   # canonical inventory + deferred moves
curriculum/scripts/intelligence/kie/
  evidence/{lifecycle,registry}.py                                   # store-level registry + scanner
  qie/convert/{docmeta,candidates,examiner,register,kvs_compose}.py  # governed qualitative conversion
  qie/convert/notation/{sources,targets,dimensions,verify,register,relation_compose}.py
  qie/store_schema.sql                                               # governed_fact, governed_relation, KVS
  qie/qp_bridge.py                                                   # ONLY qpgen integration point
  tests/{test_governed_conversion,test_notation_recovery}.py
docs/question-intelligence-quality/
  EVIDENCE_RECONCILIATION.md · GOVERNED_CONVERSION_CHECKPOINT.md
  GOVERNED_CONVERSION_BATCH1_AND_STORAGE_GOVERNANCE.md
  GOVERNED_CONVERSION_BATCH2_AND_NOTATION_FINDING.md                 # why induction is unsafe
  NOTATION_RECOVERY_CAPABILITY.md                                    # the capability + proofs
  QIE_SESSION_HANDOFF.md                                             # this file
```
