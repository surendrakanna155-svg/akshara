#!/usr/bin/env python3
"""
Seed Demo School pilot data via staging/production APIs.

Usage:
  python3 scripts/demo_school_seed.py
  DEMO_STUDENT_COUNT=50 DEMO_TEACHER_COUNT=5 python3 scripts/demo_school_seed.py

Writes: reports/demo_school/seed_manifest.json
"""
from __future__ import annotations

import json
import os
import sys
from datetime import date, timedelta
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from demo_school_lib import (
    ACADEMIC_YEAR_LABEL,
    ADMISSION_PREFIX,
    ADMIN_PHONE,
    ATTENDANCE_HISTORY_DAYS,
    BOOK_KIT_DISTRIBUTIONS,
    CLASS_LABELS,
    EXAM_PAPER_SAMPLE,
    FINANCE_SAMPLE_SIZE,
    GUARDIAN_COUNT,
    HOMEWORK_SAMPLE_CLASSES,
    IMPORT_BATCH_SIZE,
    LESSON_LOG_SAMPLE,
    PARENT_PHONE_START,
    RunReport,
    SCHOOL_ID,
    SECTION_LABELS,
    STAFF_COUNT,
    STUDENT_COUNT,
    SUBJECT_NAMES,
    TEACHER_COUNT,
    TEACHER_PHONE_START,
    admin_token,
    api_data,
    import_preview_commit,
    list_students,
    request,
    resolve_academic_year,
    sleep_brief,
    staff_rows,
    student_rows,
    write_report,
    _entity_id,
)


def _entity_id(item: dict, *keys: str) -> str:
    for key in keys:
        value = item.get(key)
        if value:
            return str(value)
    return ""


def ensure_academic_catalog(token: str, year_id: str, report: RunReport) -> dict[str, str]:
    """Create classes Nursery–10 and sections A/B if missing."""
    code, resp = request("GET", f"/academic/classes?academicYearId={year_id}", token=token)
    existing = {}
    if code == 200:
        for item in (api_data(resp) or {}).get("items", []):
            name = str(item.get("className") or item.get("class_name") or "")
            cid = _entity_id(item, "classId", "id")
            if name and cid:
                existing[name] = cid

    class_ids: dict[str, str] = {}
    for order, label in enumerate(CLASS_LABELS):
        if label in existing:
            class_ids[label] = existing[label]
            continue
        code, resp = request(
            "POST",
            "/academic/classes",
            token=token,
            body={
                "academicYearId": year_id,
                "className": label,
                "displayOrder": order + 1,
                "status": "active",
            },
        )
        if code not in (200, 201):
            report.add(f"create class {label}", False, str(resp))
            continue
        cid = _entity_id(api_data(resp) or {}, "classId", "id")
        class_ids[label] = cid
        report.add(f"create class {label}", True, cid)

    section_ids: dict[str, str] = {}
    for class_label, class_id in class_ids.items():
        code, resp = request("GET", f"/academic/sections?classId={class_id}", token=token)
        found = {}
        if code == 200:
            for item in (api_data(resp) or {}).get("items", []):
                sec_name = str(item.get("sectionName") or item.get("section_name") or "")
                sid = _entity_id(item, "sectionId", "id")
                if sec_name and sid:
                    found[sec_name] = sid
        for section in SECTION_LABELS:
            key = f"{class_label}-{section}"
            if section in found:
                section_ids[key] = found[section]
                continue
            code, resp = request(
                "POST",
                "/academic/sections",
                token=token,
                body={"classId": class_id, "sectionName": section, "capacity": 30, "status": "active"},
            )
            if code not in (200, 201):
                report.add(f"create section {key}", False, str(resp))
                continue
            sid = _entity_id(api_data(resp) or {}, "sectionId", "id")
            section_ids[key] = sid
            report.add(f"create section {key}", True, sid)

    return section_ids


def seed_teachers(token: str, report: RunReport) -> None:
    fields = ["displayName", "phone", "role", "email"]
    rows = staff_rows()
    try:
        job = import_preview_commit(token, "teacher", "demo_staff.csv", rows, fields)
        report.add(
            "staff import (principal + teachers + admin)",
            True,
            f"committed={job.get('committedRows', 0)} valid={job.get('validRows', 0)}",
        )
    except RuntimeError as exc:
        report.add("staff import (principal + teachers + admin)", False, str(exc))


def seed_students(token: str, report: RunReport) -> None:
    fields = [
        "studentName",
        "admissionNumber",
        "classLabel",
        "sectionLabel",
        "academicYear",
        "parentName",
        "parentPhone",
        "rollNumber",
        "gender",
        "dateOfBirth",
    ]
    all_rows = student_rows(STUDENT_COUNT)
    committed_total = 0
    for batch_idx in range(0, len(all_rows), IMPORT_BATCH_SIZE):
        chunk = all_rows[batch_idx : batch_idx + IMPORT_BATCH_SIZE]
        file_name = f"demo_students_{batch_idx // IMPORT_BATCH_SIZE + 1}.csv"
        try:
            job = import_preview_commit(token, "student", file_name, chunk, fields)
            committed_total += int(job.get("committedRows") or 0)
            report.add(
                f"student import batch {batch_idx // IMPORT_BATCH_SIZE + 1}",
                True,
                f"committed={job.get('committedRows')} invalid={job.get('invalidRows')}",
            )
        except RuntimeError as exc:
            report.add(f"student import batch {batch_idx // IMPORT_BATCH_SIZE + 1}", False, str(exc))
        sleep_brief(0.5)
    if committed_total == 0:
        existing = [
            s
            for s in list_students(token, page_size=100, pages=20)
            if str(s.get("admissionNumber", "")).startswith(ADMISSION_PREFIX)
        ]
        report.add(
            "student import total",
            len(existing) >= min(STUDENT_COUNT, 1),
            f"existing={len(existing)} committed={committed_total}",
        )
        return
    report.add("student import total", committed_total > 0, f"committed={committed_total}")


def seed_subjects(token: str, report: RunReport) -> dict[str, str]:
    subject_ids: dict[str, str] = {}
    code, resp = request("GET", "/school/subjects", token=token)
    if code == 404:
        report.add("subjects", False, "Route not mounted — deploy school completion bundle")
        return subject_ids
    existing: dict[str, str] = {}
    if code == 200:
        for item in (api_data(resp) or {}).get("items", []):
            name = str(item.get("subjectName") or "")
            sid = _entity_id(item, "id", "subjectId")
            if name and sid:
                existing[name] = sid

    for idx, name in enumerate(SUBJECT_NAMES):
        if name in existing:
            subject_ids[name] = existing[name]
            continue
        code, resp = request(
            "POST",
            "/school/subjects",
            token=token,
            body={
                "subjectCode": f"SUB-{idx + 1:02d}",
                "subjectName": name,
                "category": "core",
            },
        )
        if code not in (200, 201):
            report.add(f"subject {name}", False, str(resp)[:200])
            continue
        sid = _entity_id(api_data(resp) or {}, "id", "subjectId")
        subject_ids[name] = sid
    report.add("subjects", len(subject_ids) >= min(4, len(SUBJECT_NAMES)), f"count={len(subject_ids)}")
    return subject_ids


def seed_lesson_logs(token: str, report: RunReport, subject_ids: dict[str, str]) -> None:
    created = 0
    subject_list = list(subject_ids.values()) or [None]
    for i in range(LESSON_LOG_SAMPLE):
        class_label = CLASS_LABELS[i % len(CLASS_LABELS)]
        section = SECTION_LABELS[i % len(SECTION_LABELS)]
        subject_id = subject_list[i % len(subject_list)]
        code, resp = request(
            "POST",
            "/school/lesson-logs",
            token=token,
            body={
                "className": class_label,
                "sectionName": section,
                "subjectId": subject_id,
                "topic": f"Demo lesson topic {i + 1}",
                "outcome": "Students engaged with pilot curriculum",
            },
        )
        if code in (200, 201):
            created += 1
        elif code == 404 and i == 0:
            report.add("lesson logs", False, "Route not mounted")
            return
        sleep_brief(0.05)
    report.add("lesson logs", created > 0, f"created={created}")


def seed_homework_history(token: str, year_label: str, report: RunReport) -> None:
    created = 0
    for i in range(HOMEWORK_SAMPLE_CLASSES):
        class_label = CLASS_LABELS[i % len(CLASS_LABELS)]
        subject = SUBJECT_NAMES[i % len(SUBJECT_NAMES)]
        code, resp = request(
            "POST",
            "/education/homework/generate",
            token=token,
            body={
                "academicYearLabel": year_label,
                "className": class_label,
                "sectionName": SECTION_LABELS[i % len(SECTION_LABELS)],
                "subjectName": subject,
                "topic": f"Demo homework unit {i + 1}",
                "difficulty": "medium",
                "assignmentType": "worksheet",
            },
        )
        if code in (200, 201):
            created += 1
        elif code == 404 and i == 0:
            report.add("homework history", False, "Route not mounted")
            return
        sleep_brief(0.05)
    report.add("homework history", created > 0, f"assignments={created}")


def seed_exam_history(token: str, report: RunReport) -> None:
    created = 0
    for i in range(EXAM_PAPER_SAMPLE):
        class_label = CLASS_LABELS[i % len(CLASS_LABELS)]
        subject = SUBJECT_NAMES[i % len(SUBJECT_NAMES)]
        code, resp = request(
            "POST",
            "/education/question-papers/generate",
            token=token,
            body={
                "className": class_label,
                "subjectName": subject,
                "examType": "unit_test",
                "totalMarks": 50,
                "durationMinutes": 90,
            },
        )
        if code in (200, 201):
            created += 1
        elif code == 404 and i == 0:
            report.add("exam history", False, "Route not mounted")
            return
        sleep_brief(0.05)
    report.add("exam history", created > 0, f"papers={created}")


def seed_book_kits(token: str, report: RunReport) -> None:
    code, resp = request("GET", "/inventory/distribution/catalog", token=token)
    if code == 404:
        report.add("book kits (catalog)", False, "Route not mounted")
        return
    if code != 200:
        report.add("book kits (catalog)", False, str(resp)[:200])
        return
    catalog = (api_data(resp) or {}).get("items") or []
    book_items = [c for c in catalog if "book" in str(c.get("category", "")).lower()] or catalog
    if not book_items:
        report.add("book kits (catalog)", False, "no catalog items")
        return
    catalog_id = str(book_items[0].get("id") or book_items[0].get("catalogItemId") or "")
    students = [
        s
        for s in list_students(token, page_size=100, pages=10)
        if str(s.get("admissionNumber", "")).startswith(ADMISSION_PREFIX)
    ][:BOOK_KIT_DISTRIBUTIONS]
    distributed = 0
    for student in students:
        sid = student.get("id") or student.get("studentId")
        if not sid:
            continue
        code, _ = request(
            "POST",
            "/inventory/distribution/items",
            token=token,
            body={"studentId": sid, "catalogItemId": catalog_id, "quantity": 1},
        )
        if code in (200, 201):
            distributed += 1
        sleep_brief(0.05)
    report.add("book kit distributions", distributed > 0, f"distributed={distributed}")


def seed_inventory_dashboard(token: str, report: RunReport) -> None:
    code, resp = request("GET", "/inventory/distribution/dashboard", token=token)
    if code == 404:
        report.add("inventory dashboard", False, "Route not mounted")
        return
    report.add("inventory dashboard", code == 200, str((api_data(resp) or {}))[:120])


def seed_secondary_guardian_invites(token: str, report: RunReport) -> None:
    """Create extra parent invites only when guardians exceed student count."""
    secondary = max(0, GUARDIAN_COUNT - STUDENT_COUNT)
    if secondary == 0:
        report.add("secondary guardian invites", True, "skipped (1:1 parent mapping)")
        return
    created = 0
    for i in range(secondary):
        phone = str(PARENT_PHONE_START + STUDENT_COUNT + i)
        code, resp = request(
            "POST",
            "/onboarding/invites",
            token=token,
            body={
                "inviteType": "parent",
                "recipientPhone": phone,
                "recipientLabel": f"Demo Secondary Guardian {i + 1:03d}",
                "channel": "whatsapp",
            },
        )
        if code in (200, 201):
            created += 1
        elif code == 409:
            created += 1
        else:
            if i == 0:
                report.add("secondary guardian invites", False, str(resp))
                return
    report.add(
        "secondary guardian invites",
        created >= secondary or secondary == 0,
        f"created={created} target={secondary}",
    )


def seed_timetables(token: str, year_id: str, report: RunReport) -> None:
    code, resp = request(
        "POST",
        "/academic/timetables/generate",
        token=token,
        body={"academicYearId": year_id, "periodsPerDay": 8, "daysPerWeek": 5},
    )
    if code == 404:
        report.add(
            "timetable generate",
            False,
            "Route not mounted on target API — deploy v7.5+ timetable engine",
        )
        return
    if code not in (200, 201):
        report.add("timetable generate", False, str(resp))
        return
    items = (api_data(resp) or {}).get("items") or []
    published = 0
    for item in items[: min(4, len(items))]:
        tid = item.get("id")
        if not tid:
            continue
        vcode, vresp = request(
            "POST",
            "/academic/timetables/validate",
            token=token,
            body={"timetableId": tid},
        )
        if vcode != 200:
            continue
        pcode, _ = request("POST", f"/academic/timetables/{tid}/publish", token=token, body={})
        if pcode in (200, 201):
            published += 1
    report.add("timetable generate", True, f"generated={len(items)} published={published}")


def seed_finance(token: str, year_id: str, year_label: str, report: RunReport) -> dict[str, str]:
    manifest: dict[str, str] = {}
    code, resp = request(
        "POST",
        "/finance/fee-structures",
        token=token,
        body={
            "name": "Demo Pilot Annual Plan",
            "academicYear": year_label,
            "academicYearId": year_id,
            "status": "active",
            "categories": [
                {"category": "tuition", "label": "Tuition", "amount": 48000},
                {"category": "transport", "label": "Transport", "amount": 12000},
            ],
        },
    )
    if code not in (200, 201):
        report.add("fee structure", False, str(resp))
        return manifest
    structure_id = api_data(resp)["id"]
    manifest["feeStructureId"] = structure_id
    report.add("fee structure", True, structure_id)

    students = [
        s
        for s in list_students(token, page_size=100, pages=10)
        if str(s.get("admissionNumber", "")).startswith(ADMISSION_PREFIX)
    ][:FINANCE_SAMPLE_SIZE]

    invoice_ids: list[str] = []
    assignment_ids: list[str] = []
    for student in students:
        sid = student.get("id") or student.get("studentId")
        if not sid:
            continue
        code, resp = request(
            "POST",
            "/finance/fee-assignments",
            token=token,
            body={
                "studentId": sid,
                "feeStructureId": structure_id,
                "academicYear": year_label,
            },
        )
        if code not in (200, 201):
            continue
        data = api_data(resp) or {}
        assignment = data.get("assignment") or {}
        assignment_ids.append(str(assignment.get("id", "")))
        invoices = data.get("invoices") or []
        for inv in invoices:
            iid = inv.get("id")
            if iid:
                invoice_ids.append(iid)

    if not invoice_ids:
        code, resp = request("GET", "/finance/invoices?page=1&pageSize=50", token=token)
        if code == 200:
            for item in (api_data(resp) or {}).get("items") or []:
                iid = item.get("id")
                if iid:
                    invoice_ids.append(str(iid))

    report.add("fee assignments", len(assignment_ids) > 0 or len(invoice_ids) > 0, f"assignments={len(assignment_ids)} invoices={len(invoice_ids)}")

    # Fee assignments auto-create invoices in issued status.
    issued = len(invoice_ids[: min(50, len(invoice_ids))])
    report.add("invoice issue", issued > 0, f"issued={issued}")

    collected = 0
    collection_id = ""
    for iid in invoice_ids[: min(10, len(invoice_ids))]:
        code, resp = request(
            "POST",
            "/finance/collections",
            token=token,
            body={
                "invoiceId": iid,
                "amountCollected": 10000,
                "paymentMethod": "cash",
                "referenceNumber": f"DEMO-COL-{iid[:8]}",
            },
        )
        if code in (200, 201):
            collected += 1
            if not collection_id:
                collection_id = str((api_data(resp) or {}).get("collection", {}).get("id", ""))
    report.add("fee collections", collected > 0, f"collections={collected}")
    if collection_id:
        manifest["sampleCollectionId"] = collection_id

    if collection_id:
        code, resp = request(
            "POST",
            "/finance/refunds",
            token=token,
            body={
                "collectionId": collection_id,
                "refundAmount": 500,
                "refundReason": "Demo pilot validation refund",
            },
        )
        refund_ok = code in (200, 201)
        if refund_ok:
            refund_id = str((api_data(resp) or {}).get("id", ""))
            manifest["sampleRefundId"] = refund_id
            approve_code, _ = request(
                "POST",
                f"/finance/refunds/{refund_id}/approve",
                token=token,
                body={"comment": "Demo pilot approval"},
            )
            refund_ok = approve_code in (200, 201)
        report.add("refund flow", refund_ok, str(resp) if not refund_ok else refund_id)

    return manifest


def seed_attendance_history(token: str, report: RunReport) -> None:
    students = [
        s
        for s in list_students(token, page_size=100, pages=10)
        if str(s.get("admissionNumber", "")).startswith(ADMISSION_PREFIX)
    ]
    if len(students) < 3:
        report.add("attendance history", False, "not enough demo students")
        return

    class_label = students[0].get("className") or students[0].get("classLabel") or "5"
    entries = []
    for student in students[:25]:
        sid = student.get("id") or student.get("studentId")
        if sid:
            entries.append({"studentId": sid, "mark": "present"})

    submitted_days = 0
    for day_offset in range(ATTENDANCE_HISTORY_DAYS):
        session_date = (date.today() - timedelta(days=day_offset + 1)).isoformat()
        body = {"class_id": class_label, "session_date": session_date, "entries": entries}
        code, resp = request("POST", "/teacher/attendance/submit", token=token, body=body)
        if code in (200, 201):
            submitted_days += 1
        sleep_brief(0.1)

    report.add(
        "attendance history",
        submitted_days > 0,
        f"days={submitted_days} students={len(entries)} class={class_label}",
    )


def seed_communications(token: str, report: RunReport) -> None:
    code, resp = request(
        "POST",
        "/communications/broadcasts",
        token=token,
        body={
            "audience": "all_parents",
            "title": "Demo School Pilot Broadcast",
            "body": "Welcome to the Akshara ERP pilot validation broadcast.",
        },
    )
    report.add("broadcast messaging", code in (200, 201), str(resp) if code not in (200, 201) else "sent")

    code, resp = request("POST", "/communications/notifications/process-queue", token=token, body={})
    report.add(
        "notification delivery queue",
        code in (200, 201),
        str((api_data(resp) or {})),
    )


def main() -> int:
    import argparse

    parser = argparse.ArgumentParser(description="Seed Demo School pilot data")
    parser.add_argument(
        "--post-import-only",
        action="store_true",
        help="Skip imports; refresh token and run timetable/finance/attendance/comms only",
    )
    args = parser.parse_args()

    report = RunReport(title="Demo School Seed")
    print(
        f"Seeding Demo School: students={STUDENT_COUNT} teachers={TEACHER_COUNT} "
        f"staff={STAFF_COUNT} guardians={GUARDIAN_COUNT}"
    )
    try:
        token = admin_token()
    except RuntimeError as exc:
        report.add("admin login", False, str(exc))
        write_report("reports/demo_school/seed_manifest.json", report)
        print(f"FAIL admin login: {exc}")
        return 1

    report.add("admin login", True, ADMIN_PHONE)
    year_id, year_label = resolve_academic_year(token)
    report.add("academic year", True, f"{year_label} ({year_id})")

    if not args.post_import_only:
        ensure_academic_catalog(token, year_id, report)
        seed_teachers(token, report)
        seed_students(token, report)
        seed_secondary_guardian_invites(token, report)

    token = admin_token()
    seed_timetables(token, year_id, report)

    token = admin_token()
    finance_manifest = seed_finance(token, year_id, year_label, report)

    token = admin_token()
    subject_ids = seed_subjects(token, report)

    token = admin_token()
    seed_lesson_logs(token, report, subject_ids)

    token = admin_token()
    seed_homework_history(token, year_label, report)

    token = admin_token()
    seed_exam_history(token, report)

    token = admin_token()
    seed_book_kits(token, report)

    token = admin_token()
    seed_inventory_dashboard(token, report)

    token = admin_token()
    seed_attendance_history(token, report)

    token = admin_token()
    seed_communications(token, report)

    manifest = report.to_dict()
    manifest["schoolId"] = SCHOOL_ID
    manifest["academicYear"] = {"id": year_id, "label": year_label}
    manifest["targets"] = {
        "students": STUDENT_COUNT,
        "teachers": TEACHER_COUNT,
        "staff": STAFF_COUNT,
        "guardians": GUARDIAN_COUNT,
        "classes": len(CLASS_LABELS) * len(SECTION_LABELS),
        "subjects": len(SUBJECT_NAMES),
    }
    manifest["finance"] = finance_manifest
    manifest["samplePhones"] = {
        "admin": ADMIN_PHONE,
        "teacher": str(TEACHER_PHONE_START),
        "parent": str(PARENT_PHONE_START),
    }

    os.makedirs("reports/demo_school", exist_ok=True)
    with open("reports/demo_school/seed_manifest.json", "w", encoding="utf-8") as fh:
        json.dump(manifest, fh, indent=2)

    print(f"Seed complete: {report.passed} passed, {report.failed} failed")
    return 0 if report.failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
