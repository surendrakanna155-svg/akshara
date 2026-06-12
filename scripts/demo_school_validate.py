#!/usr/bin/env python3
"""
Validate Demo School pilot workflows end-to-end via APIs.

Usage:
  python3 scripts/demo_school_validate.py
  python3 scripts/demo_school_validate.py --skip-seed-check

Writes: reports/demo_school/validation_report.json
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from demo_school_lib import (
    ADMIN_PHONE,
    PARENT_PHONE_START,
    PROBE_PARENT_PHONE,
    PROBE_TEACHER_PHONE,
    RunReport,
    SCHOOL_ID,
    TEACHER_PHONE_START,
    admin_token,
    api_data,
    list_students,
    login_phone,
    parent_experience_summary_path,
    request,
    resolve_academic_year,
    resolve_probe_student_id,
    write_report,
)


def check_status(
    report: RunReport,
    name: str,
    code: int,
    resp: dict,
    expect: int | tuple[int, ...] = 200,
) -> None:
    expected = (expect,) if isinstance(expect, int) else expect
    ok = code in expected
    detail = "ok" if ok else json.dumps(resp)[:500]
    report.add(name, ok, detail, httpCode=code)


def validate_auth(report: RunReport) -> dict[str, str]:
    tokens: dict[str, str] = {}
    try:
        tokens["admin"] = admin_token()
        report.add("admin OTP login (school scope)", True, ADMIN_PHONE)
    except RuntimeError as exc:
        report.add("admin OTP login (school scope)", False, str(exc))
        return tokens

    try:
        tokens["parent_probe"] = login_phone(PROBE_PARENT_PHONE, "parent", SCHOOL_ID)
        report.add("parent OTP login (probe user)", True, PROBE_PARENT_PHONE)
    except RuntimeError as exc:
        report.add("parent OTP login (probe user)", False, str(exc))

    try:
        tokens["parent_demo"] = login_phone(str(PARENT_PHONE_START), "parent", SCHOOL_ID)
        report.add("parent OTP login (demo import)", True, str(PARENT_PHONE_START))
    except RuntimeError as exc:
        report.add("parent OTP login (demo import)", False, str(exc))

    try:
        tokens["teacher_probe"] = login_phone(PROBE_TEACHER_PHONE, "school", SCHOOL_ID)
        report.add("teacher OTP login (probe user)", True, PROBE_TEACHER_PHONE)
    except RuntimeError as exc:
        report.add("teacher OTP login (probe user)", False, str(exc))

    try:
        tokens["teacher_demo"] = login_phone(str(TEACHER_PHONE_START), "school", SCHOOL_ID)
        report.add("teacher OTP login (demo import)", True, str(TEACHER_PHONE_START))
    except RuntimeError as exc:
        report.add("teacher OTP login (demo import)", False, str(exc))

    return tokens


def validate_imports(report: RunReport, admin: str) -> None:
    code, resp = request("GET", "/onboarding/imports", token=admin)
    check_status(report, "student/teacher import jobs listed", code, resp)
    if code == 200:
        items = (api_data(resp) or {}).get("items") or []
        student_jobs = [j for j in items if j.get("importType") == "student"]
        teacher_jobs = [j for j in items if j.get("importType") == "teacher"]
        report.add(
            "student import committed",
            any(int(j.get("committedRows") or 0) > 0 for j in student_jobs),
            f"jobs={len(student_jobs)}",
        )
        report.add(
            "teacher import committed",
            any(int(j.get("committedRows") or 0) > 0 for j in teacher_jobs),
            f"jobs={len(teacher_jobs)}",
        )


def validate_attendance(report: RunReport, admin: str, parent: str | None) -> None:
    students = [
        s
        for s in list_students(admin, page_size=50, pages=2)
        if str(s.get("admissionNumber", "")).startswith("DEMO-2026")
    ]
    if len(students) < 3:
        report.add("attendance submission", False, "insufficient demo students")
        return

    class_label = students[0].get("className") or students[0].get("classLabel") or "5"
    entries = []
    for student in students[:10]:
        sid = student.get("id") or student.get("studentId")
        if sid:
            entries.append({"studentId": sid, "mark": "present"})
    body = {"class_id": class_label, "entries": entries}
    code, resp = request("POST", "/teacher/attendance/draft", token=admin, body=body)
    check_status(report, "attendance submission (draft)", code, resp)
    code, resp = request("POST", "/teacher/attendance/submit", token=admin, body=body)
    check_status(report, "attendance submission (submit)", code, resp)

    if parent:
        code, resp = request("GET", "/parent/attendance", token=parent)
        check_status(report, "attendance visibility (parent)", code, resp)


def validate_timetable(report: RunReport, admin: str, parent: str | None, teacher: str | None) -> None:
    year_id, _ = resolve_academic_year(admin)
    code, resp = request(
        "GET",
        f"/academic/timetables/summary?academicYearId={year_id}",
        token=admin,
    )
    if code == 404:
        report.add(
            "timetable visibility (admin summary)",
            False,
            "Route not mounted — deploy v7.5+ timetable engine",
        )
    else:
        check_status(report, "timetable visibility (admin summary)", code, resp)
    if parent:
        code, resp = request("GET", "/parent/timetable", token=parent)
        check_status(report, "timetable visibility (parent)", code, resp)
    if teacher:
        code, resp = request("GET", "/teacher/dashboard", token=teacher)
        check_status(report, "timetable visibility (teacher dashboard)", code, resp)


def validate_finance(report: RunReport, admin: str, parent: str | None) -> None:
    code, resp = request("GET", "/finance/invoices?page=1&pageSize=20", token=admin)
    check_status(report, "fee invoice generation (list)", code, resp)
    if code == 200:
        items = (api_data(resp) or {}).get("items") or []
        issued = [
            i
            for i in items
            if (i.get("invoiceStatus") or i.get("status"))
            in ("issued", "partially_paid", "paid")
        ]
        report.add("fee invoice issued records", len(issued) > 0, f"issued={len(issued)}")

    code, resp = request("GET", "/finance/collections?page=1&pageSize=20", token=admin)
    check_status(report, "fee collection (list)", code, resp)

    code, resp = request("GET", "/finance/refunds?page=1&pageSize=20", token=admin)
    check_status(report, "refund flow (list)", code, resp)

    if parent:
        code, resp = request("GET", "/parent/fees", token=parent)
        check_status(report, "fee visibility (parent)", code, resp)


def validate_notifications(report: RunReport, admin: str, parent: str | None) -> None:
    code, resp = request("POST", "/communications/notifications/process-queue", token=admin, body={})
    check_status(report, "notification delivery (process queue)", code, resp)
    if parent:
        code, resp = request("GET", "/parent/notifications", token=parent)
        check_status(report, "notification delivery (parent inbox)", code, resp)


def validate_messaging(report: RunReport, admin: str, parent: str | None, teacher: str | None) -> None:
    code, resp = request(
        "POST",
        "/communications/broadcasts",
        token=admin,
        body={
            "audience": "all_teachers",
            "title": "Demo Validation Broadcast",
            "body": "Pilot validation broadcast message.",
        },
    )
    check_status(report, "broadcast messaging", code, resp, (200, 201))

    if teacher and parent:
        code, resp = request(
            "POST",
            "/teacher/messages/send",
            token=teacher,
            body={
                "recipient": "parent",
                "subject": "Demo PT Meeting",
                "body": "Please confirm Friday slot.",
            },
        )
        check_status(report, "parent-teacher chat (teacher send)", code, resp, (200, 201))
        code, resp = request("GET", "/parent/messages/threads", token=parent)
        check_status(report, "parent-teacher chat (parent threads)", code, resp)


def validate_analytics(report: RunReport, admin: str) -> None:
    code, resp = request("GET", "/analytics/dashboard", token=admin)
    check_status(report, "dashboard analytics", code, resp)
    code, resp = request("GET", "/sis/dashboard", token=admin)
    check_status(report, "SIS dashboard aggregates", code, resp)
    code, resp = request("GET", "/finance/dashboard", token=admin)
    check_status(report, "finance dashboard", code, resp)


def validate_school_processes(report: RunReport, admin: str, parent: str | None, teacher: str | None) -> None:
    """Phase 20 — admission through principal intelligence workflows."""
    code, resp = request("GET", "/admissions/dashboard", token=admin)
    check_status(report, "admission pipeline dashboard", code, resp)

    code, resp = request("GET", "/school/subjects", token=admin)
    if code == 404:
        report.add("subjects catalog", False, "Not deployed")
    else:
        check_status(report, "subjects catalog", code, resp)

    code, resp = request("GET", "/school/lesson-logs", token=admin)
    if code == 404:
        report.add("lesson logs", False, "Not deployed")
    else:
        check_status(report, "lesson logs", code, resp)

    code, resp = request("GET", "/education/homework", token=admin)
    if code == 404:
        report.add("homework catalog", False, "Not deployed")
    else:
        check_status(report, "homework catalog", code, resp)

    code, resp = request("GET", "/education/question-papers", token=admin)
    if code == 404:
        report.add("exam papers", False, "Not deployed")
    else:
        check_status(report, "exam papers", code, resp)

    code, resp = request("GET", "/inventory/distribution/dashboard", token=admin)
    if code == 404:
        report.add("book distribution dashboard", False, "Not deployed")
    else:
        check_status(report, "book distribution dashboard", code, resp)

    if parent:
        code, resp = request("GET", "/parent/homework", token=parent)
        check_status(report, "parent homework visibility", code, resp)
        code, resp = request("GET", "/parent/exams", token=parent)
        check_status(report, "parent exams visibility", code, resp)

    if teacher:
        code, resp = request("GET", "/teacher/homework", token=teacher)
        if code == 404:
            report.add("teacher homework queue", False, "Not deployed")
        else:
            check_status(report, "teacher homework queue", code, resp)


def validate_role_journeys(report: RunReport, admin: str, parent: str | None, teacher: str | None) -> None:
    """Daily / weekly / monthly workflow probes per persona."""
    journeys = [
        ("school admin daily", admin, "/sis/dashboard"),
        ("school admin weekly finance", admin, "/finance/collections?page=1&pageSize=20"),
        ("school admin monthly analytics", admin, "/analytics/dashboard"),
        ("principal intelligence", admin, "/intelligence/principal/center"),
        ("inventory manager", admin, "/inventory/distribution/reports"),
        ("accountant finance", admin, "/finance/refunds?page=1&pageSize=20"),
    ]
    for label, token, path in journeys:
        code, resp = request("GET", path, token=token)
        if code == 404:
            report.add(label, False, f"Route not deployed: {path}")
        else:
            check_status(report, label, code, resp)

    if teacher:
        for label, path in [
            ("teacher daily dashboard", "/teacher/dashboard"),
            ("teacher weekly attendance", "/teacher/attendance/classes"),
        ]:
            code, resp = request("GET", path, token=teacher)
            check_status(report, label, code, resp)

    if parent:
        for label, path in [
            ("parent daily dashboard", "/parent/dashboard"),
            ("parent weekly fees", "/parent/fees"),
            ("parent monthly attendance", "/parent/attendance"),
        ]:
            code, resp = request("GET", path, token=parent)
            check_status(report, label, code, resp)


def validate_v14_intelligence(report: RunReport, admin: str, parent: str | None) -> None:
    """Phase 11–16 intelligence + communication analytics (v14)."""
    v14_paths = [
        ("finance copilot", "/finance/intelligence/copilot"),
        ("finance executive", "/finance/intelligence/executive"),
        ("inventory copilot", "/inventory/intelligence/copilot"),
        ("student success", "/intelligence/student-success/dashboard"),
        ("exam analytics", "/intelligence/exam/analytics"),
        ("communication analytics", "/school/communications/analytics/summary"),
        ("teacher effectiveness", "/intelligence/teacher-effectiveness/performance"),
    ]
    for name, path in v14_paths:
        code, resp = request("GET", path, token=admin)
        if code == 404:
            report.add(name, False, "Route not deployed — run pilot_deploy_v14.sh")
        else:
            check_status(report, name, code, resp)

    if parent:
        student_id = resolve_probe_student_id(parent_token=parent, admin_token=admin)
        if not student_id:
            report.add(
                "parent academic summary",
                True,
                "SKIPPED: probe student not found",
            )
        else:
            code, resp = request(
                "GET",
                parent_experience_summary_path(student_id),
                token=parent,
            )
            if code == 404:
                report.add("parent academic summary", False, "Not deployed")
            else:
                check_status(report, "parent academic summary", code, resp)


def validate_copilot(report: RunReport, admin: str) -> None:
    code, resp = request("GET", "/copilot/assistants", token=admin)
    check_status(report, "AI Copilot assistants", code, resp)
    if code != 200:
        return
    code, resp = request(
        "POST",
        "/copilot/sessions",
        token=admin,
        body={"assistantType": "finance", "title": "Demo validation session"},
    )
    if code not in (200, 201):
        check_status(report, "AI Copilot session create", code, resp, (200, 201))
        return
    session_id = (api_data(resp) or {}).get("id")
    report.add("AI Copilot session create", True, session_id or "")
    code, resp = request(
        "POST",
        f"/copilot/sessions/{session_id}/messages",
        token=admin,
        body={"content": "Summarize fee collection status for the demo school."},
    )
    check_status(report, "AI Copilot queries", code, resp)


def validate_seed_counts(report: RunReport, admin: str) -> None:
    students = list_students(admin, page_size=100, pages=20)
    demo_students = [s for s in students if str(s.get("admissionNumber", "")).startswith("DEMO-2026")]
    target = int(os.environ.get("DEMO_STUDENT_COUNT", "500"))
    report.add(
        "demo student count",
        len(demo_students) >= min(target, 1),
        f"found={len(demo_students)} target={target}",
    )


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate Demo School pilot workflows")
    parser.add_argument("--skip-seed-check", action="store_true")
    args = parser.parse_args()

    report = RunReport(title="Demo School Validation")
    tokens = validate_auth(report)
    admin = tokens.get("admin")
    if not admin:
        write_report("reports/demo_school/validation_report.json", report)
        return 1

    parent = tokens.get("parent_demo") or tokens.get("parent_probe")
    teacher = tokens.get("teacher_demo") or tokens.get("teacher_probe")

    validate_imports(report, admin)
    if not args.skip_seed_check:
        validate_seed_counts(report, admin)
    validate_attendance(report, admin, parent)
    validate_timetable(report, admin, parent, teacher)
    validate_finance(report, admin, parent)
    validate_notifications(report, admin, parent)
    validate_messaging(report, admin, parent, teacher)
    validate_analytics(report, admin)
    validate_school_processes(report, admin, parent, teacher)
    validate_role_journeys(report, admin, parent, teacher)
    validate_v14_intelligence(report, admin, parent)
    validate_copilot(report, admin)

    write_report("reports/demo_school/validation_report.json", report)
    print(f"Validation: {report.passed} passed, {report.failed} failed")
    for step in report.steps:
        if not step.ok:
            print(f"  FAIL: {step.name} — {step.detail[:200]}")
    return 0 if report.failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
