#!/usr/bin/env python3
"""Knowledge Intelligence Engine — Phase 1: Repository Verification.

Read-only pass over the FROZEN JEE/NEET corpus (``resources/foundation/``). For every
document it:

  * verifies structural integrity (reusing the certified acquisition primitives),
  * detects exact-content duplicates (sha256) + filename-collision hints,
  * detects corruption (bad header / truncation / parse failure / unreadable archive),
  * classifies **parser readiness** so Phase 2 (Local Parser) knows how to process each file:

        born_digital_text  → text_extract          (has a real text layer)
        sparse_text        → text_extract_review    (little text; PyMuPDF may recover more)
        scanned_image      → ocr                    (no text layer; needs Tesseract)
        encrypted          → decrypt                (password-protected)
        corrupt            → exclude                (do not feed to the parser)
        archive            → unpack                 (zip/ecar; expand first)
        unknown / undetermined → manual

Reuses ``verification_engine._verify_pdf`` and ``_sha256`` — it does not reimplement PDF
integrity or hashing. Downloads nothing; never mutates the corpus. Derived outputs are
local-only (gitignored per the resource-storage policy):

  curriculum/knowledge/repository_verification.json   machine-readable Phase-2 input manifest
  curriculum/reports/REPOSITORY_VERIFICATION_REPORT.md human-readable summary
  curriculum/PROJECT_STATUS.json (``kie_phase1`` verdict)

Usage (run under the data-lane venv so pypdf is available):
  curriculum/.venv/bin/python curriculum/scripts/intelligence/repository_verifier.py --run
  ...--run --limit 20      quick sample (first N files by path)
  ...--report-only         regenerate the Markdown report from an existing manifest
"""

from __future__ import annotations

import argparse
import sys
import zipfile
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

# Resolve curriculum root: scripts/intelligence/ -> curriculum/
CURRICULUM_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(CURRICULUM_ROOT / "scripts" / "verification"))
# Reuse certified primitives — never rebuild PDF integrity / hashing / atomic IO.
from verification_engine import VerificationEngine, _load_json, _write_json  # noqa: E402

try:  # optional but required for a meaningful readiness verdict
    import pypdf as _pypdf
    from pypdf import PdfReader

    HAVE_PYPDF = True
    PYPDF_VERSION = getattr(_pypdf, "__version__", "unknown")
except Exception:  # pragma: no cover - environment dependent
    PdfReader = None
    HAVE_PYPDF = False
    PYPDF_VERSION = None


# --------------------------------------------------------------------- tunables
# Documented, deterministic thresholds. pypdf under-extracts vs PyMuPDF, so these
# are a conservative *floor*: "sparse_text" is a review bucket, not a scanned verdict.
READINESS_SAMPLE_PAGES = 5           # pages sampled evenly across a document
BORN_DIGITAL_MIN_CHARS_PER_PAGE = 200  # >= this avg over sampled pages => real text layer
SCANNED_MAX_TOTAL_CHARS = 20         # <= this total => effectively no text (needs OCR)

# parser_class -> Phase-2 strategy
STRATEGY = {
    "born_digital_text": "text_extract",
    "sparse_text": "text_extract_review",
    "scanned_image": "ocr",
    "encrypted": "decrypt",
    "corrupt": "exclude",
    "archive": "unpack",
    "undetermined": "manual",
    "unknown": "manual",
}
# Buckets that Phase 2 can hand straight to its text pipeline.
READY_CLASSES = ("born_digital_text", "sparse_text")


def _iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _kind(path: Path) -> str:
    ext = path.suffix.lower()
    if ext == ".pdf":
        return "pdf"
    if ext in (".zip", ".ecar"):
        return "archive"
    return "other"


def _sample_indices(pages: int, k: int) -> list[int]:
    """Evenly spaced page indices (front + body + back) for a stable readiness sample."""
    if pages <= 0:
        return []
    k = min(k, pages)
    if k == 1:
        return [0]
    return sorted({int(round(i * (pages - 1) / (k - 1))) for i in range(k)})


@dataclass
class FileVerdict:
    path: str                      # relative to the source scope
    category: str                  # top-level folder (NEET, JEE_Main, …)
    kind: str                      # pdf | archive | other
    bytes: int
    sha256: str
    integrity_ok: bool
    corruption_reason: Optional[str]
    parser_class: str
    parser_strategy: str
    pages: Optional[int] = None
    encrypted: bool = False
    text_chars_sampled: int = 0
    sampled_pages: int = 0
    chars_per_page: float = 0.0
    is_duplicate: bool = False
    duplicate_of: Optional[str] = None


class RepositoryVerifier:
    """Phase-1 repository verification over a frozen corpus subtree."""

    def __init__(self, workspace: Path, source_rel: str = "resources/foundation"):
        self.workspace = Path(workspace)
        self.source_rel = source_rel
        self.source = self.workspace / source_rel
        self.knowledge = self.workspace / "knowledge"
        self.reports = self.workspace / "reports"
        self.manifest_path = self.knowledge / "repository_verification.json"
        self.report_path = self.reports / "REPOSITORY_VERIFICATION_REPORT.md"
        self.status_path = self.workspace / "PROJECT_STATUS.json"
        # Reused engine — supplies _verify_pdf + _sha256 (needs the workspace configs).
        self._engine = VerificationEngine(self.workspace)

    # ----------------------------------------------------------------- scanning

    def scan(self, limit: Optional[int] = None) -> list[Path]:
        if not self.source.is_dir():
            raise FileNotFoundError(f"source scope missing: {self.source}")
        files = [
            p for p in sorted(self.source.rglob("*"))
            if p.is_file()
            and not p.name.startswith(".")          # .DS_Store etc.
            and p.name != "INDEX.md"
        ]
        return files[:limit] if limit else files

    def _category(self, rel: Path) -> str:
        return rel.parts[0] if len(rel.parts) > 1 else "(root)"

    # ------------------------------------------------------------ per-file work

    def verify_file(self, path: Path) -> FileVerdict:
        rel = path.relative_to(self.source)
        kind = _kind(path)
        size = path.stat().st_size
        sha = self._engine._sha256(path)
        base = dict(path=str(rel), category=self._category(rel), kind=kind, bytes=size, sha256=sha)

        if kind == "pdf":
            return self._verify_pdf_file(path, base)
        if kind == "archive":
            return self._verify_archive(path, base)
        # other (markdown, unknown) — not corrupt, but not parser input either
        return FileVerdict(integrity_ok=True, corruption_reason=None,
                           parser_class="unknown", parser_strategy=STRATEGY["unknown"], **base)

    def _verify_pdf_file(self, path: Path, base: dict) -> FileVerdict:
        # 1) authoritative structural corruption verdict (reused, certified)
        code, detail, _ = self._engine._verify_pdf(path)
        # 2) readiness probe (encryption + text layer)
        pclass, pages, enc, chars, sampled = self._classify_readiness(path)

        if enc:
            final_class, integrity_ok, reason = "encrypted", True, None
        elif code:
            final_class, integrity_ok, reason = "corrupt", False, f"{code}: {detail[:100]}"
        else:
            final_class, integrity_ok, reason = pclass, True, None

        cpp = round(chars / sampled, 1) if sampled else 0.0
        return FileVerdict(
            integrity_ok=integrity_ok, corruption_reason=reason,
            parser_class=final_class, parser_strategy=STRATEGY[final_class],
            pages=pages, encrypted=enc, text_chars_sampled=chars,
            sampled_pages=sampled, chars_per_page=cpp, **base,
        )

    def _classify_readiness(self, path: Path):
        """(parser_class, pages, encrypted, text_chars, sampled_pages) via pypdf.

        Returns ('undetermined', …) if pypdf is unavailable or the file won't open —
        the structural corruption verdict from _verify_pdf still stands.
        """
        if not HAVE_PYPDF:
            return ("undetermined", None, False, 0, 0)
        try:
            reader = PdfReader(str(path))
        except Exception:
            return ("undetermined", None, False, 0, 0)

        enc = bool(getattr(reader, "is_encrypted", False))
        if enc:
            try:
                reader.decrypt("")  # many "encrypted" PDFs use an empty owner password
            except Exception:
                pass

        try:
            pages = len(reader.pages)
        except Exception:
            # can't enumerate pages: encrypted if flagged, else undetermined
            return ("encrypted" if enc else "undetermined", None, enc, 0, 0)

        chars = 0
        sampled = 0
        for i in _sample_indices(pages, READINESS_SAMPLE_PAGES):
            try:
                txt = reader.pages[i].extract_text() or ""
            except Exception:
                txt = ""
            chars += len(txt.strip())
            sampled += 1

        if enc and chars == 0:
            return ("encrypted", pages, True, 0, sampled)
        if chars <= SCANNED_MAX_TOTAL_CHARS:
            pclass = "scanned_image"
        elif (chars / sampled if sampled else 0) >= BORN_DIGITAL_MIN_CHARS_PER_PAGE:
            pclass = "born_digital_text"
        else:
            pclass = "sparse_text"
        return (pclass, pages, enc, chars, sampled)

    def _verify_archive(self, path: Path, base: dict) -> FileVerdict:
        with path.open("rb") as fh:
            head = fh.read(4)
        if head[:2] != b"PK":
            return FileVerdict(integrity_ok=False, corruption_reason="ARCHIVE_BAD_HEADER: no PK magic",
                               parser_class="corrupt", parser_strategy=STRATEGY["corrupt"], **base)
        try:
            with zipfile.ZipFile(path) as zf:
                bad = zf.testzip()  # None => all CRCs ok
            if bad is not None:
                return FileVerdict(integrity_ok=False, corruption_reason=f"ARCHIVE_CRC_FAILED: {bad}",
                                   parser_class="corrupt", parser_strategy=STRATEGY["corrupt"], **base)
        except zipfile.BadZipFile as exc:
            return FileVerdict(integrity_ok=False, corruption_reason=f"ARCHIVE_OPEN_FAILED: {exc}",
                               parser_class="corrupt", parser_strategy=STRATEGY["corrupt"], **base)
        return FileVerdict(integrity_ok=True, corruption_reason=None,
                           parser_class="archive", parser_strategy=STRATEGY["archive"], **base)

    # ------------------------------------------------------------- duplicates

    @staticmethod
    def detect_duplicates(verdicts: list[FileVerdict]) -> list[dict]:
        """Annotate exact-content duplicates (sha256). First file by path is kept."""
        by_sha: dict[str, list[FileVerdict]] = {}
        for v in verdicts:  # verdicts arrive sorted by path
            by_sha.setdefault(v.sha256, []).append(v)
        dup_sets: list[dict] = []
        for sha, group in by_sha.items():
            if len(group) < 2:
                continue
            kept, dups = group[0], group[1:]
            for d in dups:
                d.is_duplicate = True
                d.duplicate_of = kept.path
            dup_sets.append({"sha256": sha, "kept": kept.path, "duplicates": [d.path for d in dups]})
        return dup_sets

    @staticmethod
    def filename_collisions(verdicts: list[FileVerdict]) -> list[dict]:
        """Same basename but different content (content variants) — informational."""
        by_name: dict[str, set] = {}
        paths: dict[str, list[str]] = {}
        for v in verdicts:
            name = Path(v.path).name
            by_name.setdefault(name, set()).add(v.sha256)
            paths.setdefault(name, []).append(v.path)
        return [{"filename": n, "distinct_contents": len(shas), "paths": sorted(paths[n])}
                for n, shas in by_name.items() if len(shas) > 1]

    # ------------------------------------------------------------------- driver

    def run(self, limit: Optional[int] = None) -> dict:
        files = self.scan(limit)
        verdicts = [self.verify_file(p) for p in files]
        dup_sets = self.detect_duplicates(verdicts)
        collisions = self.filename_collisions(verdicts)
        manifest = self._build_manifest(verdicts, dup_sets, collisions)

        self.knowledge.mkdir(parents=True, exist_ok=True)
        _write_json(self.manifest_path, manifest)
        self.reports.mkdir(parents=True, exist_ok=True)
        self.report_path.write_text(self._render_report(manifest), encoding="utf-8")
        self._update_status(manifest)
        return manifest

    def _build_manifest(self, verdicts, dup_sets, collisions) -> dict:
        readiness: dict[str, int] = {}
        categories: dict[str, dict] = {}
        for v in verdicts:
            readiness[v.parser_class] = readiness.get(v.parser_class, 0) + 1
            c = categories.setdefault(v.category, {"files": 0, "corrupt": 0, "duplicates": 0})
            c["files"] += 1
            if not v.integrity_ok:
                c["corrupt"] += 1
            if v.is_duplicate:
                c["duplicates"] += 1

        corrupt = [{"path": v.path, "reason": v.corruption_reason} for v in verdicts if not v.integrity_ok]
        n = len(verdicts)
        dup_count = sum(1 for v in verdicts if v.is_duplicate)
        ready = sum(1 for v in verdicts if v.parser_class in READY_CLASSES and not v.is_duplicate)
        needs_ocr = sum(1 for v in verdicts if v.parser_class == "scanned_image" and not v.is_duplicate)
        needs_unpack = sum(1 for v in verdicts if v.parser_class == "archive" and not v.is_duplicate)
        encrypted = sum(1 for v in verdicts if v.parser_class == "encrypted")

        return {
            "version": "1.0",
            "phase": "1_repository_verification",
            "engine": "repository_verifier.py",
            "generated_at": _iso(),
            "pypdf": PYPDF_VERSION,
            "source_scope": self.source_rel,
            "source_root": str(self.source),
            "totals": {
                "total_files": n,
                "integrity_ok": sum(1 for v in verdicts if v.integrity_ok),
                "corrupt": len(corrupt),
                "duplicate_files": dup_count,
                "unique_documents": n - dup_count,
                "ready_for_parsing": ready,
                "needs_ocr": needs_ocr,
                "needs_unpack": needs_unpack,
                "encrypted": encrypted,
            },
            "parser_readiness": dict(sorted(readiness.items())),
            "category_breakdown": dict(sorted(categories.items())),
            "duplicate_sets": dup_sets,
            "filename_collisions": collisions,
            "corrupt_files": corrupt,
            "ready_for_phase2": bool(HAVE_PYPDF and n > 0),
            "entries": [asdict(v) for v in verdicts],
        }

    def _update_status(self, manifest: dict) -> None:
        status = _load_json(self.status_path, {}) or {}
        t = manifest["totals"]
        status["kie_phase1"] = {
            "at": manifest["generated_at"],
            "phase": manifest["phase"],
            "source_scope": manifest["source_scope"],
            "pypdf": manifest["pypdf"],
            "ready_for_phase2": manifest["ready_for_phase2"],
            **t,
            "parser_readiness": manifest["parser_readiness"],
        }
        _write_json(self.status_path, status)

    # -------------------------------------------------------------- reporting

    def _render_report(self, manifest: dict) -> str:
        t = manifest["totals"]
        L: list[str] = [
            "# Repository Verification Report — KIE Phase 1",
            "",
            f"_Generated: {manifest['generated_at']} · engine: repository_verifier.py · "
            f"pypdf: {manifest['pypdf'] or 'unavailable (structural checks only)'}_",
            "",
            f"**Source scope:** `{manifest['source_scope']}` (frozen JEE/NEET corpus)",
            "",
            "| Metric | Value |",
            "|---|---:|",
            f"| Total files | {t['total_files']} |",
            f"| Integrity OK | {t['integrity_ok']} |",
            f"| Corrupt | {t['corrupt']} |",
            f"| Duplicate files | {t['duplicate_files']} |",
            f"| Unique documents | {t['unique_documents']} |",
            f"| **Ready for text parsing** | **{t['ready_for_parsing']}** |",
            f"| Needs OCR (scanned) | {t['needs_ocr']} |",
            f"| Needs unpack (archives) | {t['needs_unpack']} |",
            f"| Encrypted | {t['encrypted']} |",
            "",
            "## Parser-readiness distribution",
            "",
            "| Parser class | Phase-2 strategy | Files |",
            "|---|---|---:|",
        ]
        for cls, count in manifest["parser_readiness"].items():
            L.append(f"| {cls} | {STRATEGY.get(cls, 'manual')} | {count} |")

        L += ["", "## Per-category breakdown", "",
              "| Category | Files | Corrupt | Duplicates |", "|---|---:|---:|---:|"]
        for cat, c in manifest["category_breakdown"].items():
            L.append(f"| {cat} | {c['files']} | {c['corrupt']} | {c['duplicates']} |")

        L += ["", "## Corrupt files", ""]
        if manifest["corrupt_files"]:
            L += ["| File | Reason |", "|---|---|"]
            L += [f"| {c['path']} | {c['reason']} |" for c in manifest["corrupt_files"]]
        else:
            L.append("_None — every file passed structural verification._")

        L += ["", "## Duplicate sets (exact content)", ""]
        if manifest["duplicate_sets"]:
            L += ["| Kept | Duplicates |", "|---|---|"]
            for d in manifest["duplicate_sets"]:
                L.append(f"| {d['kept']} | {', '.join(d['duplicates'])} |")
        else:
            L.append("_None._")

        if manifest["filename_collisions"]:
            L += ["", "## Filename collisions (same name, different content)", "",
                  "| Filename | Distinct contents |", "|---|---:|"]
            for fc in manifest["filename_collisions"]:
                L.append(f"| {fc['filename']} | {fc['distinct_contents']} |")

        verdict = "READY_FOR_PARSING" if manifest["ready_for_phase2"] else "NOT_READY"
        L += ["", "---", "",
              f"**Phase-1 verdict:** {verdict} — "
              f"{t['ready_for_parsing']} document(s) ready for the Phase-2 text parser, "
              f"{t['needs_ocr']} for OCR, {t['needs_unpack']} archive(s) to unpack. "
              f"Manifest: `curriculum/knowledge/repository_verification.json`.", ""]
        return "\n".join(L)


# ------------------------------------------------------------------------- CLI

def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--workspace", type=Path, default=CURRICULUM_ROOT)
    ap.add_argument("--source", default="resources/foundation",
                    help="corpus subtree to verify (relative to workspace)")
    ap.add_argument("--limit", type=int, default=None, help="verify only the first N files")
    ap.add_argument("--run", action="store_true", help="run verification (default action)")
    ap.add_argument("--report-only", action="store_true",
                    help="re-render the Markdown report from the existing manifest")
    args = ap.parse_args()

    verifier = RepositoryVerifier(args.workspace, args.source)

    if args.report_only:
        manifest = _load_json(verifier.manifest_path, None)
        if not manifest:
            print("No manifest found — run without --report-only first.", file=sys.stderr)
            return 1
        verifier.report_path.write_text(verifier._render_report(manifest), encoding="utf-8")
        print(f"Report re-rendered: {verifier.report_path}")
        return 0

    if not HAVE_PYPDF:
        print("WARNING: pypdf unavailable — parser-readiness will be 'undetermined'. "
              "Run under curriculum/.venv (see requirements.txt).", file=sys.stderr)

    manifest = verifier.run(limit=args.limit)
    t = manifest["totals"]
    print(f"Phase 1 complete: {t['total_files']} files · {t['integrity_ok']} OK · "
          f"{t['corrupt']} corrupt · {t['duplicate_files']} duplicates · "
          f"{t['ready_for_parsing']} ready-for-parsing · {t['needs_ocr']} OCR · "
          f"{t['needs_unpack']} unpack")
    print(f"Manifest: {verifier.manifest_path}")
    print(f"Report:   {verifier.report_path}")
    return 0 if manifest["ready_for_phase2"] else 2


if __name__ == "__main__":
    raise SystemExit(main())
