# qcorpus Staging Manifest Schemas

The staging lane emits nine JSONL manifests (one row per record) under
`curriculum/staging/qcorpus_noncert/manifests/` (gitignored, local-only). They are **derived**
and rebuilt atomically from the per-document state records, so they are safe to regenerate at
any time (`python -m qcorpus.cli manifests`). This is the contract for **read-only** QIE
consumption — no consumer should write into the staging tree.

Identity: `doc_id = sha256(file)[:16]`; `question_id = "<doc_id>:qNNNN"`;
`asset_id = "<doc_id>:aNNNN"`.

## corpus_inventory.jsonl
Every source PDF discovered on disk (incl. exact-duplicate copies + failures).
`rel_path, sha256, doc_id, size, mtime_ns, page_count, priority, group, state,
is_duplicate?, duplicate_of?`

## document_extraction_manifest.jsonl
One row per unique (content-addressed) document.
`doc_id, sha256, rel_path, source_group, priority, state, page_count, encrypted, language,
classification{exam_profile, document_type(+confidence), subject_candidate(+confidence),
chapter_candidate(+confidence), topic_candidate(+confidence), source_url, topic_url},
signals{media_class(native|mixed|scanned), native_text_ratio, image_page_ratio,
scan_probability, ocr_page_count, layout_complexity, equation_density, visual_density,
table_density, chars_per_page, parser_method, parser_confidence},
parse_meta, question_summary, counts, duplicate_paths, text_fingerprint, normalized_filename`

## page_extraction_manifest.jsonl
One row per page. `doc_id, page, width, height, ocr(bool), normalized_text, search_text?,
has_notation, image_count, equation_count, table_count, block_count, raw_char_count`.
RAW page text (pre-normalisation) lives in `raw/<doc_id>.json`, never overwritten.

## extracted_questions.jsonl
One row per recovered question.
`question_id, doc_id, number, stem, stem_search_text?, options[{label,text}],
option_label_style(alpha|numeric|none), is_mcq, answer_ref?, answer_associated,
solution_present, solution_ref?, linked_equation_count, linked_asset_ids[], visual_dependent,
pages[], start_page, status, statuses[]`.
`status` ∈ {COMPLETE, PARTIAL, QUESTION_BOUNDARY_UNCERTAIN, OPTIONS_INCOMPLETE,
ANSWER_UNRESOLVED, SOLUTION_UNRESOLVED, VISUAL_DEPENDENT, FORMULA_UNCERTAIN, OCR_DAMAGED}.
COMPLETE = structurally bounded MCQ (stem + full option set, clean boundary, not OCR-damaged,
not formula-uncertain, not visual-dependent). Answers/solutions are linked ONLY where present
in the source — never fabricated.

## visual_assets_manifest.jsonl
`asset_id, doc_id, page_number, bbox, asset_type(raster_image|vector_region),
extraction_method, width?, height?, file_path?(rel to staging root), file_hash?,
vector_item_count?, decorative(bool), linked_question_ids[], association_confidence`.
Identical images (watermarks/logos) are de-duplicated per doc and flagged `decorative`.

## equation_recovery_manifest.jsonl
`doc_id, page_number, bbox, text, kind(inline|display), detector(font_symbol_heuristic)`.

## notation_repairs.jsonl
Additive repairs + uncertainty flags (raw text never mutated).
Repairs: `doc_id, page_number, original_text, repaired_text, repair_rule, repair_confidence`.
Flags: `doc_id, page_number, snippet, reason, flag=FORMULA_UNCERTAIN, repair_rule=flag_only`.

## duplicate_groups.jsonl
`type(exact|probable), signal(sha256|text_fingerprint|filename+page_count), confidence,
doc_id?/paths[]/doc_ids[]`. Nothing is deleted; both members of a probable group are preserved.

## extraction_failures.jsonl
`doc_id, rel_path, source_group, priority, error, encrypted, page_count`.
Failures are isolated per-document; the batch never aborts.
