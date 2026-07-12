# Curriculum Acquisition Lane — Checkpoint 2026-07-12 (Official Universe Correction)

## Phase: Official Subject-Universe Discovery + Remaining Acquisition

### Matrix Correction (COMPLETE)
- **Previous narrow matrix:** 148 textbook cells (English/Math/Science/SST/CS assumed grid)
- **Corrected official universe:** **234** evidence-derived slots (per-book/volume/resource)
- **Authority:** `scripts/discovery/official_universe.py` + `discovery/official_universe.json`
- **Canonical matrix:** `reports/CANONICAL_CURRICULUM_MATRIX.json`
- **Reconciliation report:** `reports/OFFICIAL_UNIVERSE_RECONCILIATION.md`

### Key Corrections
| False assumption | Correction |
|------------------|------------|
| AP Class 5 Social Science gap | Official structure uses **EVS** at primary — EVS THB + SEM books present |
| TS Class 5 Social Science gap | Official structure uses **EVS** — DIKSHA EVS mirror on disk |
| Single Science/SST/English cell | Multiple official books per subject (semesters, splits, readers, workbooks) |
| 148 cells = truth | **234 slots** from official catalogues |

### Board Slot Counts
| Board | Slots | Notes |
|-------|------:|-------|
| CBSE/NCERT | 116 | includes 10 iewe1 workbook components |
| AP SCERT | 64 | Dynamic portal enumeration (semesters, science splits, SST components) |
| Telangana | 36 | 29 GDrive + 7 DIKSHA mirrors |
| CISCE | 18 | Syllabus + specimen + competency (free official only) |

### Source Inventory
| Metric | Value |
|--------|------:|
| Physical PDF/ZIP files | 281 |
| Official universe slots verified | 234/234 |
| New this correction wave | +10 (iewe1 workbook components) |

### Genuine Gaps (0)
All in-scope official source slots verified.

**Closed this wave:**
1. **CBSE Class 9 Words and Expressions I** — 10 official components (Prelims + Chapters 1–9) from NCERT `textbook.php?iewe1` listing
2. **CBSE Class 10 Computer Applications (Code 165)** — false NCERT textbook slot removed; syllabus + SQP + MS are authoritative official sources

### Count Reconciliation
Prior report showed universe=224, verified=224, gaps=2 because gaps were tracked **in parallel** to slots. Corrected: universe = acquirable slots only; gaps = separate non-slots. Now **234 = 234 verified, 0 gaps**.

### Registers
- **Language subjects (out of English QP scope):** 75 AP portal entries (Telugu/Hindi/Sanskrit)
- **Commercial blockers:** 44 ICSE textbook slots
- **Third-party provenance review:** 29 TS GDrive sources
- **Bilingual English-present:** 53 AP Telugu-English sources

### Execution Scripts
- Discovery: `scripts/discovery/official_universe.py`
- Acquisition wave: `scripts/acquisition/run_official_universe_wave.py`

### Out of scope (unchanged)
- OCR/extraction (not started this wave)
- ERP / Adaptive AI / frozen QP engine
