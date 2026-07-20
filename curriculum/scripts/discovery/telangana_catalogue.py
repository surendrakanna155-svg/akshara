#!/usr/bin/env python3
"""Telangana (TS SCERT) textbook discovery → DOWNLOAD_QUEUE.json merge.

PROVENANCE NOTE: scert.telangana.gov.in exposes only encrypted dynamic URLs with
no clean direct-PDF pattern. Sources are resolved via:
  1. DIKSHA official government mirrors (Classes 2-5 gaps) — Tier 3 official
  2. ncertbooks.guru Google-Drive index (Classes 1,3,5,6-10) — third-party

Third-party GDrive copies are tagged UNOFFICIAL_THIRD_PARTY_COPY_TS_SCERT_GDRIVE.
DIKSHA mirrors are tagged OFFICIAL_GOVERNMENT_DIKSHA_MIRROR_TS_SCERT.

Usage:
  telangana_catalogue.py [--to-queue]
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "common"))
from workspace import Workspace, load_json, write_json, utcnow, sanitize_filename  # noqa: E402

WORKSPACE_ROOT = Path(__file__).resolve().parents[2]
TS_LISTING = "https://www.ncertbooks.guru/ts-scert-books/"
DIKSHA_PORTAL = "https://diksha.gov.in"

# (class_num, subject_key, label, google_drive_file_id) — third-party GDrive copies
GDRIVE_BOOKS: list[tuple[int, str, str, str]] = [
    (1,  "mathematics",    "Mathematics",        "193Xmy1Coj9gCOvcg6e62zteD1uPjp3xA"),
    (1,  "english",        "English",            "1cN1m1gYyHlMtT5P9G6BXX2fd4szEVgOh"),
    (3,  "mathematics",    "Mathematics",        "1UiomCgRCAojlOnE5Pv0Ge42Z8Nlcn346"),
    (3,  "science",        "EVS",                "1IO-Q-mizr9L-tNbr1ASnoIa7V5OwaoKq"),
    (5,  "mathematics",    "Mathematics",        "1_QQDtdwR65bNtyIQvixOsiLMDd0zIsI7"),
    (5,  "english",        "English",            "1lIiI3rOxHSSd_i30tB_kLAvJOBalF5K0"),
    (6,  "mathematics",    "Mathematics",        "1m1r_OUEMFgfqeokol6OJBuOCdHqnCQ-d"),
    (6,  "science",        "Science",            "1JU1SC4MWpGXoDv8TjA9kFSyJVw_2bweg"),
    (6,  "social_science", "Social Science",     "1kAp1miKlykZ9je4ehp4DCv97bsQG8HIA"),
    (6,  "english",        "English",            "1H_CZLuOmuLRiKFb3bkslGJxXaMGFaw_T"),
    (7,  "mathematics",    "Mathematics",        "12wCgDumAnJ5E4cdsLFNkJyk---6AFytW"),
    (7,  "science",        "Science",            "19UT5oKdvDLKs6AW97vmOSvEa0R5Mnjpz"),
    (7,  "social_science", "Social Science",     "1gBbahvlumE67HVwAnaHiWypsNqxh5KRx"),
    (7,  "english",        "English",            "1ZMX1Zy-XUvCAxGsdsxU_Ci7koN9CMyj7"),
    (8,  "mathematics",    "Mathematics",        "1dwXp6vB8Mv8-72AUd6mFylRuaJVWCP0s"),
    (8,  "science",        "Physical Science",   "1L727dvyMkPdb4j_ETVEIPSsDqGGyL8j1"),
    (8,  "science",        "Biological Science", "1-aaNkgZHzz357wDb4wXgRij1ceQjNVTW"),
    (8,  "social_science", "Social Science",     "1riaSQTIxrdFJsSlgz13RABtSb2vDKpAU"),
    (8,  "english",        "English",            "1VVekJiU4CEMTtmhP6xvJqzeg5XIPe4sj"),
    (9,  "mathematics",    "Mathematics",        "1vDcrWirFsPC6PR7Nx7zBj3-Ciy3BzUhj"),
    (9,  "science",        "Physical Science",   "16W5C9XJbnQL_J2HjHoMUm0aHCrwPweYG"),
    (9,  "science",        "Biological Science", "1KvFhTzuXJQL9Rf7FoMfNUJufV8e6rfEL"),
    (9,  "social_science", "Social Science",     "1g5nVszTf4rHAfPWLHd6oO7OMHTzj2DC2"),
    (9,  "english",        "English",            "1XonMaDML8ZRMN9CAf-6JsNogqmVXMrnx"),
    (10, "mathematics",    "Mathematics",        "1A3h88QkRwsr26aRTYrhT6FOlx1-6QMga"),
    (10, "science",        "Physical Science",   "1hydGUewtczkI52GVj2vrC9kutDc6Bdyh"),
    (10, "science",        "Biological Science", "10IqSGu_YeaEz06F2ZBaLcWgaVS9Zabgy"),
    (10, "social_science", "Social Science",     "1n1r6DS1JDH5YdOJBU9G_2D7G2EmGDc1i"),
    (10, "english",        "English",            "1Jxduf_aIAyiv4TpJhtC_y4ZAbBSeZ9j1"),
]

# (class_num, subject_key, label, diksha_id, url) — official DIKSHA mirrors
DIKSHA_BOOKS: list[tuple[int, str, str, str, str]] = [
    (2, "english",     "English",     "do_31311275204320460812251",
     "https://obj.diksha.gov.in/ntp-content-production/content/do_31311275204320460812251/"
     "2nd-class-english-pdf-text-book_1680012046293_do_31311275204320460812251_5_SPINE.ecar"),
    (2, "mathematics", "Mathematics", "do_31311274625380352012248",
     "https://obj.diksha.gov.in/ntp-content-production/content/do_31311274625380352012248/"
     "2nd-class-mathematics-em-pdf-text-book_1680012053876_do_31311274625380352012248_5_SPINE.ecar"),
    (3, "english",     "English",     "do_3131113841295032321795",
     "https://obj.diksha.gov.in/ntp-content-production/content/do_3131113841295032321795/"
     "3rd-class-english-pdf-text-book_1680024513484_do_3131113841295032321795_12_SPINE.ecar"),
    (4, "english",     "English",     "do_3131113705035612161791",
     "https://obj.diksha.gov.in/ntp-content-production/content/do_3131113705035612161791/"
     "4th-class-english-pdf-text-book_1680012128365_do_3131113705035612161791_5_SPINE.ecar"),
    (4, "mathematics", "Mathematics", "do_31311136705028915211156",
     "https://obj.diksha.gov.in/ntp-content-production/content/do_31311136705028915211156/"
     "4th-class-mathematics-em-pdf-text-book_1680011872135_do_31311136705028915211156_6_SPINE.ecar"),
    (4, "science",     "EVS",         "do_31311136611530342411648",
     "https://obj.diksha.gov.in/ntp-content-production/content/do_31311136611530342411648/"
     "4th-class-environmental-science-em-pdf-text-book_1680012187705_do_31311136611530342411648_5_SPINE.ecar"),
    (5, "science",     "EVS",         "do_31343979181618790412965",
     "https://obj.diksha.gov.in/ntp-content-production/content/do_31343979181618790412965/"
     "we-our-environment_5th-class_evs_1680063148465_do_31343979181618790412965_6_SPINE.ecar"),
]

DRIVE_DL = "https://drive.usercontent.google.com/download?id={fid}&export=download&confirm=t"

# Back-compat alias used by run_acquisition.py
BOOKS = GDRIVE_BOOKS


def _gdrive_entry(ws: Workspace, cnum: int, skey: str, label: str, fid: str, seq: int) -> tuple[dict, int]:
    classes = ws.config("classes")["classes"]
    subjects = ws.config("subjects")["subjects"]
    seq += 1
    ckey = str(cnum)
    clabel = classes[ckey]["class_label"]
    ccode = classes[ckey]["code"]
    subj = subjects[skey]
    stem = sanitize_filename(label)
    rid = f"AKS-TSSCERT-{ccode}-{subj['code']}-TEXT-2025-{seq:06d}"
    fname = f"TS_{clabel}_{subj['subject_folder']}_Textbook-{stem}_2025-26_v1_English.pdf"
    dest = f"curriculum/telangana/{clabel}/{subj['subject_folder']}/Textbooks"
    return {
        "resource_id": rid,
        "expected_filename": fname,
        "original_filename": f"{stem}.pdf",
        "title": f"TS SCERT {clabel.replace('_', ' ')} {subj['display']} — {label} (English medium)",
        "document_type": "Textbook",
        "resource_category": "textbook",
        "board": "TSSCERT",
        "class_label": clabel,
        "subject": subj["display"],
        "gdrive_file_id": fid,
        "priority": "A",
        "source_portal": TS_LISTING,
        "source_url": DRIVE_DL.format(fid=fid),
        "source_website": "https://drive.google.com",
        "publisher": "TS SCERT (via ncertbooks.guru index)",
        "academic_year": "2025-26",
        "language": "English",
        "medium": "English",
        "provenance": "UNOFFICIAL_THIRD_PARTY_COPY",
        "license_status": "UNOFFICIAL_THIRD_PARTY_COPY_TS_SCERT_GDRIVE",
        "license_note": ("TS SCERT textbook, Google-Drive-hosted third-party copy indexed by "
                         "ncertbooks.guru (NOT the official scert.telangana.gov.in portal). "
                         "Owner-authorised 2026-07-09; local archive + analysis only."),
        "destination": dest,
        "alternative_sources": [DIKSHA_PORTAL],
        "search_locations": [TS_LISTING, "https://scert.telangana.gov.in"],
        "discovery_status": "URL_RESOLVED",
        "status": "PENDING",
        "retry_count": 0,
        "cataloged_at": utcnow(),
    }, seq


def _diksha_entry(ws: Workspace, cnum: int, skey: str, label: str, did: str, url: str, seq: int) -> tuple[dict, int]:
    classes = ws.config("classes")["classes"]
    subjects = ws.config("subjects")["subjects"]
    seq += 1
    ckey = str(cnum)
    clabel = classes[ckey]["class_label"]
    ccode = classes[ckey]["code"]
    subj = subjects[skey]
    stem = sanitize_filename(f"DIKSHA_{label}")
    rid = f"AKS-TSSCERT-{ccode}-{subj['code']}-DIKSHA-2025-{seq:06d}"
    orig = url.rsplit("/", 1)[-1]
    fname = f"TS_{clabel}_{subj['subject_folder']}_Textbook-{stem}_2025-26_v1_English.zip"
    dest = f"curriculum/telangana/{clabel}/{subj['subject_folder']}/Textbooks"
    return {
        "resource_id": rid,
        "expected_filename": fname,
        "original_filename": orig,
        "title": f"TS SCERT {clabel.replace('_', ' ')} {subj['display']} — {label} (DIKSHA mirror)",
        "document_type": "Textbook",
        "resource_category": "textbook",
        "board": "TSSCERT",
        "class_label": clabel,
        "subject": subj["display"],
        "diksha_content_id": did,
        "priority": "A",
        "source_portal": DIKSHA_PORTAL,
        "source_url": url,
        "source_website": DIKSHA_PORTAL,
        "publisher": "TS SCERT (DIKSHA official mirror)",
        "academic_year": "2025-26",
        "language": "English",
        "medium": "English",
        "provenance": "OFFICIAL_GOVERNMENT_DIKSHA_MIRROR",
        "license_status": "OFFICIAL_GOVERNMENT_DIKSHA_MIRROR_TS_SCERT",
        "license_note": ("TS SCERT textbook via DIKSHA government education repository "
                         "(official mirror; scert.telangana.gov.in portal has no direct PDF)."),
        "destination": dest,
        "alternative_sources": [TS_LISTING],
        "search_locations": [DIKSHA_PORTAL, "https://scert.telangana.gov.in"],
        "discovery_status": "URL_RESOLVED",
        "status": "PENDING",
        "retry_count": 0,
        "cataloged_at": utcnow(),
    }, seq


def build(ws: Workspace) -> list[dict]:
    seq = 500
    catalogue: list[dict] = []
    for cnum, skey, label, fid in GDRIVE_BOOKS:
        entry, seq = _gdrive_entry(ws, cnum, skey, label, fid, seq)
        catalogue.append(entry)
    for cnum, skey, label, did, url in DIKSHA_BOOKS:
        entry, seq = _diksha_entry(ws, cnum, skey, label, did, url, seq)
        catalogue.append(entry)
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
    args = ap.parse_args()
    ws = Workspace(args.workspace)
    catalogue = build(ws)
    n_gd = len(GDRIVE_BOOKS)
    n_dk = len(DIKSHA_BOOKS)
    print(f"TS SCERT catalogue: {len(catalogue)} textbooks "
          f"({n_gd} GDrive third-party + {n_dk} DIKSHA official mirrors)")
    disc_dir = ws.p("discovery_dir") / "telangana"
    disc_dir.mkdir(parents=True, exist_ok=True)
    write_json(disc_dir / "ts_textbooks_catalogue.json",
               {"generated_at": utcnow(), "source_listing": TS_LISTING,
                "gdrive_count": n_gd, "diksha_count": n_dk,
                "official_portal_status": "scert.telangana.gov.in — encrypted dynamic URLs only",
                "documents": catalogue})
    if args.to_queue:
        added, size = merge_queue(ws, catalogue)
        print(f"queue: merged {added} new TS entries (queue size {size})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
