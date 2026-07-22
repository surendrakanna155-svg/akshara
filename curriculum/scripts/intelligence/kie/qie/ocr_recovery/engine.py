"""OCR engine ADAPTER interface + a Tesseract adapter.

The recovery pipeline talks to OCR through ONE narrow, swappable interface:

    ocr_page(pdf_path, page_index, settings) -> Optional[str]

so a better engine (a different tesseract build, or a future vision model) can drop in later without the
pipeline changing. Two hard rules the interface enforces on every adapter:

  * DETERMINISTIC given (pdf, page, settings). Tesseract with a fixed render + fixed config string is
    deterministic (LSTM inference has no randomness); the improved settings are captured in `OcrSettings`
    and content-hashed (`settings_hash`) so a result is reproducible and idempotent.
  * NEVER FABRICATE. A render or OCR failure returns None (honest-null) — the pipeline records the page as
    `ocr_failed`, never invents text. Adapters must not synthesize, autocorrect against a language model, or
    fill gaps; they transcribe pixels only.

`OcrSettings` makes the improvement headroom over the frozen baseline EXPLICIT and recorded:
  render DPI (baseline used 300), tesseract `--oem` (1 = LSTM), `--psm` (page-segmentation mode), `-l` lang,
  and a tuple of PIL-only preprocessing ops (grayscale / autocontrast / binarize / upscale — numpy/cv2 are
  not installed, so preprocessing is Pillow-only, per the environment).
"""
from __future__ import annotations

import hashlib
import io
import json
from dataclasses import dataclass, field
from pathlib import Path
from typing import List, Optional, Protocol, runtime_checkable

# Preprocessing op names (PIL-only; validated at settings construction so a typo fails loud, not silently).
_VALID_PREPROCESS = ("grayscale", "autocontrast", "binarize", "upscale2x")


@dataclass(frozen=True)
class OcrSettings:
    """An explicit, content-hashable OCR configuration. Frozen (immutable) so it can be a dict/db key and so a
    result's settings can never drift after the fact."""
    dpi: int = 400
    oem: int = 1                       # 1 = LSTM engine (baseline used tesseract default)
    psm: int = 6                       # 6 = assume a uniform block of text (baseline used default 3)
    lang: str = "eng"
    preprocess: tuple = ("grayscale", "autocontrast")
    label: str = "improved"

    def __post_init__(self):
        for op in self.preprocess:
            if op not in _VALID_PREPROCESS:
                raise ValueError(f"unknown preprocess op {op!r}; valid: {_VALID_PREPROCESS}")

    def tesseract_config(self) -> str:
        """The explicit tesseract `config` string — recorded verbatim, never implicit."""
        return f"--oem {self.oem} --psm {self.psm} -l {self.lang}"

    def canonical(self) -> str:
        return json.dumps(
            {"dpi": self.dpi, "oem": self.oem, "psm": self.psm, "lang": self.lang,
             "preprocess": list(self.preprocess)},
            sort_keys=True,
        )

    def settings_hash(self) -> str:
        """Deterministic id of these settings (drives the content-addressed, idempotent result key)."""
        return hashlib.sha256(self.canonical().encode()).hexdigest()[:16]


# The IMPROVED settings (headroom over the frozen baseline) and an INDEPENDENT grounding pass used by the
# no-fabrication gate (a second read of the same pixels with a DIFFERENT psm — agreement across two
# independent reads is what grounds recovered text in the source render).
IMPROVED = OcrSettings(dpi=400, oem=1, psm=6, lang="eng", preprocess=("grayscale", "autocontrast"), label="improved")
GROUNDCHECK = OcrSettings(dpi=350, oem=1, psm=4, lang="eng", preprocess=("grayscale",), label="groundcheck")
# A faithful record of what produced the frozen kie.db text (phase2_parse: dpi=300, tesseract defaults, no
# preprocessing) — stored for provenance so every result names both the old and the new settings.
BASELINE = OcrSettings(dpi=300, oem=3, psm=3, lang="eng", preprocess=(), label="baseline_frozen")


@runtime_checkable
class OcrEngine(Protocol):
    """The swappable contract. Any adapter (tesseract now, a better model later) implements exactly this."""
    def ocr_page(self, pdf_path, page_index: int, settings: OcrSettings) -> Optional[str]:
        ...


def _preprocess(img, ops: tuple):
    """Apply PIL-only preprocessing in a fixed, recorded order. Deterministic."""
    from PIL import ImageOps
    for op in ops:
        if op == "grayscale":
            img = img.convert("L")
        elif op == "autocontrast":
            img = ImageOps.autocontrast(img.convert("L"))
        elif op == "binarize":
            g = img.convert("L")
            img = g.point(lambda p: 255 if p > 160 else 0, mode="L")  # fixed global threshold (deterministic)
        elif op == "upscale2x":
            img = img.resize((img.width * 2, img.height * 2))
    return img


class TesseractEngine:
    """Tesseract adapter: fitz-render → PIL-preprocess → pytesseract with an EXPLICIT config string.

    Returns None (honest-null) on ANY render/OCR failure — the pipeline treats that as `ocr_failed` and never
    fabricates. Imports of fitz/pytesseract/PIL are lazy so the package imports fine on a machine without them
    (the hermetic tests then use a fake engine); a live run that needs them will surface the ImportError as a
    None result, i.e. an honest failure rather than a fabricated success."""

    def __init__(self, tesseract_cmd: Optional[str] = None):
        self._cmd = tesseract_cmd

    def ocr_page(self, pdf_path, page_index: int, settings: OcrSettings) -> Optional[str]:
        try:
            import fitz  # PyMuPDF
            import pytesseract
            from PIL import Image
        except Exception:
            return None                       # dependency missing → honest-null, never fabricate
        if self._cmd:
            pytesseract.pytesseract.tesseract_cmd = self._cmd
        try:
            with fitz.open(str(pdf_path)) as doc:
                if page_index < 0 or page_index >= doc.page_count:
                    return None
                if doc.needs_pass:
                    doc.authenticate("")
                page = doc[page_index]
                pix = page.get_pixmap(dpi=settings.dpi)
                img = Image.open(io.BytesIO(pix.tobytes("png")))
                img = _preprocess(img, settings.preprocess)
                text = pytesseract.image_to_string(img, config=settings.tesseract_config())
        except Exception:
            return None                       # render/OCR failure → honest-null
        text = (text or "").strip()
        return text or None                   # empty OCR is honest-null, not a fabricated success


def render_available() -> bool:
    """True iff fitz + pytesseract + PIL are importable AND tesseract is on PATH — gates the live sample run."""
    try:
        import fitz  # noqa: F401
        import pytesseract
        from PIL import Image  # noqa: F401
    except Exception:
        return False
    try:
        pytesseract.get_tesseract_version()
        return True
    except Exception:
        return False
