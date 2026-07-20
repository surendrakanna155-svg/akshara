#!/usr/bin/env python3
"""CBSE Sample Question Papers + Marking Schemes → DOWNLOAD_QUEUE.json (Agent 5).

Scrapes the official CBSE Academic SQP listing pages, HEAD-probes PDF endpoints,
and queues in-scope core-subject cells only (Classes 9–10, English medium).

  SQP → sample_paper
  MS  → blueprint  (marking scheme satisfies blueprint matrix cells)

Usage:
  cbse_sqp_catalogue.py [--to-queue] [--inspect] [--no-probe]
"""

from __future__ import annotations

import argparse
import re
import sys
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "common"))
from workspace import Workspace, load_json, write_json, utcnow, sanitize_filename  # noqa: E402
from source_probe import probe_url  # noqa: E402

WORKSPACE_ROOT = Path(__file__).resolve().parents[2]
SQP_BASE = "https://cbseacademic.nic.in/web_material/SQP/ClassX_2025_26"
LISTING = "https://cbseacademic.nic.in/SQP_CLASSX_2025-26.html"
PORTAL = "https://cbseacademic.nic.in"

# stem prefix on listing page → (subject display, subject folder)
CORE_STEMS: dict[str, tuple[str, str]] = {
    "Science": ("Science", "Science"),
    "SocialScience": ("Social Science", "Social_Science"),
    "EnglishL": ("English", "English"),
    "MathsStandard": ("Mathematics", "Mathematics"),
    "ComputerApplication": ("Computer Science", "Computer_Science"),
}
# Classes covered by the Class-X secondary SQP set (IX shares secondary curriculum).
CLASS_NUMS = (9, 10)
SUBJ_CODE = {"Mathematics": "MATH", "Science": "SCI", "Social Science": "SST",
             "English": "ENG", "Computer Science": "CS"}


def _fetch_listing_urls() -> dict[str, str]:
    """Return {filename: absolute_url} from the official Class X SQP HTML page."""
    html = urllib.request.urlopen(LISTING, timeout=30).read().decode("utf-8", "replace")
    found: dict[str, str] = {}
    for href in re.findall(r'href="([^"]+\.pdf)"', html, re.I):
        name = href.rsplit("/", 1)[-1]
        url = href if href.startswith("http") else f"{PORTAL}/{href.lstrip('/')}"
        found[name] = url
    return found


def build(ws: Workspace, *, probe: bool = True) -> list[dict]:
    classes = ws.config("classes")["classes"]
    cat_folder = ws.config("download_rules")["category_to_subject_folder"]
    listing = _fetch_listing_urls()
    seq = 250
    catalogue: list[dict] = []

    for stem, (subj_disp, subj_folder) in CORE_STEMS.items():
        sqp_name = f"{stem}-SQP.pdf"
        ms_name = f"{stem}-MS.pdf"
        sqp_url = listing.get(sqp_name)
        ms_url = listing.get(ms_name)
        if not sqp_url and not ms_url:
            continue
        scode = SUBJ_CODE[subj_disp]

        for cnum in CLASS_NUMS:
            ckey = str(cnum)
            clabel = classes[ckey]["class_label"]
            ccode = classes[ckey]["code"]

            for kind, url, category, doc_type, id_token in (
                ("sqp", sqp_url, "sample_paper", "Sample Paper", "SAMP"),
                ("ms", ms_url, "blueprint", "Blueprint", "BLPR"),
            ):
                if not url:
                    continue
                if probe:
                    pr = probe_url(url, referer=LISTING)
                    if not pr["ok"]:
                        continue
                seq += 1
                orig = url.rsplit("/", 1)[-1]
                stem_fn = sanitize_filename(orig[:-4] if orig.lower().endswith(".pdf") else orig)
                rid = f"AKS-CBSE-{ccode}-{scode}-{id_token}-2025-{seq:06d}"
                suffix = "SamplePaper" if kind == "sqp" else "MarkingScheme"
                fname = (f"CBSE_{clabel}_{subj_folder}_{suffix}-"
                         f"{stem_fn}_2025-26_v1_English.pdf")
                dest = (f"curriculum/cbse/{clabel}/{subj_folder}/"
                        f"{cat_folder.get(category, 'Reference')}")
                title = (f"CBSE {clabel.replace('_', ' ')} {subj_disp} — "
                         f"{'Sample Question Paper' if kind == 'sqp' else 'Marking Scheme'} 2025-26")
                catalogue.append({
                    "resource_id": rid,
                    "expected_filename": fname,
                    "original_filename": orig,
                    "title": title,
                    "document_type": doc_type,
                    "resource_category": category,
                    "board": "CBSE",
                    "class_label": clabel,
                    "subject": subj_disp,
                    "priority": "A",
                    "source_portal": PORTAL,
                    "source_url": url,
                    "source_website": PORTAL,
                    "publisher": "CBSE",
                    "academic_year": "2025-26",
                    "language": "English",
                    "medium": "English",
                    "license_status": "OFFICIAL_PUBLIC_CBSE_CURRICULUM_ANALYSIS_ONLY",
                    "license_note": ("CBSE official SQP/marking scheme (cbseacademic.nic.in), "
                                     "blueprint/pattern analysis + local archive only"),
                    "destination": dest,
                    "alternative_sources": [],
                    "search_locations": [LISTING, url],
                    "discovery_status": "URL_RESOLVED",
                    "status": "PENDING",
                    "retry_count": 0,
                    "cataloged_at": utcnow(),
                })
    return catalogue


def merge_queue(ws: Workspace, catalogue: list[dict]) -> tuple[int, int]:
    queue = load_json(ws.pm("download_queue"), []) or []
    have = {e.get("resource_id") for e in queue}
    added = 0
    for entry in catalogue:
        if entry["resource_id"] not in have:
            queue.append(entry)
            added += 1
    write_json(ws.pm("download_queue"), queue)
    return added, len(queue)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--workspace", type=Path, default=WORKSPACE_ROOT)
    ap.add_argument("--to-queue", action="store_true")
    ap.add_argument("--inspect", action="store_true", help="build + print only, no queue write")
    ap.add_argument("--no-probe", action="store_true")
    args = ap.parse_args()
    ws = Workspace(args.workspace)
    catalogue = build(ws, probe=not args.no_probe)
    print(f"CBSE SQP catalogue: {len(catalogue)} probe-confirmed cells "
          f"(core subjects, Classes 9-10)")
    out = ws.p("discovery_dir") / "cbse" / "cbse_sqp_catalogue.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    write_json(out, {"generated_at": utcnow(), "source_listing": LISTING, "documents": catalogue})
    if args.inspect:
        for e in catalogue:
            print(e["resource_category"], e["class_label"], e["subject"], e["source_url"].rsplit("/", 1)[-1])
        return 0
    if args.to_queue:
        added, size = merge_queue(ws, catalogue)
        print(f"queue: merged {added} new CBSE SQP entries (queue size {size})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
