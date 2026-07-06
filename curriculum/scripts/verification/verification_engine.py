"""Download Verification & Recovery Engine — core library.

Canonical requirement: docs/curriculum-intelligence/spec/DOWNLOAD_VERIFICATION_AND_RECOVERY_ENGINE.md

Every downloaded resource must pass checks V1-V11 before it is accepted into the
production repository (resources/). Any failure marks the download FAILED with a
machine-readable reason, records it in FAILED_DOWNLOADS.json with retry/alternative-
source bookkeeping, and (when sources are exhausted) documents the gap in
MISSING_RESOURCES.md. Nothing is ever reported successful before all checks pass.

Stdlib-only by design (reproducibility); pypdf is used automatically when importable
for deeper page parsing, otherwise deterministic structural PDF validation applies.
"""

from __future__ import annotations

import hashlib
import json
import re
import shutil
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
from pathlib import Path

try:  # optional enhancement, never a hard dependency
    from pypdf import PdfReader  # type: ignore

    HAVE_PYPDF = True
except Exception:  # pragma: no cover - environment dependent
    PdfReader = None
    HAVE_PYPDF = False


# ---------------------------------------------------------------- reason codes

class Reason:
    MISSING_FILE = "MISSING_FILE"
    NAME_MISMATCH = "NAME_MISMATCH"
    BAD_EXTENSION = "BAD_EXTENSION"
    CONTENT_TYPE_MISMATCH = "CONTENT_TYPE_MISMATCH"
    EMPTY_FILE = "EMPTY_FILE"
    TOO_SMALL = "TOO_SMALL"
    CHECKSUM_STORE_FAILED = "CHECKSUM_STORE_FAILED"
    UNREADABLE = "UNREADABLE"
    PDF_BAD_HEADER = "PDF_BAD_HEADER"
    PDF_TRUNCATED = "PDF_TRUNCATED"
    PDF_NO_PAGES = "PDF_NO_PAGES"
    PDF_PARSE_FAILED = "PDF_PARSE_FAILED"
    METADATA_FAILED = "METADATA_FAILED"
    INDEX_FAILED = "INDEX_FAILED"
    MOVE_FAILED = "MOVE_FAILED"
    DUPLICATE = "DUPLICATE"


VERIFIED = "VERIFIED"
FAILED = "FAILED"
DUPLICATE = "DUPLICATE"


@dataclass
class CheckResult:
    check_id: str
    name: str
    passed: bool
    detail: str = ""


@dataclass
class VerificationResult:
    status: str  # VERIFIED | FAILED | DUPLICATE
    resource_id: str
    checks: list[CheckResult] = field(default_factory=list)
    reason_code: str | None = None
    detail: str = ""
    sha256: str | None = None
    final_path: str | None = None

    def to_dict(self) -> dict:
        return {
            "status": self.status,
            "resource_id": self.resource_id,
            "reason_code": self.reason_code,
            "detail": self.detail,
            "sha256": self.sha256,
            "final_path": self.final_path,
            "checks": [
                {"id": c.check_id, "name": c.name, "passed": c.passed, "detail": c.detail}
                for c in self.checks
            ],
        }


def _utcnow() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _load_json(path: Path, default):
    if path.exists():
        with path.open("r", encoding="utf-8") as fh:
            return json.load(fh)
    return default


def _write_json(path: Path, data) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    with tmp.open("w", encoding="utf-8") as fh:
        json.dump(data, fh, indent=2, ensure_ascii=False)
    tmp.replace(path)


class VerificationEngine:
    """Runs V1-V11 for one resource; owns the recovery queue and the report."""

    def __init__(self, workspace_root: Path, rules: dict | None = None, paths: dict | None = None):
        self.root = Path(workspace_root)
        cfg_dir = self.root / "configs"
        self.paths = paths or _load_json(cfg_dir / "paths.json", None)
        self.rules = rules or _load_json(cfg_dir / "verification_rules.json", None)
        if self.paths is None or self.rules is None:
            raise FileNotFoundError(
                f"configs/paths.json and configs/verification_rules.json required under {self.root}"
            )

    # ------------------------------------------------------------ path helpers

    def _p(self, key: str) -> Path:
        return self.root / self.paths[key]

    def _pm(self, key: str) -> Path:
        return self.root / self.paths["pm_files"][key]

    def _index(self, key: str) -> Path:
        return self._p("indexes_dir") / self.paths["index_files"][key]

    def _report(self, key: str) -> Path:
        return self._p("reports_dir") / self.paths["report_files"][key]

    # -------------------------------------------------------------- main entry

    def verify_resource(self, expected: dict, file_path: Path) -> VerificationResult:
        """Run all checks for one downloaded file described by `expected`.

        expected requires: resource_id, expected_filename, document_type, board,
        class_label, subject, source_url, destination (relative to resources_dir).
        """
        rid = expected.get("resource_id", "UNKNOWN")
        res = VerificationResult(status=FAILED, resource_id=rid)
        file_path = Path(file_path)

        def fail(code: str, detail: str) -> VerificationResult:
            res.reason_code, res.detail = code, detail
            self._record_failure(expected, res, file_path)
            return res

        # V1 exists
        ok = file_path.is_file()
        res.checks.append(CheckResult("V1", "file exists", ok, str(file_path)))
        if not ok:
            return fail(Reason.MISSING_FILE, f"not found: {file_path}")

        # V2 filename
        expected_name = expected.get("expected_filename") or file_path.name
        pattern_ok = re.match(self.rules["filename_pattern"], file_path.name) is not None
        name_ok = file_path.name == expected_name and pattern_ok
        res.checks.append(CheckResult("V2", "filename matches expectation + standard", name_ok,
                                      f"actual={file_path.name} expected={expected_name}"))
        if not name_ok:
            return fail(Reason.NAME_MISMATCH, f"actual={file_path.name} expected={expected_name}")

        # V3 extension + content sniff
        ext = file_path.suffix.lower().lstrip(".")
        ext_ok = ext in self.rules["allowed_extensions"]
        head = self._read_head(file_path, 4096)
        sniff_ok, sniff_detail = self._content_matches_extension(ext, head)
        res.checks.append(CheckResult("V3", "extension allowed + content matches", ext_ok and sniff_ok,
                                      f"ext={ext} sniff={sniff_detail}"))
        if not ext_ok:
            return fail(Reason.BAD_EXTENSION, f"extension .{ext} not in allowed list")
        if not sniff_ok:
            return fail(Reason.CONTENT_TYPE_MISMATCH, sniff_detail)

        # V4 size sanity
        size = file_path.stat().st_size
        floor = self.rules["min_size_bytes"].get(ext, self.rules["min_size_bytes"]["default"])
        res.checks.append(CheckResult("V4", "size reasonable", size >= floor, f"{size}B (floor {floor}B)"))
        if size == 0:
            return fail(Reason.EMPTY_FILE, "0 bytes")
        if size < floor:
            return fail(Reason.TOO_SMALL, f"{size}B below floor {floor}B for .{ext}")

        # V5 checksum
        sha = self._sha256(file_path)
        res.sha256 = sha
        res.checks.append(CheckResult("V5", "sha256 generated", True, sha[:16] + "…"))

        # duplicate check (before any store/move)
        checksum_index = _load_json(self._index("checksum"), {})
        if sha in checksum_index:
            res.status = DUPLICATE
            res.reason_code = Reason.DUPLICATE
            res.detail = f"identical to {checksum_index[sha]['resource_id']}"
            res.checks.append(CheckResult("DUP", "duplicate content diverted", True, res.detail))
            self._divert_duplicate(expected, file_path, sha, checksum_index[sha])
            return res

        # V6 checksum storable (write + read-back)
        try:
            checksum_index[sha] = {"resource_id": rid, "recorded_at": _utcnow()}
            _write_json(self._index("checksum"), checksum_index)
            stored = _load_json(self._index("checksum"), {}).get(sha, {}).get("resource_id")
            ok = stored == rid
        except OSError as exc:
            ok = False
            res.checks.append(CheckResult("V6", "checksum stored", False, str(exc)))
            return fail(Reason.CHECKSUM_STORE_FAILED, str(exc))
        res.checks.append(CheckResult("V6", "checksum stored + read back", ok, ""))
        if not ok:
            return fail(Reason.CHECKSUM_STORE_FAILED, "read-back mismatch")

        # V7 openable
        try:
            with file_path.open("rb") as fh:
                fh.read(1024)
                fh.seek(-min(1024, size), 2)
                fh.read(1024)
            res.checks.append(CheckResult("V7", "file opens (head+tail probe)", True, ""))
        except OSError as exc:
            res.checks.append(CheckResult("V7", "file opens", False, str(exc)))
            return fail(Reason.UNREADABLE, str(exc))

        # V8 PDF deep checks
        if ext == "pdf":
            code, detail, sub = self._verify_pdf(file_path)
            res.checks.extend(sub)
            if code:
                return fail(code, detail)

        # V9 metadata
        try:
            meta = self._build_metadata(expected, file_path, sha, size, ext)
            missing = [f for f in self.rules["metadata_required_fields"] if not meta.get(f)]
            if missing:
                res.checks.append(CheckResult("V9", "metadata complete", False, f"missing {missing}"))
                return fail(Reason.METADATA_FAILED, f"missing fields: {missing}")
            meta_path = self._p("metadata_resources_dir") / f"{expected_name}.metadata.json"
            _write_json(meta_path, meta)
            res.checks.append(CheckResult("V9", "metadata generated", True, str(meta_path.name)))
        except OSError as exc:
            return fail(Reason.METADATA_FAILED, str(exc))

        # V10 indexed (master + download) with read-back
        try:
            self._index_resource(rid, expected, meta, sha)
            master = _load_json(self._index("master"), {})
            ok = rid in master
            res.checks.append(CheckResult("V10", "indexed (master+download, read back)", ok, ""))
            if not ok:
                return fail(Reason.INDEX_FAILED, "master index read-back missing entry")
        except OSError as exc:
            return fail(Reason.INDEX_FAILED, str(exc))

        # V11 move to production repository + post-move checksum
        try:
            dest = self._p("resources_dir") / expected["destination"] / expected_name
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.move(str(file_path), str(dest))
            if self._sha256(dest) != sha:
                res.checks.append(CheckResult("V11", "moved + checksum re-verified", False, "post-move hash mismatch"))
                return fail(Reason.MOVE_FAILED, "post-move checksum mismatch")
            res.checks.append(CheckResult("V11", "moved to repository + re-verified", True, str(dest)))
            res.final_path = str(dest)
        except (OSError, KeyError) as exc:
            return fail(Reason.MOVE_FAILED, str(exc))

        # success bookkeeping
        res.status = VERIFIED
        self._update_master_status(rid, "VERIFIED", str(res.final_path))
        self._record_completed(expected, res, size)
        self._clear_failure(expected)
        return res

    # ---------------------------------------------------------------- checks

    @staticmethod
    def _read_head(path: Path, n: int) -> bytes:
        with path.open("rb") as fh:
            return fh.read(n)

    def _content_matches_extension(self, ext: str, head: bytes) -> tuple[bool, str]:
        if not head:
            return True, "empty content (classified by size check)"
        magic = self.rules["magic_bytes"]
        lowered = head[:512].lower()
        looks_html = any(sig.encode() in lowered for sig in self.rules["html_error_signatures"])
        if ext == "pdf":
            if head.startswith(bytes.fromhex(magic["pdf"])):
                return True, "pdf magic ok"
            if looks_html:
                return False, "HTML content masquerading as .pdf (error page?)"
            return False, "no %PDF magic"
        if ext in ("docx", "epub", "zip"):
            if head.startswith(bytes.fromhex(magic["zip_family"])):
                return True, "zip-family magic ok"
            return False, f"no zip magic for .{ext}"
        if ext == "doc":
            if head.startswith(bytes.fromhex(magic["doc_ole"])):
                return True, "ole magic ok"
            return False, "no OLE magic for .doc"
        if ext == "html":
            return True, "html accepted"
        return True, "no sniff rule"

    def _verify_pdf(self, path: Path) -> tuple[str | None, str, list[CheckResult]]:
        """Return (reason_code|None, detail, sub-checks). Deterministic first, pypdf extra."""
        checks: list[CheckResult] = []
        rules = self.rules["pdf"]
        data_head = self._read_head(path, 1024)
        size = path.stat().st_size
        with path.open("rb") as fh:
            fh.seek(max(0, size - rules["eof_scan_window_bytes"]))
            tail = fh.read()

        # header
        ok = data_head.startswith(b"%PDF-")
        checks.append(CheckResult("V8a", "pdf header", ok, data_head[:8].decode("latin-1", "replace")))
        if not ok:
            return Reason.PDF_BAD_HEADER, "missing %PDF- header", checks

        # EOF marker → truncation/partial download detection
        ok = (b"%%EOF" in tail) or not rules["require_eof_marker"]
        checks.append(CheckResult("V8b", "pdf %%EOF marker present", ok, ""))
        if not ok:
            return Reason.PDF_TRUNCATED, "no %%EOF in tail window (partial download?)", checks

        # startxref integrity
        if rules["require_startxref"]:
            m = re.findall(rb"startxref\s+(\d+)", tail)
            ok = bool(m) and 0 <= int(m[-1]) < size
            checks.append(CheckResult("V8c", "startxref offset valid", ok,
                                      f"offset={m[-1].decode() if m else 'absent'}"))
            if not ok:
                return Reason.PDF_TRUNCATED, "startxref missing or out of range", checks

        # page count + parse
        if HAVE_PYPDF:
            try:
                reader = PdfReader(str(path))
                pages = len(reader.pages)
                checks.append(CheckResult("V8d", "page count (pypdf)", pages >= rules["min_pages"], str(pages)))
                if pages < rules["min_pages"]:
                    return Reason.PDF_NO_PAGES, f"page count {pages}", checks
                sample = min(pages, rules["parse_sample_pages"])
                for i in range(sample):
                    reader.pages[i].extract_text()
                checks.append(CheckResult("V8e", "pages parse (pypdf sample)", True, f"{sample} pages"))
            except Exception as exc:  # pypdf raises many types
                checks.append(CheckResult("V8d", "pdf parse (pypdf)", False, str(exc)))
                return Reason.PDF_PARSE_FAILED, f"pypdf: {exc}", checks
        else:
            body = path.read_bytes()
            page_objs = len(re.findall(rb"/Type\s*/Page(?![s/])", body))
            counts = [int(c) for c in re.findall(rb"/Count\s+(\d+)", body)]
            pages = max([page_objs] + counts) if (page_objs or counts) else 0
            ok = pages >= rules["min_pages"]
            checks.append(CheckResult("V8d", "page count (structural)", ok, f"{pages} (pypdf unavailable)"))
            if not ok:
                return Reason.PDF_NO_PAGES, "no /Page objects found", checks
            has_root = b"/Root" in body or b"/Catalog" in body
            checks.append(CheckResult("V8e", "document catalog present (structural)", has_root, ""))
            if not has_root:
                return Reason.PDF_PARSE_FAILED, "no /Root or /Catalog object", checks
        return None, "", checks

    # ------------------------------------------------------------- persistence

    @staticmethod
    def _sha256(path: Path) -> str:
        h = hashlib.sha256()
        with path.open("rb") as fh:
            for chunk in iter(lambda: fh.read(1 << 20), b""):
                h.update(chunk)
        return h.hexdigest()

    def _build_metadata(self, expected: dict, path: Path, sha: str, size: int, ext: str) -> dict:
        now = _utcnow()
        return {
            "resource_id": expected.get("resource_id"),
            "original_filename": expected.get("original_filename", path.name),
            "repository_filename": path.name,
            "board": expected.get("board"),
            "class_label": expected.get("class_label"),
            "subject": expected.get("subject"),
            "document_type": expected.get("document_type"),
            "language": expected.get("language", "English"),
            "medium": expected.get("medium", "English"),
            "publisher": expected.get("publisher", ""),
            "academic_year": expected.get("academic_year", ""),
            "source_website": expected.get("source_website", ""),
            "source_url": expected.get("source_url"),
            "license_status": expected.get("license_status", "PENDING_VERIFICATION"),
            "download_timestamp": expected.get("download_timestamp", now),
            "verification_timestamp": now,
            "checksum_sha256": sha,
            "file_size_bytes": size,
            "file_format": ext,
            "storage_path": str(Path(self.paths["resources_dir"]) / expected.get("destination", "") / path.name),
            "document_status": "VERIFIED",
            "verification_status": "VERIFIED",
            "processing_status": "READY_FOR_EXTRACTION",
        }

    def _index_resource(self, rid: str, expected: dict, meta: dict, sha: str) -> None:
        master = _load_json(self._index("master"), {})
        master[rid] = {
            "title": expected.get("title", expected.get("expected_filename")),
            "board": expected.get("board"),
            "class_label": expected.get("class_label"),
            "subject": expected.get("subject"),
            "document_type": expected.get("document_type"),
            "repository_path": meta["storage_path"],
            "metadata_path": str(Path(self.paths["metadata_resources_dir"]) / f"{meta['repository_filename']}.metadata.json"),
            "checksum_sha256": sha,
            "verification_status": "PENDING_MOVE",
            "indexed_at": _utcnow(),
        }
        _write_json(self._index("master"), master)
        dl = _load_json(self._index("download"), {})
        dl[rid] = {"source_url": expected.get("source_url"), "sha256": sha, "verified_at": _utcnow()}
        _write_json(self._index("download"), dl)

    def _update_master_status(self, rid: str, status: str, final_path: str) -> None:
        master = _load_json(self._index("master"), {})
        if rid in master:
            master[rid]["verification_status"] = status
            master[rid]["repository_path"] = final_path
            _write_json(self._index("master"), master)

    def _divert_duplicate(self, expected: dict, path: Path, sha: str, original: dict) -> None:
        dup_dir = self._p("downloads_duplicates")
        dup_dir.mkdir(parents=True, exist_ok=True)
        shutil.move(str(path), str(dup_dir / path.name))
        dmap = _load_json(self._index("duplicates"), {})
        dmap.setdefault(sha, {"kept_resource_id": original["resource_id"], "duplicates": []})
        dmap[sha]["duplicates"].append({
            "resource_id": expected.get("resource_id"),
            "filename": path.name,
            "source_url": expected.get("source_url"),
            "recorded_at": _utcnow(),
        })
        _write_json(self._index("duplicates"), dmap)

    # --------------------------------------------------- recovery-queue side

    def _record_failure(self, expected: dict, res: VerificationResult, file_path: Path) -> None:
        failed = _load_json(self._pm("failed_downloads"), [])
        rid = expected.get("resource_id")
        entry = next((e for e in failed if e.get("resource_id") == rid), None)
        backoffs = self.rules["retry_policy"]["backoff_minutes"]
        if entry is None:
            entry = {"resource_id": rid, "url": expected.get("source_url"), "retry_count": 0,
                     "alternative_sources": expected.get("alternative_sources", []),
                     "alternative_sources_used": 0, "http_status": expected.get("http_status")}
            failed.append(entry)
        entry["retry_count"] = entry.get("retry_count", 0) + 1
        entry["failure_reason"] = res.reason_code
        entry["failure_detail"] = res.detail
        entry["last_attempt"] = _utcnow()
        wait = backoffs[min(entry["retry_count"] - 1, len(backoffs) - 1)]
        entry["next_retry"] = (datetime.now(timezone.utc) + timedelta(minutes=wait)).strftime("%Y-%m-%dT%H:%M:%SZ")
        entry["status"] = "RETRY_PENDING"
        _write_json(self._pm("failed_downloads"), failed)
        # preserve the bad artifact for forensics
        if file_path.is_file():
            fail_dir = self._p("downloads_failed")
            fail_dir.mkdir(parents=True, exist_ok=True)
            shutil.move(str(file_path), str(fail_dir / f"{rid}__{file_path.name}"))

    def _clear_failure(self, expected: dict) -> None:
        failed = _load_json(self._pm("failed_downloads"), [])
        rid = expected.get("resource_id")
        kept = [e for e in failed if e.get("resource_id") != rid]
        recovered = len(kept) != len(failed)
        if recovered:
            _write_json(self._pm("failed_downloads"), kept)

    def next_recovery_action(self, resource_id: str) -> dict:
        """What the acquisition lane should do next for a failed resource.

        Returns {action: RETRY|TRY_ALTERNATIVE|RECORD_MISSING, ...}. The engine
        never downloads; it directs the downloader (CI-A waves) deterministically.
        """
        failed = _load_json(self._pm("failed_downloads"), [])
        entry = next((e for e in failed if e.get("resource_id") == resource_id), None)
        if entry is None:
            return {"action": "NONE"}
        max_r = self.rules["retry_policy"]["max_retries_per_source"]
        if entry["retry_count"] < max_r:
            return {"action": "RETRY", "url": entry["url"], "after": entry["next_retry"]}
        alts = entry.get("alternative_sources", [])
        used = entry.get("alternative_sources_used", 0)
        if used < len(alts):
            entry["alternative_sources_used"] = used + 1
            entry["retry_count"] = 0
            entry["url"] = alts[used]
            entry["status"] = "TRYING_ALTERNATIVE"
            _write_json(self._pm("failed_downloads"), failed)
            return {"action": "TRY_ALTERNATIVE", "url": alts[used]}
        entry["status"] = self.rules["retry_policy"]["exhausted_status"]
        _write_json(self._pm("failed_downloads"), failed)
        return {"action": "RECORD_MISSING"}

    def record_missing(self, expected: dict, search_locations: list[str], reason: str) -> None:
        md = self._pm("missing_resources")
        md.parent.mkdir(parents=True, exist_ok=True)
        header = "" if md.exists() else "# Missing Resources\n\nResources unavailable after exhausting official/trusted sources.\n"
        with md.open("a", encoding="utf-8") as fh:
            fh.write(header)
            fh.write(
                f"\n## {expected.get('resource_id')}\n"
                f"- **Board:** {expected.get('board')} · **Class:** {expected.get('class_label')} · **Subject:** {expected.get('subject')}\n"
                f"- **Expected resource:** {expected.get('document_type')} — {expected.get('expected_filename')}\n"
                f"- **Search locations:** {', '.join(search_locations) if search_locations else '(recorded in discovery log)'}\n"
                f"- **Reason not available:** {reason}\n"
                f"- **Recommendation:** re-check next academic cycle; monitor official portal.\n"
                f"- **Recorded:** {_utcnow()}\n"
            )

    def _record_completed(self, expected: dict, res: VerificationResult, size: int) -> None:
        completed = _load_json(self._pm("completed_downloads"), [])
        completed.append({
            "resource_id": res.resource_id,
            "original_url": expected.get("source_url"),
            "destination_path": res.final_path,
            "file_size_bytes": size,
            "checksum_sha256": res.sha256,
            "download_time": expected.get("download_timestamp", ""),
            "verification_status": "VERIFIED",
            "metadata_status": "GENERATED",
            "verified_at": _utcnow(),
        })
        _write_json(self._pm("completed_downloads"), completed)

    # ------------------------------------------------------------------ report

    def generate_report(self) -> Path:
        queue = _load_json(self._pm("download_queue"), [])
        completed = _load_json(self._pm("completed_downloads"), [])
        failed = _load_json(self._pm("failed_downloads"), [])
        dmap = _load_json(self._index("duplicates"), {})

        expected = len(queue) if queue else len(completed) + len(failed)
        verified = len(completed)
        corrupted = sum(1 for e in failed if e.get("failure_reason", "").startswith("PDF_")
                        or e.get("failure_reason") in (Reason.UNREADABLE, Reason.CONTENT_TYPE_MISMATCH))
        empty = sum(1 for e in failed if e.get("failure_reason") in (Reason.EMPTY_FILE, Reason.TOO_SMALL))
        duplicates = sum(len(v.get("duplicates", [])) for v in dmap.values())
        retried = sum(max(0, e.get("retry_count", 0) - 1) + e.get("alternative_sources_used", 0) * 1 for e in failed)
        alternatives_used = sum(e.get("alternative_sources_used", 0) for e in failed)
        missing = sum(1 for e in failed if e.get("status") == self.rules["retry_policy"]["exhausted_status"])

        if expected > 0:
            w = self.rules["health_score_weights"]
            score = 100.0 * (
                w["verified_ratio"] * (verified / expected)
                + w["corruption_cleanliness"] * (1 - corrupted / expected)
                + w["empty_cleanliness"] * (1 - empty / expected)
                + w["missing_cleanliness"] * (1 - missing / expected)
            )
            score_str = f"{score:.1f} / 100"
        else:
            score_str = "N/A (no expected files yet)"

        lines = [
            "# Download Verification Report",
            "",
            f"_Generated: {_utcnow()} · engine: verification_engine.py · pypdf: {'yes' if HAVE_PYPDF else 'no (structural PDF checks)'}_",
            "",
            "| Metric | Value |",
            "|---|---|",
            f"| Total Expected Files | {expected} |",
            f"| Successfully Verified | {verified} |",
            f"| Corrupted Files | {corrupted} |",
            f"| Empty / Too-Small Files | {empty} |",
            f"| Duplicate Files | {duplicates} |",
            f"| Retried Downloads | {retried} |",
            f"| Alternative Sources Used | {alternatives_used} |",
            f"| Remaining Missing Resources | {missing} |",
            f"| **Overall Download Health Score** | **{score_str}** |",
            "",
            "## Outstanding failures",
            "",
        ]
        if failed:
            lines.append("| Resource | Reason | Retries | Status | Next retry |")
            lines.append("|---|---|---|---|---|")
            for e in failed:
                lines.append(
                    f"| {e.get('resource_id')} | {e.get('failure_reason')} — {e.get('failure_detail','')[:80]} "
                    f"| {e.get('retry_count')} | {e.get('status')} | {e.get('next_retry','—')} |")
        else:
            lines.append("_None._")
        report = self._report("download_verification")
        report.parent.mkdir(parents=True, exist_ok=True)
        report.write_text("\n".join(lines) + "\n", encoding="utf-8")
        return report
