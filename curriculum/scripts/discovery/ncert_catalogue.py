#!/usr/bin/env python3
"""NCERT textbook discovery → DOWNLOAD_QUEUE.json merge (spec Parts 05/06).

Resolves the direct, official NCERT complete-book download URLs
(`https://ncert.nic.in/textbook/pdf/<code>dd.zip`) for Classes 1-10, English
medium, in-scope subjects (mathematics, science/EVS, social_science, english), and
merges one queue cell per book into DOWNLOAD_QUEUE.json (idempotent by
resource_id). The book-code table below was resolved from the OFFICIAL NCERT
textbook listing (ncert.nic.in/textbook.php) and each `<code>dd.zip` was
HEAD-confirmed 200 / application/zip on discovery (byte size recorded).

These are the official free NCERT textbooks (content authority for CBSE). Used
for blueprint/pattern analysis + local archive only (owner D-8 / L2). No content
republishing. Download + verification is performed by downloader.py through the
certified VerificationEngine (V1-V11); this script only resolves + queues URLs.

Usage:
  ncert_catalogue.py [--to-queue]     # print catalogue; --to-queue merges
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "common"))
from workspace import Workspace, load_json, write_json, utcnow, sanitize_filename  # noqa: E402

WORKSPACE_ROOT = Path(__file__).resolve().parents[2]

NCERT_PDF_BASE = "https://ncert.nic.in/textbook/pdf"
NCERT_LISTING = "https://ncert.nic.in/textbook.php"
DIKSHA_SEARCH = "https://diksha.gov.in/api/content/v1/search?orgdetails=orgName:ncert"
DIKSHA_PORTAL = "https://diksha.gov.in"

# code -> (class_num, subject_key, book_title, head_bytes)
# class letter: a=1 b=2 c=3 d=4 e=5 f=6 g=7 h=8 i=9 j=10 ; medium e=English.
# head_bytes = Content-Length observed on HEAD at discovery (2026-07-12).
BOOKS: list[tuple[str, int, str, str, int]] = [
    # ---- Class 1 (English medium; EVS integrated in Math/English at this stage) ----
    ("aejm1", 1, "english",        "Marigold (English)",                                 100279141),
    ("aemr1", 1, "mathematics",    "Math-Magic (Mathematics)",                            34603008),
    # ---- Class 2 ----
    ("bejm1", 2, "english",        "Marigold (English)",                                  86775420),
    ("bemr1", 2, "mathematics",    "Math-Magic (Mathematics)",                            26214400),
    # ---- Class 3 ----
    ("cebu1", 3, "english",        "Marigold (English)",                                  46137344),
    ("cemm1", 3, "mathematics",    "Math-Magic (Mathematics)",                            70254592),
    ("ceev1", 3, "science",        "Looking Around (EVS)",                                49740565),
    # ---- Class 4 ----
    ("debu1", 4, "english",        "Marigold (English)",                                 139460608),
    ("demm1", 4, "mathematics",    "Math-Magic (Mathematics)",                            40894464),
    ("deev1", 4, "science",        "Looking Around (EVS)",                                54456945),
    # ---- Class 5 ----
    ("eeen1", 5, "english",        "Marigold (English)",                                 180355072),
    ("eemh1", 5, "mathematics",    "Math-Magic (Mathematics)",                           187769081),
    ("eeev1", 5, "science",        "Looking Around (EVS)",                                41924310),
    ("eust1", 5, "social_science", "Our World (Social Studies)",                          67108864),
    # ---- Class 6 (new NCF 2023 books; old editions withdrawn/404) ----
    ("fegp1", 6, "mathematics",    "Ganita Prakash (Mathematics)",                       21300720),
    ("fecu1", 6, "science",        "Curiosity (Science)",                                73711415),
    ("fees1", 6, "social_science", "Exploring Society: India and Beyond",                62584782),
    ("fepr1", 6, "english",        "Poorvi (English)",                                   37960041),
    # ---- Class 7 (new NCF + still-circulating old editions) ----
    ("gegp1", 7, "mathematics",    "Ganita Prakash Part I (Mathematics)",                19006857),
    ("gegp2", 7, "mathematics",    "Ganita Prakash Part II (Mathematics)",               22018839),
    ("gecu1", 7, "science",        "Curiosity (Science)",                                43748851),
    ("gees1", 7, "social_science", "Exploring Society: India and Beyond Part I",         83079210),
    ("gees2", 7, "social_science", "Exploring Society: India and Beyond Part II",         54275387),
    ("gepr1", 7, "english",        "Poorvi (English)",                                   75747388),
    ("gemh1", 7, "mathematics",    "Mathematics (prev. edition)",                        21715516),
    ("gesc1", 7, "science",        "Science (prev. edition)",                            23934049),
    ("gehc1", 7, "english",        "Honeycomb (English)",                                55161172),
    ("geah1", 7, "english",        "An Alien Hand (English Supplementary)",              12586703),
    ("gess1", 7, "social_science", "Social and Political Life II (Civics)",              29856769),
    ("gess2", 7, "social_science", "Our Environment (Geography)",                        20738062),
    ("gess3", 7, "social_science", "Our Pasts II (History)",                             18279805),
    # ---- Class 8 (new NCF + still-circulating old editions) ----
    ("hegp1", 8, "mathematics",    "Ganita Prakash Part I (Mathematics)",                24484332),
    ("hegp2", 8, "mathematics",    "Ganita Prakash Part II (Mathematics)",               53131335),
    ("hecu1", 8, "science",        "Curiosity (Science)",                                48172439),
    ("hees1", 8, "social_science", "Exploring Society: India and Beyond",                61299311),
    ("hepr1", 8, "english",        "Poorvi (English)",                                   65404574),
    ("hemh1", 8, "mathematics",    "Mathematics (prev. edition)",                        17919206),
    ("hesc1", 8, "science",        "Science (prev. edition)",                            20362325),
    ("hehd1", 8, "english",        "Honeydew (English)",                                 16233945),
    ("heih1", 8, "english",        "It So Happened (English Supplementary)",             21010735),
    ("hess2", 8, "social_science", "Resources and Development (Geography)",              51786237),
    ("hess3", 8, "social_science", "Our Pasts III (History)",                            23045559),
    ("hess4", 8, "social_science", "Social and Political Life III (Civics)",             11909208),
    # ---- Class 9 (old scheme; SST/Economics/Moments not downloadable = documented gap) ----
    ("iemh1", 9, "mathematics",    "Mathematics",                                        19403599),
    ("iesc1", 9, "science",        "Science",                                           124332937),
    ("iebe1", 9, "english",        "Beehive (English)",                                  36966616),
    # ---- Class 10 (old scheme; fully available) ----
    ("jemh1", 10, "mathematics",   "Mathematics",                                        32591292),
    ("jesc1", 10, "science",       "Science",                                            71057581),
    ("jeff1", 10, "english",       "First Flight (English)",                             18817209),
    ("jefp1", 10, "english",       "Footprints without Feet (English Supplementary)",    25146257),
    ("jewe2", 10, "english",       "Words and Expressions II (English Workbook)",        25202389),
    ("jess1", 10, "social_science","Democratic Politics II (Civics)",                    15086854),
    ("jess2", 10, "social_science","Contemporary India II (Geography)",                  16429387),
    ("jess3", 10, "social_science","India and the Contemporary World II (History)",      29113574),
    ("jess4", 10, "social_science","Understanding Economic Development (Economics)",      13370156),
]

# Class 9 SST books whose complete-book zip is 404 on ncert.nic.in but whose
# English-medium chapters are available as NCERT eTextbooks on DIKSHA (official
# government mirror). Each .ecar is a zip bundle (PK zip) containing chapter PDF.
# Resolved via DIKSHA content search API on 2026-07-09; each URL HEAD-confirmed 200.
# (code, class, subject_key, book_title, chapter_tag, chapter_title, diksha_id, url, bytes)
DIKSHA_MIRROR_CHAPTERS: list[tuple[str, int, str, str, str, str, str, str, int]] = [
    # iess1 — Democratic Politics I (6 chapters)
    ("iess1", 9, "social_science", "Democratic Politics I (Civics)",
     "Ch01", "Democracy in the Contemporary World",
     "do_31311763406360576011001",
     "https://obj.diksha.gov.in/ntp-content-production/content/do_31311763406360576011001/"
     "democratic-politicsclass-9chapter-1democracy-in-the-contemporary-world_"
     "1679046150106_do_31311763406360576011001_2.ecar", 13622418),
    ("iess1", 9, "social_science", "Democratic Politics I (Civics)",
     "Ch02", "What is Democracy? Why Democracy?",
     "do_31311763974316851211143",
     "https://obj.diksha.gov.in/ntp-content-production/content/do_31311763974316851211143/"
     "democratic-politicsclass-9chapter-2what-is-democracy-why-democracy_"
     "1679046152334_do_31311763974316851211143_2.ecar", 12812937),
    ("iess1", 9, "social_science", "Democratic Politics I (Civics)",
     "Ch03", "Constitutional Design",
     "do_31311764232803123211002",
     "https://obj.diksha.gov.in/ntp-content-production/content/do_31311764232803123211002/"
     "democratic-politicsclass-9chapter-3constitutional-design_"
     "1679046152422_do_31311764232803123211002_2.ecar", 12319330),
    ("iess1", 9, "social_science", "Democratic Politics I (Civics)",
     "Ch04", "Electoral Politics",
     "do_3131176442620231681173",
     "https://obj.diksha.gov.in/ntp-content-production/content/do_3131176442620231681173/"
     "democratic-politicsclass-9chapter-4electoral-politics_"
     "1679046152460_do_3131176442620231681173_2.ecar", 14636025),
    ("iess1", 9, "social_science", "Democratic Politics I (Civics)",
     "Ch05", "Working of Institutions",
     "do_3131176462182481921207",
     "https://obj.diksha.gov.in/ntp-content-production/content/do_3131176462182481921207/"
     "democratic-politicsclass-9chapter-5working-of-institutions_"
     "1679046150208_do_3131176462182481921207_2.ecar", 13738243),
    ("iess1", 9, "social_science", "Democratic Politics I (Civics)",
     "Ch06", "Democratic Rights",
     "do_31311764773761843211005",
     "https://obj.diksha.gov.in/ntp-content-production/content/do_31311764773761843211005/"
     "democratic-politicsclass-9chapter-6democratic-rights_"
     "1679046151647_do_31311764773761843211005_2.ecar", 11824650),
    # iess2 — Contemporary India I (6 chapters)
    ("iess2", 9, "social_science", "Contemporary India I (Geography)",
     "Ch01", "India - Size and Location",
     "do_314318725666013184124426",
     "https://obj.diksha.gov.in/ntp-content-production/content/do_314318725666013184124426/"
     "9th-social-geo-1-india-size-and-location-3.pdf_1747891564704_do_314318725666013184124426_1.ecar",
     5758356),
    ("iess2", 9, "social_science", "Contemporary India I (Geography)",
     "Ch02", "Physical Features of India",
     "do_314317655889756160119219",
     "https://obj.diksha.gov.in/ntp-content-production/content/do_314317655889756160119219/"
     "9th-social-geo-2-physical-features-of-india.pdf_1747762064139_do_314317655889756160119219_1.ecar",
     9737103),
    ("iess2", 9, "social_science", "Contemporary India I (Geography)",
     "Ch03", "Drainage",
     "do_314317658332086272120178",
     "https://obj.diksha.gov.in/ntp-content-production/content/do_314317658332086272120178/"
     "9th-social-geo-3-drainage.pdf_1747762308568_do_314317658332086272120178_1.ecar",
     4590014),
    ("iess2", 9, "social_science", "Contemporary India I (Geography)",
     "Ch04", "Climate",
     "do_31443750517742796815218",
     "https://obj.diksha.gov.in/ntp-content-production/content/do_31443750517742796815218/"
     "9th_social_tamil_semester_2_geography_ch_4_1762408399313_do_31443750517742796815218_1.ecar",
     8122746),
    ("iess2", 9, "social_science", "Contemporary India I (Geography)",
     "Ch05", "Natural Vegetation and Wildlife",
     "do_314318080311345152121972",
     "https://obj.diksha.gov.in/ntp-content-production/content/do_314318080311345152121972/"
     "9th-class-sem2-natural-vegetation-and-wildlife_1747814174457_do_314318080311345152121972_1.ecar",
     13508194),
    ("iess2", 9, "social_science", "Contemporary India I (Geography)",
     "Ch06", "Population",
     "do_314318082117468160121978",
     "https://obj.diksha.gov.in/ntp-content-production/content/do_314318082117468160121978/"
     "9th-class-sem2-population_1747814043672_do_314318082117468160121978_1.ecar",
     2544530),
    # iess3 — India and the Contemporary World I (8 chapters)
    ("iess3", 9, "social_science", "India and the Contemporary World I (History)",
     "Ch01", "The French Revolution",
     "do_3130631258870169601100",
     "https://obj.diksha.gov.in/ntp-content-production/content/do_3130631258870169601100/"
     "india-and-the-contemporary-world-1-class-ix-chapter-1the-french-revolution_"
     "1679026066592_do_3130631258870169601100_2.ecar", 1058105),
    ("iess3", 9, "social_science", "India and the Contemporary World I (History)",
     "Ch02", "Socialism in Europe and the Russian Revolution",
     "do_313066079317737472115317",
     "https://obj.diksha.gov.in/ntp-content-production/content/do_313066079317737472115317/"
     "india-and-the-contemporary-world-1-class-ix-chapter-2socialism-in-europe-and-the-russian-revolution_"
     "1679026333724_do_313066079317737472115317_2.ecar", 1581684),
    ("iess3", 9, "social_science", "India and the Contemporary World I (History)",
     "Ch03", "Nazism and the Rise of Hitler",
     "do_3130631535826288641153",
     "https://obj.diksha.gov.in/ntp-content-production/content/do_3130631535826288641153/"
     "india-and-the-contemporary-world-i-class-ixchapter-3nazism-and-the-rise-of-hitler_"
     "1679026106244_do_3130631535826288641153_2.ecar", 1447662),
    ("iess3", 9, "social_science", "India and the Contemporary World I (History)",
     "Ch04", "Forest Society and Colonialism",
     "do_31306609084234137619477",
     "https://obj.diksha.gov.in/ntp-content-production/content/do_31306609084234137619477/"
     "india-and-the-contemporary-world-i-class-ixchapter-4forest-society-and-colonialism_"
     "1679026333929_do_31306609084234137619477_2.ecar", 1786957),
    ("iess3", 9, "social_science", "India and the Contemporary World I (History)",
     "Ch05", "Pastoralists in the Modern World",
     "do_313063155220316160177",
     "https://obj.diksha.gov.in/ntp-content-production/content/do_313063155220316160177/"
     "india-and-the-contemporary-world-i-class-ixchapter-5pastoralists-in-the-modern-world_"
     "1679026066784_do_313063155220316160177_2.ecar", 844322),
    ("iess3", 9, "social_science", "India and the Contemporary World I (History)",
     "Ch06", "Peasants and Farmers",
     "do_3130631557380751361119",
     "https://obj.diksha.gov.in/ntp-content-production/content/do_3130631557380751361119/"
     "india-and-the-contemporary-world-i-class-ixchapter-6peasants-and-farmers_"
     "1679026087649_do_3130631557380751361119_2.ecar", 982694),
    ("iess3", 9, "social_science", "India and the Contemporary World I (History)",
     "Ch07", "History and Sport: The Story of Cricket",
     "do_3130631903052677121107",
     "https://obj.diksha.gov.in/ntp-content-production/content/do_3130631903052677121107/"
     "india-and-the-contemporary-world-i-class-ixchapter-7history-and-sportthe-story-of-cricket_"
     "1679045395577_do_3130631903052677121107_2.ecar", 1324372),
    ("iess3", 9, "social_science", "India and the Contemporary World I (History)",
     "Ch08", "Clothing: A Social History",
     "do_3130631921228185601156",
     "https://obj.diksha.gov.in/ntp-content-production/content/do_3130631921228185601156/"
     "india-and-the-contemporary-world-i-class-ixchapter-8clothinga-social-history_"
     "1679045335294_do_3130631921228185601156_2.ecar", 727490),
]

# Known-listed-but-not-downloadable on ncert.nic.in (HEAD 404 on dd.zip and chapter
# PDFs). iess1–iess3 are resolved via DIKSHA_MIRROR_CHAPTERS above.
NOT_AVAILABLE: list[tuple[str, int, str, str]] = [
    ("ieeo1", 9, "economics",      "Economics"),
    ("iemo1", 9, "english",        "Moments (English Supplementary)"),
    ("iewe1", 9, "english",        "Words and Expressions I (English Workbook)"),
]


def _diksha_chapter_entries(
    ws: Workspace,
    classes: dict,
    subjects: dict,
    board: dict,
    seq: int,
) -> tuple[list[dict], int]:
    """Queue Class 9 SST chapters from DIKSHA (NCERT dd.zip 404 on ncert.nic.in)."""
    catalogue: list[dict] = []
    for code, cnum, skey, book_title, chap_tag, chap_title, diksha_id, url, head_bytes in DIKSHA_MIRROR_CHAPTERS:
        seq += 1
        ckey = str(cnum)
        clabel = classes[ckey]["class_label"]
        ccode = classes[ckey]["code"]
        subj = subjects[skey]
        stem = sanitize_filename(f"{code}_{chap_tag}_{chap_title}")
        rid = f"AKS-CBSE-{ccode}-{subj['code']}-DIKSHA-{code.upper()}-{chap_tag}-2025-{seq:06d}"
        orig = url.rsplit("/", 1)[-1]
        fname = (f"NCERT_{clabel}_{subj['subject_folder']}_Textbook-{stem}"
                 f"_2025-26_v1_English.zip")
        catalogue.append({
            "resource_id": rid,
            "expected_filename": fname,
            "original_filename": orig,
            "title": (f"NCERT {clabel.replace('_', ' ')} {subj['display']} — "
                      f"{book_title}: {chap_title} (DIKSHA mirror chapter)"),
            "document_type": "Textbook",
            "resource_category": "textbook",
            "board": "CBSE",
            "class_label": clabel,
            "subject": subj["display"],
            "ncert_book_code": code,
            "diksha_content_id": diksha_id,
            "priority": "A",
            "source_portal": DIKSHA_PORTAL,
            "source_url": url,
            "source_website": DIKSHA_PORTAL,
            "publisher": "NCERT",
            "academic_year": "2025-26",
            "language": "English",
            "medium": "English",
            "license_status": "OFFICIAL_MIRROR_DIKSHA_NCERT_TEXTBOOK_ANALYSIS_ONLY",
            "license_note": ("NCERT textbook chapter via DIKSHA official government mirror "
                             "(ncert.nic.in complete-book zip unavailable); analysis + archive only"),
            "provenance": "OFFICIAL_MIRROR",
            "destination": f"curriculum/{board['board_folder']}/{clabel}/{subj['subject_folder']}/Textbooks",
            "alternative_sources": [f"{NCERT_PDF_BASE}/{code}dd.zip"],
            "search_locations": [DIKSHA_SEARCH, DIKSHA_PORTAL, NCERT_LISTING],
            "discovery_status": "URL_RESOLVED_DIKSHA_MIRROR",
            "head_content_length": head_bytes,
            "status": "PENDING",
            "retry_count": 0,
            "cataloged_at": utcnow(),
        })
    return catalogue, seq


def build(ws: Workspace) -> list[dict]:
    classes = ws.config("classes")["classes"]
    subjects = ws.config("subjects")["subjects"]
    board = ws.config("boards")["boards"]["cbse"]
    seq = 100  # NCERT textbook cells occupy a distinct seq band from CBSE SQP cells
    catalogue: list[dict] = []
    for code, cnum, skey, title, head_bytes in BOOKS:
        seq += 1
        ckey = str(cnum)
        clabel = classes[ckey]["class_label"]
        ccode = classes[ckey]["code"]
        subj = subjects[skey]
        rid = f"AKS-CBSE-{ccode}-{subj['code']}-TEXT-2025-{seq:06d}"
        fname = (f"NCERT_{clabel}_{subj['subject_folder']}_Textbook-{code}"
                 f"_2025-26_v1_English.zip")
        dest = f"curriculum/{board['board_folder']}/{clabel}/{subj['subject_folder']}/Textbooks"
        catalogue.append({
            "resource_id": rid,
            "expected_filename": fname,
            "original_filename": f"{code}dd.zip",
            "title": f"NCERT {clabel.replace('_', ' ')} {subj['display']} — {title} (complete book)",
            "document_type": "Textbook",
            "resource_category": "textbook",
            "board": "CBSE",
            "class_label": clabel,
            "subject": subj["display"],
            "ncert_book_code": code,
            "priority": "A",
            "source_portal": "https://ncert.nic.in",
            "source_url": f"{NCERT_PDF_BASE}/{code}dd.zip",
            "source_website": "https://ncert.nic.in",
            "publisher": "NCERT",
            "academic_year": "2025-26",
            "language": "English",
            "medium": "English",
            "license_status": "OFFICIAL_PUBLIC_NCERT_TEXTBOOK_ANALYSIS_ONLY",
            "license_note": ("NCERT official free textbook (ncert.nic.in), content authority "
                             "for CBSE; used for blueprint/pattern analysis + local archive only"),
            "destination": dest,
            "alternative_sources": [],
            "search_locations": [NCERT_LISTING, f"{NCERT_PDF_BASE}/{code}dd.zip"],
            "discovery_status": "URL_RESOLVED",
            "head_content_length": head_bytes,
            "status": "PENDING",
            "retry_count": 0,
            "cataloged_at": utcnow(),
        })
    diksha_entries, _seq = _diksha_chapter_entries(ws, classes, subjects, board, seq)
    catalogue.extend(diksha_entries)
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
    n_zip = len(BOOKS)
    n_diksha = len(DIKSHA_MIRROR_CHAPTERS)
    total_bytes = sum(e.get("head_content_length", 0) for e in catalogue)
    print(f"NCERT catalogue: {n_zip} NCERT zip books + {n_diksha} DIKSHA mirror chapters "
          f"= {len(catalogue)} queue cells, {total_bytes/1_048_576:.1f} MiB expected; "
          f"{len(NOT_AVAILABLE)} not-publicly-available (documented gap)")
    # write a discovery catalogue snapshot alongside the CBSE one
    disc_dir = ws.p("discovery_dir") / "cbse"
    disc_dir.mkdir(parents=True, exist_ok=True)
    write_json(disc_dir / "ncert_textbooks_catalogue.json", {
        "generated_at": utcnow(),
        "source_listing": NCERT_LISTING,
        "downloadable": catalogue,
        "diksha_mirror_chapters": n_diksha,
        "not_publicly_available": [
            {"ncert_book_code": c, "class": n, "subject": s, "book": t} for c, n, s, t in NOT_AVAILABLE
        ],
    })
    if args.to_queue:
        added, size = merge_queue(ws, catalogue)
        print(f"queue: merged {added} new NCERT entries → {ws.pm('download_queue')} (queue size {size})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
