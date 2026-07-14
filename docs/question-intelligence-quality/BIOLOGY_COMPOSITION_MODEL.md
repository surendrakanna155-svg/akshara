# Biology on the unified compositional engine — model determination

**Date:** 2026-07-14 · Owner-directed: extend the unified compositional architecture to Biology across genuine
NEET reasoning (concept, process, cause-effect, pathway, genetics, physiology), **not** restricted to
quantitative, while preserving the **locked verification hierarchy** (deterministic/domain verifier → evidence/
KVS corroboration → LLM only as fallback/examiner). This documents what the evidence supports and the resulting
model.

## Evidence audit (read-only) — what the corpus actually holds

| Source | State | Usable for deterministic Biology? |
|---|---|---|
| `kvs_sequence`, `kvs_structure_function`, `kvs_comparison` | **empty (0 rows)** | No — the structured tables that would hold pathways / structure-function / comparisons were never populated. |
| `kvs_assertion` (1,761), `kvs_taxonomy` (131) | present but **noisy** (document-structure, e.g. "Heartbeat"→"Blood vessels"; `parent_child` predicates; `evidence_count=0`) | No — not clean biological relations. |
| `question_dna` Biology (248, across PROCESS_SEQUENCE/CAUSAL/STRUCTURE_FUNCTION/… lanes) | lane-tagged but `construction` is **thin** (`{"concept":"BIO_X"}`), `solution_dna` empty | No — carries the concept label but not the structured relation. |
| `concept_edges` (1,654) | `relationship_type = parent_child` (document hierarchy noise); concept `definition` fields empty | No — not "part-of / causes / precedes / performs". |
| `tier2_verdict` (411 **agree**, Biology) | rich verified content but as **free text** in `note` (e.g. "Bt toxin order B→E→C→A"; "Noise stress → adrenaline → nervousness") | **As corroboration only** — verified facts, but unstructured; cannot be a deterministic generator/verifier substrate on its own. |

**Determination:** the corpus does **not** provide clean, structured, deterministically-verifiable biological
*relations*. Auto-extracting them from the noisy corpus would require an LLM to structure free text — which
would make an LLM the **primary truth source**, violating the locked hierarchy. Therefore, exactly as we did
for Chemistry (`chem_data.py` — a verified periodic-table/balanced-equation base rather than trusting noisy OCR),
deterministic evidence-grounded Biology uses a **curated canonical knowledge base** plus a **deterministic
genetics solver**.

## The model (unified engine, same operators/compositions/verification/depth)

1. **Genetics — deterministic solver** (`genetics.py`). Mendelian inheritance is rule-based and computable:
   monohybrid/dihybrid ratios, test cross, blood-group and sex-linkage. Verified **two independent ways**
   (explicit Punnett-square enumeration vs. the ratio formula) — a genuine **Tier-1 deterministic** verifier,
   no corpus needed. This is core NEET Biology and needs no evidence table.

2. **Concept / process / pathway / structure-function / cause-effect / taxonomy — curated canonical KB**
   (`bio_data.py`) + evidence-grounded compositions (`biology.py`). The KB encodes **canonical NEET facts**
   (blood-circulation and digestion order, cardiac cycle, nephron/urine formation, mitosis phases; gland→
   hormone→effect; structure→function→system; deficiency→disease; taxonomic ranks). Questions are generated
   **from** the KB and verified **against** it by deterministic lookup/traversal (e.g. "what immediately follows
   step X in process P?" is checked against the canonical ordered list; "which structure performs function F?"
   against the canonical structure→function map). Multi-hop **compositional depth** chains relations
   (gland→hormone→effect; structure→function→system), each hop verified against the KB.

3. **Verification hierarchy (locked) — how each tier is used:**
   - **Tier-1 deterministic** — genetics solver (two-way); KB lookup/traversal for order/relation questions.
   - **Tier-2 evidence corroboration** — the 411 Tier-2-verified Biology facts corroborate KB entries where they
     overlap; a KB entry contradicted by a verified fact is rejected.
   - **Tier-3 LLM** — **quality examiner only** (phrasing, ambiguity, single-answer). Never the truth source,
     never the generator of the answer.

## Honesty
The curated KB is **canonical textbook knowledge** (like the periodic table), not corpus-extracted noise and not
LLM-fabricated; each fact is human-verifiable and, where possible, corroborated by the Tier-2 set. This is the
correct deterministic, evidence-grounded model *given the measured absence of clean structured relations in the
corpus* — and it keeps Biology on the one unified engine (operators + compositions + independent verification +
computed reasoning depth), exactly like Physics and Chemistry. `kie.db`/`qpgen`/Certified Bank remain untouched.
