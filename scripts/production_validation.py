#!/usr/bin/env python3
"""
Production validation orchestrator — feature freeze / pilot readiness only.

Runs full-scale demo seed, multi-school isolation checks, performance timings,
and delegates to existing verify scripts.

Writes: reports/production_validation/results.json
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parent))

from demo_school_lib import (
    ADMIN_PHONE,
    BASE,
    ORG_ID,
    PARENT_PHONE_START,
    SCHOOL_ID,
    admin_token,
    api_data,
    list_students,
    login_phone,
    request,
    resolve_academic_year,
)

REPORT_DIR = Path("reports/production_validation")
RESULTS_PATH = REPORT_DIR / "results.json"

SCHOOL_A = SCHOOL_ID
SCHOOL_B = "a2000000-0000-4000-8000-000000000002"
STUDENT_PROBE_B = "a4000000-0000-4000-8000-000000000002"
LEAD_PROBE_B = "b5000000-0000-4000-8000-000000000002"
PARENT_PROBE_A = "9876543211"


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def timed_request(
    method: str,
    path: str,
    token: str | None = None,
    body: dict | None = None,
) -> tuple[float, int, dict[str, Any]]:
    start = time.perf_counter()
    code, resp = request(method, path, token=token, body=body)
    elapsed_ms = round((time.perf_counter() - start) * 1000, 1)
    return elapsed_ms, code, resp


def run_subprocess(label: str, cmd: list[str], env: dict[str, str] | None = None) -> dict[str, Any]:
    start = time.perf_counter()
    merged_env = {**os.environ, **(env or {})}
    proc = subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        env=merged_env,
        cwd=Path(__file__).resolve().parent.parent,
    )
    elapsed_s = round(time.perf_counter() - start, 1)
    return {
        "label": label,
        "command": " ".join(cmd),
        "exitCode": proc.returncode,
        "durationSeconds": elapsed_s,
        "stdoutTail": proc.stdout[-4000:] if proc.stdout else "",
        "stderrTail": proc.stderr[-2000:] if proc.stderr else "",
        "ok": proc.returncode == 0,
    }


def measure_performance(admin: str, year_id: str) -> dict[str, Any]:
    benchmarks: list[dict[str, Any]] = []

    def bench(name: str, method: str, path: str, body: dict | None = None) -> None:
        ms, code, resp = timed_request(method, path, token=admin, body=body)
        benchmarks.append(
            {
                "name": name,
                "method": method,
                "path": path,
                "latencyMs": ms,
                "httpCode": code,
                "ok": code in (200, 201),
                "error": None if code in (200, 201) else str(resp.get("error", resp))[:200],
            }
        )

    bench("finance dashboard", "GET", "/finance/dashboard")
    bench("sis dashboard", "GET", "/sis/dashboard")
    bench("admissions dashboard", "GET", "/admissions/dashboard")
    bench("analytics dashboard", "GET", "/analytics/dashboard")
    bench("analytics health", "GET", "/analytics/health")
    bench("copilot assistants", "GET", "/copilot/assistants")
    bench("timetable summary", "GET", f"/academic/timetables/summary?academicYearId={year_id}")
    bench("finance inventory reconciliation", "GET", "/finance/inventory-reconciliation/dashboard")

    ms, code, resp = timed_request(
        "POST",
        "/communications/broadcasts",
        token=admin,
        body={
            "audience": "all_teachers",
            "title": "Production Validation Broadcast",
            "body": "Timing probe broadcast.",
        },
    )
    benchmarks.append(
        {
            "name": "broadcast send",
            "method": "POST",
            "path": "/communications/broadcasts",
            "latencyMs": ms,
            "httpCode": code,
            "ok": code in (200, 201),
        }
    )

    ms, code, resp = timed_request("POST", "/copilot/sessions", token=admin, body={
        "assistantType": "finance",
        "title": "Production validation copilot timing",
    })
    session_id = (api_data(resp) or {}).get("id") if code in (200, 201) else None
    benchmarks.append(
        {
            "name": "copilot session create",
            "method": "POST",
            "path": "/copilot/sessions",
            "latencyMs": ms,
            "httpCode": code,
            "ok": code in (200, 201),
        }
    )
    if session_id:
        ms, code, _ = timed_request(
            "POST",
            f"/copilot/sessions/{session_id}/messages",
            token=admin,
            body={"content": "Summarize outstanding fee invoices for this school."},
        )
        benchmarks.append(
            {
                "name": "copilot message query",
                "method": "POST",
                "path": f"/copilot/sessions/{session_id}/messages",
                "latencyMs": ms,
                "httpCode": code,
                "ok": code in (200, 201),
            }
        )

    return {"benchmarks": benchmarks, "capturedAt": utc_now()}


def verify_multi_school(admin_a: str) -> dict[str, Any]:
    checks: list[dict[str, Any]] = []

    def add(name: str, ok: bool, detail: str, **extra: Any) -> None:
        checks.append({"name": name, "ok": ok, "detail": detail, **extra})

    ms, code, health = timed_request("GET", "/health/tenant-access")
    isolation = (api_data(health) or {}).get("isolation") or {}
    probe_count = len(isolation.get("tests") or [])
    probe_pass = isolation.get("pass") is True
    add(
        "tenant isolation probes",
        probe_pass and probe_count >= 200,
        f"pass={probe_pass} count={probe_count}",
        latencyMs=ms,
    )

    ms, code, _ = timed_request("GET", f"/sis/students/{STUDENT_PROBE_B}", token=admin_a)
    add("School A admin cannot read School B student", code in (403, 404), f"http={code}", latencyMs=ms)

    ms, code, _ = timed_request("GET", f"/admissions/leads/{LEAD_PROBE_B}", token=admin_a)
    add("School A admin cannot read School B lead", code in (403, 404), f"http={code}", latencyMs=ms)

    _, code_a, dash_a = timed_request("GET", "/analytics/dashboard", token=admin_a)
    students_a = list_students(admin_a, page_size=100, pages=10)
    demo_a = [s for s in students_a if str(s.get("admissionNumber", "")).startswith("DEMO-")]
    analytics_a = api_data(dash_a) or {}
    add(
        "analytics scoped to School A demo dataset",
        code_a == 200 and len(demo_a) >= 1,
        f"demoStudents={len(demo_a)} analyticsKeys={list(analytics_a.keys())[:6]}",
    )

    _, code, copilot = timed_request("GET", "/copilot/assistants", token=admin_a)
    items = (api_data(copilot) or {}).get("items") or []
    add("copilot assistants (School A scope)", code == 200 and len(items) >= 1, f"assistants={len(items)}")

    _, code, sess_resp = timed_request(
        "POST",
        "/copilot/sessions",
        token=admin_a,
        body={"assistantType": "finance", "title": "Isolation probe session"},
    )
    session_id = (api_data(sess_resp) or {}).get("id")
    if session_id:
        _, cross_code, _ = timed_request(
            "GET",
            f"/copilot/sessions/{session_id}",
            token=admin_a,
        )
        add("copilot session readable in same school scope", cross_code == 200, f"http={cross_code}")
    else:
        add("copilot session readable in same school scope", False, f"create failed http={code}")

    parent_a = login_phone(PARENT_PROBE_A, "parent", SCHOOL_A)
    _, code, _ = timed_request("GET", "/parent/notifications", token=parent_a)
    add("School A parent notifications accessible", code == 200, f"http={code}")

    _, cross_parent_code, _ = timed_request(
        "GET",
        f"/sis/students/{STUDENT_PROBE_B}",
        token=parent_a,
    )
    add(
        "School A parent cannot read School B student",
        cross_parent_code in (403, 404),
        f"http={cross_parent_code}",
    )

    _, b_code, _ = timed_request(
        "POST",
        "/communications/broadcasts",
        token=admin_a,
        body={
            "audience": "all_parents",
            "title": "School A isolation broadcast",
            "body": "School A only message.",
        },
    )
    add("School A broadcast accepted", b_code in (200, 201), f"http={b_code}")

    try:
        login_phone(ADMIN_PHONE, "school", SCHOOL_B)
        add("Demo School B admin provisioning", False, "unexpected — membership should not exist")
    except RuntimeError:
        add(
            "Demo School B admin provisioning",
            True,
            "expected MEMBERSHIP_NOT_FOUND — School B uses probe tenant; full demo seed requires separate admin",
        )

    passed = sum(1 for c in checks if c["ok"])
    return {
        "schoolA": SCHOOL_A,
        "schoolB": SCHOOL_B,
        "checks": checks,
        "passed": passed,
        "failed": len(checks) - passed,
        "capturedAt": utc_now(),
    }


def dataset_summary(admin: str) -> dict[str, Any]:
    students = list_students(admin, page_size=100, pages=20)
    demo = [s for s in students if str(s.get("admissionNumber", "")).startswith("DEMO-")]
    _, code, imports = timed_request("GET", "/onboarding/imports", token=admin)
    jobs = (api_data(imports) or {}).get("items") or [] if code == 200 else []
    teacher_committed = sum(
        int(j.get("committedRows") or 0)
        for j in jobs
        if j.get("importType") == "teacher"
    )
    student_committed = sum(
        int(j.get("committedRows") or 0)
        for j in jobs
        if j.get("importType") == "student"
    )
    _, inv_code, inv_resp = timed_request("GET", "/finance/invoices?page=1&pageSize=1", token=admin)
    inv_total = (api_data(inv_resp) or {}).get("total") or len((api_data(inv_resp) or {}).get("items") or [])
    return {
        "demoStudentsListed": len(demo),
        "totalStudentsListed": len(students),
        "studentImportCommittedRows": student_committed,
        "teacherImportCommittedRows": teacher_committed,
        "financeInvoiceTotalHint": inv_total,
        "targets": {
            "students": int(os.environ.get("DEMO_STUDENT_COUNT", "500")),
            "teachers": int(os.environ.get("DEMO_TEACHER_COUNT", "35")),
            "guardians": int(os.environ.get("DEMO_GUARDIAN_COUNT", "750")),
        },
    }


def main() -> int:
    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    results: dict[str, Any] = {
        "title": "Akshara ERP Production Validation",
        "startedAt": utc_now(),
        "apiBaseUrl": BASE,
        "organizationId": ORG_ID,
        "demoSchoolA": SCHOOL_A,
        "demoSchoolB": SCHOOL_B,
        "phases": {},
    }

    skip_seed = os.environ.get("SKIP_FULL_SEED", "").lower() in ("1", "true", "yes")

    if not skip_seed:
        print("=== Phase 1: Full Demo School scale seed (500/35/750) ===")
        seed_env = {
            "DEMO_STUDENT_COUNT": os.environ.get("DEMO_STUDENT_COUNT", "500"),
            "DEMO_TEACHER_COUNT": os.environ.get("DEMO_TEACHER_COUNT", "35"),
            "DEMO_GUARDIAN_COUNT": os.environ.get("DEMO_GUARDIAN_COUNT", "750"),
            "DEMO_FINANCE_SAMPLE_SIZE": os.environ.get("DEMO_FINANCE_SAMPLE_SIZE", "100"),
            "DEMO_ATTENDANCE_DAYS": os.environ.get("DEMO_ATTENDANCE_DAYS", "14"),
        }
        results["phases"]["fullSeed"] = run_subprocess(
            "demo_school_seed.py",
            [sys.executable, "scripts/demo_school_seed.py"],
            seed_env,
        )
    else:
        results["phases"]["fullSeed"] = {"skipped": True, "reason": "SKIP_FULL_SEED set"}

    print("=== Phase 2: Auth + dataset summary ===")
    admin = admin_token()
    year_id, year_label = resolve_academic_year(admin)
    results["academicYear"] = {"id": year_id, "label": year_label}
    results["dataset"] = dataset_summary(admin)

    print("=== Phase 3: Multi-school isolation ===")
    results["multiSchool"] = verify_multi_school(admin)

    print("=== Phase 4: Performance benchmarks ===")
    results["performance"] = measure_performance(admin, year_id)

    print("=== Phase 5: Existing verification scripts ===")
    results["phases"]["demoValidate"] = run_subprocess(
        "demo_school_validate.py",
        [sys.executable, "scripts/demo_school_validate.py"],
    )
    results["phases"]["pilotStagingVerify"] = run_subprocess(
        "pilot_staging_verify.sh",
        ["bash", "scripts/pilot_staging_verify.sh"],
    )
    results["phases"]["productionLaunchVerify"] = run_subprocess(
        "production_launch_verify.sh",
        ["bash", "scripts/production_launch_verify.sh"],
    )

    results["finishedAt"] = utc_now()
    failures = []
    if results["phases"].get("fullSeed", {}).get("ok") is False:
        failures.append("fullSeed")
    if results["multiSchool"]["failed"] > 0:
        failures.append("multiSchool")
    for key in ("demoValidate", "pilotStagingVerify", "productionLaunchVerify"):
        if results["phases"].get(key, {}).get("ok") is False:
            failures.append(key)
    perf_fail = [b for b in results["performance"]["benchmarks"] if not b["ok"]]
    if perf_fail:
        failures.append(f"performance({len(perf_fail)})")
    results["overallPass"] = len(failures) == 0
    results["failures"] = failures

    with open(RESULTS_PATH, "w", encoding="utf-8") as fh:
        json.dump(results, fh, indent=2)

    print(f"\nResults written to {RESULTS_PATH}")
    print(f"Overall: {'PASS' if results['overallPass'] else 'FAIL'} — {failures or 'none'}")
    return 0 if results["overallPass"] else 1


if __name__ == "__main__":
    sys.exit(main())
