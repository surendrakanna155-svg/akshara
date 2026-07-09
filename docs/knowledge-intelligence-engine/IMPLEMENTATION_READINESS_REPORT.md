# Knowledge Intelligence Engine — Implementation Readiness Report

**Date:** 2026-07-09 · **Author:** engineering audit (single-session, read-only pass) ·
**Status:** ✅ Audit complete — Phase 1 authorized and started same session.

> **Scope of this report.** The product direction is now the **AI-powered JEE/NEET
> Knowledge Intelligence Engine (KIE)**. The local repository (`curriculum/resources/foundation/`)
> is the *input*; the KIE is the *product*. **Repository acquisition is COMPLETE and FROZEN** —
> no downloading, crawling, searching, or repository expansion. **School Question Paper
> Generation** (the CBSE/AP/TS/CISCE Classes 6–10 blueprint-solver program under
> `docs/curriculum-intelligence/` and `supabase/functions/_shared/education/`) is **archived and
> must not be developed further.** This report audits what already exists, classifies it as
> reusable / partial / out-of-scope / missing against the 8-phase KIE pipeline, and records the
> environment decisions taken to unblock implementation.

---

## 1. Executive summary

- The repository is **substantially built for a different product** (school paper generation).
  Roughly **2,400 lines of certified, tested Python data-lane code** exist for *acquisition +
  verification + metadata + coverage*, plus a large Deno/TS "Question Intelligence" engine in the
  app. Under the new JEE/NEET direction, the acquisition/coverage/board machinery and the Deno
  solver are **out of scope**, but several **primitives are directly reusable** (PDF integrity
  checks, sha256, duplicate detection, manifest/report patterns).
- **The KIE proper (Phases 2–8: parser → metadata → chunking → concept extraction → knowledge
  graph → question intelligence → AI generation) does not exist yet.** One thin Phase-1 stub
  (`run_pipeline.py`, header-only PDF check) is the only KIE-labelled code.
- **Environment was blocked and is now unblocked.** No PDF-parsing libraries were installed and
  the system Python (3.14, PEP-668 externally-managed) refused installs. A dedicated, gitignored
  **Python 3.13 virtualenv** (`curriculum/.venv`) now exists with `pypdf` installed; PyMuPDF /
  pdfplumber / Tesseract are staged for Phase 2 (3.13 has reliable wheels; 3.14 did not).
- **The corpus is real and mixed.** 363 foundation files (334 PDF, 29 ZIP, 1 index). A sample
  probe shows three parser classes coexisting: **born-digital text**, **sparse-text**, and
  **scanned (0 extractable chars → OCR required)**. This makes Phase 1 "parser readiness"
  classification a genuine prerequisite, not a formality.

**Verdict:** Ready to implement. Phase 1 (Repository Verification) can be built now on `pypdf`
alone; Phases 2–8 are greenfield and sequenced behind it.

---

## 2. Environment findings & decisions taken this session

| Finding | Detail | Decision |
|---|---|---|
| No parsing libs | `fitz`/PyMuPDF, `pdfplumber`, `pytesseract`, `PIL`, `numpy`, `pandas`, `sympy`, `pypdf` all **absent** | Install into an isolated venv, not system Python |
| System Python locked | Homebrew Python 3.14.2, PEP-668 externally-managed → `pip install` refused | Do **not** use `--break-system-packages` |
| Python 3.14 too new | Binary-wheel libraries (PyMuPDF, numpy) lag on 3.14 | **Use Python 3.13.11** (present on machine) for the data lane |
| Venv created | `curriculum/.venv` (py3.13) + `pypdf 6.14.2` installed; added to `curriculum/.gitignore`; `requirements.txt` committed | KIE data-lane runs under this venv |
| Existing engine degrades gracefully | `verification_engine.py` already uses `pypdf` when importable, structural checks otherwise | Reuse it; it now gets real page-parsing for free |

**Reproducibility:** `curriculum/scripts/intelligence/requirements.txt` pins the data-lane deps.
Recreate with `python3.13 -m venv curriculum/.venv && curriculum/.venv/bin/pip install -r
curriculum/scripts/intelligence/requirements.txt`.

---

## 3. Corpus inventory (the KIE input — frozen)

`curriculum/resources/foundation/` — the JEE/NEET corpus (verified by `ingest_manifest.json`:
363 files, 0 corrupt by the naive header check):

| Category | Files | Notes |
|---|---:|---|
| NEET | 152 | previous papers, answer keys, mock tests |
| JEE_Main | 75 | official NTA + mirror papers/solutions |
| Practice_Resources | 54 | DPPs, mock tests, formula sheets |
| NCERT | 29 | source textbooks (concept ground truth) |
| AIIMS | 26 | legacy medical-entrance papers (some scanned) |
| JEE_Advanced | 20 | previous papers |
| AIPMT | 6 | legacy pre-NEET medical papers |
| NTA_Sample | 1 | sample paper |
| **Total** | **363** | 334 pdf · 29 zip · 1 md |

**Out of scope (present but archived):** `resources/curriculum/` (199 files, CBSE/AP/TS/ICSE
school boards) and `resources/archive/` (115 files) — belong to the archived school-QP program;
the KIE must not consume them by default.

**Parser-readiness reality (8-file random probe, `pypdf`):** born-digital text (≈400–2500
chars/page), sparse text (≈60 chars/page — column/image-heavy; PyMuPDF likely recovers more), and
fully scanned (0 chars → OCR). No encrypted files in the sample. This is the empirical basis for
Phase 1's classifier.

---

## 4. Component audit — reuse / partial / out-of-scope / missing

Legend: 🟢 reuse as-is · 🟡 reuse primitives / adapt · ⚫ out-of-scope (archived) · 🔴 missing (build)

| Component | Path | Verdict | Notes for the KIE |
|---|---|---|---|
| **PDF integrity checks** | `verification_engine.py::_verify_pdf` | 🟢 | header/EOF/startxref/page-count (pypdf or structural). Reuse verbatim for corruption detection. |
| **Checksum + duplicate logic** | `verification_engine.py::_sha256`, checksum_index | 🟢 | sha256 streaming + duplicate diversion. Reuse for repo-level dedup. |
| **Manifest / report pattern** | `verification_engine.py`, `repository_audit.py` | 🟢 | JSON-first, atomic writes, Markdown report generator, `PROJECT_STATUS.json` verdicts. Mirror this shape for every KIE phase. |
| **Ingest scan (KIE stub)** | `intelligence/run_pipeline.py` | 🟡 | already scans `foundation/` + writes `ingest_manifest.json`, but PDF check is header-only. **Superseded** by the Phase 1 verifier. |
| **Config-over-code** | `configs/{paths,verification_rules,...}.json` | 🟢 | thresholds/layout externalised. Phase 1 reads `verification_rules.json:pdf`. |
| **Metadata engine** | `metadata/metadata_tools.py` | 🟡 | validate + secondary-index rebuild — but its schema is board/class/subject (school). Phase 3 needs a **JEE/NEET metadata schema** (exam, year, subject, doc-type, shift, paper-code). Reuse the validate/rebuild *pattern*, replace the schema. |
| **Acquisition (crawler/discovery/download)** | `scripts/{crawler,discovery,download,acquisition}/` | ⚫ | FROZEN. Do not run or extend. |
| **Coverage matrix / board certification** | `reports/coverage_matrix.py`, `common/coverage.py`, `repository_audit.py::certify` | ⚫ | school-board Priority-A coverage — irrelevant to JEE/NEET. Keep the **audit A1–A6 pattern** as a reference only. |
| **Deno/TS "Question Intelligence" engine** | `supabase/functions/_shared/education/**` | ⚫ | school blueprint solver + governance. Archived per directive; **do not touch.** KIE question generation (Phase 7–8) is a new local Python pipeline, not this. |
| **CBSE blueprints** | `knowledge/blueprints/*.json` | ⚫ | CBSE Class-X exam blueprints (school). Not JEE/NEET. |
| **Local parser (text/tables/eqns/images/diagrams/boundaries)** | — | 🔴 | **Missing.** Phase 2. Needs PyMuPDF + pdfplumber (+ Tesseract for scanned). |
| **Chunking engine** | — | 🔴 | **Missing.** Phase 4. No `scripts/chunking/` exists. |
| **Concept / formula / example / PYQ extraction** | — | 🔴 | **Missing.** Phase 5. |
| **Knowledge graph** | — | 🔴 | **Missing.** Phase 6. |
| **Question intelligence (difficulty/Bloom/trends)** | — | 🔴 | **Missing.** Phase 7. |
| **Original question generation** | — | 🔴 | **Missing.** Phase 8. AI only on small semantic chunks (LLM policy). |
| **DB / persistence for KIE** | — | 🔴 | **Missing.** Local-first: JSON/SQLite indexes under `curriculum/knowledge/` (gitignored). No Supabase/tenant DB dependency for the KIE. |

---

## 5. Phase-by-phase readiness (the 8-phase pipeline)

| Phase | Goal | Reuse | Missing / gap | Status |
|---|---|---|---|---|
| **1 Repository Verification** | verify repo, detect duplicates + corruption, verify parser readiness | 🟢 `_verify_pdf`, `_sha256`, manifest/report pattern | repo-level dedup pass + **parser-readiness classifier** (text/sparse/scanned/encrypted/corrupt) + Phase-2 input manifest | **BUILDING NOW** |
| **2 Local Parser** | text, tables, equations, images, diagrams, page/chapter/exercise/question boundaries | pypdf (floor) | PyMuPDF + pdfplumber + Tesseract; boundary detection heuristics | Next; libs staged |
| **3 Metadata Engine** | per-document metadata | metadata_tools *pattern* | JEE/NEET schema (exam, year, shift, subject, paper-code, doc-type) | Blocked on Phase 2 |
| **4 Chunking** | semantic chunks | — | boundary-aware chunker over Phase-2 output | Blocked on Phase 2 |
| **5 Concept Extraction** | concepts, formulae, definitions, examples, PYQs, relationships | — | deterministic extractors + small-chunk AI (≤10%) | Blocked on Phase 4 |
| **6 Knowledge Graph** | concept/chapter/prereq/formula/PYQ/difficulty links | — | graph store (SQLite/JSON) + relationship builders | Blocked on Phase 5 |
| **7 Question Intelligence** | difficulty, Bloom, frequency, patterns, mistakes, trends | — | analysers over PYQ corpus (analysis only, never republish) | Blocked on Phase 6 |
| **8 AI Question Generation** | unlimited **original** questions | — | offline-AI generation + validation/certification gate; never reproduce source items | Blocked on Phase 7 |

**LLM policy (locked):** never send whole PDFs/books to a model; 90–95% deterministic local
processing, 5–10% AI reasoning on small semantic chunks only (concept classification, Bloom,
relationships, ambiguity, generation). Every phase: compiles, has tests, passes regression, is
committed, becomes the next recovery checkpoint.

---

## 6. Risks & mitigations

| # | Risk | Mitigation |
|---|---|---|
| R1 | Copyright — source items are licensed; PYQs must not be republished | KIE stores *derived* knowledge only; local-only (gitignored); Phase 8 emits **original** questions; PYQs used for pattern analysis (D8 original-content-first) |
| R2 | Scanned PDFs (0 text-layer) need OCR | Phase 1 classifies them; Phase 2 routes to Tesseract; OCR quality tracked |
| R3 | PyMuPDF/pdfplumber wheels on Python 3.14 | Resolved — data lane pinned to **Python 3.13** venv |
| R4 | `pypdf` under-extracts vs PyMuPDF → some "sparse" misclassified | Phase 1 marks sparse as *review*, not scanned; Phase 2 (PyMuPDF) reclassifies; classifier is a conservative floor |
| R5 | Accidental scope bleed into archived school-QP code | Standing rule: KIE code lives under `curriculum/scripts/intelligence/`; never edit `supabase/functions/_shared/education/**` or run acquisition |
| R6 | Corpus is frozen but derived outputs grow | Derived knowledge → `curriculum/knowledge/` (gitignored per local-storage policy); commit only code/schemas/manifests/tests |

---

## 7. Decisions taken this session (no owner input required — within directive)

1. **Data-lane runtime = `curriculum/.venv` (Python 3.13) + `pypdf`.** Gitignored; reproducible via `requirements.txt`.
2. **KIE code home = `curriculum/scripts/intelligence/`** (already the KIE-labelled directory).
3. **KIE doc home = `docs/knowledge-intelligence-engine/`** (this report) — kept distinct from the archived `docs/curriculum-intelligence/` program.
4. **Reuse, don't rebuild:** Phase 1 imports `verification_engine`'s `_verify_pdf` + `_sha256` rather than reimplementing PDF integrity/hashing.
5. **Input = `resources/foundation/` only.** `resources/curriculum/` and `resources/archive/` are excluded from the KIE by default.

---

## 8. Immediate next action — Phase 1 (Repository Verification)

**Build** `curriculum/scripts/intelligence/repository_verifier.py`:
- enumerate `resources/foundation/`; per file: integrity (reuse `_verify_pdf`), sha256, size, kind;
- **duplicate detection** — exact sha256 sets (+ filename-collision hints);
- **corruption detection** — PDF header/EOF/startxref/parse failures; ZIP open test;
- **parser-readiness classification** — `born_digital_text` / `sparse_text` / `scanned_image` /
  `encrypted` / `corrupt` / `archive`, each mapped to a Phase-2 strategy (`text_extract` /
  `text_extract_review` / `ocr` / `decrypt` / `exclude` / `unpack`);
- **emit** `curriculum/knowledge/repository_verification.json` (Phase-2 input manifest) +
  `curriculum/reports/REPOSITORY_VERIFICATION_REPORT.md` (human summary) + a KIE status verdict.

**Definition of done (per project quality rules):** compiles/runs clean · unittest suite added and
green under the venv · existing curriculum regression suite still green · committed as the Phase-1
recovery checkpoint · EOS one-line verdict surfaced.

---

## 9. Phase 1 — EXECUTED (2026-07-09, same session)

Built `curriculum/scripts/intelligence/repository_verifier.py` (+ 10 unittest cases) reusing the
certified `verification_engine` primitives. Ran over the full frozen corpus in ~60s. Result:

| Metric | Value |
|---|---:|
| Total files | 363 |
| Integrity OK | 361 |
| **Corrupt (newly detected)** | **2** |
| Duplicate files | 1 |
| Ready for text parsing (born-digital + sparse) | 239 |
| Needs OCR (scanned) | 93 |
| Needs unpack (archives) | 28 |
| Encrypted | 0 |

**Parser-readiness:** born_digital_text 226 · sparse_text 14 · scanned_image 93 · archive 28 · corrupt 2.

**Corruption Phase 1 caught that the header-only ingest missed** (`ingest_manifest.json` reported
0 corrupt):
- `NCERT/Class_11/Textbooks/NCERT_Class11_lech2dd.zip` — not actually a zip (mislabeled/partial).
- `NEET/.../NEET_2024_..._R4-paper-solution.pdf` — truncated (no `%%EOF`, partial download).

**Exact duplicate:** an `NTA_Sample` file is byte-identical to a `JEE_Main/2025` official paper.

**Verdict:** `READY_FOR_PARSING`. Outputs (gitignored, local-only): manifest
`curriculum/knowledge/repository_verification.json` (the Phase-2 input work-list),
`curriculum/reports/REPOSITORY_VERIFICATION_REPORT.md`, `PROJECT_STATUS.json:kie_phase1`.

**Tests:** 45/45 curriculum unittest cases green (system py3 = 43 run + 2 pypdf-skipped; venv py3.13 =
45 run). No regression to the existing acquisition/verification suite.

**Next (Phase 2 — Local Parser):** install PyMuPDF + pdfplumber (+ Tesseract) into the venv; parse
the 239 text-ready docs (text/tables/equations/coordinates) and route the 93 scanned docs to OCR;
unpack the 28 archives and re-verify their contents through Phase 1. PyMuPDF will reclassify some of
the 14 `sparse_text` docs upward. Exclude the 2 corrupt files (documented, not deleted).
