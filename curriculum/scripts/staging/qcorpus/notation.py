"""Mathematical / scientific notation — PRESERVATION-FIRST, with deterministic-only repair.

Policy (from the lane brief):
  • Native, high-quality text is PRESERVED, never "repaired". PyMuPDF already keeps Unicode
    super/subscripts (x², H₂SO₄, 10⁻³¹) intact for born-digital PDFs, so there is nothing to
    fix — we only ADD a searchable ASCII form.
  • Only DETERMINISTIC, information-preserving, high-confidence rules produce normalized
    output, and they write to an ADDITIVE `search_text` field — they NEVER overwrite the raw
    or normalized Unicode text.
  • Anything ambiguous (a possible OCR flattening such as 10^-31 -> 10-31, x² -> x2,
    H₂SO₄ -> H2SO4) is FLAGGED as FORMULA_UNCERTAIN and left untouched — never silently
    "corrected".

Every applied repair records (doc_id, page, original_text, repaired_text, rule, confidence);
the caller attaches doc_id/page.
"""
from __future__ import annotations

import re
from typing import List, Tuple

_SUP = {"⁰": "0", "¹": "1", "²": "2", "³": "3", "⁴": "4", "⁵": "5", "⁶": "6", "⁷": "7",
        "⁸": "8", "⁹": "9", "⁺": "+", "⁻": "-", "⁼": "=", "⁽": "(", "⁾": ")", "ⁿ": "n", "ⁱ": "i"}
_SUB = {"₀": "0", "₁": "1", "₂": "2", "₃": "3", "₄": "4", "₅": "5", "₆": "6", "₇": "7",
        "₈": "8", "₉": "9", "₊": "+", "₋": "-", "₌": "=", "₍": "(", "₎": ")"}
_SUP_RE = re.compile("[" + "".join(map(re.escape, _SUP)) + "]+")
_SUB_RE = re.compile("[" + "".join(map(re.escape, _SUB)) + "]+")

MATH_SYMBOLS = set("∫∑∏√∞±×÷≤≥≠≈→←↔⇒⇔∂∇∈∉⊂⊆⊃⊇∪∩∅°′″⋅∘∓≡∝⊥∠∴∵ℏℓµμ"
                   "αβγδεζηθικλμνξπρστυφχψωΓΔΘΛΞΠΣΦΨΩ")
_SCI = re.compile(r"\d(\.\d+)?\s*[×xX]\s*10")               # scientific-notation cue

# ── FORMULA_UNCERTAIN detectors (flag, never auto-repair) ────────────────────────
_FLAT_EXP = re.compile(r"(?:×?\s*10)\s*[-–—]\s*\d{1,3}\b")  # 10-31 : possible flattened exponent
_FLAT_SUB = re.compile(r"\b(?:[A-Z][a-z]?){1,3}\d{1,3}(?:[A-Z][a-z]?\d{0,3})*\b")  # H2SO4
_LOST_SUP = re.compile(r"\b[a-zA-Z]\d\b")                   # x2 : possible lost superscript


def _window(text: str, start: int, end: int, pad: int = 24) -> str:
    return text[max(0, start - pad):min(len(text), end + pad)].replace("\n", " ").strip()


def has_notation(text: str) -> bool:
    if not text:
        return False
    if any(ch in MATH_SYMBOLS for ch in text):
        return True
    if _SUP_RE.search(text) or _SUB_RE.search(text):
        return True
    return bool(_SCI.search(text))


def build_search_text(text: str) -> Tuple[str, List[dict]]:
    """Expand Unicode super/subscripts into an ADDITIVE ASCII search form.

    Returns (search_text, repairs). search_text is a searchable projection (x²->x^2,
    H₂SO₄->H_2SO_4, 10⁻³¹->10^-31); it does NOT replace the original. Each expansion is a
    high-confidence, reversible repair record.
    """
    repairs: List[dict] = []

    def _sup(m):
        expanded = "".join(_SUP[c] for c in m.group(0))
        return "^" + (expanded if len(expanded) == 1 else "{" + expanded + "}")

    def _sub(m):
        expanded = "".join(_SUB[c] for c in m.group(0))
        return "_" + (expanded if len(expanded) == 1 else "{" + expanded + "}")

    out = text
    for rx, fn, rule in ((_SUP_RE, _sup, "unicode_superscript_expand"),
                         (_SUB_RE, _sub, "unicode_subscript_expand")):
        for m in rx.finditer(text):
            repairs.append({
                "original_text": m.group(0),
                "repaired_text": fn(m),
                "repair_rule": rule,
                "repair_confidence": 0.99,
            })
        out = rx.sub(fn, out)
    # Unify Unicode minus in the search projection only.
    if "−" in out:
        out = out.replace("−", "-")
    return out, repairs


def flag_uncertain(text: str, is_ocr: bool) -> List[dict]:
    """FORMULA_UNCERTAIN candidates. On native text we only flag the exponent case (which is
    unambiguous even born-digital); the noisier lost-super/subscript heuristics fire ONLY on
    OCR pages, where flattening actually happens — this keeps born-digital text unflagged."""
    flags: List[dict] = []
    for m in _FLAT_EXP.finditer(text):
        flags.append({"snippet": _window(text, m.start(), m.end()),
                      "reason": "possible_flattened_exponent", "flag": "FORMULA_UNCERTAIN"})
    if is_ocr:
        seen = set()
        for rx, reason in ((_LOST_SUP, "possible_lost_superscript"),
                           (_FLAT_SUB, "possible_flattened_subscript")):
            for m in rx.finditer(text):
                tok = m.group(0)
                if tok in seen or tok.isalpha() or tok.isdigit():
                    continue
                seen.add(tok)
                flags.append({"snippet": _window(text, m.start(), m.end()),
                              "reason": reason, "flag": "FORMULA_UNCERTAIN", "token": tok})
    return flags[:200]  # cap: preserve evidence without unbounded growth on pathological pages
