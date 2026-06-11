#!/usr/bin/env python3
"""Shared API client and constants for Demo School pilot seed/validation."""
from __future__ import annotations

import csv
import io
import json
import os
import re
import time
import urllib.error
import urllib.request
from dataclasses import dataclass, field
from typing import Any

BASE = os.environ.get(
    "API_BASE_URL",
    "https://oeicxjpewrumkfgyqnnj.supabase.co/functions/v1/api",
)
ORG_ID = os.environ.get("DEMO_ORG_ID", "a1000000-0000-4000-8000-000000000001")
SCHOOL_ID = os.environ.get("DEMO_SCHOOL_ID", "a2000000-0000-4000-8000-000000000001")
SCHOOL_NAME = os.environ.get("DEMO_SCHOOL_NAME", "Akshara Staging School")
ACADEMIC_YEAR_LABEL = os.environ.get("DEMO_ACADEMIC_YEAR", "2026-27")
ACADEMIC_YEAR_ID = os.environ.get(
    "DEMO_ACADEMIC_YEAR_ID",
    "ce100000-0000-4000-8000-000000000001",
)

ADMIN_PHONE = os.environ.get("DEMO_ADMIN_PHONE", "9876543210")
PROBE_PARENT_PHONE = "9876543211"
PROBE_STUDENT_PHONE = "9876543212"
PROBE_TEACHER_PHONE = "9876543213"

CLASS_LABELS = ["Nursery", "LKG", "UKG"] + [str(n) for n in range(1, 11)]
SECTION_LABELS = ["A", "B"]
ADMISSION_PREFIX = os.environ.get("DEMO_ADMISSION_PREFIX", "DEMO-2026")

TEACHER_PHONE_START = int(os.environ.get("DEMO_TEACHER_PHONE_START", "9000000001"))
PARENT_PHONE_START = int(os.environ.get("DEMO_PARENT_PHONE_START", "9000100001"))

STUDENT_COUNT = int(os.environ.get("DEMO_STUDENT_COUNT", "500"))
TEACHER_COUNT = int(os.environ.get("DEMO_TEACHER_COUNT", "20"))
STAFF_COUNT = int(os.environ.get("DEMO_STAFF_COUNT", "10"))
GUARDIAN_COUNT = int(os.environ.get("DEMO_GUARDIAN_COUNT", "500"))
IMPORT_BATCH_SIZE = int(os.environ.get("DEMO_IMPORT_BATCH_SIZE", "50"))
FINANCE_SAMPLE_SIZE = int(os.environ.get("DEMO_FINANCE_SAMPLE_SIZE", "150"))
ATTENDANCE_HISTORY_DAYS = int(os.environ.get("DEMO_ATTENDANCE_DAYS", "30"))
HOMEWORK_SAMPLE_CLASSES = int(os.environ.get("DEMO_HOMEWORK_CLASSES", "8"))
LESSON_LOG_SAMPLE = int(os.environ.get("DEMO_LESSON_LOG_SAMPLE", "40"))
EXAM_PAPER_SAMPLE = int(os.environ.get("DEMO_EXAM_PAPER_SAMPLE", "6"))
BOOK_KIT_DISTRIBUTIONS = int(os.environ.get("DEMO_BOOK_KIT_DISTRIBUTIONS", "50"))

SUBJECT_NAMES = [
    "English",
    "Mathematics",
    "Science",
    "Social Studies",
    "Hindi",
    "Computer Science",
    "Physical Education",
    "Art",
]

NON_TEACHING_STAFF_LABELS = [
    "Accountant",
    "Office Clerk",
    "Librarian",
    "Lab Assistant",
    "Transport Coordinator",
    "Store Manager",
    "Receptionist",
    "IT Support",
    "Counselor",
    "Security Supervisor",
]

REQUEST_TIMEOUT = int(os.environ.get("DEMO_API_TIMEOUT", "180"))


@dataclass
class StepResult:
    name: str
    ok: bool
    detail: str = ""
    data: dict[str, Any] = field(default_factory=dict)


@dataclass
class RunReport:
    title: str
    steps: list[StepResult] = field(default_factory=list)

    def add(self, name: str, ok: bool, detail: str = "", **data: Any) -> None:
        self.steps.append(StepResult(name, ok, detail, dict(data)))

    @property
    def passed(self) -> int:
        return sum(1 for s in self.steps if s.ok)

    @property
    def failed(self) -> int:
        return sum(1 for s in self.steps if not s.ok)

    def to_dict(self) -> dict[str, Any]:
        return {
            "title": self.title,
            "passed": self.passed,
            "failed": self.failed,
            "steps": [
                {"name": s.name, "ok": s.ok, "detail": s.detail, "data": s.data}
                for s in self.steps
            ],
        }


def request(
    method: str,
    path: str,
    token: str | None = None,
    body: dict | None = None,
    timeout: int = REQUEST_TIMEOUT,
) -> tuple[int, dict[str, Any]]:
    url = f"{BASE.rstrip('/')}{path}"
    payload = json.dumps(body).encode() if body is not None else None
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(url, data=payload, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            raw = resp.read().decode()
            return resp.status, json.loads(raw) if raw else {}
    except urllib.error.HTTPError as exc:
        raw = exc.read().decode()
        try:
            parsed = json.loads(raw) if raw else {}
        except json.JSONDecodeError:
            parsed = {"raw": raw}
        return exc.code, parsed


def login_phone(
    phone: str,
    scope: str = "",
    school_id: str = "",
    login_type: str = "phone",
    student_id: str = "",
) -> str:
    login_body: dict[str, Any] = {"identifier": phone, "type": login_type}
    if login_type == "student_id":
        login_body = {"identifier": student_id, "type": "student_id", "schoolId": school_id}
    code, resp = request("POST", "/auth/login", body=login_body)
    if code != 200:
        raise RuntimeError(f"login failed for {phone}: {resp}")
    msg = resp["data"]["message"]
    otp_match = re.search(r"Use code (\d+)", msg)
    if not otp_match:
        raise RuntimeError(f"OTP not found in login response: {resp}")
    verify_body: dict[str, Any] = {
        "identifier": student_id if login_type == "student_id" else phone,
        "type": login_type,
        "otp": otp_match.group(1),
        "sessionId": resp["data"]["sessionId"],
    }
    if scope:
        verify_body["scope"] = scope
        if school_id:
            verify_body["schoolId"] = school_id
    code, resp = request("POST", "/auth/verify-otp", body=verify_body)
    if code != 200:
        raise RuntimeError(f"verify-otp failed for {phone}: {resp}")
    return resp["data"]["accessToken"]


def admin_token() -> str:
    return login_phone(ADMIN_PHONE, "school", SCHOOL_ID)


def api_data(resp: dict[str, Any]) -> Any:
    return resp.get("data")


def csv_text(rows: list[dict[str, str]], fieldnames: list[str]) -> str:
    buf = io.StringIO()
    writer = csv.DictWriter(buf, fieldnames=fieldnames, lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)
    return buf.getvalue()


def student_rows(count: int) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    slots = [(c, s) for c in CLASS_LABELS for s in SECTION_LABELS]
    for i in range(count):
        class_label, section = slots[i % len(slots)]
        roll = str((i // len(SECTION_LABELS)) + 1)
        parent_phone = str(PARENT_PHONE_START + i)
        rows.append(
            {
                "studentName": f"Demo Student {i + 1:04d}",
                "admissionNumber": f"{ADMISSION_PREFIX}-{i + 1:04d}",
                "classLabel": class_label,
                "sectionLabel": section,
                "academicYear": ACADEMIC_YEAR_LABEL,
                "parentName": f"Demo Guardian {parent_phone[-4:]}",
                "parentPhone": parent_phone,
                "rollNumber": roll,
                "gender": "female" if i % 2 else "male",
                "dateOfBirth": f"201{ i % 6}-{(i % 12) + 1:02d}-15",
            }
        )
    return rows


def staff_rows() -> list[dict[str, str]]:
    """Principal + teachers + non-teaching staff (schoolAdmin role)."""
    rows: list[dict[str, str]] = [
        {
            "displayName": "Demo Principal",
            "phone": str(TEACHER_PHONE_START),
            "role": "principal",
            "email": "demo.principal@akshara-pilot.local",
        },
    ]
    for i in range(TEACHER_COUNT):
        rows.append(
            {
                "displayName": f"Demo Teacher {i + 1:02d}",
                "phone": str(TEACHER_PHONE_START + 1 + i),
                "role": "teacher",
                "email": f"demo.teacher{i + 1:02d}@akshara-pilot.local",
            }
        )
    staff_phone_start = TEACHER_PHONE_START + 1 + TEACHER_COUNT
    for i in range(STAFF_COUNT):
        label = NON_TEACHING_STAFF_LABELS[i % len(NON_TEACHING_STAFF_LABELS)]
        rows.append(
            {
                "displayName": f"Demo {label} {i + 1:02d}",
                "phone": str(staff_phone_start + i),
                "role": "schoolAdmin",
                "email": f"demo.staff{i + 1:02d}@akshara-pilot.local",
            }
        )
    return rows


def teacher_rows(count: int) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    for i in range(count):
        rows.append(
            {
                "displayName": f"Demo Teacher {i + 1:02d}",
                "phone": str(TEACHER_PHONE_START + i),
                "role": "principal" if i == 0 else "teacher",
                "email": f"demo.teacher{i + 1:02d}@akshara-pilot.local",
            }
        )
    return rows


def resolve_academic_year(token: str) -> tuple[str, str]:
    """Return (year_id, year_label), creating the demo year if needed."""
    code, resp = request("GET", "/academic/years", token=token)
    if code == 200:
        for item in (api_data(resp) or {}).get("items", []):
            label = str(item.get("yearLabel") or item.get("year_label") or "")
            if label == ACADEMIC_YEAR_LABEL:
                year_id = _entity_id(item, "yearId", "id")
                if year_id:
                    return year_id, label

    code, resp = request(
        "POST",
        "/academic/years",
        token=token,
        body={
            "yearLabel": ACADEMIC_YEAR_LABEL,
            "startDate": "2026-04-01",
            "endDate": "2027-03-31",
            "isCurrent": True,
            "status": "active",
        },
    )
    if code not in (200, 201):
        raise RuntimeError(f"failed to create academic year: {resp}")
    data = api_data(resp) or {}
    return _entity_id(data, "yearId", "id"), ACADEMIC_YEAR_LABEL


def _entity_id(item: dict, *keys: str) -> str:
    for key in keys:
        value = item.get(key)
        if value:
            return str(value)
    return ""


def import_preview_commit(
    token: str,
    import_type: str,
    file_name: str,
    rows: list[dict[str, str]],
    fieldnames: list[str],
) -> dict[str, Any]:
    csv_payload = csv_text(rows, fieldnames)
    path = f"/onboarding/imports/{import_type}s/preview"
    code, resp = request(
        token=token,
        method="POST",
        path=path,
        body={"fileName": file_name, "csvText": csv_payload},
    )
    if code not in (200, 201):
        raise RuntimeError(f"{import_type} preview failed: {resp}")
    data = api_data(resp) or {}
    job = data.get("job") or data
    job_id = job.get("id") or job.get("jobId")
    if not job_id:
        raise RuntimeError(f"{import_type} preview missing job id: {resp}")
    code, resp = request(
        token=token,
        method="POST",
        path=f"/onboarding/imports/{job_id}/commit",
        body={},
    )
    if code not in (200, 201):
        raise RuntimeError(f"{import_type} commit failed: {resp}")
    commit_data = api_data(resp) or {}
    return commit_data.get("job") or commit_data


def list_students(token: str, page_size: int = 100, pages: int = 30) -> list[dict[str, Any]]:
    items: list[dict[str, Any]] = []
    for page in range(1, pages + 1):
        code, resp = request(
            "GET",
            f"/sis/students?page={page}&pageSize={page_size}",
            token=token,
        )
        if code != 200:
            break
        data = api_data(resp) or {}
        batch = data.get("items") or data.get("students") or []
        if not batch:
            break
        items.extend(batch)
        pagination = data.get("pagination") or {}
        if not pagination.get("hasMore", False):
            break
    return items


def write_report(path: str, report: RunReport) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(report.to_dict(), fh, indent=2)


def sleep_brief(seconds: float = 0.2) -> None:
    time.sleep(seconds)
