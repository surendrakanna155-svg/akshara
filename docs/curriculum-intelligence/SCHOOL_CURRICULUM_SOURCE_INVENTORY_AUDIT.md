# School Curriculum Source Inventory Audit

**Audit date:** 2026-07-12  
**Corrected:** 2026-07-12 (acquisition-list reconciliation pass)  
**Auditor:** Read-only inventory pass (no downloads, no OCR, no file modifications)  
**Evidence basis:** Physical files on disk, discovery catalogues (`ap_textbooks_catalogue.json`, `ts_textbooks_catalogue.json`, `ncert_textbooks_catalogue.json`, `cbse_syllabus_catalogue.json`), `MISSING_RESOURCES.md` (stale — many entries now on disk), `knowledge/kie/kie.db`, qcorpus manifests.

---

## CORRECTION ADDENDUM (2026-07-12)

### Issue 1 — AP “20/20” vs missing-download list (resolved)

These measure **different things**:

| Metric | Meaning |
|--------|---------|
| **20/20 primary slots** | One English-medium textbook per `boards.json` subject (English, Mathematics, Science, Social Science) × Classes 6–10. **All 20 slots have at least one valid English PDF/ZIP on disk.** |
| **Items previously in §6 download list** | Mixed three categories incorrectly: (a) stale `MISSING_RESOURCES.md` entries for files **already downloaded** under different filenames; (b) **additional** AP portal volumes beyond the primary slot (Minor Media English, supplementary readers, EVS as separate title); (c) genuinely missing split volumes within a slot. |

**Corrected genuinely-missing AP count: 2** (proven official titles, primary-slot gaps).  
**Not missing:** 15 `Telugu-English` mirror files (English content present — OCR extraction only).  
**Moved to verification:** Minor Media English (Classes 6–9), FIRST FLIGHT (Class 10), MATHEMATICS SEM-1 (Class 10).

### Issue 2 — CBSE Class 10 “Computer Science” (resolved)

Official CBSE secondary subject name is **Computer Applications** (syllabus: `Computer_Applications_Sec_2025-26.pdf`). Config folder is `Computer_Science` but this is **not** CBSE “Computer Science” (senior secondary), **not** AI, **not** IT.

- Class 9: `CBSE_Class_09_Computer_Science_Textbook-ICT_DIKSHA_2025-26_v1_English.zip` on disk (DIKSHA mirror).
- Class 10: **no textbook on disk**; **no resolved free official textbook URL** in NCERT catalogue or discovery JSON.
- **Removed from download list** → Section C (manual verification).

### Issue 3 — Corrected download count

**DOWNLOAD NOW: 8 files** (6 Telangana + 2 Andhra Pradesh). See §6-CORRECTED.

### SOURCE MISSING vs SOURCE EXISTS BUT NOT ENGINE-READY

| Category | Count | Examples |
|----------|------:|---------|
| **SOURCE MISSING** (no physical file) | **8** | 6 TS textbooks, AP Class 9 Math SEM-1, AP Class 10 Physical Sciences |
| **SOURCE EXISTS — needs OCR/engine** | **~201** | All CBSE ZIPs/PDFs, all AP PDFs (except 2 gaps), 11 present TS PDFs, ICSE syllabus/SQP |
| **SOURCE EXISTS — English-only extraction** | **15** | AP `Telugu-English` mirror PDFs |
| **SOURCE EXISTS — edition/provenance verify** | **17** | All present TS PDFs (third-party GDrive) |

---

## 1. Executive Summary

### Scope finding (Classes 1–5)

**Zero Classes 1–5 curriculum source material exists anywhere in this repository.** The active Curriculum Intelligence program, acquisition matrix, discovery catalogues, and `curriculum/configs/boards.json` all define scope as **Classes 6–10 only**. No PDFs, ZIPs, manifests, or catalogue entries were found for Classes 1–5. Supporting regular school QP for Classes 1–5 would require a **new scope expansion** (discovery + acquisition infrastructure does not exist yet).

### Headline counts (Classes 6–10)

| Metric | Count | Notes |
|--------|------:|-------|
| **Expected primary textbook slots** (4 boards × Classes 6–10) | **92** | Per `boards.json` subject lists |
| **Physical primary textbook coverage** | **56 / 92** (60.9%) | ZIP or PDF on disk |
| **English-medium sources present** | **~56 slots + supplementary volumes** | CBSE NCERT ZIPs; AP/TS English PDFs |
| **AP bilingual-name sources** | **15 files** | Filename `Telugu-English`; see §3 |
| **TS bilingual sources detected** | **0** | Sampled TS PDFs: English embedded text only |
| **OCR/extraction complete (board curriculum)** | **0 docs** | qcorpus: 865 foundation docs, 0 board-curriculum |
| **KIE certified board docs** | **28 doc-groups** | Partial Class 6–10 NCERT + Class 10 CBSE/TS science only |
| **Engine-ready for school QP** | **0 full profiles** | Partial `CBSE_X` / `TS_X` Class 10 science ingest only |
| **Missing downloadable sources** | **8 books** | See §6-CORRECTED (excludes ICSE commercial textbooks) |
| **ICSE commercial textbooks (not free)** | **32 slots** | Cannot download from official CISCE sources |
| **Duplicate hash groups (board PDFs)** | **11 groups** | Mostly identical CBSE Class 9/10 SQP+MS pairs |
| **Unknown / review required** | **15 AP `Telugu-English` files** | Naming convention vs embedded-text sampling mismatch |

### Board-level source coverage (primary textbooks only)

| Board | Slots | Physical present | Gap |
|-------|------:|-----------------:|-----|
| **CBSE / NCERT** | 22 | **21** | Class 10 Computer Applications — no proven free textbook URL (see §C) |
| **Andhra Pradesh (APSCERT)** | 20 | **18** | 2 split-volume gaps within Math/Science slots; 15 bilingual mirrors = OCR only |
| **Telangana (TSSCERT)** | 20 | **14** | 6 textbooks missing; 11 on disk = third-party provenance |
| **ICSE / CISCE** | 30 | **0** | No free official textbooks exist |

### Source coverage vs engine-ready coverage

| Layer | Status |
|-------|--------|
| **Source coverage (PDF/ZIP on disk)** | Strong for CBSE/AP primary textbooks; moderate for TS; absent for ICSE textbooks |
| **OCR / extraction** | Not started for board curriculum lane |
| **KIE certification / concept indexing** | Foundation JEE/NEET corpus only; partial Class 10 CBSE/TS science |
| **Engine-ready school QP** | **Not achievable today** for any board × class × subject combination |

**EOS gate (audit scope):** This document is an inventory audit only — no implementation was performed. Audit deliverable is complete.

---

## 2. Existing Source Inventory

### 2.1 CBSE / NCERT (Classes 6–10)

**Official source expected:** [ncert.nic.in/textbook.php](https://ncert.nic.in/textbook.php), [cbseacademic.nic.in](https://cbseacademic.nic.in) (syllabus, SQP, marking schemes).

**Storage pattern:** NCERT textbooks stored as **verified ZIP archives** under `curriculum/resources/curriculum/cbse/Class_XX/{Subject}/Textbooks/`. Class 7 Mathematics additionally has **extracted chapter PDFs** under `gegp1dd/`. Duplicate copies also exist in `curriculum/resources/foundation/NCERT/` (same NCERT codes).

#### Primary textbook matrix

| Class | Subject | Edition | Official Source | Physical | English | Bilingual | OCR | Verified | Status | Evidence |
|-------|---------|---------|-----------------|----------|---------|-----------|-----|----------|--------|----------|
| 6 | English | 2025-26 Poorvi | NCERT `fepr1dd.zip` | ZIP ✓ | ✓ | No | No | ✓ | COMPLETE_SOURCE | `cbse/Class_06/English/Textbooks/NCERT_Class_06_English_Textbook-fepr1_2025-26_v1_English.zip` |
| 6 | Mathematics | 2025-26 Ganita Prakash | NCERT `fegp1dd.zip` | ZIP ✓ | ✓ | No | No | ✓ | COMPLETE_SOURCE | `cbse/Class_06/Mathematics/Textbooks/NCERT_Class_06_Mathematics_Textbook-fegp1_2025-26_v1_English.zip` |
| 6 | Science | 2025-26 Curiosity | NCERT `fecu1dd.zip` | ZIP ✓ | ✓ | No | No | ✓ | COMPLETE_SOURCE | `cbse/Class_06/Science/Textbooks/NCERT_Class_06_Science_Textbook-fecu1_2025-26_v1_English.zip` |
| 6 | Social Science | 2025-26 Exploring Society | NCERT `fees1dd.zip` | ZIP ✓ | ✓ | No | No | ✓ | COMPLETE_SOURCE | `cbse/Class_06/Social_Science/Textbooks/NCERT_Class_06_Social_Science_Textbook-fees1_2025-26_v1_English.zip` |
| 7 | English | 2025-26 Poorvi + prev. Honeycomb/Alien Hand | NCERT `gepr1/gehc1/geah1dd.zip` | ZIP ✓ (3) | ✓ | No | No | ✓ | COMPLETE_SOURCE | 3 ZIPs in `cbse/Class_07/English/Textbooks/` |
| 7 | Mathematics | 2025-26 Ganita Prakash + prev. | NCERT `gegp1/gegp2/gemh1dd.zip` | ZIP ✓ + 9 ch. PDFs | ✓ | No | No | ✓ | COMPLETE_SOURCE | ZIPs + `gegp1dd/gegp101.pdf`…`gegp108.pdf` |
| 7 | Science | 2025-26 Curiosity + prev. | NCERT `gecu1/gesc1dd.zip` | ZIP ✓ (2) | ✓ | No | No | ✓ | COMPLETE_SOURCE | `cbse/Class_07/Science/Textbooks/` |
| 7 | Social Science | 2025-26 + prev. split volumes | NCERT `gees1/gees2/gess1-3dd.zip` | ZIP ✓ (5) | ✓ | No | No | ✓ | COMPLETE_SOURCE | `cbse/Class_07/Social_Science/Textbooks/` |
| 8 | English | 2025-26 Poorvi + prev. Honeydew/It So Happened | NCERT `hepr1/hehd1/heih1dd.zip` | ZIP ✓ (3) | ✓ | No | No | ✓ | COMPLETE_SOURCE | `cbse/Class_08/English/Textbooks/` |
| 8 | Mathematics | 2025-26 + prev. | NCERT `hegp1/hegp2/hemh1dd.zip` | ZIP ✓ (3) | ✓ | No | No | ✓ | COMPLETE_SOURCE | `cbse/Class_08/Mathematics/Textbooks/` |
| 8 | Science | 2025-26 + prev. | NCERT `hecu1/hesc1dd.zip` | ZIP ✓ (2) | ✓ | No | No | ✓ | COMPLETE_SOURCE | `cbse/Class_08/Science/Textbooks/` |
| 8 | Social Science | 2025-26 + prev. split | NCERT `hees1/hess2-4dd.zip` | ZIP ✓ (4) | ✓ | No | No | ✓ | COMPLETE_SOURCE | `cbse/Class_08/Social_Science/Textbooks/` |
| 9 | English | Beehive (main) | NCERT `iebe1dd.zip` | ZIP ✓ | ✓ | No | No | ✓ | COMPLETE_SOURCE | `cbse/Class_09/English/Textbooks/` |
| 9 | English | Moments (supplementary) | NCERT `iemo1` | — | — | — | — | — | **NOT_PUBLICLY_AVAILABLE** | Listed in `ncert_textbooks_catalogue.json` §not_publicly_available |
| 9 | Mathematics | Mathematics | NCERT `iemh1dd.zip` | ZIP ✓ | ✓ | No | No | ✓ | COMPLETE_SOURCE | `cbse/Class_09/Mathematics/Textbooks/` |
| 9 | Science | Science | NCERT `iesc1dd.zip` | ZIP ✓ | ✓ | No | No | ✓ | COMPLETE_SOURCE | `cbse/Class_09/Science/Textbooks/` |
| 9 | Social Science | 20 chapter ZIPs (Civics/Geo/History/Econ) | NCERT `iess1-3` chapters | ZIP ✓ (20) | ✓ | No | No | ✓ | COMPLETE_SOURCE | `cbse/Class_09/Social_Science/Textbooks/` |
| 9 | Computer Science | ICT (DIKSHA mirror) | DIKSHA | ZIP ✓ | ✓ | No | No | ✓ | COMPLETE_SOURCE | `CBSE_Class_09_Computer_Science_Textbook-ICT_DIKSHA_2025-26_v1_English.zip` |
| 10 | English | First Flight + Footprints + Workbook | NCERT `jeff1/jefp1/jewe2dd.zip` | ZIP ✓ (3) | ✓ | No | No | ✓ | COMPLETE_SOURCE | `cbse/Class_10/English/Textbooks/` |
| 10 | Mathematics | Mathematics | NCERT `jemh1dd.zip` | ZIP ✓ | ✓ | No | No | ✓ | COMPLETE_SOURCE | `cbse/Class_10/Mathematics/Textbooks/` |
| 10 | Science | Science | NCERT `jesc1dd.zip` | ZIP ✓ | ✓ | No | No | ✓ | COMPLETE_SOURCE | `cbse/Class_10/Science/Textbooks/` |
| 10 | Social Science | 4 split volumes | NCERT `jess1-4dd.zip` | ZIP ✓ (4) | ✓ | No | No | ✓ | COMPLETE_SOURCE | `cbse/Class_10/Social_Science/Textbooks/` |
| 10 | Computer Science | Computer Applications | NCERT / CBSE academic | **None** | — | — | — | — | **MISSING** | No ZIP/PDF in `cbse/Class_10/Computer_Science/Textbooks/` |

#### Assessment / syllabus sources (non-textbook, present on disk)

| Class | Doc type | Subjects covered | Count | Status |
|-------|----------|------------------|------:|--------|
| 9–10 | Syllabus | Math, Science, SST, English (10 only) | 7 | COMPLETE_SOURCE |
| 9–10 | Sample papers (SQP) | Math, Science, SST, English, CS | 5 | COMPLETE_SOURCE |
| 9–10 | Marking schemes (MS) | Math, Science, SST, English, CS | 5 | COMPLETE_SOURCE |
| 6–8 | Syllabus / SQP / MS | All Priority-A subjects | 0 | MISSING |

#### Other subjects present (not primary textbook slots)

- **Foundation NCERT lane** (`resources/foundation/NCERT/`): Classes 6–12 STEM ZIPs for JEE/NEET pipeline — separate from board curriculum folder but same NCERT authority.
- **Archive** (`resources/archive/NCERT_non_stem/`): Class 9 SST `.ecar` DIKSHA chapter mirrors (56 files) — archived, not active curriculum path.
- **DIKSHA `.ecar`**: 20 files — DIKSHA mobile archives, not extracted.

---

### 2.2 Andhra Pradesh / APSCERT (Classes 6–10)

**Official source expected:** [cse.ap.gov.in/textBooksDownloadingPagetitleWise](https://cse.ap.gov.in/textBooksDownloadingPagetitleWise), [scert.ap.gov.in](https://scert.ap.gov.in)

**Physical count:** 74 files (67 textbook PDFs + supplementary volumes) under `curriculum/resources/curriculum/ap/`

#### Primary textbook matrix (all 20 slots physically present)

| Class | Subject | Physical PDFs | English content | Bilingual files | Status |
|-------|---------|:-------------:|:---------------:|:---------------:|--------|
| 6 | English | 2 | ✓ (sampled) | 0 | COMPLETE_SOURCE |
| 6 | Mathematics | 3 (SEM-1, SEM-2, Telugu-English) | ✓ | 1 | BILINGUAL_SOURCE |
| 6 | Science | 3 (SEM-1, SEM-2, Telugu-English) | ✓ | 1 | BILINGUAL_SOURCE |
| 6 | Social Science | 3 (SEM-1, SEM-2, Telugu-English) | ✓ | 1 | BILINGUAL_SOURCE |
| 7 | English | 2 | ✓ | 0 | COMPLETE_SOURCE |
| 7 | Mathematics | 3 | ✓ | 1 | BILINGUAL_SOURCE |
| 7 | Science | 3 | ✓ | 1 | BILINGUAL_SOURCE |
| 7 | Social Science | 3 | ✓ | 1 | BILINGUAL_SOURCE |
| 8 | English | 2 | ✓ | 0 | COMPLETE_SOURCE |
| 8 | Mathematics | 3 | ✓ | 1 | BILINGUAL_SOURCE |
| 8 | Science | 7 (split Bio/Physics/Gen.Sci + Telugu-English) | ✓ | 1 | BILINGUAL_SOURCE |
| 8 | Social Science | 6 (Geo/History/Politics + SEM + Telugu-English) | ✓ | 1 | BILINGUAL_SOURCE |
| 9 | English | 2 | ✓ | 0 | COMPLETE_SOURCE |
| 9 | Mathematics | 2 (SEM-2, Telugu-English) | ✓ | 1 | BILINGUAL_SOURCE |
| 9 | Science | 5 | ✓ | 1 | BILINGUAL_SOURCE |
| 9 | Social Science | 4 | ✓ | 1 | BILINGUAL_SOURCE |
| 10 | English | 5 (main + Footprints + minor media) | ✓ | 0 | COMPLETE_SOURCE |
| 10 | Mathematics | 3 | ✓ | 1 | BILINGUAL_SOURCE |
| 10 | Science | 2 (Biology EM + Telugu-English) | ✓ | 1 | BILINGUAL_SOURCE |
| 10 | Social Science | 4 (3 NCERT-named splits + Telugu-English) | ✓ | 1 | BILINGUAL_SOURCE |

**Key evidence paths:**
- Primary: `curriculum/resources/curriculum/ap/Class_{06-10}/{Subject}/Textbooks/AP_Class_*_English.pdf`
- Bilingual-name: `*_Textbook-Telugu-English_2025-26_v1_English.pdf` (15 files, Classes 6–10 × Math/Science/SST)

#### Supplementary / split volumes still missing (16 unique)

Logged in `curriculum/MISSING_RESOURCES.md`, confirmed absent on disk — see §6.

#### Duplicates detected (AP)

| Type | Example | Status |
|------|---------|--------|
| Dual English naming | `AP_Class_06_English_Textbook-6_English_Textbook_*` AND `AP_Class_06_English_Textbook-English_*` | DUPLICATE (same class, two filenames) |
| SEM-1 + SEM-2 + Telugu-English mirror | Class 6–8 Math/Science/SST | Not duplicate — complementary volumes; Telugu-English may mirror content |

---

### 2.3 Telangana / TSSCERT (Classes 6–10)

**Official source expected:** [scert.telangana.gov.in](https://scert.telangana.gov.in) (encrypted portal — no direct PDF URLs)  
**Current provenance:** Third-party Google Drive copies via [ncertbooks.guru/ts-scert-books](https://www.ncertbooks.guru/ts-scert-books/) — owner-approved 2026-07-09, flagged `UNOFFICIAL_THIRD_PARTY_COPY`.

**Physical count:** 17 textbook PDFs under `curriculum/resources/curriculum/telangana/`

| Class | Subject | Physical | English (sampled) | Bilingual | Status | Evidence |
|-------|---------|:--------:|:-------------------:|:---------:|--------|----------|
| 6 | English | ✓ | ✓ | No | COMPLETE_SOURCE | `TS_Class_06_English_Textbook-English_2025-26_v1_English.pdf` |
| 6 | Mathematics | ✓ | ✓ | No | COMPLETE_SOURCE | `TS_Class_06_Mathematics_Textbook-Mathematics_2025-26_v1_English.pdf` |
| 6 | Science | ✓ | ✓ | No | COMPLETE_SOURCE | `TS_Class_06_Science_Textbook-Science_2025-26_v1_English.pdf` |
| 6 | Social Science | ✗ | — | — | **MISSING** | Catalogue: `AKS-TSSCERT-06-SST-TEXT-2025-000503` |
| 7 | English | ✓ | ✓ | No | COMPLETE_SOURCE | |
| 7 | Mathematics | ✓ | ✓ | No | COMPLETE_SOURCE | |
| 7 | Science | ✓ | ✓ | No | COMPLETE_SOURCE | |
| 7 | Social Science | ✓ | ✓ | No | COMPLETE_SOURCE | |
| 8 | English | ✓ | ✓ | No | COMPLETE_SOURCE | |
| 8 | Mathematics | ✓ | ✓ | No | COMPLETE_SOURCE | |
| 8 | Science | ✓ (Physical + Biological) | ✓ | No | COMPLETE_SOURCE | 2 PDFs |
| 8 | Social Science | ✓ | ✓ | No | COMPLETE_SOURCE | |
| 9 | English | ✓ | ✓ | No | COMPLETE_SOURCE | |
| 9 | Mathematics | ✗ | — | — | **MISSING** | Catalogue: `AKS-TSSCERT-09-MATH-TEXT-2025-000514` |
| 9 | Science | ✗ | — | — | **MISSING** | Physical + Biological Science (2 PDFs) |
| 9 | Social Science | ✗ | — | — | **MISSING** | Catalogue: `AKS-TSSCERT-09-SST-TEXT-2025-000517` |
| 10 | English | ✓ | ✓ | No | COMPLETE_SOURCE | |
| 10 | Mathematics | ✓ | ✓ | No | COMPLETE_SOURCE | |
| 10 | Science | ✓ (Physical + Biological) | ✓ | No | COMPLETE_SOURCE | 2 PDFs |
| 10 | Social Science | ✗ | — | — | **MISSING** | Catalogue: `AKS-TSSCERT-10-SST-TEXT-2025-000522` |

**Note:** All 17 present TS PDFs sampled (embedded text, first 3 pages) show **English-only** content. No Telugu characters detected in sample. Bilingual extraction policy still applies if future editions or full-document scan reveals mixed pages.

---

### 2.4 ICSE / CISCE (Classes 6–10)

**Official source expected:** [cisce.org](https://cisce.org) — syllabus and specimen papers only. **CISCE does not publish free official textbooks** (commercial: Selina, Frank, Morning Star, etc.) per `curriculum/discovery/icse/sources.json`.

**Physical count:** 18 files — all syllabus, sample papers, or question banks. **Zero textbooks.**

| Class | What exists on disk | Status |
|-------|---------------------|--------|
| 6–8 | **Nothing** | MISSING (all 32 cells UNRESOLVED in matrix) |
| 9 | English specimen paper (1) | PARTIAL (assessment only) |
| 10 | Syllabus + specimen for: Math, Physics, Chemistry, Biology, History, Geography, English (2), CS syllabus + CFQ bank | PARTIAL (17 verified assessment cells) |

**ICSE textbooks (30 slots):** All **MISSING / NOT_PUBLICLY_AVAILABLE** — cannot be acquired from CISCE official sources. Would require commercial purchase.

#### Other ICSE subjects in discovery (not yet downloaded)

Economics, Economic Applications, Commercial Studies, Physical Education, Home Science — listed in `cisce_source_urls.json` but not in active `boards.json` subject scope.

---

### 2.5 Classes 1–5 (entire scope)

| Board | Classes 1–5 material | Status |
|-------|---------------------|--------|
| CBSE/NCERT | None | MISSING (no catalogue, no files) |
| APSCERT | None | MISSING |
| TSSCERT | None | MISSING |
| CISCE | None | MISSING |

**Historical docs** (e.g. `docs/archive/planning/QUESTION_PAPER_FOUNDATION_MASTER_PLAN.md`) mention Class 6–12 vision but contain **no physical Class 1–5 sources**.

---

## 3. AP/TS Bilingual Source Register

### Policy for future OCR (ENGLISH CONTENT ONLY)

When OCR is later executed on AP/TS material:

1. Select/extract **only English-content pages or English-content regions**
2. Ignore Telugu duplicate/mirrored instructional content
3. Preserve English diagrams, tables, equations, labels, and question content
4. Do **not** mix Telugu OCR text into the English curriculum corpus
5. Do **not** treat Telugu and English mirrored versions as separate concepts/chapters
6. Maintain source-page provenance to the original PDF
7. If a page contains both English and Telugu, extract English only
8. If safe language separation is uncertain, **flag the page for review** instead of contaminating the English corpus

### AP bilingual register (15 files)

| Board | Class | Subject | File | English detected | Telugu detected | Layout pattern | Future OCR policy | Manual review |
|-------|-------|---------|------|:----------------:|:---------------:|----------------|-------------------|:-------------:|
| APSCERT | 6 | Mathematics | `AP_Class_06_Mathematics_Textbook-Telugu-English_2025-26_v1_English.pdf` | ✓ (sample p1-3) | ✗ (sample) | UNKNOWN — name implies mirror; sampled pages English-only | ENGLISH CONTENT ONLY | **YES** |
| APSCERT | 6 | Science | `AP_Class_06_Science_Textbook-Telugu-English_2025-26_v1_English.pdf` | ✓ | ✗ (sample) | UNKNOWN | ENGLISH CONTENT ONLY | **YES** |
| APSCERT | 6 | Social Science | `AP_Class_06_Social_Science_Textbook-Telugu-English_2025-26_v1_English.pdf` | ✓ | ✗ (sample) | UNKNOWN | ENGLISH CONTENT ONLY | **YES** |
| APSCERT | 7 | Mathematics | `AP_Class_07_Mathematics_Textbook-Telugu-English_2025-26_v1_English.pdf` | ✓ | ✗ (sample) | UNKNOWN | ENGLISH CONTENT ONLY | **YES** |
| APSCERT | 7 | Science | `AP_Class_07_Science_Textbook-Telugu-English_2025-26_v1_English.pdf` | ✓ | ✗ (sample) | UNKNOWN | ENGLISH CONTENT ONLY | **YES** |
| APSCERT | 7 | Social Science | `AP_Class_07_Social_Science_Textbook-Telugu-English_2025-26_v1_English.pdf` | ✓ | ✗ (sample) | UNKNOWN | ENGLISH CONTENT ONLY | **YES** |
| APSCERT | 8 | Mathematics | `AP_Class_08_Mathematics_Textbook-Telugu-English_2025-26_v1_English.pdf` | ✓ | ✗ (sample) | UNKNOWN | ENGLISH CONTENT ONLY | **YES** |
| APSCERT | 8 | Science | `AP_Class_08_Science_Textbook-Telugu-English_2025-26_v1_English.pdf` | ✓ | ✗ (sample) | UNKNOWN | ENGLISH CONTENT ONLY | **YES** |
| APSCERT | 8 | Social Science | `AP_Class_08_Social_Science_Textbook-Telugu-English_2025-26_v1_English.pdf` | ✓ | ✗ (sample) | UNKNOWN | ENGLISH CONTENT ONLY | **YES** |
| APSCERT | 9 | Mathematics | `AP_Class_09_Mathematics_Textbook-Telugu-English_2025-26_v1_English.pdf` | ✓ | ✗ (sample) | UNKNOWN | ENGLISH CONTENT ONLY | **YES** |
| APSCERT | 9 | Science | `AP_Class_09_Science_Textbook-Telugu-English_2025-26_v1_English.pdf` | ✓ | ✗ (sample) | UNKNOWN | ENGLISH CONTENT ONLY | **YES** |
| APSCERT | 9 | Social Science | `AP_Class_09_Social_Science_Textbook-Telugu-English_2025-26_v1_English.pdf` | ✓ | ✗ (sample) | UNKNOWN | ENGLISH CONTENT ONLY | **YES** |
| APSCERT | 10 | Mathematics | `AP_Class_10_Mathematics_Textbook-Telugu-English_2025-26_v1_English.pdf` | ✓ | ✗ (sample) | UNKNOWN | ENGLISH CONTENT ONLY | **YES** |
| APSCERT | 10 | Science | `AP_Class_10_Science_Textbook-Telugu-English_2025-26_v1_English.pdf` | ✓ | ✗ (sample) | UNKNOWN | ENGLISH CONTENT ONLY | **YES** |
| APSCERT | 10 | Social Science | `AP_Class_10_Social_Science_Textbook-Telugu-English_2025-26_v1_English.pdf` | ✓ | ✗ (sample) | UNKNOWN | ENGLISH CONTENT ONLY | **YES** |

**Detection method:** Embedded PDF text layer sampling (first 3 pages, PyMuPDF) — **not OCR**. Non-`Telugu-English` AP textbooks also sampled (SEM-1, Physics, Biology EM): all showed English-only embedded text in samples. Full-document scan still required before OCR pipeline.

**TS bilingual register:** No TS files flagged. All 17 present TS PDFs sampled English-only. Policy still applies if future TS editions contain mixed pages.

---

## 4. Engine-Ready Coverage

The KIE Question Paper Generation Engine (`curriculum/scripts/intelligence/kie/qpgen/`) reads **only** certified rows in `knowledge/kie/kie.db` — never raw PDFs.

### Currently engine-usable (school board)

| Profile | Board | Class | Subjects in kie.db | Usable for school QP? | Reason |
|---------|-------|-------|-------------------|----------------------|--------|
| `CBSE_X` | CBSE | 10 | Physics, Chemistry, Biology (+ 1 unlabeled) | **Partial only** | No Math, SST, English, CS; no chapter taxonomy; 4.7% deterministic fill rate |
| `TS_X` | Telangana | 10 | Physics, Chemistry, Biology, Mathematics | **Partial only** | No SST, English; no AP profile exists |
| `FOUNDATION` | NCERT | 6–12 (mixed) | STEM from JEE/NEET corpus | **No** | Wrong exam provenance for school papers |

### Not engine-ready (all other board × class × subject)

| Gap stage | Applies to |
|-----------|------------|
| **OCR / extraction** | All 208 board curriculum files (0 in qcorpus board lane) |
| **KIE Phase 1–7 pipeline** | All board textbooks except partial Class 10 CBSE/TS science ingest |
| **English-only extraction** | 15 AP `Telugu-English` files (precautionary) |
| **Chapter segmentation** | All board sources (ZIPs unextracted; AP/TS PDFs unparsed) |
| **Taxonomy / concept indexing** | `concept_board_mappings` 100% FOUNDATION; no CBSE/AP/TS grade mappings |
| **Syllabus-boundary mapping** | Not wired — `curate/taxonomy.py` not connected to engine |
| **Verification / certification** | Board lane D-5 certification incomplete |
| **Exam profile definition** | No profiles for Classes 6–9, AP, ICSE, SST, English, CS |

**Bottom line:** **Zero** board × class × subject combinations are fully engine-ready for regular school question-paper generation today.

---

## 5. Existing But Not Engine-Ready

| Source group | Count | Missing stages |
|--------------|------:|----------------|
| CBSE NCERT ZIPs (Classes 6–10) | 62 ZIPs + 9 ch. PDFs | ZIP extraction → OCR → KIE ingest → chapter map → concept index → board profile |
| CBSE assessment docs (SQP/MS/syllabus, Classes 9–10) | 28 PDFs | OCR → pattern extraction → blueprint wiring |
| AP textbook PDFs | 67+ | OCR (English-only policy on 15 files) → KIE ingest → `AP_X` profile (not defined) |
| TS textbook PDFs | 17 | OCR → KIE ingest → partial `TS_X` exists but incomplete |
| ICSE syllabus/specimen (Classes 9–10) | 18 | OCR → assessment intelligence only (no textbook corpus) |
| Foundation JEE/NEET (Classes 11–12) | 1,199 PDFs | Engine-ready for competitive exams only — **wrong corpus for school QP** |

### Per-source usability blockers (representative)

| Board | Class | Subject | Has PDF/ZIP | Blocker |
|-------|-------|---------|:-----------:|---------|
| CBSE | 10 | Science | ✓ ZIP | Partially ingested; no full paper generation integrity |
| CBSE | 6–9 | All | ✓ ZIP | Not ingested into kie.db for school profiles |
| CBSE | 10 | Computer Science | ✗ | Source missing |
| AP | 6–10 | All | ✓ PDF | No `AP_X` exam profile; no OCR; no KIE ingest |
| TS | 6–10 | Partial | ✓/✗ | 5 textbooks missing; remainder not OCR'd |
| CISCE | 6–10 | All textbooks | ✗ | Commercial — not acquirable from official sources |

---

## 6-CORRECTED. Missing Download List (authoritative)

**DOWNLOAD NOW: 8 files.** Only sources with **proven official title + edition + source URL** and **no physical file on disk**.

| # | Board | Class | Exact Subject | Exact Official Book Title | Academic Year/Edition | Why Missing | Preferred Official Source |
|---|-------|-------|---------------|---------------------------|----------------------|-------------|---------------------------|
| 1 | Telangana | 6 | Social Science | Social Science (English medium) | 2025-26 | No PDF on disk | https://drive.usercontent.google.com/download?id=1kAp1miKlykZ9je4ehp4DCv97bsQG8HIA&export=download&confirm=t |
| 2 | Telangana | 9 | Mathematics | Mathematics (English medium) | 2025-26 | No PDF on disk | https://drive.usercontent.google.com/download?id=1vDcrWirFsPC6PR7Nx7zBj3-Ciy3BzUhj&export=download&confirm=t |
| 3 | Telangana | 9 | Science | Physical Science (English medium) | 2025-26 | No PDF on disk | https://drive.usercontent.google.com/download?id=16W5C9XJbnQL_J2HjHoMUm0aHCrwPweYG&export=download&confirm=t |
| 4 | Telangana | 9 | Science | Biological Science (English medium) | 2025-26 | No PDF on disk | https://drive.usercontent.google.com/download?id=1KvFhTzuXJQL9Rf7FoMfNUJufV8e6rfEL&export=download&confirm=t |
| 5 | Telangana | 9 | Social Science | Social Science (English medium) | 2025-26 | No PDF on disk | https://drive.usercontent.google.com/download?id=1g5nVszTf4rHAfPWLHd6oO7OMHTzj2DC2&export=download&confirm=t |
| 6 | Telangana | 10 | Social Science | Social Science (English medium) | 2025-26 | No PDF on disk | https://drive.usercontent.google.com/download?id=1n1r6DS1JDH5YdOJBU9G_2D7G2EmGDc1i&export=download&confirm=t |
| 7 | Andhra Pradesh | 9 | Mathematics | MATHEMATICS SEM-1 (Telugu-English medium) | 2025-26 | Only SEM-2 on disk; SEM-1 absent | https://cse.ap.gov.in/loadsupdocumentuploadbyid?req_doc_id=2025-2026T09170022508150948980HXAK |
| 8 | Andhra Pradesh | 10 | Science | PHYSICAL SCIENCES (Telugu-English medium) | 2025-26 | Only BIOLOGICAL SCIENCE on disk; Physical Sciences absent | https://cse.ap.gov.in/loadsupdocumentuploadbyid?req_doc_id=2025-2026T10170062508151032031DAAV |

### Telangana on-disk reconciliation (all 23 catalogue entries)

| Class | Subject | Book | Status |
|-------|---------|------|--------|
| 6 | English | English | EXISTS — third-party GDrive — OCR only |
| 6 | Mathematics | Mathematics | EXISTS — third-party GDrive — OCR only |
| 6 | Science | Science | EXISTS — third-party GDrive — OCR only |
| 6 | Social Science | Social Science | **MISSING** — item 1 above |
| 7 | English | English | EXISTS — third-party GDrive — OCR only |
| 7 | Mathematics | Mathematics | EXISTS — third-party GDrive — OCR only |
| 7 | Science | Science | EXISTS — third-party GDrive — OCR only |
| 7 | Social Science | Social Science | EXISTS — third-party GDrive — OCR only |
| 8 | English | English | EXISTS — third-party GDrive — OCR only |
| 8 | Mathematics | Mathematics | EXISTS — third-party GDrive — OCR only |
| 8 | Science | Physical Science | EXISTS — third-party GDrive — OCR only |
| 8 | Science | Biological Science | EXISTS — third-party GDrive — OCR only |
| 8 | Social Science | Social Science | EXISTS — third-party GDrive — OCR only |
| 9 | English | English | EXISTS — third-party GDrive — OCR only |
| 9 | Mathematics | Mathematics | **MISSING** — item 2 above |
| 9 | Science | Physical Science | **MISSING** — item 3 above |
| 9 | Science | Biological Science | **MISSING** — item 4 above |
| 9 | Social Science | Social Science | **MISSING** — item 5 above |
| 10 | English | English | EXISTS — third-party GDrive — OCR only |
| 10 | Mathematics | Mathematics | EXISTS — third-party GDrive — OCR only |
| 10 | Science | Physical Science | EXISTS — third-party GDrive — OCR only |
| 10 | Science | Biological Science | EXISTS — third-party GDrive — OCR only |
| 10 | Social Science | Social Science | **MISSING** — item 6 above |

### Removed from download list (with reason)

| Previously listed | Correct disposition |
|-------------------|---------------------|
| AP supplementary readers, EVS, split SST (Classes 6–8) | **DO NOT DOWNLOAD** — General Science / Social SEM volumes already on disk |
| AP Class 9 SST Geography/History/Politics | **DO NOT DOWNLOAD** — `Social_Studies_Sem-1/II` + Economics already on disk |
| AP Class 10 Contemporary India-2 | **DO NOT DOWNLOAD** — present as `India_And_The_Contemporary_World-2` |
| AP Class 10 EVS / Physics EM (from stale MISSING_RESOURCES) | **Superseded** — item 8 uses official portal title PHYSICAL SCIENCES |
| CBSE Class 10 Computer Science textbook | **Section C** — subject is Computer Applications; no proven free textbook URL |
| All 15 AP `Telugu-English` files | **English-only extraction** — not missing |

---

## 7. Download Priority Summary (corrected)

| Priority | Count | Contents |
|----------|------:|----------|
| **DOWNLOAD NOW** | **8** | 6 Telangana + 2 Andhra Pradesh (table above) |
| **Manual verification** | **12+** | CBSE Class 10 Computer Applications; AP Minor Media / FIRST FLIGHT; 11 TS on-disk files |
| **OCR / engine processing** | **~201** | All other board sources on disk |
| **Not acquirable free** | **32** | ICSE commercial textbooks |

---

## 8. Duplicate Detection Report

| # | Type | Files | Hash / evidence | Status |
|---|------|-------|-----------------|--------|
| 1 | CBSE Class 9 = Class 10 SQP | English, Math, Science, SST, CS sample papers | SHA256 identical (e.g. `f2488e02…`) | DUPLICATE |
| 2 | CBSE Class 9 = Class 10 MS | English, Math, Science, SST, CS marking schemes | SHA256 identical (10 groups) | DUPLICATE |
| 3 | NCERT Class 10 in archive + active | `jess1-4`, `jeff1`, `jefp1`, `jewe2` ZIPs | Same codes in `archive/NCERT_non_stem/` and `cbse/Class_10/` | DUPLICATE |
| 4 | NCERT foundation + cbse lanes | Classes 6–10 STEM ZIPs | Same `*dd.zip` codes in `foundation/NCERT/` and `curriculum/cbse/` | DUPLICATE |
| 5 | AP dual English filenames | e.g. `Textbook-6_English_Textbook` vs `Textbook-English` per class | Different filenames, likely same or overlapping editions | UNKNOWN_REVIEW_REQUIRED |
| 6 | Downloads/duplicates folder | 97 rejected duplicate copies | `curriculum/downloads/duplicates/` | DUPLICATE (quarantined) |
| 7 | Downloads/failed folder | 75 failed acquisition copies | Includes TS Class 10 SST, AP Class 10 volumes | MANIFEST_ONLY / failed copies |

---

## 9. Manifest vs Physical Reconciliation

| Artifact | Git status | On disk | Notes |
|----------|------------|---------|-------|
| `COVERAGE_MATRIX.json` | Tracked | ✓ | 104/736 cells verified (14.1%); 60/92 textbook cells VERIFIED |
| `COMPLETED_DOWNLOADS.json` | Local (gitignored) | ✓ | 171 verified downloads |
| `PROVENANCE_MANIFEST.json` | **Deleted in git** | ✗ | Regenerate via `scripts/reports/build_provenance.py` |
| `DOWNLOAD_QUEUE.json` | Local | ✓ | 195 queued |
| `MISSING_RESOURCES.md` | Tracked | ✓ | 60 AP entries; 29 now superseded by successful downloads |
| Discovery catalogues | Tracked | ✓ | 61 NCERT + 40 AP + 23 TS + 18 CISCE URLs |
| `knowledge/kie/kie.db` | Local (gitignored) | ✓ | 362 certified foundation docs + partial board |
| qcorpus staging | Local (gitignored) | ✓ | 865 docs, 22,759 questions — **foundation only** |

**Matrix vs physical discrepancy:** Coverage matrix marks 60 textbook cells VERIFIED but does not embed `local_path` in row `sources` (paths not propagated in matrix export). Physical verification (this audit) confirms those files exist on disk.

---

## 10. Final Owner Action List

### Files to download: **22** (P0 + P1)

See numbered list in §6 items 1–22.

**Note:** `India and the Contemporary World-2` for AP Class 10 SST is **already possessed** as `AP_Class_10_Social_Science_Textbook-India_And_The_Contemporary_World-2_2025-26_v1_English.pdf` — do not re-download.

### Manual verification needed: **17 items**

| # | File / topic | Why |
|---|-------------|-----|
| 1–15 | All 15 AP `Telugu-English` named PDFs | Filename implies bilingual; embedded-text sample showed English-only on first pages — confirm full-document layout before OCR |
| 16 | AP dual English textbook pairs (Classes 6–10) | Two filenames per class — confirm whether duplicate editions or distinct volumes |
| 17 | All 17 TS textbook PDFs | Third-party GDrive provenance — confirm edition year matches 2025-26 SCERT curriculum |

### Classes 1–5 decision required

No material exists. Expanding to Classes 1–5 requires owner approval for new scope + discovery catalogues before any downloads.

### ICSE textbook decision required

32 commercial textbook slots cannot be filled from CISCE official sources. Options: (a) acquire commercial PDFs under license, (b) use syllabus-only QP generation, (c) document as permanent DOCUMENTED_GAP.

---

## Appendix A — Canonical Inventory Matrix (abbreviated)

Full matrix uses statuses: `COMPLETE_SOURCE` · `BILINGUAL_SOURCE` · `SOURCE_EXISTS_OCR_MISSING` · `OCR_EXISTS_SOURCE_MISSING` · `MANIFEST_ONLY` · `PARTIAL` · `MISSING` · `DUPLICATE` · `UNKNOWN_REVIEW_REQUIRED`

| Board | Class | Subject | Edition | Official Source | Physical | English | Bilingual | OCR | Verified | Status |
|-------|-------|---------|---------|-----------------|:--------:|:-------:|:---------:|:---:|:--------:|--------|
| CBSE | 6–9 | Math/Sci/SST/Eng | 2025-26 NCERT | ncert.nic.in | ZIP ✓ | ✓ | No | No | ✓ | SOURCE_EXISTS_OCR_MISSING |
| CBSE | 10 | Math/Sci/SST/Eng | 2025-26 NCERT | ncert.nic.in | ZIP ✓ | ✓ | No | No | ✓ | SOURCE_EXISTS_OCR_MISSING |
| CBSE | 10 | Computer Science | 2025-26 | cbseacademic.nic.in | ✗ | — | — | — | — | MISSING |
| CBSE | 9–10 | SQP/MS/Syllabus | 2025-26 | cbseacademic.nic.in | PDF ✓ | ✓ | No | No | ✓ | SOURCE_EXISTS_OCR_MISSING |
| AP | 6–10 | Math/Sci/SST | 2025-26 EM | cse.ap.gov.in | PDF ✓ | ✓ | 15 mirrors | No | ✓ | BILINGUAL_SOURCE |
| AP | 6–10 | English | 2025-26 | cse.ap.gov.in | PDF ✓ | ✓ | No | No | ✓ | SOURCE_EXISTS_OCR_MISSING |
| TS | 6–8,10 | Core (excl. gaps) | 2025-26 | GDrive 3rd-party | PDF ✓ | ✓ | No | No | partial | SOURCE_EXISTS_OCR_MISSING |
| TS | 6,9,10 | SST/Math/Sci gaps | 2025-26 | GDrive 3rd-party | ✗ | — | — | — | — | MISSING |
| CISCE | 9–10 | Syllabus/SQP | 2025-26 | cisce.org | PDF ✓ | ✓ | No | No | ✓ | PARTIAL |
| CISCE | 6–10 | All textbooks | — | Commercial | ✗ | — | — | — | — | MISSING |
| ALL | 1–5 | All | — | — | ✗ | — | — | — | — | MISSING |

---

## Appendix B — Search locations inspected

- `curriculum/` (resources, downloads, discovery, reports, knowledge, staging, metadata, scripts, acquisition, archive)
- `docs/curriculum-intelligence/` (31 files)
- `docs/knowledge-intelligence-engine/`
- `docs/execution/`, `docs/roadmap/`
- `docs/archive/` (historical references)
- `curriculum/resources/archive/` (115 archived files)
- `curriculum/downloads/{failed,duplicates,verified,incoming}/`
- `curriculum/staging/qcorpus_noncert/manifests/`
- `curriculum/knowledge/kie/{kie.db,parsed/}`
- Git-tracked manifests referencing deleted files (`PROVENANCE_MANIFEST.json`)

---

*End of audit. No files were modified, downloaded, moved, or OCR-processed during this pass.*
