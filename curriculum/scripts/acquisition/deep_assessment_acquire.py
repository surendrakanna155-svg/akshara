#!/usr/bin/env python3
"""Deep assessment discovery — expanded DIKSHA + SCERT crawl → immediate download.

Legal/public only. Skips third-party aggregators (AglaSem, TeacherNews, etc.).
Streams: find URL → download → next (no batch wait).

Usage:
  deep_assessment_acquire.py [--board all|cbse|ap|telangana]
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
import urllib.request
import zlib
from collections import Counter
from pathlib import Path
from urllib.parse import urljoin

HERE = Path(__file__).resolve()
WORKSPACE_ROOT = HERE.parents[2]
SCRIPTS = HERE.parents[1]
for sub in ("common", "download", "discovery", "acquisition", "reports"):
    p = str(SCRIPTS / sub)
    if p not in sys.path:
        sys.path.insert(0, p)

from workspace import Workspace, get_engine, sanitize_filename, utcnow, write_json  # noqa: E402
import immediate_acquire  # noqa: E402
import diksha_catalogue  # noqa: E402
import fetch_papers_direct as fpd  # noqa: E402
import scert_portal_discover  # noqa: E402

LOG = WORKSPACE_ROOT / "acquisition" / "deep_assessment.log"
DIKSHA_SEARCH = diksha_catalogue.DIKSHA_SEARCH
DIKSHA_PORTAL = diksha_catalogue.DIKSHA_PORTAL

BOARD_MAP = {
    "cbse": ("CBSE", "CBSE", "cbse"),
    "ap": ("APSCERT", "State (Andhra Pradesh)", "ap"),
    "telangana": ("TSSCERT", "State (Telangana)", "telangana"),
}

# Per-subject deep queries (assessment-focused)
DEEP_QUERIES = [
    "abhyasa deepika",
    "formative assessment question paper",
    "summative assessment question paper",
    "FA1 question paper",
    "FA2 question paper",
    "SA1 question paper",
    "SA2 question paper",
    "unit test question paper",
    "CBA question paper",
    "slip test",
    "model question paper",
    "practice question paper",
    "practice questions",
    "question bank",
    "FLN assessment",
    "midline test",
    "endline test",
]

SUBJECT_QUERIES = [
    "mathematics formative",
    "science formative",
    "english formative",
    "social science formative",
    "mathematics summative",
    "science summative",
    "english summative",
    "social science summative",
]

TS_SCERT_SEEDS = [
    "https://scert.telangana.gov.in/",
    "https://scert.telangana.gov.in/pdf/publication/general/",
    "https://scert.telangana.gov.in/pdf/publication/ebooks/",
]

SKIP_NAME = re.compile(
    r"best practices while developing|teacher resource|training manual|course assessment framework",
    re.I,
)


def log(msg: str) -> None:
    line = f"[{utcnow()}] {msg}"
    print(line, flush=True)
    LOG.parent.mkdir(parents=True, exist_ok=True)
    with LOG.open("a", encoding="utf-8") as fh:
        fh.write(line + "\n")


def _diksha_post(query: str | None, filters: dict, limit: int = 40) -> list[dict]:
    body: dict = {"request": {"filters": {**filters, "status": ["Live"]}, "limit": limit}}
    if query:
        body["request"]["query"] = query
    data = json.dumps(body).encode()
    req = urllib.request.Request(
        DIKSHA_SEARCH, data=data,
        headers={"Content-Type": "application/json", "User-Agent": "AksharaCurriculumBot/1.0"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=45) as resp:
        payload = json.loads(resp.read().decode())
    return payload.get("result", {}).get("content", []) or []


def discover_diksha_deep(ws: Workspace, boards: set[str]) -> list[dict]:
    boards_cfg = ws.config("boards")["boards"]
    seen: set[str] = set()
    out: list[dict] = []

    for bkey, (bcode, diksha_board, _) in BOARD_MAP.items():
        if bcode not in boards:
            continue
        bcfg = boards_cfg[bkey]
        board_folder = bcfg["board_folder"]
        for cnum in bcfg["subjects_by_class"]:
            in_scope = set(bcfg["subjects_by_class"][cnum])
            gl = f"Class {cnum}"
            all_queries = DEEP_QUERIES + SUBJECT_QUERIES
            for query in all_queries:
                try:
                    items = _diksha_post(
                        query,
                        {"board": [diksha_board], "gradeLevel": [gl],
                         "contentType": ["PracticeResource", "TextBook"]},
                    )
                except Exception:
                    continue
                for item in items:
                    name = item.get("name") or ""
                    if SKIP_NAME.search(name):
                        continue
                    if diksha_catalogue._SKIP_NAME.search(name):
                        continue
                    kind = diksha_catalogue._doc_kind(item)
                    if not kind:
                        continue
                    category, doc_type, id_token, assessment_subtype = kind
                    # assessment lane only
                    if category == "textbook" and assessment_subtype == "":
                        if not re.search(r"practice question|cba|abhyasa", name, re.I):
                            continue
                    slug = diksha_catalogue._map_subject(item, in_scope)
                    if not slug:
                        continue
                    url = item.get("downloadUrl") or item.get("artifactUrl")
                    if not url or url in seen:
                        continue
                    seen.add(url)
                    out.append(diksha_catalogue._entry_from_item(
                        ws, board_code=bcode, board_folder=board_folder,
                        class_num=int(cnum), subject_slug=slug,
                        category=category, doc_type=doc_type, id_token=id_token,
                        assessment_subtype=assessment_subtype,
                        item=item, url=url,
                    ))
    log(f"DIKSHA deep: {len(out)} assessment candidates")
    return out


def discover_ts_scert_pdfs(ws: Workspace) -> list[dict]:
    """Crawl TS SCERT static PDF tree for FLN/assessment publications."""
    boards_cfg = ws.config("boards")["boards"]["telangana"]
    classes = ws.config("classes")["classes"]
    subjects = ws.config("subjects")["subjects"]
    cat_folder = ws.config("download_rules")["category_to_subject_folder"]
    seen_pages: set[str] = set()
    pdf_urls: set[str] = set()
    queue = list(TS_SCERT_SEEDS)

    while queue and len(seen_pages) < 60:
        url = queue.pop()
        if url in seen_pages:
            continue
        seen_pages.add(url)
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "AksharaCurriculumBot/1.0"})
            with urllib.request.urlopen(req, timeout=25) as resp:
                html = resp.read(400_000).decode("utf-8", "ignore")
        except Exception:
            continue
        for m in re.finditer(r'href=["\']([^"\']+)["\']', html, re.I):
            href = m.group(1).split("#")[0]
            full = urljoin(url, href)
            if href.lower().endswith(".pdf"):
                pdf_urls.add(full.replace("/.pdf", ".pdf").replace("/./", "/"))
            elif re.search(r"pdf|publication|ebook|fln|assessment", href, re.I):
                if "scert.telangana.gov.in" in full or href.startswith(("/", ".")):
                    if full not in seen_pages:
                        queue.append(full)

    entries: list[dict] = []
    assess_pat = re.compile(
        r"fln|midline|endline|assessment|abhyasa|formative|summative|unit|test|workbook|item.bank|practice",
        re.I,
    )
    for url in sorted(pdf_urls):
        if not assess_pat.search(url):
            continue
        title = url.rsplit("/", 1)[-1]
        # FLN / general assessment → Class_01 primary bucket
        clabel = "Class_01"
        subj = subjects["english"]
        seq = zlib.crc32(url.encode()) & 0xFFFFFF
        stem = sanitize_filename(title[:-4] if title.lower().endswith(".pdf") else title)
        fname = f"TSSCERT_{clabel}_General_Assessment-SCERT_{stem}_2025-26_v1_English.pdf"
        entries.append({
            "resource_id": f"AKS-TSSCERT-01-GEN-SCERT-{seq:06d}",
            "expected_filename": fname,
            "original_filename": title,
            "title": f"TS SCERT assessment publication — {title}",
            "document_type": "Assessment",
            "resource_category": "sample_paper",
            "board": "TSSCERT",
            "class_label": clabel,
            "subject": "General",
            "priority": "A",
            "source_portal": "https://scert.telangana.gov.in",
            "source_url": url.replace("/.pdf/publication", "/pdf/publication").replace("gov.in/.", "gov.in/"),
            "source_website": "https://scert.telangana.gov.in",
            "license_status": "OFFICIAL_PUBLIC_TS_SCERT_DIRECT",
            "license_note": "TS SCERT official publication PDF (FLN/assessment)",
            "destination": f"curriculum/telangana/{clabel}/General/{cat_folder.get('sample_paper', 'Sample_Papers')}",
            "alternative_sources": [],
            "search_locations": [url],
            "discovery_status": "URL_RESOLVED_SCERT_CRAWL",
            "status": "PENDING",
            "retry_count": 0,
            "cataloged_at": utcnow(),
            "assessment_subtype": "formative_summative",
        })
    log(f"TS SCERT crawl: {len(entries)} assessment PDFs")
    return entries


def run(ws: Workspace, *, boards: set[str]) -> dict:
    log(f"DEEP ASSESSMENT start boards={sorted(boards)}")
    engine = get_engine(ws.root)
    stats: Counter = Counter()
    processed = 0

    lanes: list[tuple[str, list[dict]]] = []
    if "CBSE" in boards:
        lanes.append(("cbse_papers", fpd.discover_cbse(ws)))
    if "TSSCERT" in boards:
        lanes.append(("ts_scert_discover", scert_portal_discover.discover(ws, "telangana")))
        lanes.append(("ts_scert_crawl", discover_ts_scert_pdfs(ws)))
    lanes.append(("diksha_deep", discover_diksha_deep(ws, boards)))

    seen_urls: set[str] = set()
    for lane_name, batch in lanes:
        n = 0
        for entry in batch:
            cat = entry.get("resource_category", "")
            if cat == "textbook" and not entry.get("assessment_subtype"):
                continue
            url = entry.get("source_url")
            if not url or url in seen_urls:
                continue
            seen_urls.add(url)
            n += 1
            processed += 1
            outcome = immediate_acquire.acquire_one(ws, entry, engine, allow_network=True)
            stats[outcome] += 1
            if outcome == "VERIFIED":
                log(f"OK {entry['board']} {entry['class_label']} {entry['subject']} "
                    f"{entry.get('assessment_subtype')} -> {entry['expected_filename']}")
        log(f"lane {lane_name}: {n} processed stats={dict(stats)}")

    import run_matrix_gap_fill as mgf  # noqa: E402
    import build_provenance  # noqa: E402
    import subject_coverage_audit  # noqa: E402
    import assessment_evidence_matrix  # noqa: E402

    extended = mgf._extend_matrix(ws)
    manifest = build_provenance.build(ws)
    write_json(ws.root / "PROVENANCE_MANIFEST.json", manifest)
    cov = subject_coverage_audit.audit(ws)
    write_json(ws.p("reports_dir") / "SUBJECT_COVERAGE_AUDIT.json", cov)
    ass = assessment_evidence_matrix.build(ws)
    write_json(ws.p("reports_dir") / "ASSESSMENT_EVIDENCE_MATRIX.json", ass)

    report = {
        "generated_at": utcnow(),
        "mode": "DEEP_ASSESSMENT",
        "boards": sorted(boards),
        "processed": processed,
        "stats": dict(stats),
        "matrix_extended": extended,
        "coverage": cov["status_counts"],
        "assessment_cells_with_evidence": ass["cells_with_any_evidence"],
    }
    write_json(ws.p("reports_dir") / "DEEP_ASSESSMENT_REPORT.json", report)
    log(f"DONE processed={processed} stats={dict(stats)} "
        f"assessment={ass['cells_with_any_evidence']}/{ass['cell_count']}")
    return report


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--workspace", type=Path, default=WORKSPACE_ROOT)
    ap.add_argument("--board", default="all", choices=["all", "cbse", "ap", "telangana"])
    args = ap.parse_args()
    boards = {"CBSE", "APSCERT", "TSSCERT"} if args.board == "all" else {BOARD_MAP[args.board][0]}
    ws = Workspace(args.workspace)
    run(ws, boards=boards)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
