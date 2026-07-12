# PARSER ROUTING BENCHMARK — selected route: PyMuPDF + pdfplumber + Tesseract

**Decision:** reuse the proven in-repo loss-minimising route (kie.phase2_parse); do NOT install Docling / MinerU / Marker. Rationale in `qcorpus/benchmark.py` docstring — the priority corpus is born-digital, heavy ML parsers are absent from the locked venv, and detection-first OCR already routes native/mixed/scanned pages optimally.

| slice | media | method | pages | ch/pg | Q | complete | opts | ans | eqns | imgs | s/pg |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| biology_diagram_rich | native | pymupdf | 5 | 3214.0 | 45 | 0 | 45 | 0 | 1 | 50 | 0.083 |
| physics_equation_heavy | native | pymupdf | 6 | 2033.3 | 12 | 0 | 9 | 0 | 242 | 35 | 0.069 |
| chemistry_notation | native | pymupdf | 7 | 2393.6 | 16 | 0 | 6 | 0 | 0 | 86 | 0.125 |
| maths_formula_heavy | native | pymupdf | 2 | 1044.5 | 14 | 0 | 7 | 0 | 0 | 3 | 0.047 |
| native_text_bank | native | pymupdf | 8 | 1347.8 | 5 | 0 | 5 | 0 | 0 | 12 | 0.326 |
| scanned_paper | scanned | tesseract | 20 | 395.4 | 0 | 0 | 0 | 0 | 0 | 20 | 0.923 |
| multi_column_dpp | mixed | mixed | 43 | 115.2 | 1 | 0 | 1 | 0 | 22 | 53 | 0.434 |

Measured on one representative document per type. Text recovery = ch/pg; structure recovery = Q/options/answers; runtime = s/pg. Native docs use `pymupdf` (no OCR); scanned docs escalate to `tesseract`; mixed docs use `mixed`.
