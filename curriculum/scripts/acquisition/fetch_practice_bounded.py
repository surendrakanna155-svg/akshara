#!/usr/bin/env python3
"""Bounded JEE/NEET practice-resource fetcher — high-value only.

Scope: DPP, mocks, sample papers, question banks from trusted public CDNs.
Excludes: school board papers, DIKSHA, state curriculum, guide books.

Workflow: discover → probe → download → verify magic bytes → organize → log.

Usage:
  fetch_practice_bounded.py [--dry-run] [--limit N]
"""

from __future__ import annotations

import argparse
import hashlib
import re
import sys
import time
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import unquote, urljoin, urlparse

HERE = Path(__file__).resolve()
WORKSPACE = HERE.parents[2]
PRACTICE = WORKSPACE / "resources" / "foundation" / "Practice_Resources"
LOG = WORKSPACE / "acquisition" / "foundation_download.log"
EVIDENCE = WORKSPACE / "reports" / "PRACTICE_RESOURCES_EVIDENCE.md"

UA = "AksharaCurriculumBot/1.0 (+education-repository)"
DELAY = 1.5

# Trusted listing pages — public CDN links only; no auth/payment.
SOURCES: list[tuple[str, str, str]] = [
    ("motion_neet_sample", "NEET/Mock_Tests", "https://motion.ac.in/examinfo/neet-sample-papers/"),
    ("aakash_neet_mock", "NEET/Mock_Tests", "https://www.aakash.ac.in/neet-mock-test-pdf-download"),
    ("embibe_jee", "JEE_Main/Question_Banks", "https://www.embibe.com/exams/jee-main-previous-year-papers/"),
    ("motion_neet_pyq", "NEET/DPP", "https://motion.ac.in/examinfo/neet-previous-year-question-papers/"),
    ("motion_jee", "JEE_Main/Question_Banks", "https://motion.ac.in/examinfo/jee-main-previous-year-question-papers/"),
]

# Per-source cap — quality over volume.
CAP_PER_SOURCE = 12

HIGH_VALUE = re.compile(
    r"(jee|neet|main|advanced|dpp|mock|sample|question|paper|shift|physics|chemistry|"
    r"biology|maths|mathematics|botany|zoology|solution|answer)",
    re.I,
)
SKIP = re.compile(
    r"(admission|residential|csr|refund|policy|guideline|brochure|ebook|ias|cat|gate|"
    r"ncert-textbook|class-?\d{1,2}[^0-9].*textbook)",
    re.I,
)


def _iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _log(msg: str) -> None:
    line = f"[{_iso()}] {msg}"
    print(line, flush=True)
    LOG.parent.mkdir(parents=True, exist_ok=True)
    with LOG.open("a", encoding="utf-8") as fh:
        fh.write(line + "\n")


def _sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def _existing_hashes(root: Path) -> dict[str, Path]:
    out: dict[str, Path] = {}
    if not root.is_dir():
        return out
    for p in root.rglob("*.pdf"):
        try:
            out[_sha256(p)] = p
        except OSError:
            pass
    return out


def _probe_pdf(url: str) -> tuple[bool, str]:
    headers = {"User-Agent": UA, "Range": "bytes=0-7"}
    req = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            magic = resp.read(8)
            if magic.startswith(b"%PDF"):
                return True, "ok"
            return False, f"bad_magic:{magic[:4]!r}"
    except Exception as exc:  # noqa: BLE001
        return False, type(exc).__name__


def _extract_pdfs(page_url: str) -> list[str]:
    req = urllib.request.Request(page_url, headers={"User-Agent": UA})
    html = urllib.request.urlopen(req, timeout=30).read().decode("utf-8", "replace")
    links: set[str] = set()
    for m in re.finditer(r'href=["\']([^"\']+)["\']', html):
        href = m.group(1)
        if ".pdf" in href.lower():
            links.add(urljoin(page_url, href))
    for m in re.finditer(r'(https?://[^\s"\'<>]+\.pdf[^\s"\'<>]*)', html, re.I):
        links.add(m.group(1))
    return sorted(links)


def _classify(url: str, default_subdir: str) -> str:
    u = url.lower()
    if "dpp" in u:
        if "neet" in u:
            return "NEET/DPP"
        return "JEE_Main/DPP"
    if any(x in u for x in ("mock", "sample")):
        if "neet" in u:
            return "NEET/Mock_Tests"
        return "JEE_Main/Mock_Tests"
    if any(x in u for x in ("formula", "revision", "handbook", "short-notes")):
        if "neet" in u:
            return "NEET/Revision_Notes"
        return "JEE_Main/Formula_Sheets"
    return default_subdir


def _fname(url: str, source: str) -> str:
    base = unquote(urlparse(url).path.rsplit("/", 1)[-1])
    base = re.sub(r"[^\w.\- +()%]", "_", base)
    if not base.lower().endswith(".pdf"):
        base += ".pdf"
    prefix = {"motion": "Motion", "embibe": "Embibe", "aakash": "Aakash"}.get(
        source.split("_")[0], source.split("_")[0].title()
    )
    exam = "NEET" if "neet" in url.lower() else "JEE"
    if base.lower().startswith(prefix.lower()):
        return base
    return f"{prefix}_{exam}_{base}"


def _filter_urls(urls: list[str]) -> list[str]:
    out: list[str] = []
    for u in urls:
        if SKIP.search(u):
            continue
        if not HIGH_VALUE.search(u):
            continue
        out.append(u)
    return out


def _download(url: str, dest: Path) -> tuple[bool, str]:
    dest.parent.mkdir(parents=True, exist_ok=True)
    tmp = dest.with_suffix(".part")
    try:
        req = urllib.request.Request(url, headers={"User-Agent": UA})
        with urllib.request.urlopen(req, timeout=60) as resp, tmp.open("wb") as fh:
            while True:
                chunk = resp.read(1 << 16)
                if not chunk:
                    break
                fh.write(chunk)
        data = tmp.read_bytes()
        if b"%PDF" not in data[:1024]:
            tmp.unlink(missing_ok=True)
            return False, "verify_fail:not_pdf"
        tmp.rename(dest)
        return True, "ok"
    except Exception as exc:  # noqa: BLE001
        tmp.unlink(missing_ok=True)
        return False, f"fetch:{type(exc).__name__}"


def run(*, dry_run: bool, limit: int | None) -> dict:
    PRACTICE.mkdir(parents=True, exist_ok=True)
    hashes = _existing_hashes(PRACTICE)
    stats = {"discovered": 0, "ok": 0, "skip": 0, "fail": 0, "probe_fail": 0}

    _log("=== fetch_practice_bounded START ===")

    for source_id, default_sub, page_url in SOURCES:
        try:
            raw = _extract_pdfs(page_url)
        except Exception as exc:  # noqa: BLE001
            _log(f"DISCOVER_FAIL {source_id} {page_url} {type(exc).__name__}: {exc}")
            continue

        urls = _filter_urls(raw)[:CAP_PER_SOURCE]
        stats["discovered"] += len(urls)
        _log(f"DISCOVER {source_id}: {len(raw)} raw → {len(urls)} capped")

        for url in urls:
            if limit is not None and stats["ok"] >= limit:
                break

            subdir = _classify(url, default_sub)
            fname = _fname(url, source_id)
            dest = PRACTICE / subdir / fname

            if dest.is_file():
                stats["skip"] += 1
                _log(f"SKIP exists {dest.relative_to(PRACTICE)}")
                continue

            ok_probe, reason = _probe_pdf(url)
            if not ok_probe:
                stats["probe_fail"] += 1
                _log(f"PROBE_FAIL {url} {reason}")
                continue

            if dry_run:
                _log(f"WOULD_FETCH → {subdir}/{fname}")
                continue

            ok, note = _download(url, dest)
            if not ok:
                stats["fail"] += 1
                _log(f"FAIL {url} {note}")
                continue

            digest = _sha256(dest)
            if digest in hashes:
                dest.unlink(missing_ok=True)
                stats["skip"] += 1
                _log(f"SKIP dup {url}")
                continue

            hashes[digest] = dest
            stats["ok"] += 1
            _log(f"OK {dest.relative_to(WORKSPACE / 'resources' / 'foundation')}")
            time.sleep(DELAY)

    _log(f"=== fetch_practice_bounded END {stats} ===")
    return stats


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--limit", type=int, default=None, help="Max new downloads")
    args = ap.parse_args()
    stats = run(dry_run=args.dry_run, limit=args.limit)
    print("done:", stats)
    return 0 if stats["fail"] == 0 else 1


if __name__ == "__main__":
    sys.path.insert(0, str(HERE.parents[1] / "common"))
    raise SystemExit(main())
