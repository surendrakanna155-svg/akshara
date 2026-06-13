#!/usr/bin/env python3
"""Generate Patrol journey test Dart files from journey definitions."""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "patrol_test" / "journeys" / "generated_journeys_test.dart"

JOURNEYS = [
    # Admissions
    ("erp admissions dashboard", "superAdmin", None, "Total Leads"),
    ("erp admissions leads", "superAdmin", "Admissions", "Leads"),
    ("erp admissions enrollment", "superAdmin", "Admissions", "Enrollment"),
    ("erp admissions reports", "principal", "Admissions", "Reports"),
    ("erp admissions approval", "principal", "Admissions", "Approval"),
    # Finance
    ("erp finance dashboard", "finance", None, "Fee Collected (MTD)"),
    ("erp finance collections", "finance", "Finance", "Collections"),
    ("erp finance defaulters", "finance", "Finance", "Defaulters"),
    ("erp finance structures", "finance", "Finance", "Fee Structures"),
    ("erp finance reports", "finance", "Finance", "Reports"),
    ("erp finance refunds", "finance", "Finance", "Refunds"),
    ("erp finance receipt verify", "finance", "Finance", "Receipt"),
    ("erp fee collect", "finance", "Finance", "Collect"),
    ("erp fee generate", "finance", "Finance", "Generate"),
    # HR
    ("erp hr employees", "superAdmin", "HR", "Employees"),
    ("erp hr attendance", "superAdmin", "HR", "Attendance"),
    ("erp hr payroll", "superAdmin", "HR", "Payroll"),
    ("erp hr create teacher nav", "superAdmin", "HR", "Employees"),
    ("erp hr settings", "superAdmin", "HR", "HR"),
    # SIS
    ("erp sis students", "superAdmin", "SIS", "Students"),
    ("erp sis onboarding", "superAdmin", "SIS", "Students"),
    ("erp sis student edit", "superAdmin", "SIS", "Students"),
    ("erp student promote nav", "superAdmin", "SIS", "Students"),
    ("erp school creation nav", "superAdmin", "Management", "School"),
    # Inventory
    ("erp inventory assets", "inventory", None, "Total Assets"),
    ("erp inventory distribution", "inventory", "Inventory", "Distribution"),
    ("erp inventory maintenance", "inventory", "Inventory", "Maintenance"),
    # Management
    ("erp management analytics", "principal", None, "Principal overview"),
    ("erp management settings", "principal", "Management", "Settings"),
    ("erp management tasks", "principal", "Management", "Tasks"),
    ("erp control center", "superAdmin", "Management", "Control"),
    ("erp principal mgmt", "principal", None, "Principal overview"),
    # Other ERP
    ("erp communications mgmt", "superAdmin", "Management", "Communication"),
    ("erp exam reports", "superAdmin", "Education", "Exam"),
    ("erp homework intel", "superAdmin", "Education", "Homework"),
    ("erp timetable mgmt", "superAdmin", "Education", "Timetable"),
    ("erp transport routes", "superAdmin", "Transport", "Routes"),
    ("erp hostel rooms", "superAdmin", "Hostel", "Rooms"),
    ("erp library catalog", "superAdmin", "Library", "Catalog"),
    ("erp alumni registry", "superAdmin", "Management", "Alumni"),
    # Teacher mobile
    ("teacher home", "teacher", None, "Today's Classes"),
    ("teacher attendance mark", "teacher", None, "Today's Classes"),
    ("teacher attendance submit", "teacher", None, "Today's Classes"),
    ("teacher homework queue", "teacher", None, "Today's Classes"),
    ("teacher homework review", "teacher", None, "Today's Classes"),
    ("teacher exams", "teacher", None, "Today's Classes"),
    ("teacher timetable", "teacher", None, "Today's Classes"),
    ("teacher messages", "teacher", None, "Today's Classes"),
    ("teacher leave", "teacher", None, "Today's Classes"),
    ("teacher settings", "teacher", None, "Today's Classes"),
    # Parent mobile
    ("parent home refresh", "parent", None, "Fees"),
    ("parent fees tab", "parent", None, "Fees"),
    ("parent homework", "parent", None, "Fees"),
    ("parent attendance detail", "parent", None, "Fees"),
    ("parent notices", "parent", None, "Fees"),
    ("parent events", "parent", None, "Fees"),
    ("parent profile", "parent", None, "Fees"),
    ("parent timetable", "parent", None, "Fees"),
    ("parent pay fee", "parent", None, "Fees"),
    ("parent receipts", "parent", None, "Fees"),
    # Student mobile
    ("student home", "student", None, "Home"),
    ("student attendance", "student", None, "Home"),
    ("student homework due", "student", None, "Home"),
    ("student exam schedule", "student", None, "Home"),
    ("student notices", "student", None, "Home"),
    ("student profile", "student", None, "Home"),
    ("student settings", "student", None, "Home"),
    ("student timetable day", "student", None, "Home"),
    # Workflows
    ("workflow school creation", "superAdmin", "Management", "School"),
    ("workflow teacher creation", "superAdmin", "HR", "Employees"),
    ("workflow student creation", "superAdmin", "SIS", "Students"),
    ("workflow parent creation", "superAdmin", "SIS", "Students"),
    ("workflow attendance", "teacher", None, "Today's Classes"),
    ("workflow homework", "teacher", None, "Today's Classes"),
    ("workflow fees", "finance", None, "Fee Collected (MTD)"),
    ("workflow inventory", "inventory", None, "Total Assets"),
    ("workflow exams", "superAdmin", "Education", "Exam"),
    ("workflow reports", "finance", "Finance", "Reports"),
    ("workflow timetable", "superAdmin", "Education", "Timetable"),
    ("workflow communications", "superAdmin", "Management", "Communication"),
    ("workflow analytics", "principal", None, "Principal overview"),
]

PERSONA_MAP = {
    "principal": "QaLoginPersona.principal",
    "teacher": "QaLoginPersona.teacher",
    "parent": "QaLoginPersona.parent",
    "student": "QaLoginPersona.student",
    "finance": "QaLoginPersona.finance",
    "inventory": "QaLoginPersona.inventory",
    "superAdmin": "QaLoginPersona.superAdmin",
}


def dart_string(value: str) -> str:
    if "'" in value:
        escaped = value.replace('"', r'\"')
        return f'"{escaped}"'
    return f"'{value}'"


def emit() -> str:
    lines = [
        "// GENERATED — do not edit by hand. Run: python3 scripts/qa/generate_patrol_journeys.py",
        "import 'package:patrol/patrol.dart';",
        "",
        "import 'package:akshara_erp/features/auth/qa_login_persona.dart';",
        "",
        "import '../helpers/patrol_app.dart';",
        "import '../helpers/patrol_helpers.dart';",
        "",
        "void main() {",
    ]
    for name, persona, module, anchor in JOURNEYS:
        persona_expr = PERSONA_MAP[persona]
        lines.append(f"  patrolTest(")
        lines.append(f"    'journey: {name}',")
        lines.append(f"    config: aksharaPatrolConfig(),")
        lines.append(f"    ($) async {{")
        if module:
            lines.append(
                f"      await openErpModule($, {persona_expr}, {dart_string(module)});"
            )
        else:
            lines.append(f"      await bootstrapAndLogin($, {persona_expr});")
        lines.append(
            f"      await assertVisibleText($, {dart_string(anchor)}, timeout: const Duration(seconds: 25));"
        )
        slug = name.replace(" ", "_").replace("/", "_")
        lines.append(
            f"      await capturePatrolScreenshot($, 'journey_{slug}', subdir: 'journeys');"
        )
        lines.append(f"    }},")
        lines.append(f"  );")
        lines.append("")
    lines.append("}")
    return "\n".join(lines) + "\n"


def main() -> None:
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(emit(), encoding="utf-8")
    manifest = ROOT / "qa" / "patrol" / "journey_manifest.json"
    manifest.parent.mkdir(parents=True, exist_ok=True)
    manifest.write_text(
        json.dumps(
            [{"name": j[0], "persona": j[1], "module": j[2], "anchor": j[3]} for j in JOURNEYS],
            indent=2,
        ),
        encoding="utf-8",
    )
    print(f"Wrote {OUT} ({len(JOURNEYS)} journeys)")
    print(f"Wrote {manifest}")


if __name__ == "__main__":
    main()
