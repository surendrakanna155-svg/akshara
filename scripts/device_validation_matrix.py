#!/usr/bin/env python3
"""Phase 21 v15.2 — Real device validation matrix (API smoke for all roles)."""
from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from demo_school_lib import RunReport, admin_token, login_phone, request, write_report, SCHOOL_ID

PROBE_PHONES = {
    "admin": "9876543210",
    "parent": "9876543211",
    "student": "9876543212",
    "teacher": "9876543213",
}

ROLE_FLOWS = {
    "admin": [
        ("dashboard", "/sis/dashboard"),
        ("finance", "/finance/dashboard"),
        ("inventory", "/inventory/distribution/dashboard"),
        ("intelligence", "/intelligence/principal/center"),
    ],
    "teacher": [
        ("dashboard", "/teacher/dashboard"),
        ("attendance", "/teacher/attendance/classes"),
        ("homework", "/teacher/homework"),
    ],
    "parent": [
        ("dashboard", "/parent/dashboard"),
        ("fees", "/parent/fees"),
        ("homework", "/parent/homework"),
        ("attendance", "/parent/attendance"),
    ],
    "student": [
        ("dashboard", "/student/dashboard"),
        ("homework", "/student/homework"),
        ("exams", "/student/exams"),
    ],
}


def main() -> int:
    report = RunReport(title="Device Validation Matrix")
    tokens: dict[str, str] = {}

    try:
        tokens["admin"] = admin_token()
        report.add("admin login", True, PROBE_PHONES["admin"])
    except RuntimeError as exc:
        report.add("admin login", False, str(exc))
        write_report("reports/phase21/device_validation.json", report)
        return 1

    for role, phone in PROBE_PHONES.items():
        if role == "admin":
            tokens[role] = tokens["admin"]
            continue
        scope = "parent" if role == "parent" else "student" if role == "student" else "school"
        try:
            tokens[role] = login_phone(phone, scope, SCHOOL_ID)
            report.add(f"{role} login", True, phone)
        except RuntimeError as exc:
            report.add(f"{role} login", False, str(exc))

    for role, flows in ROLE_FLOWS.items():
        token = tokens.get(role)
        if not token:
            continue
        for label, path in flows:
            code, resp = request("GET", path, token=token)
            ok = code in (200, 201)
            if code == 404:
                report.add(f"{role} {label}", False, f"404 — deploy required")
            else:
                report.add(f"{role} {label}", ok, f"http={code}")

    write_report("reports/phase21/device_validation.json", report)
    print(json.dumps(report.to_dict(), indent=2))
    print(f"Device matrix: {report.passed} passed, {report.failed} failed")
    return 0 if report.failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
