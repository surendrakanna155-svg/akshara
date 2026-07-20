#!/usr/bin/env python3
"""Search URL → if PDF exists → download immediately. Nothing else."""
from __future__ import annotations

import hashlib
import re
import sys
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts" / "common"))
from workspace import Workspace, utcnow  # noqa: E402

ORD = {1: "1st", 2: "2nd", 3: "3rd", 4: "4th", 5: "5th", 6: "6th", 7: "7th", 8: "8th", 9: "9th", 10: "10th"}
SUBJ = {"english": "english", "mathematics": "maths", "science": "science", "social_science": "social-studies"}
DOC_RE = re.compile(r"single-doc-download/([0-9a-f-]{36})", re.I)
UA = {"User-Agent": "AksharaCurriculumBot/1.0"}


def ap_urls() -> list[tuple[str, str, str, str]]:
    """(page_url, board_folder, class_label, subject_folder, exam)"""
    out = []
    base = "https://schools.aglasem.com"
    # classes 1-5: fa2 only
    scope = {
        1: ["english", "mathematics"], 2: ["english", "mathematics"],
        3: ["english", "mathematics", "science"], 4: ["english", "mathematics", "science"],
        5: ["english", "mathematics", "science", "social_science"],
        6: ["english", "mathematics", "science", "social_science"],
        7: ["english", "mathematics", "science", "social_science"],
        8: ["english", "mathematics", "science", "social_science"],
        9: ["english", "mathematics", "science", "social_science"],
        10: ["english", "mathematics", "science", "social_science"],
    }
    folders = {"english": "English", "mathematics": "Mathematics", "science": "Science", "social_science": "Social_Science"}
    for cls, subs in scope.items():
        exams = ("fa2",) if cls <= 5 else ("fa1", "fa2")
        for exam in exams:
            for sk in subs:
                slug = SUBJ[sk]
                if cls <= 5 or exam == "fa2":
                    url = f"{base}/ap-{ORD[cls]}-class-{exam}-{slug}-question-paper/"
                else:
                    url = f"{base}/ap-{ORD[cls]}-{exam}-question-paper-{slug}/"
                out.append((url, f"Class_{cls:02d}", folders[sk], exam))
    return out


def cbse_urls() -> list[tuple[str, str, str, str]]:
    out = []
    base = "https://schools.aglasem.com"
    mapping = {
        10: {
            "english": "english-communicative",
            "mathematics": "maths-basic",
            "science": "science",
        },
    }
    folders = {"english": "English", "mathematics": "Mathematics", "science": "Science", "social_science": "Social_Science"}
    for cls, subs in mapping.items():
        for sk, slug in subs.items():
            url = f"{base}/cbse-question-paper-class-{cls}-{slug}/"
            out.append((url, f"Class_{cls:02d}", folders[sk], "previous_paper"))
    return out


def _dest(ws: Workspace, board: str, clabel: str, subj_folder: str, exam: str, uuid: str) -> Path:
    name = f"T3P_{board}_{clabel}_{subj_folder}_{exam}_{uuid[:8]}.pdf"
    return (
        ws.p("resources_dir") / "curriculum" / board / clabel / subj_folder
        / "Trusted_Third_Party_Assessment" / name
    )


def _try_one(ws: Workspace, board: str, item: tuple) -> str:
    page_url, clabel, subj_folder, exam = item
    try:
        html = urllib.request.urlopen(
            urllib.request.Request(page_url, headers=UA), timeout=20,
        ).read(300_000).decode("utf-8", "ignore")
    except Exception:
        return "NO_PAGE"
    m = DOC_RE.search(html)
    if not m:
        return "NO_PDF"
    uuid = m.group(1)
    dest = _dest(ws, board, clabel, subj_folder, exam, uuid)
    if dest.is_file() and dest.stat().st_size > 1000:
        return "EXISTS"
    dl = f"https://docs.aglasem.com/product/single-doc-download/{uuid}?title=DL"
    try:
        resp = urllib.request.urlopen(urllib.request.Request(dl, headers=UA), timeout=45)
        data = resp.read()
    except Exception:
        return "DL_FAIL"
    if not data.startswith(b"%PDF") or len(data) < 2000:
        return "NOT_PDF"
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(data)
    return f"OK {dest.name}"


def main() -> int:
    ws = Workspace(ROOT)
    jobs = [("ap", u) for u in ap_urls()] + [("cbse", u) for u in cbse_urls()]
    print(f"searching {len(jobs)} pages...", flush=True)
    stats = {}
    with ThreadPoolExecutor(10) as pool:
        futs = {pool.submit(_try_one, ws, b, u): (b, u) for b, u in jobs}
        for fut in as_completed(futs):
            r = fut.result()
            stats[r.split()[0]] = stats.get(r.split()[0], 0) + 1
            if r.startswith("OK"):
                print(r, flush=True)
    print("done:", stats, flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
