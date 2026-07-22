# OCR Recovery Lane

**Owner-authorized 2026-07-22. Runs PARALLEL to Program B and must never block it.** A deterministic pipeline
that re-OCRs low-confidence / honest-null documents and proposes **verified improvements**, so corpus coverage
can rise over time — without ever mutating the frozen substrate or fabricating text.

## Owner rules (binding)
1. Detect low-quality OCR pages · 2. Re-run OCR with improved settings/models · 3. Compare old vs new
**deterministically** · 4. Keep **only objectively improved** results · 5. **Preserve both** original + recovered
for audit · 6. Feed only **verified** improvements back. **Never overwrite existing OCR automatically · never
fabricate missing text · every recovered document independently verified before it could replace the previous
version.** Program B continues on the currently-certified OCR + honest-null rules; this lane is separate.

## Engineering (package `kie/qie/ocr_recovery/`, derived store `ocr_recovery.db`, both gitignored)
- **`quality.py`** — pure deterministic score(text)∈[0,1] = 0.25·alpha + 0.40·word-hit + 0.15·token-len +
  0.20·clean-run. The word-hit term (dictionary + a dict-free pronounceability heuristic) is what separates real
  English from romanized/OCR garble that an alpha-ratio cannot catch.
- **`engine.py`** — a swappable `OcrEngine` interface + a Tesseract adapter (fitz render → PIL preprocess →
  pytesseract with an explicit, content-hashed `OcrSettings`). Improved settings over the frozen baseline
  (DPI 300→400, `--oem 1` LSTM, `--psm 6`, grayscale+autocontrast). **Honest-null:** any render/OCR failure
  returns `None` — never fabricated.
- **`detect.py`** — flags candidates by parser_class (scanned/sparse) or a low content score; records the
  worst-scoring pages as re-OCR targets. kie.db read-only.
- **`recover.py`** — the 6-step pipeline. **Improvement gate:** `recovered − original ≥ 0.05` (strict; else
  `kept_original`, never regress). **No-fabrication gate** (pure `fabrication_check`): NF-A numbers (retain most
  originals AND cap invented new numbers), NF-B the recovered content must be **grounded in a coherent original**
  (recall-of-recovered ≥ 0.30), NF-C when the original is too garbled, an **independent second read** at a
  different psm must ground the recovered text (recall-of-recovered ≥ 0.30). The local PDF's sha256 is verified
  against the frozen `source_documents.sha256` before OCR (never OCR the wrong file). The **manifest is a
  PROPOSAL only** — a future version-bumped, independently-gated kie.db rebuild could consume it; **this lane
  never applies it.**

## Status
- Built + reviewed (all files read) + **35 tests green** (incl. red-team tests for the invented-content exploit).
- Independently adversarially verified (refute-first): **freeze-safety, honest-null, determinism, "never mutate
  kie.db" all CONFIRMED against real tesseract runs; kie.db byte-identical + chmod 444.** The verifier REFUTED
  the no-fabrication gate (a smaller-set containment made invented ADDITIONS invisible) — **fixed:** the gate now
  measures **recall-of-recovered** (invented content absent from the reference drives it down) + caps invented
  numbers; locked by red-team tests reproducing the exact exploit → now `rejected_fabrication`.
- Bounded real run proved one genuine improvement (Motion NEET DPP p2: 0.795→0.869, corrected a scholarship tier,
  preserved every fee number) with 0 fabrications.

## Honest limitations
- **Conservative by design** — many scanned docs are already acceptable, so verified improvements are the
  minority. The lane produces *verified candidates*, not volume.
- **Bilingual floor** — under `-l eng`, Hindi on NTA papers is irreducible garble; the biggest headroom is
  `-l eng+hin` (Hindi traineddata not currently installed).
- **Bounded run only** — the full ~149-candidate batch is a longer job (tesseract is slow; the NF-C grounding
  pass doubles cost on garbled pages). **Re-integration into kie.db is NOT done and is explicitly gated.**
- Non-blocking P2s (documented, tracked): the quality metric is gameable by dictionary-word padding (defused for
  *fabrication* by the recall gate); the detection threshold sits below romanized-garbage scores (those are
  caught by parser_class); the result store is an idempotent upsert (deterministic → stable), not literal
  append-only.