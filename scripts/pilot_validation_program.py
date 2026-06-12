#!/usr/bin/env python3
"""Akshara Pilot Validation Program — phases 1–10 API orchestration."""
from __future__ import annotations

import json
import subprocess
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from demo_school_lib import (
    PROBE_PARENT_PHONE,
    PROBE_TEACHER_PHONE,
    RunReport,
    SCHOOL_ID,
    admin_token,
    api_data,
    login_phone,
    request,
    write_report,
)

REPORT_DIR = Path("reports/pilot_validation")
REPORT_DIR.mkdir(parents=True, exist_ok=True)


def probe(report: RunReport, name: str, token: str, path: str, ok_codes: tuple[int, ...] = (200, 201)) -> None:
    started = time.perf_counter()
    code, resp = request("GET", path, token=token)
    elapsed_ms = int((time.perf_counter() - started) * 1000)
    ok = code in ok_codes
    if not ok and code == 403:
        err = (resp or {}).get("error", {}).get("message", "")
        report.add(name, False, f"http={code} {err} ({elapsed_ms}ms)")
    elif not ok and code == 404:
        report.add(name, False, f"404 deploy required ({elapsed_ms}ms)")
    else:
        report.add(name, ok, f"http={code} ({elapsed_ms}ms)")


def phase_principal(report: RunReport, admin: str) -> None:
    for name, path in [
        ("P1 school dashboard", "/sis/dashboard"),
        ("P1 operations hub", "/operations/hub"),
        ("P1 principal command", "/principal-command/center"),
        ("P1 student risk", "/intelligence/risk/students"),
        ("P1 teacher performance", "/intelligence/teacher-effectiveness/performance"),
        ("P1 attendance analytics", "/analytics/dashboard"),
        ("P1 fee analytics", "/finance/dashboard"),
        ("P1 inventory analytics", "/inventory/distribution/dashboard"),
        ("P1 school health", "/analytics/health"),
        ("P1 executive reports", "/intelligence/principal/center"),
    ]:
        probe(report, name, admin, path)


def phase_school_admin(report: RunReport, admin: str) -> None:
    for name, path in [
        ("P2 admissions", "/admissions/dashboard"),
        ("P2 SIS students", "/sis/students?page=1&pageSize=20"),
        ("P2 subjects", "/school/subjects"),
        ("P2 lesson logs", "/school/lesson-logs"),
        ("P2 timetable", "/academic/timetables/summary"),
        ("P2 pilot dashboard", "/school/pilot/dashboard"),
        ("P2 branding", "/school/branding"),
        ("P2 communications queue", "/communications/notifications/process-queue"),
    ]:
        if name == "P2 communications queue":
            code, resp = request("POST", path, token=admin, body={})
            report.add(name, code in (200, 201), f"http={code}")
        else:
            probe(report, name, admin, path)


def phase_teacher(report: RunReport, teacher: str) -> None:
    for name, path in [
        ("P3 attendance", "/teacher/attendance/classes"),
        ("P3 homework", "/teacher/homework"),
        ("P3 lesson logs", "/school/lesson-logs"),
        ("P3 lesson analytics", "/school/lesson-analytics/teacher"),
        ("P3 teacher assistant", "/teacher-assistant/insights"),
        ("P3 teacher success", "/intelligence/teacher/success-center"),
        ("P3 exam papers", "/education/question-papers"),
    ]:
        probe(report, name, teacher, path)


def phase_parent(report: RunReport, parent: str) -> None:
    for name, path in [
        ("P4 dashboard", "/parent/dashboard"),
        ("P4 attendance", "/parent/attendance"),
        ("P4 homework", "/parent/homework"),
        ("P4 fees", "/parent/fees"),
        ("P4 experience hub", "/parent/experience/hub"),
        ("P4 printable report", "/parent/experience/report/printable?studentId=student_1"),
        ("P4 guidance summary", "/parent/experience/summary?studentId=student_1"),
    ]:
        probe(report, name, parent, path)
    code, resp = request("GET", "/copilot/assistants", token=parent)
    report.add(
        "P4 no open AI copilot",
        code in (401, 403),
        f"parent copilot denied http={code}",
    )


def phase_student(report: RunReport, student: str) -> None:
    for name, path in [
        ("P5 dashboard", "/student/dashboard"),
        ("P5 homework", "/student/homework"),
        ("P5 exams", "/student/exams"),
        ("P5 attendance", "/student/attendance"),
    ]:
        probe(report, name, student, path)


def phase_accountant(report: RunReport, admin: str) -> None:
    for name, path in [
        ("P6 collections", "/finance/collections?page=1&pageSize=20"),
        ("P6 invoices", "/finance/invoices?page=1&pageSize=20"),
        ("P6 refunds", "/finance/refunds?page=1&pageSize=20"),
        ("P6 finance reports", "/finance/intelligence/executive"),
        ("P6 finance dashboard", "/finance/dashboard"),
    ]:
        probe(report, name, admin, path)


def phase_inventory(report: RunReport, admin: str) -> None:
    for name, path in [
        ("P7 inventory dashboard", "/inventory/dashboard"),
        ("P7 distribution", "/inventory/distribution/dashboard"),
        ("P7 distribution reports", "/inventory/distribution/reports"),
        ("P7 procurement", "/inventory/procurement"),
    ]:
        probe(report, name, admin, path)


def phase_performance(report: RunReport, admin: str) -> None:
    budgets = {500: 3000, 1000: 5000, 2000: 8000}
    for scale, budget_ms in budgets.items():
        started = time.perf_counter()
        code, _ = request("GET", f"/sis/students?page=1&pageSize={min(scale, 100)}", token=admin)
        elapsed = int((time.perf_counter() - started) * 1000)
        report.add(
            f"P8 SIS list scale={scale}",
            code == 200 and elapsed < budget_ms,
            f"http={code} {elapsed}ms budget={budget_ms}ms",
        )


def run_shell_step(report: RunReport, name: str, cmd: list[str]) -> None:
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=300, check=False)
        ok = proc.returncode == 0
        detail = (proc.stdout or proc.stderr or "").strip().splitlines()[-1] if proc.stdout or proc.stderr else f"exit={proc.returncode}"
        report.add(name, ok, detail[:200])
    except Exception as exc:
        report.add(name, False, str(exc))


def main() -> int:
    report = RunReport(title="Pilot Validation Program")
    root = Path(__file__).resolve().parents[1]

    run_shell_step(report, "P9 pilot readiness", ["bash", str(root / "scripts/pilot_readiness_verify.sh")])
    run_shell_step(report, "P9 device matrix", [sys.executable, str(root / "scripts/device_validation_matrix.py")])

    try:
        admin = admin_token()
        teacher = login_phone(PROBE_TEACHER_PHONE, "school", SCHOOL_ID)
        parent = login_phone(PROBE_PARENT_PHONE, "parent", SCHOOL_ID)
        student = login_phone(PROBE_STUDENT_PHONE, "student", SCHOOL_ID)
    except RuntimeError as exc:
        report.add("auth bootstrap", False, str(exc))
        write_report(str(REPORT_DIR / "program_report.json"), report)
        return 1

    phase_principal(report, admin)
    phase_school_admin(report, admin)
    phase_teacher(report, teacher)
    phase_parent(report, parent)
    phase_student(report, student)
    phase_accountant(report, admin)
    phase_inventory(report, admin)
    phase_performance(report, admin)

    write_report(str(REPORT_DIR / "program_report.json"), report)
    print(json.dumps(report.to_dict(), indent=2))
    print(f"Pilot validation: {report.passed} passed, {report.failed} failed")
    for step in report.steps:
        if not step.ok:
            print(f"  FAIL: {step.name} — {step.detail[:120]}")
    return 0 if report.failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
