# Full Repository Processing Report — Knowledge Intelligence Engine

_Deterministic pipeline (Phases 1–7), canonical `kie/` package, no LLM. Verification: 16/16 checks passed._

## Verdict: ✅ CERTIFIED — all verification checks passed

## Verification checks

| Check | Result | Detail |
|---|---|---|
| All processable docs parsed | ✅ | parsed=360 processable=360 |
| Parse stage ledger complete | ✅ | parse-done=360/360 |
| No failed stages | ✅ | failed=none |
| No doc stuck between stages (parse→metadata→chunk→concept) | ✅ | 0 parsed docs missing a downstream stage |
| Metadata records == parsed | ✅ | metadata=360 parsed=360 |
| Chunk ledger complete | ✅ | chunk-done=360/360 |
| Concept ledger complete | ✅ | concept-done=360/360 |
| FTS5 index consistent with chunks | ✅ | chunks_fts=33870 chunks=33870 |
| Parsed JSON files match DB rows (no orphans/missing) | ✅ | disk=360 db=360 orphan=0 missing=0 |
| Every parsed output_ref file exists on disk | ✅ | missing_output_ref=0 |
| No orphan chunks (all reference a source doc) | ✅ | orphan_chunks=0 |
| Knowledge Graph refreshed after full concept extraction | ✅ | graph@2026-07-10T08:47:04Z >= concept@2026-07-10T08:38:48Z |
| Concept edges present (graph non-empty) | ✅ | edges=2640 |
| Question Intelligence refreshed after full chunking | ✅ | questions@2026-07-10T08:50:20Z >= chunk@2026-07-10T08:38:47Z |
| Question patterns present | ✅ | patterns=4853 |
| All parsed docs use current parser schema | ✅ | 0 docs parsed by an earlier parser version (missing enriched fields) |

## 1. Documents processed

| Metric | Value |
|---|---:|
| Total source documents | 362 |
| Certified (D-5) | 360 |
| Processable (certified, non-excluded) | 360 |
| **Parsed** | **360** |
| Metadata records | 360 |
| Document sections | 29210 |

## 2. OCR vs native-text

- Native-text (no OCR) documents: **205**
- OCR-involved documents: **155**  (mean OCR confidence 84.6)

| Parse method | Docs | Pages |
|---|---:|---:|
| pymupdf | 202 | 8794 |
| tesseract | 92 | 2094 |
| mixed | 38 | 1014 |
| archive:mixed | 25 | 6102 |
| archive:pymupdf | 3 | 512 |

## 3. Parse success/failure

- Parsed successfully: 360/360
- Failed: 0
- Skipped by design (exclude/corrupt): 2

## 4. Chunks

- Total chunks: **33870**  (FTS5 rows: 33870)
- Docs with zero chunks: 0
- By block type: {'paragraph': 22728, 'table': 11142}

## 5. Concepts

- Total concepts: **2548**
- By subject domain: {None: 5, 'Biology': 606, 'Chemistry': 377, 'Mathematics': 629, 'Physics': 931}
- Formulas: 281

## 6. Knowledge Graph

- Concept edges: **2640**  ·  concept→board mappings: 2548
- Edge kinds: {'parent_child': 803, 'prerequisite': 15, 'related': 1822}
- Refreshed at: 2026-07-10T08:47:04Z (after concept stage @ 2026-07-10T08:38:48Z)

## 7. Question Intelligence

- Question patterns: **4853**  ·  families: 2015
- Pattern types: {'assertion_reason': 378, 'match': 290, 'mcq': 1592, 'numerical': 537, 'short_answer': 2056}
- Bloom levels: {'analyze': 512, 'apply': 1390, 'hots': 481, 'remember': 896, 'understand': 1574}
- Refreshed at: 2026-07-10T08:50:20Z (after chunk stage @ 2026-07-10T08:38:47Z)

## 8. Duplicates

- Exact duplicates (skipped): 1
- Corrupt (excluded): 2
- Excluded/unsupported: 2

## 9. Processing time

- 1h 24m 2s (final resumed segment)
- Note: total wall-clock spanned several resumable segments (mid-run optimizations: detection-first OCR + graphics-heavy hang fix); the pipeline is content-hash checkpointed.

## 10. Warnings / quality issues

- OCR docs below 60% confidence: 4
- Docs parsed by an earlier parser version (missing enriched fields): 0
- Exam distribution (certified): {'AIIMS': 26, 'AIPMT': 6, 'JEE_Advanced': 20, 'JEE_Main': 74, 'NCERT': 28, 'NEET': 151, 'NTA_Sample': 1, 'Practice_Resources': 54}

## 11. Recommendations

- **Parallelize OCR** across CPU cores — OCR is the dominant wall-clock cost (~2,400 image pages) and is embarrassingly parallel; no quality trade-off.
- **Targeted re-parse of the 0 earlier-schema docs** (if full parse-field consistency is desired) — chunks/concepts already reflect them, so KG/QI are complete; only the enriched parse fields (image refs / equations / chapter boundaries) are missing.
- Consider a **checksum/manifest of derived outputs** for drift detection across future runs.
- Phase 8 (AI question generation) remains gated — unlock only via owner P3-AI authorization.

