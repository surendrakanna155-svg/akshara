#!/usr/bin/env python3
"""Academic 5C.0c staging deployment verification."""
from __future__ import annotations

import concurrent.futures
import json
import os
import re
import sys
import urllib.error
import urllib.request
from dataclasses import dataclass, field
from typing import Any

BASE = os.environ.get(
    "API_BASE_URL",
    "https://oeicxjpewrumkfgyqnnj.supabase.co/functions/v1/api",
)
ORG_ID = "a1000000-0000-4000-8000-000000000001"
SCHOOL_A = "a2000000-0000-4000-8000-000000000001"
SCHOOL_B = "a2000000-0000-4000-8000-000000000002"
YEAR_A = "ce100000-0000-4000-8000-000000000001"
YEAR_B = "ce100000-0000-4000-8000-000000000002"
CLASS_A = "cf100000-0000-4000-8000-000000000001"
CLASS_B = "cf100000-0000-4000-8000-000000000003"
SECTION_A = "d0100000-0000-4000-8000-000000000001"
SECTION_B = "d0100000-0000-4000-8000-000000000003"
ASSIGN_A = "d2000000-0000-4000-8000-000000000001"
ASSIGN_B = "d2000000-0000-4000-8000-000000000002"
TEACHER_A = "d1000000-0000-4000-8000-000000000001"
TEACHER_B = "d1000000-0000-4000-8000-000000000002"


@dataclass
class Report:
    sections: dict[str, list[str]] = field(default_factory=dict)
    pass_count: int = 0
    fail_count: int = 0
    probe_report: dict[str, Any] | None = None

    def log(self, section: str, msg: str, ok: bool) -> None:
        self.sections.setdefault(section, []).append(f"{'PASS' if ok else 'FAIL'}: {msg}")
        if ok:
            self.pass_count += 1
        else:
            self.fail_count += 1


report = Report()


def request(
    method: str,
    path: str,
    token: str | None = None,
    body: dict | None = None,
) -> tuple[int, dict]:
    url = f"{BASE}{path}"
    data = json.dumps(body).encode() if body is not None else None
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            raw = resp.read().decode()
            return resp.status, json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        raw = e.read().decode()
        try:
            payload = json.loads(raw) if raw else {}
        except json.JSONDecodeError:
            payload = {"raw": raw}
        return e.code, payload


def login_phone(phone: str, scope: str = "", school_id: str = "") -> str:
    code, resp = request("POST", "/auth/login", body={"identifier": phone, "type": "phone"})
    if code != 200:
        raise RuntimeError(f"login failed {phone}: {resp}")
    msg = resp["data"]["message"]
    otp = re.search(r"Use code (\d+)", msg).group(1)
    session_id = resp["data"]["sessionId"]
    verify_body: dict[str, Any] = {
        "identifier": phone,
        "type": "phone",
        "otp": otp,
        "sessionId": session_id,
    }
    if scope:
        verify_body["scope"] = scope
        if school_id:
            verify_body["schoolId"] = school_id
    code, resp = request("POST", "/auth/verify-otp", body=verify_body)
    if code != 200:
        raise RuntimeError(f"verify failed {phone}: {resp}")
    return resp["data"]["accessToken"]


def verify_probes() -> None:
    section = "Probe Verification"
    code, resp = request("GET", "/health/tenant-access")
    report.probe_report = resp
    if code != 200:
        report.log(section, f"health endpoint HTTP {code}", False)
        return
    iso = resp.get("data", {}).get("isolation", {})
    tests = iso.get("tests", [])
    names = [t["name"] for t in tests]
    dupes = {n for n in names if names.count(n) > 1}
    report.log(section, f"probe count {len(tests)}/121", len(tests) == 121)
    report.log(section, f"all probes pass={iso.get('pass')}", iso.get("pass") is True)
    report.log(section, f"no duplicate probe names (dupes={len(dupes)})", len(dupes) == 0)
    failed = [t for t in tests if not t.get("pass")]
    report.log(section, f"no skipped/failed probes (failed={len(failed)})", len(failed) == 0)
    academic = [
        t for t in tests
        if "academic" in t["name"].lower()
        or "teacher_assignment" in t["name"].lower()
        or ("class" in t["name"].lower() and "sis" not in t["name"].lower())
    ]
    report.log(section, f"5C academic probes executed ({len(academic)})", len(academic) >= 20)
    for t in failed[:5]:
        report.log(section, f"failed probe: {t['name']}", False)


def verify_routes(admin: str) -> None:
    section = "Route Verification"

    def check(label: str, method: str, path: str, expected: int, body: dict | None = None) -> None:
        code, resp = request(method, path, token=admin, body=body)
        ok = code == expected
        if not ok:
            report.log(section, f"{label} expected {expected} got {code}: {resp.get('error', resp)}", False)
        else:
            report.log(section, f"{label} → {code}", True)

    check("GET /academic/years", "GET", "/academic/years", 200)
    check("GET /academic/classes", "GET", "/academic/classes", 200)
    check("GET /academic/sections", "GET", "/academic/sections", 200)
    check("GET /academic/teacher-assignments", "GET", "/academic/teacher-assignments", 200)

    ts = str(int(__import__("time").time()))
    year_body = {
        "yearLabel": f"Verify-{ts}",
        "startDate": "2028-04-01",
        "endDate": "2029-03-31",
        "isCurrent": False,
    }
    code, resp = request("POST", "/academic/years", token=admin, body=year_body)
    data = resp.get("data") or {}
    new_year = data.get("yearId", "")
    report.log(section, f"POST /academic/years → 201", code == 201 and bool(new_year))

    check(
        "PUT /academic/years/:id",
        "PUT",
        f"/academic/years/{new_year or YEAR_A}",
        200,
        {"yearLabel": f"Verify-Updated-{ts}"},
    )

    dup_year = {
        "yearLabel": "2026-27",
        "startDate": "2026-04-01",
        "endDate": "2027-03-31",
    }
    check("POST duplicate year label → 409", "POST", "/academic/years", 409, dup_year)

    check(
        "POST /academic/years missing fields → 422",
        "POST",
        "/academic/years",
        422,
        {"yearLabel": "Incomplete"},
    )

    class_body = {
        "academicYearId": YEAR_A,
        "className": f"VerifyClass-{ts}",
        "displayOrder": 99,
    }
    code, resp = request("POST", "/academic/classes", token=admin, body=class_body)
    data = resp.get("data") or {}
    new_class = data.get("classId", "")
    report.log(section, f"POST /academic/classes → 201", code == 201 and bool(new_class))

    check(
        "PUT /academic/classes/:id",
        "PUT",
        f"/academic/classes/{new_class or CLASS_A}",
        200,
        {"className": f"VerifyClass-Updated-{ts}"},
    )

    check(
        "POST duplicate class → 409",
        "POST",
        "/academic/classes",
        409,
        {"academicYearId": YEAR_A, "className": "5"},
    )

    section_body = {
        "classId": CLASS_A,
        "sectionName": f"Z-{ts}",
        "capacity": 40,
        "strength": 0,
    }
    code, resp = request("POST", "/academic/sections", token=admin, body=section_body)
    data = resp.get("data") or {}
    new_section = data.get("sectionId", "")
    report.log(section, f"POST /academic/sections → 201", code == 201 and bool(new_section))

    check(
        "PUT /academic/sections/:id",
        "PUT",
        f"/academic/sections/{new_section or SECTION_A}",
        200,
        {"strength": 1},
    )

    check(
        "POST duplicate section → 409",
        "POST",
        "/academic/sections",
        409,
        {"classId": CLASS_A, "sectionName": "A"},
    )

    assign_body = {
        "teacherId": TEACHER_A,
        "sectionId": new_section or SECTION_A,
        "role": "subject_teacher",
        "isPrimary": False,
    }
    code, resp = request("POST", "/academic/teacher-assignments", token=admin, body=assign_body)
    data = resp.get("data") or {}
    new_assign = data.get("assignmentId", "")
    ok = code == 201 and bool(new_assign)
    if not ok:
        report.log(
            section,
            f"POST /academic/teacher-assignments → 201 (got {code}: {resp.get('error')})",
            False,
        )
    else:
        report.log(section, "POST /academic/teacher-assignments → 201", True)

    check(
        "PUT /academic/teacher-assignments/:id",
        "PUT",
        f"/academic/teacher-assignments/{new_assign or ASSIGN_A}",
        200,
        {"role": "subject_teacher", "isPrimary": False},
    )

    check(
        "POST teacher not in school → 422",
        "POST",
        "/academic/teacher-assignments",
        422,
        {
            "teacherId": TEACHER_B,
            "sectionId": SECTION_A,
            "role": "subject_teacher",
            "isPrimary": False,
        },
    )

    check(
        "PUT cross-school year → 404",
        "PUT",
        f"/academic/years/{YEAR_B}",
        404,
        {"yearLabel": "Hack"},
    )
    check(
        "PUT cross-school class → 404",
        "PUT",
        f"/academic/classes/{CLASS_B}",
        404,
        {"className": "Hack"},
    )
    check(
        "PUT cross-school section → 404",
        "PUT",
        f"/academic/sections/{SECTION_B}",
        404,
        {"strength": 99},
    )
    check(
        "PUT cross-school assignment → 404",
        "PUT",
        f"/academic/teacher-assignments/{ASSIGN_B}",
        404,
        {"isPrimary": False},
    )


def verify_security(admin: str, org: str, parent: str, student: str) -> None:
    section = "Security Verification"
    routes = [
        ("GET", "/academic/years"),
        ("POST", "/academic/years"),
        ("PUT", f"/academic/years/{YEAR_A}"),
        ("GET", "/academic/classes"),
        ("POST", "/academic/classes"),
        ("PUT", f"/academic/classes/{CLASS_A}"),
        ("GET", "/academic/sections"),
        ("POST", "/academic/sections"),
        ("PUT", f"/academic/sections/{SECTION_A}"),
        ("GET", "/academic/teacher-assignments"),
        ("POST", "/academic/teacher-assignments"),
        ("PUT", f"/academic/teacher-assignments/{ASSIGN_A}"),
    ]
    for scope_label, token in [("org", org), ("parent", parent), ("student", student)]:
        for method, path in routes:
            body = {} if method != "GET" else None
            code, _ = request(method, path, token=token, body=body)
            report.log(
                section,
                f"{scope_label} JWT {method} {path} → 403",
                code == 403,
            )

    for method, path in [
        ("GET", "/academic/years"),
        ("GET", "/academic/classes"),
        ("GET", "/academic/sections"),
        ("GET", "/academic/teacher-assignments"),
    ]:
        code, _ = request(method, path, token=admin)
        ok = code == 200
        report.log(section, f"school admin {method} {path} → success ({code})", ok)


def verify_concurrency(admin: str) -> None:
    section = "Concurrency Verification"
    ts = str(int(__import__("time").time()))

    def create_current_year(i: int) -> int:
        code, resp = request(
            "POST",
            "/academic/years",
            token=admin,
            body={
                "yearLabel": f"RaceYear-{ts}-{i}",
                "startDate": "2030-04-01",
                "endDate": "2031-03-31",
                "isCurrent": True,
            },
        )
        return code

    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        codes = list(pool.map(create_current_year, [1, 2]))
    success = sum(1 for c in codes if c == 201)
    conflict = sum(1 for c in codes if c == 409)
    report.log(
        section,
        f"concurrent current-year writes: success={success} conflict={conflict} codes={codes}",
        success >= 1 and conflict >= 1,
    )

    section_target = SECTION_A
    def create_primary(i: int) -> int:
        code, _ = request(
            "POST",
            "/academic/teacher-assignments",
            token=admin,
            body={
                "teacherId": TEACHER_A,
                "sectionId": section_target,
                "role": "class_teacher",
                "isPrimary": True,
            },
        )
        return code

    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        ta_codes = list(pool.map(create_primary, [1, 2]))
    ta_success = sum(1 for c in ta_codes if c == 201)
    ta_conflict = sum(1 for c in ta_codes if c == 409)
    report.log(
        section,
        f"concurrent primary-teacher writes: success={ta_success} conflict={ta_conflict} codes={ta_codes}",
        ta_success >= 1 and ta_conflict >= 1,
    )


def verify_fixtures(admin: str) -> None:
    section = "Fixture Verification"

    code, resp = request("GET", "/academic/years", token=admin)
    items = resp.get("data", {}).get("items", [])
    year_ids = {i.get("yearId") for i in items}
    report.log(section, f"School A year fixture visible ({YEAR_A})", YEAR_A in year_ids)

    code, resp = request("GET", "/academic/classes", token=admin)
    items = resp.get("data", {}).get("items", [])
    class_ids = {i.get("classId") for i in items}
    report.log(section, f"School A class fixture visible ({CLASS_A})", CLASS_A in class_ids)

    code, resp = request("GET", f"/academic/sections?classId={CLASS_B}", token=admin)
    items = resp.get("data", {}).get("items", [])
    report.log(section, f"cross-school class filter returns 0 rows (got {len(items)})", len(items) == 0)

    code, resp = request(
        "GET",
        f"/academic/teacher-assignments?sectionId={SECTION_B}",
        token=admin,
    )
    items = resp.get("data", {}).get("items", [])
    report.log(section, f"cross-school section filter returns 0 rows (got {len(items)})", len(items) == 0)

    code, _ = request("PUT", f"/academic/years/{YEAR_B}", token=admin, body={"status": "active"})
    report.log(section, "cross-school year write → 404", code == 404)


def audit_module() -> None:
    section = "Audit Report"
    root = os.path.join(os.path.dirname(__file__), "..", "supabase", "functions", "_shared", "academic")
    hits: list[str] = []
    for name in os.listdir(root):
        if not name.endswith(".ts") or name.endswith("_test.ts"):
            continue
        path = os.path.join(root, name)
        with open(path, encoding="utf-8") as f:
            text = f.read()
        for term in ("service_role", "createServiceClient"):
            if term in text and "assertEquals" not in text:
                hits.append(f"{name}: {term}")
    report.log(section, f"service_role/createServiceClient occurrences: {len(hits)}", len(hits) == 0)


def print_report() -> None:
    print("\n=== ACADEMIC 5C.0c STAGING VERIFICATION ===\n")
    for section, lines in report.sections.items():
        print(f"## {section}")
        for line in lines:
            print(f"  {line}")
        print()
    print(f"TOTAL: {report.pass_count} passed, {report.fail_count} failed")
    verdict = (
        "PASS — Academic Foundation live on staging"
        if report.fail_count == 0
        else "FAIL — deployment blockers found"
    )
    print(f"\nVERDICT: {verdict}\n")


def main() -> int:
    admin = login_phone("9876543210")
    parent = login_phone("9876543211", "parent", SCHOOL_A)
    student = login_phone("9876543212", "student", SCHOOL_A)
    code, org_resp = request(
        "POST",
        "/auth/context/switch",
        token=admin,
        body={"scope": "organization", "organizationId": ORG_ID},
    )
    org = org_resp.get("data", {}).get("accessToken", "") if code == 200 else ""

    verify_probes()
    verify_routes(admin)
    verify_security(admin, org, parent, student)
    verify_concurrency(admin)
    verify_fixtures(admin)
    audit_module()
    print_report()

    if report.probe_report:
        probe_path = "/tmp/academic_probe_report_5c0c.json"
        with open(probe_path, "w", encoding="utf-8") as f:
            json.dump(report.probe_report, f, indent=2)
        print(f"Full probe report written to {probe_path}")

    return 0 if report.fail_count == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
