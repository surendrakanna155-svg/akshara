# Akshara — Canonical Evidence & Knowledge Governance Registry

**Generated:** 2026-07-15T07:32:11Z · **Authority:** single store-level source of truth for ALL owned QIE/curriculum evidence + its lifecycle state. Re-run `python -m kie.evidence.registry` to refresh.

**Totals:** 23 stores · 59.4 GB · by scope {'in_scope': 8, 'held': 4, 'mixed': 4, 'out_of_scope': 1, 'n_a': 6} · by state {'1_raw_source': 11, 'q_quarantine': 5, '3_extracted_evidence': 2, '2_ocr_normalized': 3, '7_qie_available': 1, '4_recovered_notation': 1}

Lifecycle: `1_raw → 2_ocr → 3_extracted → 4_recovered → 5_verified → 6_concept_bound → 7_qie_available` (`q_quarantine` = rejected/out-of-scope/superseded).

| id | path | role | state | scope | size | detail |
|---|---|---|---|---|---|---|
| RAW_FOUNDATION | `resources/foundation` | raw_source | 1_raw_source | in_scope | 3.8 GB | 1199 PDFs |
| RAW_CURSOR_DOWNLOADS | `resources/foundation/Cursor_Downloads` | raw_source | 1_raw_source | in_scope | 1.7 GB | 865 PDFs |
| RAW_CURRICULUM_CBSE | `resources/curriculum/cbse` | raw_source | 1_raw_source | in_scope | 3.0 GB | 48 PDFs |
| RAW_CURRICULUM_AP | `resources/curriculum/ap` | raw_source | 1_raw_source | held | 10.6 GB | 230 PDFs |
| RAW_CURRICULUM_TS | `resources/curriculum/telangana` | raw_source | 1_raw_source | held | 1.1 GB | 31 PDFs |
| RAW_CURRICULUM_ICSE | `resources/curriculum/icse` | raw_source | 1_raw_source | held | 35.9 MB | 20 PDFs |
| RAW_INTAKE | `resources/intake` | raw_source | 1_raw_source | mixed | 83.4 MB | 19 PDFs |
| ARCH_BOARD_OUT_OF_SCOPE | `resources/archive/board_out_of_scope` | quarantine | q_quarantine | out_of_scope | 27.1 GB | 7 PDFs |
| ARCH_NCERT_NON_STEM | `resources/archive/NCERT_non_stem` | quarantine | q_quarantine | held | 1.3 GB | 0 PDFs |
| ARCH_DUPLICATES | `resources/archive/duplicates` | quarantine | q_quarantine | n_a | 123.9 MB | 52 PDFs |
| DL_DUPLICATES | `downloads/duplicates` | quarantine | q_quarantine | n_a | 7.3 GB | 99 PDFs |
| DL_FAILED | `downloads/failed` | quarantine | q_quarantine | n_a | 587.8 MB | 70 PDFs |
| STG_QCORPUS | `staging/qcorpus_noncert` | staging_derived | 3_extracted_evidence | in_scope | 1.1 GB | 22759 Q / 865 docs |
| STG_BOARD_CURRICULUM | `staging/board_curriculum` | staging_derived | 2_ocr_normalized | mixed | 1.1 GB |  |
| KDB_KIE | `knowledge/kie/kie.db` | knowledge_db | 3_extracted_evidence | in_scope | 157.1 MB | chunks:42141 concepts:3006 formulas:317 (w/symbols:0) |
| KDB_QIE | `knowledge/kie/qie.db` | knowledge_db | 7_qie_available | in_scope | 3.1 MB | facts:92 SF:14 seq:17 cmp:8 distr:274 · relations:28 cert/5 rej · bank:1496 |
| KDB_INTAKE_STAGING | `knowledge/kie/intake/staging` | knowledge_db | 2_ocr_normalized | mixed | 13.1 MB |  |
| KDB_PARSED | `knowledge/kie/parsed` | staging_derived | 2_ocr_normalized | in_scope | 254.7 MB |  |
| NOTATION_PAGES | `knowledge/kie/notation_pages` | staging_derived | 4_recovered_notation | in_scope | 4.4 MB |  |
| GOV_PROVENANCE_MANIFEST | `PROVENANCE_MANIFEST.json` | governance_index | 1_raw_source | mixed | 1008.0 KB |  |
| GOV_INDEXES | `indexes` | governance_index | 1_raw_source | n_a | 1.4 MB |  |
| GOV_REPORTS | `reports` | governance_index | 1_raw_source | n_a | 2.3 MB |  |
| GOV_DISCOVERY | `discovery` | governance_index | 1_raw_source | n_a | 1.1 MB |  |

## How to read a lifecycle state
- **1_raw / 2_ocr / 3_extracted** — evidence exists but is NOT usable knowledge. An extracted question is not a QIE-available record.
- **5_verified** — structured facts/relations, independently verified (deterministic + examiner).
- **6_concept_bound / 7_qie_available** — safely bound to a certified concept and reachable by the unified engine → qpgen.

## Detail layers (this registry references, never duplicates)
- Per-file curriculum provenance → `PROVENANCE_MANIFEST.json`, `indexes/`, `reports/`.
- Per-doc qcorpus extraction → `staging/qcorpus_noncert/manifests/*.jsonl`.
- Verified knowledge rows → `knowledge/kie/qie.db` (KVS + item_model + pilot_verified_item).

See `EVIDENCE_MIGRATION_MAP.md` for the deferred old-path → canonical-path physical layout.
