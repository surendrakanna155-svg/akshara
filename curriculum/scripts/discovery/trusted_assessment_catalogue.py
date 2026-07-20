#!/usr/bin/env python3
"""Trusted third-party assessment discovery — controlled provenance expansion.

Official-first policy unchanged. This catalogue runs ONLY for assessment evidence
(sample papers, FA/SA, unit tests, model papers, etc.) when official paths are
exhausted. Every entry carries provenance_tier=TRUSTED_THIRD_PARTY and is stored
under Trusted_Third_Party_Assessment/ — never mixed with official folders.

Usage:
  trusted_assessment_catalogue.py [--workspace DIR] [--board ap|cbse|telangana|all]
                                  [--inspect] [--to-queue]
"""
from __future__ import annotations

import argparse
import re
import sys
import time
import urllib.request
import zlib
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from urllib.parse import urljoin

HERE = Path(__file__).resolve()
SCRIPTS = HERE.parents[1]
sys.path.insert(0, str(SCRIPTS / "common"))
from workspace import Workspace, load_json, sanitize_filename, utcnow, write_json  # noqa: E402
from provenance_tier import TIER_TRUSTED_THIRD_PARTY  # noqa: E402

WORKSPACE_ROOT = HERE.parents[2]

AGLASEM_SCHOOLS = "https://schools.aglasem.com"
AGLASEM_DOCS_DL = "https://docs.aglasem.com/product/single-doc-download/{uuid}?title={board_tag}"

ORDINAL = {
    1: "1st", 2: "2nd", 3: "3rd", 4: "4th", 5: "5th",
    6: "6th", 7: "7th", 8: "8th", 9: "9th", 10: "10th",
}

BOARD_META = {
    "ap": ("APSCERT", "ap", "AP"),
    "telangana": ("TSSCERT", "telangana", "TS"),
    "cbse": ("CBSE", "cbse", "CBSE"),
}

SUBJECT_SLUG_MAP: dict[str, str] = {
    "english": "english",
    "maths": "mathematics",
    "mathematics": "mathematics",
    "math": "mathematics",
    "science": "science",
    "social-studies": "social_science",
    "social-science": "social_science",
    "social": "social_science",
}

ASSESSMENT_FROM_SLUG: dict[str, str] = {
    "fa1": "fa1", "fa2": "fa2", "fa3": "fa3", "fa4": "fa4",
    "sa1": "sa1", "sa2": "sa2", "sa3": "sa3",
    "sample-paper": "sample_paper", "sample-papers": "sample_paper",
    "model-paper": "model_paper", "model-papers": "model_paper",
    "previous-year": "previous_paper", "question-paper": "other_assessment",
    "unit-test": "unit_test",
}

DOC_UUID_RE = re.compile(
    r"single-doc-download/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})",
    re.I,
)
HREF_RE = re.compile(r'href=["\']([^"\']+)["\']', re.I)


def _fetch(url: str, *, delay: float = 0.0) -> str:
    req = urllib.request.Request(url, headers={"User-Agent": "AksharaCurriculumBot/1.0 (+education-repository)"})
    with urllib.request.urlopen(req, timeout=45) as resp:
        data = resp.read(800_000).decode("utf-8", "ignore")
    time.sleep(delay)
    return data


LOW_CLASS_SUBJECT_SLUG = {
    "english": "english",
    "mathematics": "maths",
    "science": "science",
    "social_science": "social-studies",
}

HIGH_CLASS_SUBJECT_SLUG = {
    "english": "english",
    "mathematics": "maths",
    "science": "science",
    "social_science": "social-studies",
}


def _ap_page_url(class_num: int, exam: str, subject_key: str) -> str | None:
    slug = (
        LOW_CLASS_SUBJECT_SLUG.get(subject_key)
        if class_num <= 5
        else HIGH_CLASS_SUBJECT_SLUG.get(subject_key)
    )
    if not slug:
        return None
    ord_ = ORDINAL[class_num]
    # AglaSem uses two URL families for AP:
    #   FA1 (6–10): ap-6th-fa1-question-paper-english/
    #   FA2 (6–10): ap-8th-class-fa2-english-question-paper/  (class-* pattern)
    #   FA2 (1–5):  ap-1st-class-fa2-english-question-paper/
    if class_num <= 5 or exam == "fa2":
        return f"{AGLASEM_SCHOOLS}/ap-{ord_}-class-{exam}-{slug}-question-paper/"
    return f"{AGLASEM_SCHOOLS}/ap-{ord_}-{exam}-question-paper-{slug}/"


def _ap_direct_targets(ws: Workspace) -> list[tuple[str, int, str, str]]:
    """(page_url, class_num, exam, subject_key) — no index crawl."""
    boards = ws.config("boards")["boards"]["ap"]
    targets: list[tuple[str, int, str, str]] = []
    for class_num in range(1, 11):
        ckey = str(class_num)
        subjects = boards["subjects_by_class"].get(ckey, [])
        exams = ("fa2",) if class_num <= 5 else ("fa1", "fa2")
        for exam in exams:
            for sk in subjects:
                url = _ap_page_url(class_num, exam, sk)
                if url:
                    targets.append((url, class_num, exam, sk))
    return targets


def _entry_from_page(
    ws: Workspace,
    page_url: str,
    *,
    board_code: str,
    board_folder: str,
    board_tag: str,
    class_num: int,
    subject_key: str,
    assessment_subtype: str,
    cfg: dict,
    publisher: str,
) -> dict | None:
    try:
        req = urllib.request.Request(page_url, headers={"User-Agent": "AksharaCurriculumBot/1.0"})
        with urllib.request.urlopen(req, timeout=20) as resp:
            html = resp.read(400_000).decode("utf-8", "ignore")
    except Exception:
        return None
    uuids = _extract_doc_ids(html)
    if not uuids:
        return None
    return _make_entry(
        ws,
        board_code=board_code,
        board_folder=board_folder,
        board_tag=board_tag,
        class_num=class_num,
        subject_key=subject_key,
        assessment_subtype=assessment_subtype,
        doc_uuid=uuids[0],
        page_url=page_url,
        cfg=cfg,
        publisher=publisher,
    )


def discover_ap_parallel(ws: Workspace, *, workers: int = 8) -> list[dict]:
    """Fast AP path: direct subject URLs + parallel page probe (no index crawl)."""
    cfg = ws.config("trusted_assessment_sources")
    publisher = cfg["allowed_domains"][0]["publisher"]
    board_code, board_folder, board_tag = BOARD_META["ap"]
    targets = _ap_direct_targets(ws)
    entries: list[dict] = []
    seen: set[str] = set()

    def _work(item: tuple[str, int, str, str]) -> dict | None:
        url, class_num, exam, sk = item
        return _entry_from_page(
            ws, url,
            board_code=board_code, board_folder=board_folder, board_tag=board_tag,
            class_num=class_num, subject_key=sk, assessment_subtype=exam,
            cfg=cfg, publisher=publisher,
        )

    with ThreadPoolExecutor(max_workers=workers) as pool:
        futures = {pool.submit(_work, t): t for t in targets}
        for fut in as_completed(futures):
            entry = fut.result()
            if entry and entry["source_url"] not in seen:
                seen.add(entry["source_url"])
                entries.append(entry)
    return entries


CBSE_PYQ_SUBJECT_SLUG = {
    "english": ["english-communicative", "english-language-and-literature", "english"],
    "mathematics": ["maths-basic", "maths-standard", "mathematics", "maths"],
    "science": ["science"],
    "social_science": ["social-science", "social-science"],
}


def _cbse_pyq_page_url(class_num: int, subject_key: str, slug: str) -> str:
    return f"{AGLASEM_SCHOOLS}/cbse-question-paper-class-{class_num}-{slug}/"


def discover_cbse_pyq_parallel(ws: Workspace, *, workers: int = 8) -> list[dict]:
    """CBSE previous-year question papers from AglaSem class hubs."""
    cfg = ws.config("trusted_assessment_sources")
    publisher = cfg["allowed_domains"][0]["publisher"]
    board_code, board_folder, board_tag = BOARD_META["cbse"]
    boards = ws.config("boards")["boards"]["cbse"]
    targets: list[tuple[str, int, str]] = []

    for class_num in range(6, 11):
        ckey = str(class_num)
        hub = f"{AGLASEM_SCHOOLS}/cbse-class-{class_num}-question-paper/"
        try:
            req = urllib.request.Request(hub, headers={"User-Agent": "AksharaCurriculumBot/1.0"})
            with urllib.request.urlopen(req, timeout=20) as resp:
                html = resp.read(500_000).decode("utf-8", "ignore")
        except Exception:
            continue
        for sk in boards["subjects_by_class"].get(ckey, []):
            for slug in CBSE_PYQ_SUBJECT_SLUG.get(sk, [sk.replace("_", "-")]):
                candidate = _cbse_pyq_page_url(class_num, sk, slug)
                if candidate.split("/")[-2] in html or slug in html:
                    targets.append((candidate, class_num, sk))
                    break
            else:
                # fallback: scan hub links for subject match
                for href in HREF_RE.findall(html):
                    if not href.startswith("http"):
                        href = urljoin(hub, href)
                    slug_part = href.rstrip("/").split("/")[-1]
                    if f"class-{class_num}" not in slug_part:
                        continue
                    if any(tok in slug_part for tok in CBSE_PYQ_SUBJECT_SLUG.get(sk, [sk.split("_")[0]])):
                        targets.append((href if href.endswith("/") else href + "/", class_num, sk))
                        break

    entries: list[dict] = []
    seen: set[str] = set()

    def _work(item: tuple[str, int, str]) -> dict | None:
        url, class_num, sk = item
        return _entry_from_page(
            ws, url,
            board_code=board_code, board_folder=board_folder, board_tag=board_tag,
            class_num=class_num, subject_key=sk, assessment_subtype="previous_paper",
            cfg=cfg, publisher=publisher,
        )

    with ThreadPoolExecutor(max_workers=workers) as pool:
        for entry in (fut.result() for fut in as_completed(pool.submit(_work, t) for t in targets)):
            if entry and entry["source_url"] not in seen:
                seen.add(entry["source_url"])
                entries.append(entry)
    return entries


def discover_all_parallel(ws: Workspace, *, boards: set[str], workers: int = 8) -> list[dict]:
    """Combined fast discovery for AP + CBSE PYQ."""
    by_url: dict[str, dict] = {}
    if "ap" in boards:
        for e in discover_ap_parallel(ws, workers=workers):
            by_url[e["source_url"]] = e
    if "cbse" in boards:
        for e in discover_cbse_pyq_parallel(ws, workers=workers):
            by_url[e["source_url"]] = e
    return list(by_url.values())


def _allowed_url(url: str, cfg: dict) -> bool:
    low = url.lower()
    for pat in cfg.get("excluded_patterns", []):
        if pat in low:
            return False
    for dom in cfg.get("excluded_domains", []):
        if dom in low:
            return False
    for src in cfg.get("allowed_domains", []):
        if src["domain"] in low or src.get("cdn_domain", "") in low:
            return True
    return False


def _extract_doc_ids(html: str) -> list[str]:
    return list(dict.fromkeys(DOC_UUID_RE.findall(html)))


def _subject_in_scope(ws: Workspace, board_key: str, class_num: int, subject_key: str) -> bool:
    boards = ws.config("boards")["boards"]
    ckey = str(class_num)
    return subject_key in boards[board_key]["subjects_by_class"].get(ckey, [])


def _board_key_from_code(board_code: str) -> str:
    for k, (code, _, _) in BOARD_META.items():
        if code == board_code:
            return k
    return "ap"


def _make_entry(
    ws: Workspace,
    *,
    board_code: str,
    board_folder: str,
    board_tag: str,
    class_num: int,
    subject_key: str,
    assessment_subtype: str,
    doc_uuid: str,
    page_url: str,
    cfg: dict,
    publisher: str,
) -> dict | None:
    if not _subject_in_scope(ws, _board_key_from_code(board_code), class_num, subject_key):
        return None

    classes = ws.config("classes")["classes"]
    subjects = ws.config("subjects")["subjects"]
    cinfo = classes[str(class_num)]
    subj = subjects[subject_key]
    clabel = cinfo["class_label"]
    ccode = cinfo["code"]

    dl_url = AGLASEM_DOCS_DL.format(uuid=doc_uuid, board_tag=board_tag)
    if not _allowed_url(dl_url, cfg) or not _allowed_url(page_url, cfg):
        return None

    seq = zlib.crc32(doc_uuid.encode()) % 900_000
    rid = f"AKS-{board_code}-T3P-{ccode}-{subj['code']}-{assessment_subtype.upper()}-{seq:06d}"
    fname = (
        f"{cfg['filename_prefix']}_{board_code}_{clabel}_{subj['subject_folder']}_"
        f"{assessment_subtype}_{doc_uuid[:8]}.pdf"
    )
    storage = cfg["storage_folder"]
    note = cfg["license_note_template"].format(publisher=publisher, source_page_url=page_url)

    return {
        "resource_id": rid,
        "expected_filename": sanitize_filename(fname),
        "original_filename": f"{doc_uuid}.pdf",
        "title": (
            f"[T3P] {board_code} {clabel.replace('_', ' ')} {subj['display']} "
            f"{assessment_subtype.replace('_', ' ').upper()} — AglaSem"
        ),
        "document_type": "Sample Paper" if assessment_subtype in ("sample_paper", "model_paper") else "Question Bank",
        "resource_category": "sample_paper",
        "assessment_subtype": assessment_subtype,
        "provenance_tier": cfg["provenance_tier"],
        "board": board_code,
        "class_label": clabel,
        "subject": subj["display"],
        "subject_key": subject_key,
        "priority": "A",
        "source_portal": page_url,
        "source_page_url": page_url,
        "source_url": dl_url,
        "source_website": AGLASEM_SCHOOLS,
        "publisher": publisher,
        "academic_year": "2024-25",
        "language": "English",
        "license_status": cfg["license_status"],
        "license_note": note,
        "destination": f"curriculum/{board_folder}/{clabel}/{subj['subject_folder']}/{storage}",
        "alternative_sources": [],
        "discovery_status": "TRUSTED_THIRD_PARTY_DISCOVERED",
        "official_exhausted": True,
        "status": "PENDING",
        "retry_count": 0,
        "cataloged_at": utcnow(),
        "aglasem_doc_uuid": doc_uuid,
    }


def _parse_subject_slug(slug: str) -> str | None:
    for part in slug.split("-"):
        if part in SUBJECT_SLUG_MAP:
            return SUBJECT_SLUG_MAP[part]
    if "english" in slug:
        return "english"
    if "math" in slug:
        return "mathematics"
    if "science" in slug:
        return "science"
    if "social" in slug:
        return "social_science"
    return None


def _parse_assessment_from_path(path_slug: str) -> str:
    low = path_slug.lower()
    for token, atype in ASSESSMENT_FROM_SLUG.items():
        if token in low:
            return atype
    if re.search(r"\bfa\s*1\b|fa1", low):
        return "fa1"
    if re.search(r"\bfa\s*2\b|fa2", low):
        return "fa2"
    if re.search(r"\bsa\s*1\b|sa1", low):
        return "sa1"
    if re.search(r"\bsa\s*2\b|sa2", low):
        return "sa2"
    return "other_assessment"


def _discover_page(
    ws: Workspace,
    page_url: str,
    *,
    board_code: str,
    board_folder: str,
    board_tag: str,
    class_num: int,
    subject_key: str | None,
    assessment_subtype: str | None,
    cfg: dict,
    publisher: str,
    seen_urls: set[str],
) -> list[dict]:
    if page_url in seen_urls:
        return []
    seen_urls.add(page_url)

    try:
        html = _fetch(page_url)
    except Exception:
        return []

    entries: list[dict] = []
    for doc_uuid in _extract_doc_ids(html):
        subj = subject_key or _parse_subject_slug(page_url)
        if not subj:
            continue
        atype = assessment_subtype or _parse_assessment_from_path(page_url)
        entry = _make_entry(
            ws,
            board_code=board_code,
            board_folder=board_folder,
            board_tag=board_tag,
            class_num=class_num,
            subject_key=subj,
            assessment_subtype=atype,
            doc_uuid=doc_uuid,
            page_url=page_url,
            cfg=cfg,
            publisher=publisher,
        )
        if entry and entry["source_url"] not in seen_urls:
            seen_urls.add(entry["source_url"])
            entries.append(entry)
    return entries


def _discover_ap_aglasem(ws: Workspace, cfg: dict, publisher: str, seen: set[str]) -> list[dict]:
    board_code, board_folder, board_tag = BOARD_META["ap"]
    entries: list[dict] = []

    for class_num in range(1, 11):
        ord_ = ORDINAL[class_num]
        for exam in ("fa1", "fa2"):
            index_url = f"{AGLASEM_SCHOOLS}/ap-{ord_}-class-{exam}-question-papers/"
            try:
                html = _fetch(index_url)
            except Exception:
                continue

            subj_links = []
            for href in HREF_RE.findall(html):
                if not href.startswith("http"):
                    href = urljoin(index_url, href)
                slug = href.rstrip("/").split("/")[-1]
                if f"-{exam}-question-paper-" in slug and slug.startswith("ap-"):
                    subj_links.append(href)

            for link in sorted(set(subj_links)):
                slug = link.rstrip("/").split("/")[-1]
                subj_key = _parse_subject_slug(slug)
                if not subj_key:
                    continue
                entries.extend(
                    _discover_page(
                        ws, link,
                        board_code=board_code,
                        board_folder=board_folder,
                        board_tag=board_tag,
                        class_num=class_num,
                        subject_key=subj_key,
                        assessment_subtype=exam,
                        cfg=cfg,
                        publisher=publisher,
                        seen_urls=seen,
                    )
                )
    return entries


def _discover_ts_aglasem(ws: Workspace, cfg: dict, publisher: str, seen: set[str]) -> list[dict]:
    board_code, board_folder, board_tag = BOARD_META["telangana"]
    entries: list[dict] = []

    for class_num in (9, 10):
        index_url = f"{AGLASEM_SCHOOLS}/ts-class-{class_num}-question-paper/"
        try:
            html = _fetch(index_url)
        except Exception:
            continue

        subj_links = []
        for href in HREF_RE.findall(html):
            if not href.startswith("http"):
                href = urljoin(index_url, href)
            slug = href.rstrip("/").split("/")[-1]
            if slug.startswith(f"ts-class-{class_num}-question-paper-") and slug != f"ts-class-{class_num}-question-paper":
                subj_links.append(href)

        for link in sorted(set(subj_links)):
            slug = link.rstrip("/").split("/")[-1]
            subj_key = _parse_subject_slug(slug)
            if not subj_key:
                continue
            entries.extend(
                _discover_page(
                    ws, link,
                    board_code=board_code,
                    board_folder=board_folder,
                    board_tag=board_tag,
                    class_num=class_num,
                    subject_key=subj_key,
                    assessment_subtype="model_paper",
                    cfg=cfg,
                    publisher=publisher,
                    seen_urls=seen,
                )
            )
    return entries


def _discover_cbse_aglasem(ws: Workspace, cfg: dict, publisher: str, seen: set[str]) -> list[dict]:
    board_code, board_folder, board_tag = BOARD_META["cbse"]
    entries: list[dict] = []

    for class_num in range(6, 11):
        index_url = f"{AGLASEM_SCHOOLS}/cbse-sample-papers-class-{class_num}/"
        try:
            html = _fetch(index_url)
        except Exception:
            continue

        subj_links = []
        for href in HREF_RE.findall(html):
            if not href.startswith("http"):
                href = urljoin(index_url, href)
            slug = href.rstrip("/").split("/")[-1]
            if f"class-{class_num}" in slug and "sample-paper" in slug and slug.count("-") >= 4:
                subj_links.append(href)

        for link in sorted(set(subj_links)):
            slug = link.rstrip("/").split("/")[-1]
            subj_key = _parse_subject_slug(slug)
            if not subj_key:
                continue
            entries.extend(
                _discover_page(
                    ws, link,
                    board_code=board_code,
                    board_folder=board_folder,
                    board_tag=board_tag,
                    class_num=class_num,
                    subject_key=subj_key,
                    assessment_subtype="sample_paper",
                    cfg=cfg,
                    publisher=publisher,
                    seen_urls=seen,
                )
            )
    return entries


def discover_stream(ws: Workspace, *, boards: set[str] | None = None):
    """Yield assessment entries as each AglaSem page is crawled (stream mode)."""
    cfg = ws.config("trusted_assessment_sources")
    publisher = cfg["allowed_domains"][0]["publisher"]
    seen_urls: set[str] = set()
    target = boards or {"ap", "telangana", "cbse"}

    if "ap" in target:
        board_code, board_folder, board_tag = BOARD_META["ap"]
        for class_num in range(1, 11):
            ord_ = ORDINAL[class_num]
            for exam in ("fa1", "fa2"):
                index_url = f"{AGLASEM_SCHOOLS}/ap-{ord_}-class-{exam}-question-papers/"
                try:
                    html = _fetch(index_url)
                except Exception:
                    continue
                subj_links = []
                for href in HREF_RE.findall(html):
                    if not href.startswith("http"):
                        href = urljoin(index_url, href)
                    slug = href.rstrip("/").split("/")[-1]
                    if f"-{exam}-question-paper-" in slug and slug.startswith("ap-"):
                        subj_links.append(href)
                for link in sorted(set(subj_links)):
                    subj_key = _parse_subject_slug(link.rstrip("/").split("/")[-1])
                    if not subj_key:
                        continue
                    for entry in _discover_page(
                        ws, link,
                        board_code=board_code, board_folder=board_folder, board_tag=board_tag,
                        class_num=class_num, subject_key=subj_key, assessment_subtype=exam,
                        cfg=cfg, publisher=publisher, seen_urls=seen_urls,
                    ):
                        yield entry

    if "telangana" in target:
        board_code, board_folder, board_tag = BOARD_META["telangana"]
        for class_num in (9, 10):
            index_url = f"{AGLASEM_SCHOOLS}/ts-class-{class_num}-question-paper/"
            try:
                html = _fetch(index_url)
            except Exception:
                continue
            subj_links = []
            for href in HREF_RE.findall(html):
                if not href.startswith("http"):
                    href = urljoin(index_url, href)
                slug = href.rstrip("/").split("/")[-1]
                if slug.startswith(f"ts-class-{class_num}-question-paper-") and slug != f"ts-class-{class_num}-question-paper":
                    subj_links.append(href)
            for link in sorted(set(subj_links)):
                subj_key = _parse_subject_slug(link.rstrip("/").split("/")[-1])
                if not subj_key:
                    continue
                for entry in _discover_page(
                    ws, link,
                    board_code=board_code, board_folder=board_folder, board_tag=board_tag,
                    class_num=class_num, subject_key=subj_key, assessment_subtype="model_paper",
                    cfg=cfg, publisher=publisher, seen_urls=seen_urls,
                ):
                    yield entry

    if "cbse" in target:
        board_code, board_folder, board_tag = BOARD_META["cbse"]
        for class_num in range(6, 11):
            index_url = f"{AGLASEM_SCHOOLS}/cbse-sample-papers-class-{class_num}/"
            try:
                html = _fetch(index_url)
            except Exception:
                continue
            subj_links = []
            for href in HREF_RE.findall(html):
                if not href.startswith("http"):
                    href = urljoin(index_url, href)
                slug = href.rstrip("/").split("/")[-1]
                if f"class-{class_num}" in slug and "sample-paper" in slug and slug.count("-") >= 4:
                    subj_links.append(href)
            for link in sorted(set(subj_links)):
                subj_key = _parse_subject_slug(link.rstrip("/").split("/")[-1])
                if not subj_key:
                    continue
                for entry in _discover_page(
                    ws, link,
                    board_code=board_code, board_folder=board_folder, board_tag=board_tag,
                    class_num=class_num, subject_key=subj_key, assessment_subtype="sample_paper",
                    cfg=cfg, publisher=publisher, seen_urls=seen_urls,
                ):
                    yield entry


def build(ws: Workspace, *, boards: set[str] | None = None) -> list[dict]:
    by_url: dict[str, dict] = {}
    for entry in discover_stream(ws, boards=boards):
        by_url[entry["source_url"]] = entry
    return list(by_url.values())


def merge_queue(ws: Workspace, catalogue: list[dict]) -> tuple[int, int]:
    queue = load_json(ws.pm("download_queue"), []) or []
    have_ids = {e.get("resource_id") for e in queue}
    have_urls = {e.get("source_url") for e in queue}
    added = 0
    for entry in catalogue:
        if entry["resource_id"] in have_ids or entry["source_url"] in have_urls:
            continue
        queue.append(entry)
        added += 1
    write_json(ws.pm("download_queue"), queue)
    return added, len(queue)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--workspace", type=Path, default=WORKSPACE_ROOT)
    ap.add_argument("--board", default="all", choices=["ap", "cbse", "telangana", "all"])
    ap.add_argument("--inspect", action="store_true")
    ap.add_argument("--to-queue", action="store_true")
    args = ap.parse_args()
    ws = Workspace(args.workspace)
    boards = {"ap", "cbse", "telangana"} if args.board == "all" else {args.board}
    cat = build(ws, boards=boards)
    out = ws.p("discovery_dir") / "trusted_assessment_catalogue.json"
    write_json(out, {
        "generated_at": utcnow(),
        "policy": "controlled_provenance_expansion_assessment_only",
        "provenance_tier": TIER_TRUSTED_THIRD_PARTY,
        "documents": cat,
    })
    print(f"trusted assessment catalogue: {len(cat)} entries → {out}")
    if args.inspect:
        for e in cat[:40]:
            print(e["board"], e["class_label"], e["subject"], e["assessment_subtype"], e["source_url"][:70])
    if args.to_queue:
        added, total = merge_queue(ws, cat)
        print(f"queue merge: +{added} (total {total})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
