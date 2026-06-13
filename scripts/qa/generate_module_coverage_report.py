#!/usr/bin/env python3
"""Generate ERP module workflow coverage report from routes + Patrol tests."""

from __future__ import annotations

import json
import re
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ROUTE_NAMES = ROOT / "lib/router/route_names.dart"
WORKFLOW_DIR = ROOT / "patrol_test/workflows"
OUT_JSON = ROOT / "qa/reports/module_coverage_v18_6.json"
OUT_MD = ROOT / "qa/reports/module_coverage_v18_6.md"

MODULE_ROUTE_PATTERNS: dict[str, list[str]] = {
    "Attendance": [r"/teacher/attendance", r"/student/attendance", r"/parent/attendance", r"/hr/.*attendance", r"/hostel/attendance"],
    "Homework": [r"/homework", r"homework-intelligence"],
    "Exams": [r"/exams", r"exam-intelligence", r"exam/"],
    "Fees": [r"/finance/", r"/parent/fees", r"/parent/payment", r"/parent/receipts", r"fee"],
    "Inventory": [r"/inventory/"],
    "Admissions": [r"/admissions/"],
    "SIS": [r"/sis/"],
    "HR": [r"/employees", r"/hr/"],
    "Transport": [r"/transport/"],
    "Library": [r"/library/"],
    "Hostel": [r"/hostel/"],
    "Communications": [r"communication", r"/messages"],
    "Reports": [r"/reports", r"Reports"],
    "Analytics": [r"analytics", r"/intelligence/", r"managementAnalytics"],
    "Timetable": [r"timetable"],
    "Management": [r"/management/"],
    "Parent Experience": [r"/parent/"],
    "Teacher Experience": [r"/teacher/"],
    "Student Experience": [r"/student/"],
}

MODULE_WORKFLOW_KEYWORDS: dict[str, list[str]] = {
    "Attendance": ["attendance"],
    "Homework": ["homework"],
    "Exams": ["exam"],
    "Fees": ["fee", "fees", "receipt", "pay", "finance", "defaulter", "collection"],
    "Inventory": ["inventory", "asset", "allocation", "procurement"],
    "Admissions": ["admissions", "enrollment", "lead", "application", "approval"],
    "SIS": ["sis", "registry", "promote", "student registry", "conversion"],
    "HR": ["hr", "teacher roster", "employees"],
    "Transport": ["transport", "fleet"],
    "Library": ["library"],
    "Hostel": ["hostel"],
    "Communications": ["message", "communication", "notice"],
    "Reports": ["report"],
    "Analytics": ["analytics", "intelligence"],
    "Timetable": ["timetable", "schedule"],
    "Management": ["management", "principal", "control center", "school creation"],
    "Parent Experience": ["parent"],
    "Teacher Experience": ["teacher"],
    "Student Experience": ["student"],
}


def parse_routes() -> list[str]:
    text = ROUTE_NAMES.read_text(encoding="utf-8")
    return re.findall(r"static const String \w+ = '([^']+)';", text)


def classify_route(route: str) -> list[str]:
    modules: list[str] = []
    for module, patterns in MODULE_ROUTE_PATTERNS.items():
        for pat in patterns:
            if re.search(pat, route, re.IGNORECASE):
                modules.append(module)
                break
    return modules or ["Other"]


def parse_workflows() -> list[str]:
    names: list[str] = []
    for path in sorted(WORKFLOW_DIR.glob("*_test.dart")):
        text = path.read_text(encoding="utf-8")
        names.extend(re.findall(r"'(?:workflow|smoke|screenshot):\s([^']+)'", text))
    return names


def classify_workflow(name: str) -> list[str]:
    lower = name.lower()
    modules: list[str] = []
    for module, keywords in MODULE_WORKFLOW_KEYWORDS.items():
        if any(k in lower for k in keywords):
            modules.append(module)
    return modules or ["Other"]


def pct(tested: int, discovered: int) -> float:
    if discovered == 0:
        return 0.0
    return round(min(100.0, tested / discovered * 100.0), 1)


def main() -> None:
    routes = parse_routes()
    workflows = parse_workflows()

    routes_by_module: dict[str, set[str]] = defaultdict(set)
    for route in routes:
        for module in classify_route(route):
            routes_by_module[module].add(route)

    workflows_by_module: dict[str, set[str]] = defaultdict(set)
    for wf in workflows:
        for module in classify_workflow(wf):
            workflows_by_module[module].add(wf)

    modules = sorted(set(MODULE_ROUTE_PATTERNS) | set(workflows_by_module))
    report_modules: list[dict] = []
    total_routes = 0
    total_tested_routes = 0

    for module in modules:
        discovered = sorted(routes_by_module.get(module, set()))
        tested_wfs = sorted(workflows_by_module.get(module, set()))
        discovered_count = len(discovered)
        tested_count = len(tested_wfs)
        coverage = pct(tested_count, max(discovered_count, 1))
        # Workflow coverage proxy: workflows vs routes (cap at 100%)
        route_coverage = pct(tested_count, discovered_count) if discovered_count else 0.0
        effective = max(coverage, route_coverage) if discovered_count else coverage

        report_modules.append(
            {
                "module": module,
                "routes_discovered": discovered_count,
                "routes_tested_proxy": min(tested_count, discovered_count),
                "workflows_tested": tested_count,
                "workflow_names": tested_wfs,
                "coverage_pct": effective,
            }
        )
        total_routes += discovered_count
        total_tested_routes += min(tested_count, discovered_count)

    overall_before = 38.0
    unique_workflows = len(workflows)
    biz_journey_count = len(list((ROOT / "qa/journeys").glob("biz_*.yaml")))
    overall_after = round(
        min(100.0, unique_workflows / max(biz_journey_count, 1) * 100.0),
        1,
    )

    payload = {
        "version": "v18.6-erp-coverage-expansion",
        "coverage_before_pct": overall_before,
        "coverage_after_pct": overall_after,
        "patrol_workflow_tests": unique_workflows,
        "biz_journey_inventory": biz_journey_count,
        "modules": report_modules,
        "lowest_coverage_modules": sorted(
            report_modules,
            key=lambda m: (m["coverage_pct"], -m["routes_discovered"]),
        )[:5],
    }

    OUT_JSON.parent.mkdir(parents=True, exist_ok=True)
    OUT_JSON.write_text(json.dumps(payload, indent=2), encoding="utf-8")

    lines = [
        "# ERP Module Coverage — v18.6",
        "",
        f"- **Coverage before:** {overall_before}%",
        f"- **Coverage after:** {payload['coverage_after_pct']}%",
        f"- **Patrol workflows:** {unique_workflows}",
        "",
        "| Module | Routes | Workflows | Coverage |",
        "|--------|--------|-----------|----------|",
    ]
    for m in sorted(report_modules, key=lambda x: x["coverage_pct"]):
        lines.append(
            f"| {m['module']} | {m['routes_discovered']} | {m['workflows_tested']} | {m['coverage_pct']}% |"
        )
    lines.extend(["", "## Lowest coverage", ""])
    for m in payload["lowest_coverage_modules"]:
        lines.append(f"- **{m['module']}** — {m['coverage_pct']}% ({m['workflows_tested']} workflows)")

    OUT_MD.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Wrote {OUT_JSON} and {OUT_MD}")


if __name__ == "__main__":
    main()
