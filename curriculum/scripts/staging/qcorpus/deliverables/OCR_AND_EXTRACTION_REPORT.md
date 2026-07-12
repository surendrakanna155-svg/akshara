# OCR & EXTRACTION REPORT — Question-Corpus Staging Lane

_Generated: 2026-07-12T06:01:55Z_

**Lane:** RAW DOCUMENT → LOSS-MINIMISING EXTRACTION → STRUCTURED STAGING CORPUS. NON-CERTIFIED · NON-PRODUCTION · never merged into kie.db or the Certified Question Bank.

## Corpus

| metric | value |
|---|---:|
| source groups | 7 |
| PDFs discovered (files on disk) | 865 |
| unique documents (content-addressed) | 863 |
| unique documents extracted | 862 |
| exact-duplicate copies collapsed | 2 |
| probable-duplicate groups | 11 |
| total pages | 12926 |
| native / mixed / scanned docs | 621 / 202 / 39 |
| OCR docs / OCR pages | 256 / 2673 |

### Document state

| state | count |
|---|---:|
| COMPLETE | 862 |
| FAILED | 1 |

## Parser routes (measured)

| method | docs |
|---|---:|
| mixed | 237 |
| pymupdf | 606 |
| tesseract | 19 |

## Question recovery (corpus-wide)

| metric | value |
|---|---:|
| questions recovered | 22759 |
| complete | 9421 |
| partial | 1064 |
| MCQ / non-MCQ | 12074 / 10685 |
| options associated | 12074 |
| answers associated | 10354 |
| solutions associated | 7585 |
| equation-bearing | 10372 |
| formula-uncertain | 510 |
| visual-dependent | 2062 |
| boundary-uncertain | 8151 |
| answer-unresolved | 12405 |
| solution-unresolved | 15174 |

## Visual + equation assets

- visual assets preserved: **70541**
- equation candidates recovered: **91878**
- notation records (repairs + uncertainty flags): **3007**

## By source group

| source group | docs | questions |
|---|---:|---:|
| allen_jee_main_mock | 4 | 90 |
| jeeadv_ac_in_archive | 62 | 822 |
| jeebooks_dpp | 3 | 1718 |
| mathongo_jee_advanced_dpps | 14 | 1853 |
| mathongo_jee_main_chapterwise | 86 | 2651 |
| physicsaholics_dpps | 316 | 4350 |
| studentbro_neet_dpps | 377 | 11275 |

## By priority

| priority | docs | questions |
|---|---:|---:|
| P1_studentbro_biology | 39 | 1798 |
| P2_studentbro_chemistry | 87 | 3728 |
| P3_studentbro_physics | 87 | 3139 |
| P4_mathongo_jee_main | 86 | 2651 |
| P5_studentbro_mathematics | 164 | 2610 |
| P6_mathongo_jee_advanced | 14 | 1853 |
| P7_jee_advanced_archive | 62 | 822 |
| P8_physicsaholics | 316 | 4350 |
| P9_allen_and_jeebooks | 7 | 1808 |

## By subject

| subject | docs | questions |
|---|---:|---:|
| Biology | 39 | 1798 |
| Chemistry | 115 | 5030 |
| Mathematics | 201 | 4052 |
| Physics | 441 | 10967 |
| UNKNOWN | 66 | 912 |

## Manifest row counts

| manifest | rows |
|---|---:|
| corpus_inventory | 865 |
| document_extraction_manifest | 863 |
| duplicate_groups | 13 |
| equation_recovery_manifest | 91878 |
| extracted_questions | 22759 |
| extraction_failures | 1 |
| notation_repairs | 3007 |
| page_extraction_manifest | 12926 |
| visual_assets_manifest | 70541 |

## Integrity & isolation

- RAW extraction preserved separately from NORMALIZED (raw/ never overwritten).
- Normalized text never overwrites raw evidence; notation repairs are additive (`search_text`); ambiguous notation flagged FORMULA_UNCERTAIN, never silently changed.
- Every COMPLETE question carries source provenance (doc_id + sha256 + page span).
- Resume is crash-safe: terminal-state docs are skipped on re-run (atomic checkpoints).
- This lane writes ONLY under the staging root (every write sink is STAGING_ROOT-derived; audited statically). It has NO KIE-DB write path (no store/sqlite/execute in qcorpus).
- Phase-0 pre-registration is byte-frozen (unchanged). kie/qpgen/ unchanged by this lane.
- kie.db is a live SQLite DB in WAL mode concurrently owned by the separate KIE/Phase-0 lane; its whole-file hash may change from that lane's checkpoints. This lane is proven NOT the writer: (1) static — no DB write path; (2) runtime — a controlled extraction leaves kie.db byte-identical (isolation probe: `kie_db_unchanged_by_lane`).
