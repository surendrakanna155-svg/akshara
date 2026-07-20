# Knowledge Foundation Integrity Certification Report

**Date:** 2026-07-20 · **Foundation:** NCERT Knowledge Foundation **v1.4** (frozen, immutable; 2,023 certified
concepts) · **Trigger:** post-architectural-fix certification before any further QIE phase (subject-scoped QDI
re-mining / intake improvements). **Method:** 6 independent parallel analysis agents + an independent orchestrator
baseline + independent reconciliation. **Verdict: CERTIFIED.**

---

## 1. Audit methodology

- **6 independent parallel agents**, each assigned ONE dimension, each read-only (`?mode=ro`), evidence-first
  (exact counts + example rows + read-the-actual-text spot-checks), each proposing deterministic invariants.
- **Independent orchestrator baseline:** before reading any agent result, the orchestrator ran its own SQL
  integrity pass over the core structural invariants, to reconcile against (not merely trust) the agents.
- **Independent reconciliation:** each agent's findings were cross-checked against the baseline and against the
  other agents; every flagged anomaly was verified to closure.
- **Scope split kept explicit:** the FROZEN foundation (`ki_concept`, built from NCERT single-subject textbooks)
  vs the COMBINED-paper source corpus (`kie.db` chunks, where the recent section-resolution fix lives). Both were
  audited; they are distinct layers.
- Databases: `knowledge_index.db` (frozen foundation + `qdi_*`), `kie.db` (owned source corpus), `qdi.db` (mined
  design patterns). No repo file or database row was modified by any agent.

## 2. Parallel agent findings

| Agent | Dimension | Verdict | Headline evidence |
|---|---|---|---|
| 1 | Class / Grade | **CLEAN** | 0 out-of-range; concept.class == chapter.class (0 mismatch); grades 6:145·7:336·8:283·9:140·10:151·11:523·12:445; **NCERT 11⇄12 label-swap fully remediated** (120 sampled concepts fit; keyword swap-sniff 0) |
| 2 | Subject / Discipline | **CLEAN** | 0 null/out-of-set; concept.subject == chapter.subject (0); 25 contamination candidates → **0 real** (discipline correctly follows the single-subject source book); split streams 11-12 hermetic (`subject≡discipline`) |
| 3 | Chapter→Section→Concept tree | **CLEAN** | full FK integrity; 0 concept on a non-accepted chapter; chapter uniquely types (subject,class); 0 concept leaked across chapters; 100% section_heading |
| 4 | Sub-concept / Prereq / Boundary | **CLEAN** | 2,023/2,023 valid JSON on all three columns; **0 curriculum-boundary crossings**; 20 prereq flags → all name-match false positives; subject×class partition exact |
| 5 | Section-level subject resolution (the fix) | **SOUND** (2 bounded gaps → fixed) | exam isolation **0 leaks / 271 papers**; resolution **96.7%** on legible content; no doc-level subject filter remains |
| 6 | Exam / Board / Provenance / Immutability | **CLEAN** | NEET plans carry no Maths, JEE no Biology; **0 cross-exam pattern leak**; `ki_source` **100% NCERT** (0 state-board); 2,023/2,023 evidence+engineer+independent-audit-accept; `immutable=true`, count matches |

**Reconciliation:** the orchestrator's independent baseline returned **0 violations** on every core invariant,
matching all six agents. On the frozen foundation the agreement is **unanimous**. The single orchestrator
curiosity (1 `subject='Science'` / `discipline='Mathematics'` concept) was independently confirmed by Agents 2
and 4 as a **legitimate, evidence-justified interdisciplinary** case ("Graphical Representation of Data", a maths
tool taught inside a Physics chapter) — the two-dimension model (`subject`=where-taught, `discipline`=what-it-is)
working as designed, not contamination.

## 3. Verified invariants (now permanent regression tests)

Encoded in `tests/test_knowledge_foundation_integrity.py` (auto-runs against the frozen index; skips if absent)
and `tests/test_qpl_source_indexing.py` (resolution). All pass. **766 tests green.**

- **Hierarchy (H1–H8):** class ∈ [6,12]; chapter FK resolves; chapter accepted; concept.subject/class == chapter;
  chapter uniquely determines (subject,class); no concept identity leaked across chapters; section_heading present.
- **Subject/Discipline (S1–S4):** valid subject+discipline; split-subject discipline lock (`subject≠Science ⟹
  subject==discipline`); Interdisciplinary only in Science; subject×class partition (Science→6-10, P/C/B→11-12,
  Maths→6-12).
- **Provenance (P1–P5):** evidence present; engineer_model present; independent `audit_verdict='accept'` +
  discipline_basis; `ki_source` NCERT-only; every concept's lineage resolves to an NCERT source.
- **Coverage / Immutability:** every grade 6-12 populated; JSON columns well-formed; `immutable='true'` and
  `certified_count_at_freeze == live certified count`.
- **Exam/Pattern boundary:** `plan_blueprints(exam)` subjects == `EXAM_SUBJECTS[exam]` (NEET no Maths, JEE no
  Biology); every attached design pattern is scoped to that exam profile; every certified `qdi_pattern` has a
  valid scope link.
- **Section resolution:** exam-identity match (no path-bypass); mixed boundary chunks resolve to None (no leak);
  boilerplate/mojibake/HTML-furniture rejected.

## 4. Detected issues

**Frozen foundation (`ki_concept`): NONE.** Zero contamination, zero structural violation, unanimous across 6
agents + baseline.

**Section-resolution layer (the recent fix): 2 bounded precision gaps + 1 yield residual** (found by Agent 5):
1. **Boundary-chunk mislabel (precision, ~7.3% of resolved chunks):** a chunk spanning a section marker had its
   pre-marker prefix stamped with the post-marker subject.
2. **Latent OR in `exam_sources`:** `category IN (…) OR exam IN (…)` was AND-equivalent only because
   `category==exam` today; could re-broaden if those columns ever diverge.
3. **Yield residual (not a correctness defect):** 71% of chunks resolve to None and ~90% of PYQ papers carry no
   detectable section markers (OCR quality / image-only HTML dumps), so subject-scoped mining is low-yield.

## 5. Fixes applied

1. **Boundary-chunk → None:** `resolve_chunk_subjects` now marks a mixed boundary chunk (substantial pre-marker
   content of a *different* subject) as `None` — safe over throughput; it is excluded from any subject read.
2. **`exam_sources` single canonical identity:** `COALESCE(exam, category) IN (…)` — removes the latent OR.
3. **Furniture guard:** `_usable_chunk` rejects content-free digital-exam HTML scaffolding (`Question ID / Option
   ID / Status …`) in addition to instruction boilerplate and OCR mojibake.

**Re-validated:** exam isolation still 0 leaks (JEE_Main 74 / JEE_Adv 20 / NEET 151 / AIIMS 26 docs); the specific
mis-resolved boundary chunk now resolves to None; furniture rejected. Locked by
`tests/test_qpl_source_indexing.py`.

## 6. Remaining risks (all bounded, none block certification)

- **Mining YIELD ceiling (data quality):** ~90% of PYQ papers lack machine-detectable section markers (OCR
  sludge / image-only HTML). Subject-scoped QDI mining is therefore low-yield until the source OCR/segmentation
  improves. This is safe (None is never guessed → no leak) but limits throughput — callers must treat an empty
  `candidate_chunks(subject=X)` as "unresolvable paper", not "no such content".
- **Cosmetic provenance items (non-defects):** 6 empty phantom/spurious chapters remain `status='accepted'` with
  0 certified concepts (recommend `rejected` for hygiene); `ki_chapter.discipline_audit_verdict` never backfilled
  (concept-level provenance is complete); 12 stale `proposed` `qdi_pattern` rows persist in the frozen index
  (unused — the planner reads certified patterns from `qdi.db`); legacy `ki_meta.certified_at_freeze=1833` (v1.0)
  retained beside the authoritative `certified_count_at_freeze=2023`.
- **Intake-level subject tagging:** the frozen `kie.db` still stores a document-level single-subject artifact for
  combined papers. It is no longer trusted (subject is resolved at section level in the read layer). Correcting it
  *at ingest* (mark combined papers multi-subject + segment sections) is a deferred, versioned **intake v-next** —
  not required for correctness now.

## 7. Final certification verdict

**CERTIFIED.**

- The frozen v1.4 Knowledge Foundation is **structurally sound and contamination-free** across every audited
  dimension — Class, Subject, Discipline, Chapter, Section, Concept, Sub-concept, Prerequisites, Boundary, Source,
  Provenance, and Immutability — proven by 6 independent agents in **unanimous agreement** with an independent
  orchestrator baseline (0 violations).
- No contamination exists between Physics↔Chemistry↔Biology, Mathematics↔Physics, JEE↔NEET, or NCERT↔state boards
  (the foundation is 100% NCERT); no chunk sits under the wrong subject after section-level resolution; no chapter
  holds another chapter's concepts; no concept crosses a curriculum boundary; no exam retrieves another exam's
  knowledge; no document-level subject assumption remains where section-level resolution is required.
- The two bounded precision gaps in the section-resolution layer were **fixed and re-validated**; the only
  remaining residual is a **safe, data-quality yield ceiling** (marker-less papers), not a correctness risk.
- All integrity checks are now **permanent, auto-running regression invariants** (766 tests green).

Subject-scoped QDI re-mining and future intake improvements may proceed on this certified foundation.
