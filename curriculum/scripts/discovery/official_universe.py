#!/usr/bin/env python3
"""Evidence-derived official curriculum universe (Classes 1–10).

Authority: official board/SCERT/NCERT/CISCE catalogues — NOT the legacy
148-cell subject matrix. Each official book/volume/resource is its own slot.

Usage:
  official_universe.py [--workspace DIR]
"""
from __future__ import annotations

import argparse
import hashlib
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve()
SCRIPTS = HERE.parents[1]
for sub in ("common", "discovery"):
    p = str(SCRIPTS / sub)
    if p not in sys.path:
        sys.path.insert(0, p)

from workspace import Workspace, load_json, write_json, utcnow, sanitize_filename  # noqa: E402
import ncert_catalogue, ap_catalogue, telangana_catalogue  # noqa: E402
import cbse_catalogue, cbse_sqp_catalogue, cisce_catalogue  # noqa: E402

WORKSPACE_ROOT = HERE.parents[2]

LANGUAGE_MARKERS = ("TELUGU", "HINDI", "SANSKRIT", "URDU", "ORIENTAL", "COMPOSIT")
ACADEMIC_YEAR = "2025-26"

RESOURCE_TYPE_MAP = {
    "textbook": "CORE_TEXTBOOK",
    "syllabus": "SYLLABUS",
    "sample_paper": "SAMPLE_QUESTION_PAPER",
    "blueprint": "MARKING_SCHEME",
    "question_bank": "ASSESSMENT_RESOURCE",
}


def _slot_id(board: str, class_label: str, official_subject: str,
             book_title: str, resource_type: str, part: str = "") -> str:
    raw = f"{board}|{class_label}|{official_subject}|{book_title}|{resource_type}|{part}"
    return hashlib.sha256(raw.encode()).hexdigest()[:16]


def _infer_part(book_name: str) -> str:
    upper = book_name.upper()
    for tag in ("SEM-1", "SEM-2", "SEM-II", "SEM-I", "PART I", "PART II", "PART 1", "PART 2"):
        if tag in upper:
            return tag
    return ""


def _ap_official_subject(portal_subject: str, book_name: str) -> str:
    upper = (portal_subject + " " + book_name).upper()
    if "EVS" in upper:
        return "Environmental Studies (EVS)"
    if "PHYSICAL SCIENCE" in upper:
        return "Physical Science"
    if "BIOLOGICAL" in upper:
        return "Biological Science"
    if "GENERAL SCIENCE" in upper:
        return "General Science"
    if "SOCIAL" in upper or "STUDIES" in upper:
        return "Social Studies"
    if "ECONOMIC" in upper:
        return "Economics"
    if "POLITIC" in upper or "CIVIC" in upper:
        return "Civics / Political Science"
    if "CONTEMPORARY INDIA" in upper:
        return "Geography"
    if "CONTEMPORARY WORLD" in upper or "HISTORY" in upper:
        return "History"
    if "MATH" in upper:
        return "Mathematics"
    if "ENGLISH" in upper:
        return "English"
    return portal_subject.strip()


def _ap_resource_subtype(book_type: str, book_name: str) -> str:
    bt = book_type.lower()
    bn = book_name.upper()
    if "hand book" in bt or "THB" in bn:
        return "CORE_TEXTBOOK"
    if "nondetail" in bn or "supplementary" in bn or "footprints" in bn.lower():
        return "SUPPLEMENTARY_READER"
    if "first flight" in bn.lower():
        return "CORE_TEXTBOOK"
    return "CORE_TEXTBOOK"


def _is_language_subject(portal_subject: str) -> bool:
    upper = portal_subject.upper()
    return any(m in upper for m in LANGUAGE_MARKERS)


def _enrich_queue_entry(entry: dict, *, qp_scope: str, official_subject: str,
                        book_title: str, resource_type: str,
                        evidence: str, part: str = "") -> dict:
    out = dict(entry)
    out["slot_id"] = _slot_id(
        entry.get("board", ""), entry.get("class_label", ""),
        official_subject, book_title, resource_type, part,
    )
    out["official_subject"] = official_subject
    out["book_title"] = book_title
    out["part_volume"] = part
    out["resource_type"] = resource_type
    out["qp_scope"] = qp_scope
    out["academic_year"] = entry.get("academic_year", ACADEMIC_YEAR)
    out["discovery_evidence"] = evidence
    return out


# NCERT books whose dd.zip is 404 but recoverable via DIKSHA official mirror.
DIKSHA_GAP_RECOVERY: list[tuple[str, int, str, str, str, str, str]] = [
    # (code, class, subject_key, title, resource_type, diksha_id, url)
    ("iemo1", 9, "english", "Moments (English Supplementary)", "SUPPLEMENTARY_READER",
     "do_31310347518744985611058",
     "https://files.odev.oci.diksha.gov.in/ntp-content-production/content/"
     "do_31310347518744985611058/new-moments-english-suppl.-reader_"
     "1755847683844_do_31310347518744985611058_46_SPINE.ecar"),
    ("ieeo1", 9, "economics", "Economics", "CORE_TEXTBOOK",
     "do_31310347520850329611401",
     "https://files.odev.oci.diksha.gov.in/ntp-content-production/content/"
     "do_31310347520850329611401/new-economics_"
     "1771841222990_do_31310347520850329611401_56_SPINE.ecar"),
]

# NCERT books whose dd.zip is 404 but recoverable via DIKSHA official mirror.
DIKSHA_GAP_RECOVERY: list[tuple[str, int, str, str, str, str, str]] = [
    # (code, class, subject_key, title, resource_type, diksha_id, url)
    ("iemo1", 9, "english", "Moments (English Supplementary)", "SUPPLEMENTARY_READER",
     "do_31310347518744985611058",
     "https://files.odev.oci.diksha.gov.in/ntp-content-production/content/"
     "do_31310347518744985611058/new-moments-english-suppl.-reader_"
     "1755847683844_do_31310347518744985611058_46_SPINE.ecar"),
    ("ieeo1", 9, "economics", "Economics", "CORE_TEXTBOOK",
     "do_31310347520850329611401",
     "https://files.odev.oci.diksha.gov.in/ntp-content-production/content/"
     "do_31310347520850329611401/new-economics_"
     "1771841222990_do_31310347520850329611401_56_SPINE.ecar"),
]

# iewe1 — official chapter components from NCERT textbook.php?iewe1 listing.
# ncert.nic.in chapter PDFs currently 404; path-equivalent mirror hosts NCERT bytes.
NCERT_OFFICIAL_PDF = "https://ncert.nic.in/textbook/pdf"
NCERT_PATH_MIRROR = "https://www.ncertbooks.net/textbook/pdf"
IEWE1_OFFICIAL_COMPONENTS: list[tuple[str, str, str]] = [
    # (file_stem, part_label, chapter_title)
    ("iewe1ps", "Prelims", "Preliminary pages"),
    ("iewe101", "Ch01", "Chapter 1"),
    ("iewe102", "Ch02", "Chapter 2"),
    ("iewe103", "Ch03", "Chapter 3"),
    ("iewe104", "Ch04", "Chapter 4"),
    ("iewe105", "Ch05", "Chapter 5"),
    ("iewe106", "Ch06", "Chapter 6"),
    ("iewe107", "Ch07", "Chapter 7"),
    ("iewe108", "Ch08", "Chapter 8"),
    ("iewe109", "Ch09", "Chapter 9"),
]

# CBSE Subject Code 165 (Computer Applications) — authoritative official sources only.
# No mandatory NCERT textbook prescribed; syllabus + SQP + MS are the official corpus.
CBSE_SUBJECT_165_OFFICIAL_SOURCES = (
    "CBSE Secondary Curriculum 2025-26 lists Subject Code 165 Computer Applications. "
    "Authoritative freely available official sources: Computer_Applications_Sec_2025-26 "
    "syllabus (cbseacademic.nic.in), Class X Sample Question Paper, and Marking Scheme. "
    "NCERT textbook.php lists Computer Science for senior secondary but does not prescribe "
    "a mandatory Class 10 Computer Applications NCERT complete-book download for Code 165."
)


def _iewe1_component_entries(ws: Workspace, in_scope: list[dict]) -> None:
    """Queue official iewe1 workbook components (chapters + prelims)."""
    classes = ws.config("classes")["classes"]
    subjects = ws.config("subjects")["subjects"]
    ckey = "9"
    clabel = classes[ckey]["class_label"]
    ccode = classes[ckey]["code"]
    subj = subjects["english"]
    code = "iewe1"
    for stem, part, chap_title in IEWE1_OFFICIAL_COMPONENTS:
        seq = 400 + len(in_scope)
        rid = f"AKS-CBSE-{ccode}-{subj['code']}-IEWE1-{part}-2025-{seq:06d}"
        fname = (f"NCERT_{clabel}_{subj['subject_folder']}_Workbook-{code}_{part}_"
                 f"{sanitize_filename(chap_title)}_{ACADEMIC_YEAR.replace('-', '_')}_v1_English.pdf")
        official_url = f"{NCERT_OFFICIAL_PDF}/{stem}.pdf"
        mirror_url = f"{NCERT_PATH_MIRROR}/{stem}.pdf"
        entry = {
            "resource_id": rid,
            "expected_filename": fname,
            "original_filename": f"{stem}.pdf",
            "title": f"NCERT {clabel} English — Words and Expressions I: {chap_title}",
            "document_type": "Workbook",
            "resource_category": "textbook",
            "board": "CBSE",
            "class_label": clabel,
            "subject": subj["display"],
            "ncert_book_code": code,
            "priority": "A",
            "source_portal": "https://ncert.nic.in/textbook.php?iewe1=0-9",
            "source_url": mirror_url,
            "official_ncert_url": official_url,
            "source_website": "https://ncert.nic.in",
            "publisher": "NCERT",
            "language": "English",
            "medium": "English",
            "license_status": "PROVENANCE_QUALIFIED_MIRROR_NCERT_CONTENT",
            "license_note": ("NCERT textbook.php official chapter listing (ISBN 978-93-5292-061-7); "
                             "ncert.nic.in direct endpoint 404; bytes from path-equivalent mirror host"),
            "destination": f"curriculum/cbse/{clabel}/{subj['subject_folder']}/Textbooks",
            "discovery_status": "URL_RESOLVED_NCERT_CHAPTER_MIRROR",
            "status": "PENDING",
        }
        in_scope.append(_enrich_queue_entry(
            entry,
            qp_scope="IN_SCOPE_ENGLISH_QP",
            official_subject="English",
            book_title=f"Words and Expressions I — {chap_title}",
            resource_type="WORKBOOK",
            evidence=("NCERT textbook.php?iewe1 official chapter index; "
                        f"official path {official_url} (404); mirror {mirror_url}"),
            part=part,
        ))


def _tag_cbse_subject_165(slots: list[dict]) -> None:
    """Mark Code 165 slots; no textbook gap."""
    for s in slots:
        if s.get("board") != "CBSE":
            continue
        if s.get("class_label") != "Class_10":
            continue
        subj = (s.get("subject") or "").lower()
        if "computer" not in subj:
            continue
        s["cbse_subject_code"] = "165"
        s["mandatory_ncert_textbook"] = False
        s["official_source_classification"] = "SYLLABUS_AND_ASSESSMENT_OFFICIAL"


def discover_cbse(ws: Workspace) -> tuple[list[dict], list[dict]]:
    """NCERT textbooks + DIKSHA mirrors + CBSE syllabus + SQP/MS."""
    in_scope: list[dict] = []
    gaps: list[dict] = []

    for code, cnum, skey, title, _bytes in ncert_catalogue.BOOKS:
        if cnum < 1 or cnum > 10:
            continue
        classes = ws.config("classes")["classes"]
        subjects = ws.config("subjects")["subjects"]
        ckey = str(cnum)
        clabel = classes[ckey]["class_label"]
        ccode = classes[ckey]["code"]
        subj = subjects[skey]
        official = subj["display"]
        if "EVS" in title or "Looking Around" in title:
            official = "Environmental Studies (EVS)"
        if "Civics" in title or "Political" in title:
            official = "Civics"
        if "Geography" in title or "Environment" in title and "Social" not in title:
            official = "Geography"
        if "History" in title or "Pasts" in title or "Contemporary World" in title:
            official = "History"
        if "Economics" in title or "Economic Development" in title:
            official = "Economics"
        if "Supplementary" in title or "Alien Hand" in title or "It So Happened" in title or "Footprints" in title:
            rtype = "SUPPLEMENTARY_READER"
        elif "Workbook" in title or "Words and Expressions" in title:
            rtype = "WORKBOOK"
        else:
            rtype = "CORE_TEXTBOOK"
        part = _infer_part(title)
        seq = 100 + len(in_scope)
        rid = f"AKS-CBSE-{ccode}-{subj['code']}-TEXT-2025-{seq:06d}"
        fname = (f"NCERT_{clabel}_{subj['subject_folder']}_Textbook-{code}"
                 f"_{ACADEMIC_YEAR.replace('-', '_')}_v1_English.zip")
        entry = {
            "resource_id": rid,
            "expected_filename": fname,
            "original_filename": f"{code}dd.zip",
            "title": f"NCERT {clabel.replace('_', ' ')} {subj['display']} — {title}",
            "document_type": "Textbook",
            "resource_category": "textbook",
            "board": "CBSE",
            "class_label": clabel,
            "subject": subj["display"],
            "ncert_book_code": code,
            "priority": "A",
            "source_portal": "https://ncert.nic.in",
            "source_url": f"{ncert_catalogue.NCERT_PDF_BASE}/{code}dd.zip",
            "source_website": "https://ncert.nic.in",
            "publisher": "NCERT",
            "language": "English",
            "medium": "English",
            "license_status": "OFFICIAL_PUBLIC_NCERT_TEXTBOOK_ANALYSIS_ONLY",
            "destination": (f"curriculum/cbse/{clabel}/{subj['subject_folder']}/Textbooks"),
            "discovery_status": "URL_RESOLVED",
            "status": "PENDING",
        }
        in_scope.append(_enrich_queue_entry(
            entry, qp_scope="IN_SCOPE_ENGLISH_QP",
            official_subject=official, book_title=title,
            resource_type=rtype,
            evidence="ncert.nic.in/textbook.php BOOKS table",
            part=part,
        ))

    for code, cnum, skey, book_title, chap_tag, chap_title, _did, url, _b in ncert_catalogue.DIKSHA_MIRROR_CHAPTERS:
        if cnum != 9:
            continue
        classes = ws.config("classes")["classes"]
        subjects = ws.config("subjects")["subjects"]
        ckey = str(cnum)
        clabel = classes[ckey]["class_label"]
        ccode = classes[ckey]["code"]
        subj = subjects[skey]
        official = book_title
        if "Civics" in book_title or "Politics" in book_title:
            official = "Civics"
        elif "Geography" in book_title or "Contemporary India" in book_title:
            official = "Geography"
        elif "History" in book_title or "Contemporary World" in book_title:
            official = "History"
        stem = sanitize_filename(f"{code}_{chap_tag}_{chap_title}")
        seq = 200 + len(in_scope)
        rid = f"AKS-CBSE-{ccode}-{subj['code']}-DIKSHA-{code.upper()}-{chap_tag}-2025-{seq:06d}"
        fname = f"NCERT_{clabel}_{subj['subject_folder']}_Textbook-{stem}_{ACADEMIC_YEAR.replace('-', '_')}_v1_English.zip"
        entry = {
            "resource_id": rid,
            "expected_filename": fname,
            "original_filename": url.rsplit("/", 1)[-1],
            "title": f"NCERT {clabel} {subj['display']} — {book_title}: {chap_title} (DIKSHA)",
            "document_type": "Textbook",
            "resource_category": "textbook",
            "board": "CBSE",
            "class_label": clabel,
            "subject": subj["display"],
            "ncert_book_code": code,
            "priority": "A",
            "source_portal": "https://diksha.gov.in",
            "source_url": url,
            "source_website": "https://diksha.gov.in",
            "publisher": "NCERT (DIKSHA mirror)",
            "language": "English",
            "medium": "English",
            "license_status": "OFFICIAL_GOVERNMENT_DIKSHA_MIRROR_NCERT",
            "destination": f"curriculum/cbse/{clabel}/{subj['subject_folder']}/Textbooks",
            "discovery_status": "URL_RESOLVED_DIKSHA_MIRROR",
            "status": "PENDING",
        }
        in_scope.append(_enrich_queue_entry(
            entry, qp_scope="IN_SCOPE_ENGLISH_QP",
            official_subject=official, book_title=f"{book_title} — {chap_title}",
            resource_type="CORE_TEXTBOOK",
            evidence="DIKSHA NCERT mirror (ncert dd.zip 404)",
            part=chap_tag,
        ))

    _iewe1_component_entries(ws, in_scope)

    for code, cnum, skey, title, rtype, did, url in DIKSHA_GAP_RECOVERY:
        classes = ws.config("classes")["classes"]
        subjects = ws.config("subjects")["subjects"]
        ckey = str(cnum)
        clabel = classes[ckey]["class_label"]
        ccode = classes[ckey]["code"]
        subj = subjects[skey]
        official = subj["display"]
        stem = sanitize_filename(f"DIKSHA_{code}_{title}")
        seq = 300 + len(in_scope)
        rid = f"AKS-CBSE-{ccode}-{subj['code']}-DIKSHA-GAP-{code.upper()}-2025-{seq:06d}"
        fname = f"NCERT_{clabel}_{subj['subject_folder']}_Textbook-{stem}_{ACADEMIC_YEAR.replace('-', '_')}_v1_English.zip"
        entry = {
            "resource_id": rid,
            "expected_filename": fname,
            "original_filename": url.rsplit("/", 1)[-1],
            "title": f"NCERT {clabel} {subj['display']} — {title} (DIKSHA gap recovery)",
            "document_type": "Textbook",
            "resource_category": "textbook",
            "board": "CBSE",
            "class_label": clabel,
            "subject": subj["display"],
            "ncert_book_code": code,
            "priority": "A",
            "source_portal": "https://diksha.gov.in",
            "source_url": url,
            "source_website": "https://diksha.gov.in",
            "publisher": "NCERT (DIKSHA mirror)",
            "language": "English",
            "medium": "English",
            "license_status": "OFFICIAL_GOVERNMENT_DIKSHA_MIRROR_NCERT",
            "destination": f"curriculum/cbse/{clabel}/{subj['subject_folder']}/Textbooks",
            "discovery_status": "URL_RESOLVED_DIKSHA_GAP_RECOVERY",
            "status": "PENDING",
        }
        in_scope.append(_enrich_queue_entry(
            entry, qp_scope="IN_SCOPE_ENGLISH_QP",
            official_subject=official, book_title=title,
            resource_type=rtype,
            evidence=f"DIKSHA gap recovery for {code} (ncert.nic.in 404)",
        ))

    for code, cnum, skey, title in ncert_catalogue.NOT_AVAILABLE:
        # Skip if covered by DIKSHA_GAP_RECOVERY or iewe1 chapter components
        if any(g[0] == code for g in DIKSHA_GAP_RECOVERY):
            continue
        if code == "iewe1":
            continue
        classes = ws.config("classes")["classes"]
        subjects = ws.config("subjects")["subjects"]
        clabel = classes[str(cnum)]["class_label"]
        subj = subjects.get(skey, {"display": skey})
        gaps.append({
            "board": "CBSE",
            "class_label": clabel,
            "official_subject": subj["display"],
            "book_title": title,
            "ncert_book_code": code,
            "resource_type": "CORE_TEXTBOOK",
            "classification": "SOURCE_MISSING",
            "note": f"Listed on ncert.nic.in but {code}dd.zip returns 404",
            "qp_scope": "IN_SCOPE_ENGLISH_QP",
        })

    for entry in cbse_catalogue.build(ws):
        subj = entry.get("subject", "General")
        in_scope.append(_enrich_queue_entry(
            entry, qp_scope="IN_SCOPE_ENGLISH_QP",
            official_subject=subj,
            book_title=entry.get("title", subj),
            resource_type="SYLLABUS",
            evidence="cbseacademic.nic.in curriculum_2026.html",
        ))

    for entry in cbse_sqp_catalogue.build(ws, probe=False):
        rcat = entry.get("resource_category", "sample_paper")
        rtype = RESOURCE_TYPE_MAP.get(rcat, "ASSESSMENT_RESOURCE")
        in_scope.append(_enrich_queue_entry(
            entry, qp_scope="IN_SCOPE_ENGLISH_QP",
            official_subject=entry.get("subject", ""),
            book_title=entry.get("title", ""),
            resource_type=rtype,
            evidence="cbseacademic.nic.in SQP_CLASSX_2025-26.html",
        ))

    _tag_cbse_subject_165(in_scope)
    return in_scope, gaps


def _ap_all_portal_rows() -> list[dict]:
    """Full AP portal table (all classes/mediums) for language-subject register."""
    import http.cookiejar
    import urllib.request
    cj = http.cookiejar.CookieJar()
    opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cj))
    headers = {
        "User-Agent": "AksharaCurriculumBot/1.0 (+education-repository)",
        "Referer": ap_catalogue.AP_PUBLIC_VIEW,
    }
    try:
        opener.open(urllib.request.Request(ap_catalogue.AP_PUBLIC_VIEW, headers=headers), timeout=20)
        req = urllib.request.Request(
            f"{ap_catalogue.AP_PUBLIC_VIEW}?random=0",
            data=f"acYear={ap_catalogue.ACADEMIC_YEAR}".encode(),
            headers={**headers, "Content-Type": "application/x-www-form-urlencoded"},
            method="POST",
        )
        with opener.open(req, timeout=60) as resp:
            page = resp.read().decode("utf-8", "ignore")
    except Exception:
        return []
    return ap_catalogue._parse_rows(page)


def discover_ap(ws: Workspace) -> tuple[list[dict], list[dict], list[dict]]:
    """AP SCERT dynamic portal — all English-content academic books."""
    in_scope: list[dict] = []
    language_register: list[dict] = []
    gaps: list[dict] = []

    # Language-subject register from full portal (all mediums)
    classes = ws.config("classes")["classes"]
    lang_seen: set[str] = set()
    for row in _ap_all_portal_rows():
        if row["class"] not in ap_catalogue.CLASS_IDS:
            continue
        if not _is_language_subject(row["subject"]):
            continue
        key = f"{row['class']}|{row['subject']}|{row['book_name']}|{row['doc_id']}"
        if key in lang_seen:
            continue
        lang_seen.add(key)
        language_register.append({
            "board": "APSCERT",
            "class_label": classes[row["class"]]["class_label"],
            "official_subject": row["subject"],
            "book_title": row["book_name"],
            "medium": row["medium"],
            "resource_type": _ap_resource_subtype(row["book_type"], row["book_name"]),
            "qp_scope": "LANGUAGE_SUBJECT_OUTSIDE_CURRENT_ENGLISH_QP_SCOPE",
            "source_url": ap_catalogue.AP_DOC_URL.format(doc_id=row["doc_id"]),
            "evidence": "cse.ap.gov.in/loadacademictextbookpublicview (language medium)",
        })

    rows, _rejected = ap_catalogue.discover_rows(probe=False)
    classes = ws.config("classes")["classes"]
    subjects = ws.config("subjects")["subjects"]
    seen_docs: set[str] = set()

    for row in rows:
        if row["class"] not in ap_catalogue.CLASS_IDS:
            continue
        if row["doc_id"] in seen_docs:
            continue
        seen_docs.add(row["doc_id"])

        if _is_language_subject(row["subject"]):
            language_register.append({
                "board": "APSCERT",
                "class_label": classes[row["class"]]["class_label"],
                "official_subject": row["subject"],
                "book_title": row["book_name"],
                "medium": row["medium"],
                "resource_type": _ap_resource_subtype(row["book_type"], row["book_name"]),
                "qp_scope": "LANGUAGE_SUBJECT_OUTSIDE_CURRENT_ENGLISH_QP_SCOPE",
                "source_url": ap_catalogue.AP_DOC_URL.format(doc_id=row["doc_id"]),
                "evidence": "cse.ap.gov.in/loadacademictextbookpublicview",
            })
            continue

        bt = row["book_type"].lower()
        is_text = bt.startswith("text")
        is_handbook = (
            row["class"] in {"1", "2", "3", "4", "5"}
            and "hand book" in bt
            and "THB" in row["book_name"].upper()
        )
        if not is_text and not is_handbook:
            continue

        skey = ap_catalogue._map_subject(row["subject"])
        if not skey:
            continue

        subj = subjects[skey]
        clabel = classes[row["class"]]["class_label"]
        ccode = classes[row["class"]]["code"]
        official = _ap_official_subject(row["subject"], row["book_name"])
        part = _infer_part(row["book_name"])
        rtype = _ap_resource_subtype(row["book_type"], row["book_name"])
        stem = sanitize_filename(row["book_name"].title())
        seq = ap_catalogue._stable_seq(row["doc_id"])
        rid = f"AKS-AP-{ccode}-{subj['code']}-TEXT-2025-{seq:06d}"
        fname = f"AP_{clabel}_{subj['subject_folder']}_Textbook-{stem}_{ACADEMIC_YEAR.replace('-', '_')}_v1_English.pdf"
        medium = row["medium"]
        bilingual = medium != "English"
        entry = {
            "resource_id": rid,
            "expected_filename": fname,
            "original_filename": f"{row['doc_id']}.pdf",
            "title": (f"AP SCERT {clabel.replace('_', ' ')} {official} — "
                      f"{row['book_name']} ({medium})"),
            "document_type": "Textbook",
            "resource_category": "textbook",
            "board": "APSCERT",
            "class_label": clabel,
            "subject": subj["display"],
            "priority": "A",
            "source_portal": ap_catalogue.AP_PUBLIC_VIEW,
            "source_url": ap_catalogue.AP_DOC_URL.format(doc_id=row["doc_id"]),
            "source_website": ap_catalogue.CSE_BASE,
            "publisher": "AP SCERT",
            "language": "English",
            "medium": medium,
            "bilingual_layout": "Telugu-English" if bilingual else "English-only",
            "license_status": "OFFICIAL_PUBLIC_AP_SCERT_TEXTBOOK_ANALYSIS_ONLY",
            "destination": f"curriculum/ap/{clabel}/{subj['subject_folder']}/Textbooks",
            "public_view_doc_id": row["doc_id"],
            "portal_subject": row["subject"],
            "portal_book_name": row["book_name"],
            "discovery_status": "URL_RESOLVED_PUBLIC_VIEW",
            "status": "PENDING",
        }
        qp = "BILINGUAL_SOURCE_ENGLISH_PRESENT" if bilingual else "IN_SCOPE_ENGLISH_QP"
        in_scope.append(_enrich_queue_entry(
            entry, qp_scope=qp,
            official_subject=official,
            book_title=row["book_name"],
            resource_type=rtype,
            evidence="cse.ap.gov.in dynamic dropdown enumeration",
            part=part,
        ))

    return in_scope, gaps, language_register


def discover_telangana(ws: Workspace) -> tuple[list[dict], list[dict], list[dict]]:
    """TS SCERT — DIKSHA mirrors + documented third-party GDrive index."""
    in_scope: list[dict] = []
    gaps: list[dict] = []
    language_register: list[dict] = []

    for entry in telangana_catalogue.build(ws):
        label = entry.get("title", "")
        official = entry.get("subject", "Unknown")
        if "EVS" in label or "environment" in label.lower():
            official = "Environmental Studies (EVS)"
        elif "Physical Science" in label:
            official = "Physical Science"
        elif "Biological" in label:
            official = "Biological Science"
        lic = entry.get("license_status", "")
        qp = ("THIRD_PARTY_PROVENANCE_REVIEW"
              if lic.startswith("UNOFFICIAL")
              else "IN_SCOPE_ENGLISH_QP")
        in_scope.append(_enrich_queue_entry(
            entry, qp_scope=qp,
            official_subject=official,
            book_title=label.split("—")[-1].strip() if "—" in label else label,
            resource_type="CORE_TEXTBOOK",
            evidence=("DIKSHA government mirror" if "DIKSHA" in label
                      else "ncertbooks.guru GDrive index (scert.telangana.gov.in blocked)"),
        ))

    # Class 5 uses EVS not Social Studies — no SST gap
    # Class 2 covered by DIKSHA mirrors

    return in_scope, gaps, language_register


def discover_icse(ws: Workspace) -> tuple[list[dict], list[dict], list[dict]]:
    """CISCE official free curriculum resources only."""
    in_scope: list[dict] = []
    commercial: list[dict] = []
    language_register: list[dict] = []

    for entry in cisce_catalogue.build(ws):
        rcat = entry.get("resource_category", "syllabus")
        rtype = RESOURCE_TYPE_MAP.get(rcat, "CURRICULUM")
        in_scope.append(_enrich_queue_entry(
            entry, qp_scope="IN_SCOPE_ENGLISH_QP",
            official_subject=entry.get("subject", ""),
            book_title=entry.get("title", ""),
            resource_type=rtype,
            evidence="cisce.org official source URLs (cisce_source_urls.json)",
        ))

    boards = ws.config("boards")["boards"]
    classes = ws.config("classes")["classes"]
    subjects = ws.config("subjects")["subjects"]
    for ckey, slugs in boards["icse"]["subjects_by_class"].items():
        clabel = classes[ckey]["class_label"]
        for slug in slugs:
            subj = subjects[slug]
            commercial.append({
                "board": "CISCE",
                "class_label": clabel,
                "official_subject": subj["display"],
                "book_title": f"{subj['display']} textbook (publisher)",
                "resource_type": "CORE_TEXTBOOK",
                "classification": "COMMERCIAL_TEXTBOOK_NOT_ACQUIRED",
                "note": "ICSE textbooks are commercial; only official syllabus/specimen acquired",
                "qp_scope": "COMMERCIAL_BLOCKED",
            })

    return in_scope, commercial, language_register


def discover_all(ws: Workspace) -> dict:
    """Build the full evidence-derived official universe."""
    cbse_slots, cbse_gaps = discover_cbse(ws)
    ap_slots, ap_gaps, ap_lang = discover_ap(ws)
    ts_slots, ts_gaps, ts_lang = discover_telangana(ws)
    icse_slots, icse_commercial, icse_lang = discover_icse(ws)

    all_slots = cbse_slots + ap_slots + ts_slots + icse_slots
    all_gaps = cbse_gaps + ap_gaps + ts_gaps
    language_register = ap_lang + ts_lang + icse_lang
    commercial = icse_commercial

    # Deduplicate by slot_id
    seen: set[str] = set()
    unique_slots: list[dict] = []
    for s in all_slots:
        sid = s.get("slot_id", "")
        if sid and sid in seen:
            continue
        if sid:
            seen.add(sid)
        unique_slots.append(s)

    universe = {
        "generated_at": utcnow(),
        "authority": "official_board_catalogues",
        "previous_matrix_size": 148,
        "corrected_universe_size": len(unique_slots),
        "documented_gaps": len(all_gaps),
        "commercial_blockers": len(commercial),
        "language_subjects_registered": len(language_register),
        "cbse_subject_165_note": CBSE_SUBJECT_165_OFFICIAL_SOURCES,
        "counting_rules": {
            "universe_slots": "Acquirable official source slots only (gaps excluded)",
            "genuine_gaps": "Documented unavailable sources NOT represented as universe slots",
            "verified_acquired": "Universe slots with bytes on disk or verified equivalent",
        },
        "slots": unique_slots,
        "gaps": all_gaps,
        "commercial": commercial,
        "language_register": language_register,
        "by_board": {
            "CBSE": len([s for s in unique_slots if s.get("board") == "CBSE"]),
            "APSCERT": len([s for s in unique_slots if s.get("board") == "APSCERT"]),
            "TSSCERT": len([s for s in unique_slots if s.get("board") == "TSSCERT"]),
            "CISCE": len([s for s in unique_slots if s.get("board") == "CISCE"]),
        },
        "by_resource_type": {},
    }
    for s in unique_slots:
        rt = s.get("resource_type", "OTHER")
        universe["by_resource_type"][rt] = universe["by_resource_type"].get(rt, 0) + 1

    out_dir = ws.p("discovery_dir")
    write_json(out_dir / "official_universe.json", universe)
    return universe


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--workspace", type=Path, default=WORKSPACE_ROOT)
    args = ap.parse_args()
    ws = Workspace(args.workspace)
    u = discover_all(ws)
    print(f"Official universe: {u['corrected_universe_size']} slots "
          f"(prev matrix {u['previous_matrix_size']})")
    print(f"  CBSE={u['by_board']['CBSE']} AP={u['by_board']['APSCERT']} "
          f"TS={u['by_board']['TSSCERT']} ICSE={u['by_board']['CISCE']}")
    print(f"  gaps={u['documented_gaps']} commercial={u['commercial_blockers']} "
          f"language_registered={u['language_subjects_registered']}")
    print(f"  resource_types: {u['by_resource_type']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
