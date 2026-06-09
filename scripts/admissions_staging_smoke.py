#!/usr/bin/env python3
"""Admissions staging E2E + security smoke tests."""
from __future__ import annotations

import json
import re
import subprocess
import sys
import urllib.error
import urllib.request

BASE = "https://oeicxjpewrumkfgyqnnj.supabase.co/functions/v1/api"
ORG_ID = "a1000000-0000-4000-8000-000000000001"
SCHOOL_A = "a2000000-0000-4000-8000-000000000001"
LEAD_SCHOOL_B = "b5000000-0000-4000-8000-000000000002"

PASS = 0
FAIL = 0


def log(msg: str) -> None:
    print(f"[smoke] {msg}")


def ok(name: str) -> None:
    global PASS
    PASS += 1
    log(f"PASS: {name}")


def bad(name: str, detail: str = "") -> None:
    global FAIL
    FAIL += 1
    log(f"FAIL: {name}" + (f" — {detail}" if detail else ""))


def request(
    method: str,
    path: str,
    token: str | None = None,
    body: dict | None = None,
) -> tuple[int, dict]:
    data = None
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    if body is not None:
        data = json.dumps(body).encode()
    req = urllib.request.Request(f"{BASE}{path}", data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            raw = resp.read().decode()
            return resp.status, json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        raw = e.read().decode()
        try:
            payload = json.loads(raw) if raw else {}
        except json.JSONDecodeError:
            payload = {"raw": raw}
        return e.code, payload


def login(phone: str, scope: str | None = None, school_id: str | None = None) -> str:
    _, login_resp = request("POST", "/auth/login", body={"identifier": phone, "type": "phone"})
    message = login_resp["data"]["message"]
    otp = re.search(r"Use code (\d+)", message).group(1)
    session_id = login_resp["data"]["sessionId"]
    verify_body: dict = {
        "identifier": phone,
        "type": "phone",
        "otp": otp,
        "sessionId": session_id,
    }
    if scope:
        verify_body["scope"] = scope
    if school_id:
        verify_body["schoolId"] = school_id
    _, verify_resp = request("POST", "/auth/verify-otp", body=verify_body)
    return verify_resp["data"]["accessToken"]


def sql_query_scalar(query: str, column: str = "id") -> str | None:
    result = subprocess.run(
        ["supabase", "db", "query", query, "--linked"],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        return None
    raw = result.stdout.strip()
    json_start = raw.find("{")
    if json_start < 0:
        return None
    try:
        payload = json.loads(raw[json_start:])
        rows = payload.get("rows", [])
        if not rows:
            return None
        return str(rows[0].get(column, "")) or None
    except json.JSONDecodeError:
        return None


def main() -> int:
    # Health probes
    _, health = request("GET", "/health/tenant-access")
    tests = health.get("data", {}).get("isolation", {}).get("tests", [])
    if health.get("data", {}).get("isolation", {}).get("pass") and len(tests) >= 11:
        ok(f"tenant-access {len(tests)} probes passing")
    else:
        bad("tenant-access probes", json.dumps(health.get("data", {})))

    # Auth regression
    admin = login("9876543210")
    parent = login("9876543211", "parent", SCHOOL_A)
    student = login("9876543212", "student", SCHOOL_A)
    for label, token in [("admin /auth/me", admin), ("parent /auth/me", parent), ("student /auth/me", student)]:
        code, _ = request("GET", "/auth/me", token=token)
        ok(f"auth {label}") if code == 200 else bad(f"auth {label}", str(code))

    # E2E flow
    log("E2E: Lead → Application → Document → Approval → Enrollment")
    code, lead_resp = request(
        "POST",
        "/admissions/leads",
        token=admin,
        body={
            "parent_name": "Smoke Parent",
            "student_name": "Smoke Student",
            "class_label": "5",
            "phone": "9999900001",
            "source": "walk_in",
            "counselor": "Smoke Counselor",
        },
    )
    lead_id = lead_resp.get("data", {}).get("id")
    ok(f"create lead ({lead_id})") if code == 201 and lead_id else bad("create lead", json.dumps(lead_resp))

    code, _ = request("GET", f"/admissions/leads/{lead_id}", token=admin)
    ok("get lead detail") if code == 200 else bad("get lead detail", str(code))

    code, upd = request(
        "PUT",
        f"/admissions/leads/{lead_id}",
        token=admin,
        body={"notes": "Smoke test note"},
    )
    ok("update lead") if code == 200 and upd.get("data", {}).get("notes") == "Smoke test note" else bad("update lead", json.dumps(upd))

    code, app_resp = request(
        "POST",
        "/admissions/applications",
        token=admin,
        body={
            "student_name": "Smoke Student",
            "class_label": "5",
            "parent_name": "Smoke Parent",
            "lead_id": lead_id,
            "counselor": "Smoke Counselor",
        },
    )
    app_id = app_resp.get("data", {}).get("id")
    ok(f"create application ({app_id})") if code == 201 and app_id else bad("create application", json.dumps(app_resp))

    code, submit = request("POST", f"/admissions/applications/{app_id}/submit", token=admin, body={})
    ok("submit application") if code == 200 and submit.get("data", {}).get("status") == "submitted" else bad("submit application", json.dumps(submit))

    code, doc_resp = request(
        "POST",
        "/admissions/documents/upload",
        token=admin,
        body={
            "lead_id": lead_id,
            "document_type": "birth_certificate",
            "file_name": "birth.pdf",
        },
    )
    doc_id = doc_resp.get("data", {}).get("id")
    ok(f"upload document ({doc_id})") if code == 201 and doc_id else bad("upload document", json.dumps(doc_resp))

    code, doc_ok = request(
        "POST",
        f"/admissions/documents/{doc_id}/approve",
        token=admin,
        body={"note": "Verified"},
    )
    ok("approve document") if code == 200 and doc_ok.get("data", {}).get("status") == "verified" else bad("approve document", json.dumps(doc_ok))

    approval_id = sql_query_scalar(
        f"SELECT id::text AS id FROM admissions_approvals WHERE application_id = '{app_id}' LIMIT 1;"
    )
    if approval_id:
        code, adm = request(
            "POST",
            f"/admissions/approval/{approval_id}/approve",
            token=admin,
            body={"comment": "Approved"},
        )
        ok("admission approval") if code == 200 and adm.get("data", {}).get("decision") == "approved" else bad("admission approval", json.dumps(adm))
    else:
        bad("resolve approval id for application", app_id or "")

    code, enroll = request(
        "POST",
        "/admissions/enrollments",
        token=admin,
        body={
            "application_id": app_id,
            "student": {
                "full_name": "Smoke Student Enrolled",
                "date_of_birth": "2015-01-01",
                "gender": "female",
            },
            "parent": {
                "guardian_name": "Staging Parent",
                "phone": "9876543211",
                "relationship": "mother",
            },
            "academic": {
                "seeking_class": "5",
                "section": "A",
                "academic_year": "2026-27",
            },
        },
    )
    student_id = enroll.get("data", {}).get("previewStudentId")
    adm_num = enroll.get("data", {}).get("generatedAdmissionNumber")
    if code == 201 and student_id and adm_num:
        ok(f"enrollment + student ({student_id}, {adm_num})")
    else:
        bad("enrollment", json.dumps(enroll))

    guardian_link = sql_query_scalar(
        f"SELECT count(*)::text AS id FROM student_guardians WHERE student_id = '{student_id}' AND guardian_user_id = 'a3000000-0000-4000-8000-000000000003';",
        column="id",
    )
    ok("parent link via guardian phone") if guardian_link == "1" else bad("parent link", f"count={guardian_link}")

    # Security
    code, _ = request("GET", f"/admissions/leads/{LEAD_SCHOOL_B}", token=admin)
    ok("School A cannot read School B lead (404)") if code == 404 else bad("cross-school lead", str(code))

    _, switch = request(
        "POST",
        "/auth/context/switch",
        token=admin,
        body={"scope": "organization", "organizationId": ORG_ID},
    )
    org_token = switch.get("data", {}).get("accessToken")
    code, _ = request("GET", "/admissions/leads", token=org_token)
    ok("org scope denied admissions (403)") if code == 403 else bad("org scope admissions", str(code))

    code, _ = request("GET", "/admissions/leads", token=parent)
    ok("parent scope denied admissions (403)") if code == 403 else bad("parent admissions", str(code))

    code, _ = request("GET", "/admissions/leads", token=student)
    ok("student scope denied admissions (403)") if code == 403 else bad("student admissions", str(code))

    log(f"Results: {PASS} passed, {FAIL} failed")
    return 0 if FAIL == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
