# Multimodal Document Ingestion Architecture

**Date:** 2026-07-11 · **Status:** SPEC (proposal — not implemented)
**Goal:** Extract the full structure of complex educational PDFs — text, equations, diagrams, tables,
question boundaries — with provenance, so nothing that the source question depends on is silently lost.
**Governs:** the input to Question DNA extraction. Replaces the "one parser for every PDF" reality.

---

## 1. What is wrong today (measured)

Current pipeline (`phase2_parse.py` → `phase4_chunk.py`):
- **One route for all documents**: PyMuPDF text + Tesseract fallback (only when a page has <20 chars) +
  pdfplumber tables. No document-class routing; no multi-column reading-order reconstruction.
- **Equations** are a font/symbol heuristic that tags spans and truncates to 200 chars; the result lives
  in a transient `parsed/<doc_id>.json` and is **never persisted or read downstream**.
- **Images/figures** are extracted (xref, bbox, dims, digest) into the same JSON side-file and **dropped
  at the DB boundary** — no `images` table, no chunk link; no phase after Phase 2 reads them.
- **Question boundaries are never detected**: chunking is token-budget + heading only; `block_type` is
  only ever `paragraph` or `table`. A stem, its options, and its solution can split across chunks or merge
  with unrelated prose, with no link declaring "these are one question."
- **Provenance is partial**: `page_start/end` populated; `char_start/end` columns exist but are always
  NULL; **no bounding box reaches the relational store at all**.

Consequence: even where the corpus is rich (verbatim NEET/JEE MCQs with real distractors), the structure
is destroyed before it can become an Item Model, and diagram-dependent questions cannot be identified.

---

## 2. Design principle — route, don't force

> No single parser is correct for a native-text JEE paper, a scanned regional textbook, a two-column
> question bank, and an equation-dense worksheet. Classify first, then route.

```
PDF
 → integrity verification            (reuse phase1_verify: hash, page count, not-encrypted)
 → document classification           (native | scanned | mixed | multi-column | equation-heavy | diagram-heavy)
 → per-class parser route            (§4)
 → text extraction + OCR fallback
 → formula extraction                (real, structured — §5)
 → image / vector-drawing extraction (persisted — §6)
 → table extraction                  (existing pdfplumber/PyMuPDF path — keep)
 → reading-order reconstruction      (multi-column aware — §7)
 → QUESTION BOUNDARY detection       (stem / options / answer / solution — §8)
 → visual association                (link figures/equations/tables to their question — §9)
 → provenance record                 (§10)
```

Each stage records confidence; low-confidence documents are quarantined for review, not silently ingested.

---

## 3. Benchmark corpus (build before choosing parsers)

Assemble a labelled benchmark spanning the hard cases, so parser choice is **measured**, not assumed:
```
native text PDFs · scanned PDFs · multi-column · equation-heavy math · chemistry notation
· physics diagrams · biology figures · graphs · tables · assertion-reason layouts
· match-the-following layouts · questions spanning pages
```
For each document, hand-label the ground truth: question count, per-question stem/options/answer text,
present figures/equations/tables. Metrics per parser route: question-boundary F1, option-association
accuracy, equation-capture rate, figure-capture rate, table-cell accuracy, reading-order correctness,
OCR CER on scanned pages.

---

## 4. Parser routing (benchmark-driven, licence-compatible)

Candidates to benchmark (all must be licence-compatible for local analytical use):
```
PyMuPDF (fitz)   — native text, blocks, images, vector drawings, tables   (already in use)
Tesseract        — OCR fallback for scanned pages                          (already in use)
pdfplumber       — ruled-grid tables                                       (already in use)
Docling          — layout + reading order + tables + formula regions       (evaluate)
MinerU           — scientific/scanned layout + formula + reading order     (evaluate)
Marker           — PDF→structured markdown, equations to LaTeX             (evaluate)
```
**Do not adopt on reputation — adopt on benchmark score per document class.** Likely outcome (to be
proven): keep PyMuPDF for native text; route scanned/equation-heavy/multi-column to whichever of
Docling/MinerU/Marker wins the benchmark for that class; keep pdfplumber for tables. Routing table is
versioned and re-run when a parser is upgraded.

**No silent caps:** if a route cannot handle a document class, that is logged and the document is
quarantined — never partially ingested and reported as complete.

---

## 5. Formula / equation extraction (real, not a heuristic tag)

Target: a structured representation, not a truncated glyph string.
```
equation {
  raw_text, latex_or_mathml (where the route can produce it), bbox, page,
  kind: display | inline, symbols[], detector, confidence,
  linked_question_id (§9)
}
```
Where the route emits LaTeX/MathML (Marker/MinerU), store it. Where only glyphs are available, store the
raw text + symbols and flag `equation_confidence` low. Feed into the **relation library**: an equation
that solver-verifies against a source problem's numbers becomes a real `formulas.expression` (+ `symbols`)
entry — closing the "law names only" gap (`phase5_concept.py:155-163`).

---

## 6. Image / figure / vector-drawing extraction (persist, link)

Every visual asset is persisted (new `visual_assets` store; detail in
`VISUAL_INTELLIGENCE_SPECIFICATION.md`) with:
```
asset_id, resource_id, page, bbox, kind (raster|vector), digest, dims, extraction_confidence,
linked_chunk_id, linked_question_id
```
Vector drawings (PyMuPDF `get_drawings`) are captured too — many physics/geometry figures are vector, not
raster, and are the ones we can most faithfully reconstruct as semantic visuals. **The DB-boundary drop is
eliminated**: assets that today die in the JSON side-file get a persisted row and a chunk/question link.

Source assets remain L2 analytical only; production items use generated semantic visuals (VISUAL spec).

---

## 7. Reading-order reconstruction (multi-column)

For multi-column classes, use the route's layout model (Docling/MinerU produce reading order) or a
geometric column-detection pass (cluster block x-ranges, order within column, then columns L→R). Without
this, a two-column question bank interleaves unrelated columns into one chunk — an observed corruption
mode. Reading order is validated on the benchmark before a multi-column document is trusted.

---

## 8. Question-boundary detection (the missing structural layer)

The single highest-value ingestion upgrade. After reading-order reconstruction, detect and bind:
```
question {
  question_id, resource_id, page(s), bbox_span,
  question_number,          // "1.", "Q7", "(iii)"
  stem_block,               // the prompt text
  option_blocks[],          // (1)(2)(3)(4) / (A)(B)(C)(D) — separated, ordered
  answer_ref,               // where the key is (answer line / answer table / end-of-paper key)
  solution_ref,             // worked solution block if present
  linked_visual_ids[],      // figures/equations/tables this question uses (§9)
  extraction_confidence
}
```
Detection is deterministic-first (numbering regex, option-marker runs, "Ans:"/answer-key tables, assertion
/reason and match-column layouts — logic already prototyped in `phase7_questions.is_question/classify_type`
but currently applied to arbitrary chunks). A Tier-1 model resolves ambiguous boundaries only where the
deterministic pass is unsure. New `block_type` values (`question`, `option`, `solution`) — already promised
by the `chunks` schema comment but never written — are populated here.

**Rules:** never drop a diagram; never convert a diagram-dependent question to text-only; a question that
spans a page break stays one `question` with a multi-page `bbox_span`; if a stem and its options cannot be
confidently bound, flag the question `ambiguous_source` rather than emit a broken item.

---

## 9. Visual/answer/solution association

Bind each figure/equation/table to the question that references it (proximity + caption/number matching +
"see figure" references). Store `linked_question_id` on the asset and `linked_visual_ids[]` on the
question. This is what lets Visual DNA determine `answerable_without_visual` and lets the diagram-locked
flag work.

---

## 10. Provenance record (mandatory, per extracted unit)

Every extracted question and asset carries:
```
resource_id, page_number, bounding_box, question_number, source_text_block_ref,
option_block_refs[], linked_image_ids[], linked_diagram_ids[], linked_table_ids[],
linked_formula_ids[], answer_reference, solution_reference, extraction_confidence, license_status
```
This closes today's provenance gaps: `char_start/end` populated, bbox persisted to the relational store,
images/equations linked to chunks. It is the substrate the DNA layer requires (`QUESTION_DNA_SPEC` §2).

---

## 11. Relationship to intake and the frozen phases

- Intake (`intake/pipeline.py`) reuses the phase functions, so improving Phase 2/4 here improves intake
  automatically — but this is a **scoped change to the ingestion phases**, not a content-lane-only change,
  and is called out as such in the roadmap (Phase E).
- The change is additive to the store: new tables (`visual_assets`, `questions`) + populated columns
  (`char_start/end`, new `block_type`s, real `formulas.expression`). Existing certified downstream
  behavior is preserved; the 360-doc baseline is re-derived, not re-authored.

---

## 12. Acceptance criteria

- Parser routing chosen by measured benchmark score per document class (not by default).
- Question-boundary F1, option-association accuracy, and figure/equation capture rate reported per class;
  regressions blocked.
- Zero silent diagram loss: every source figure is either persisted+linked or the question is flagged
  diagram-locked — measured and reported.
- Every extracted unit carries full provenance incl. bbox and licence class.
- Ambiguous/low-confidence documents quarantined, counted, and surfaced — never silently ingested.

---

## Reconciliation Amendment (2026-07-12, post-Fable-5) — the E-lite boundary

Governed by `OPUS_FABLE_RECONCILIATION_RECORD.md` F9/§6. The board-acquisition lane is **live** (171 verified
/ 227 downloaded PDFs, 2026-07-09) and the owner is preparing ~200-300 more. If these ingest through the
current phases, their equations/figures/question-boundaries are destroyed at the known loss points and must
be re-parsed later — colliding with intake dedup/versioning and the "360-doc baseline immutable" rule. So a
minimal slice moves **early** (into Phase A), while the full platform stays late (Phase E-full).

**E-LITE (Phase A) — the minimum ingestion capability required BEFORE large-scale DNA mining. For newly
ingested documents, persist so nothing the source question depends on is silently lost:**
- question / option / answer / solution **boundary block types** (populate the `chunks` block_type values the
  schema already enumerates but never writes) with question↔option↔answer↔solution association;
- **equations** (raw + LaTeX/MathML where the parser yields it) and **tables** persisted and linked, not
  dropped at the parse→chunk boundary;
- **images / vector drawings** persisted to `visual_assets` with a chunk/question link (eliminate the
  JSON-side-file drop);
- **page + bbox + char-offset provenance** on every extracted unit; licence class carried through.

**Explicitly NOT in E-lite (stays Phase E-full):** the multi-parser routing **benchmark** (Docling/MinerU/
Marker adoption), reading-order reconstruction beyond the deterministic pass, semantic-visual **generation**
(SVG), and the DIAGRAM_VISUAL / graph-DATA_INTERPRETATION / EXPERIMENT_OBSERVATION generation lanes.
E-full's parser benchmark is also scoped down: **2 candidates × 4 dominant document classes × ~25 labelled
docs** first, expanding only when a real document class demands it — not 4 parsers × 12 classes up front.

E-lite is additive and versioned; it must reconcile with intake immutability as an owner-visible governance
edit (Record §8, risk 8).
