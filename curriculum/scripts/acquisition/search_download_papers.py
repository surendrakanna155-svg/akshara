#!/usr/bin/env python3
"""Web search seeds → find PDF links on page → download if file exists."""
from __future__ import annotations

import re
import sys
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from urllib.parse import urljoin, urlparse

ROOT = Path(__file__).resolve().parents[2]
UA = "Mozilla/5.0 (compatible; AksharaCurriculumBot/1.0)"
PDF_RE = re.compile(r'href=["\']([^"\']+\.pdf[^"\']*)["\']', re.I)
DOC_RE = re.compile(r'single-doc-download/([0-9a-f-]{36})', re.I)
HREF_RE = re.compile(r'href=["\']([^"\']+)["\']', re.I)

# Seeds from web search (AglaSem + Schools360 + official CBSE index)
SEEDS = [
    # AglaSem AP — direct subject pages
    "https://schools.aglasem.com/ap-6th-class-fa1-question-papers/",
    "https://schools.aglasem.com/ap-7th-class-fa1-question-papers/",
    "https://schools.aglasem.com/ap-8th-class-fa1-question-papers/",
    "https://schools.aglasem.com/ap-9th-class-fa1-question-papers/",
    "https://schools.aglasem.com/ap-10th-class-fa1-question-papers/",
    "https://schools.aglasem.com/ap-6th-class-fa2-question-papers/",
    "https://schools.aglasem.com/ap-7th-class-fa2-question-papers/",
    "https://schools.aglasem.com/ap-8th-class-fa2-question-papers/",
    "https://schools.aglasem.com/ap-9th-class-fa2-question-papers/",
    "https://schools.aglasem.com/ap-10th-class-fa2-question-papers/",
    "https://schools.aglasem.com/cbse-class-10-question-paper/",
    "https://schools.aglasem.com/cbse-previous-year-question-papers/",
    # Schools360 from search
    "https://www.schools360.in/fa2-all-subjects-papers-pdf/",
    "https://www.schools360.in/fa1-english-model-question-papers-6th7th8th9th10th-classes-ap-ts/",
    "https://www.schools360.in/fa2-maths-cce-model-question-papers-6th-7th-8th-9th-10-classes-ap-ts/",
    "https://www.schools360.in/ap-6th-class-fa2-question-papers/",
    "https://www.schools360.in/ap-10th-class-fa2-question-paper/",
    # Official CBSE
    "https://www.cbse.gov.in/cbsenew/question-paper.html",
]

OUT = ROOT / "resources" / "curriculum" / "_search_downloads" / "question_papers"


def fetch(url: str, limit: int = 600_000) -> str:
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=25) as r:
        return r.read(limit).decode("utf-8", "ignore")


def collect_links(page_url: str, html: str) -> set[str]:
    links: set[str] = set()
    for href in HREF_RE.findall(html):
        if href.startswith("#") or href.startswith("javascript:"):
            continue
        abs_u = urljoin(page_url, href)
        low = abs_u.lower()
        if low.endswith(".pdf"):
            links.add(abs_u)
        elif "single-doc-download/" in low:
            m = DOC_RE.search(abs_u)
            if m:
                links.add(f"https://docs.aglasem.com/product/single-doc-download/{m.group(1)}?title=DL")
        elif any(x in low for x in ("question-paper", "model-paper", "fa1", "fa2", "sample-paper", "previous-year")):
            if urlparse(abs_u).netloc and abs_u not in SEEDS:
                links.add(abs_u)  # follow one hop
    for uuid in DOC_RE.findall(html):
        links.add(f"https://docs.aglasem.com/product/single-doc-download/{uuid}?title=DL")
    return links


def download(url: str) -> str:
    try:
        req = urllib.request.Request(url, headers={"User-Agent": UA})
        with urllib.request.urlopen(req, timeout=45) as r:
            data = r.read()
        if not data.startswith(b"%PDF") or len(data) < 1500:
            return "SKIP"
        name = urlparse(url).path.split("/")[-1] or "paper.pdf"
        if not name.lower().endswith(".pdf"):
            name = re.sub(r"[^a-zA-Z0-9._-]+", "_", url[-60:]) + ".pdf"
        dest = OUT / name
        if dest.is_file() and dest.stat().st_size > 1500:
            return "EXISTS"
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(data)
        return f"OK {name} ({len(data)//1024}KB)"
    except Exception as exc:
        return f"FAIL {type(exc).__name__}"


def main() -> int:
    print(f"searching {len(SEEDS)} seed pages...", flush=True)
    pdf_urls: set[str] = set()
    child_pages: set[str] = set()

    for seed in SEEDS:
        try:
            html = fetch(seed)
        except Exception as e:
            print(f"page fail {seed}: {e}", flush=True)
            continue
        for link in collect_links(seed, html):
            if link.lower().endswith(".pdf") or "docs.aglasem.com" in link:
                pdf_urls.add(link)
            elif link.startswith("http"):
                child_pages.add(link)

    # one child hop (subject pages)
    for page in list(child_pages)[:80]:
        try:
            html = fetch(page)
            for link in collect_links(page, html):
                if link.lower().endswith(".pdf") or "docs.aglasem.com" in link:
                    pdf_urls.add(link)
        except Exception:
            pass

    print(f"found {len(pdf_urls)} PDF URLs — downloading...", flush=True)
    stats: dict[str, int] = {}
    with ThreadPoolExecutor(12) as pool:
        futs = {pool.submit(download, u): u for u in pdf_urls}
        for fut in as_completed(futs):
            r = fut.result()
            k = r.split()[0]
            stats[k] = stats.get(k, 0) + 1
            if r.startswith("OK"):
                print(r, flush=True)

    print("done:", stats, flush=True)
    print("saved to:", OUT, flush=True)
    return 0


if __name__ == "__main__":
    sys.path.insert(0, str(ROOT / "scripts" / "common"))
    raise SystemExit(main())
