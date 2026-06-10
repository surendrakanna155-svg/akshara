#!/usr/bin/env python3
"""Backfill nullable academic catalog FK columns (5C.2a).

Rules:
- FK columns only — never modify TEXT labels
- Year label normalization matches Flutter/server (trim, dash, whitespace)
- Exact class/section name match — no fuzzy matching
- Idempotent updates (only WHERE fk IS NULL)
"""
from __future__ import annotations

import argparse
import csv
import json
import os
import re
import sys
from dataclasses import dataclass, field
from typing import Any

try:
    import psycopg
except ImportError:
    print("Install psycopg: pip install 'psycopg[binary]'", file=sys.stderr)
    sys.exit(1)


def normalize_academic_year_label(label: str) -> str:
    text = label.strip().replace("–", "-").replace("—", "-")
    return re.sub(r"\s+", "", text)


@dataclass
class MismatchRow:
    table: str
    row_id: str
    reason: str
    academic_year: str
    class_name: str
    section_name: str


@dataclass
class BackfillReport:
    updated: dict[str, int] = field(default_factory=dict)
    mismatches: list[MismatchRow] = field(default_factory=list)

    def add_mismatch(
        self,
        table: str,
        row_id: str,
        reason: str,
        academic_year: str,
        class_name: str,
        section_name: str,
    ) -> None:
        self.mismatches.append(
            MismatchRow(table, row_id, reason, academic_year, class_name, section_name)
        )


def load_years(conn: psycopg.Connection) -> list[dict[str, Any]]:
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT id, organization_id, school_id, year_label, status
            FROM academic_years
            """
        )
        cols = [d.name for d in cur.description]
        return [dict(zip(cols, row)) for row in cur.fetchall()]


def load_classes(conn: psycopg.Connection) -> list[dict[str, Any]]:
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT id, organization_id, school_id, academic_year_id, class_name, status
            FROM classes
            """
        )
        cols = [d.name for d in cur.description]
        return [dict(zip(cols, row)) for row in cur.fetchall()]


def load_sections(conn: psycopg.Connection) -> list[dict[str, Any]]:
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT id, organization_id, school_id, class_id, section_name, status
            FROM sections
            """
        )
        cols = [d.name for d in cur.description]
        return [dict(zip(cols, row)) for row in cur.fetchall()]


def resolve_year(
    years: list[dict[str, Any]],
    org_id: str,
    school_id: str,
    label: str,
    report: BackfillReport,
    table: str,
    row_id: str,
    class_name: str,
    section_name: str,
) -> str | None:
    normalized = normalize_academic_year_label(label)
    if not normalized:
        report.add_mismatch(
            table, row_id, "missing_year_context", label, class_name, section_name
        )
        return None
    matches = [
        y
        for y in years
        if y["organization_id"] == org_id
        and y["school_id"] == school_id
        and normalize_academic_year_label(y["year_label"]) == normalized
    ]
    if not matches:
        report.add_mismatch(
            table, row_id, "year_not_found", label, class_name, section_name
        )
        return None
    if len(matches) > 1:
        report.add_mismatch(
            table, row_id, "ambiguous_class", label, class_name, section_name
        )
        return None
    year = matches[0]
    if year["status"] != "active":
        report.add_mismatch(
            table, row_id, "inactive_catalog", label, class_name, section_name
        )
        return None
    return str(year["id"])


def resolve_class(
    classes: list[dict[str, Any]],
    org_id: str,
    school_id: str,
    year_id: str,
    class_name: str,
    report: BackfillReport,
    table: str,
    row_id: str,
    academic_year: str,
    section_name: str,
) -> str | None:
    trimmed = class_name.strip()
    if not trimmed:
        return None
    matches = [
        c
        for c in classes
        if c["organization_id"] == org_id
        and c["school_id"] == school_id
        and c["academic_year_id"] == year_id
        and c["class_name"] == trimmed
    ]
    if not matches:
        report.add_mismatch(
            table, row_id, "class_not_found", academic_year, class_name, section_name
        )
        return None
    if len(matches) > 1:
        report.add_mismatch(
            table, row_id, "ambiguous_class", academic_year, class_name, section_name
        )
        return None
    cls = matches[0]
    if cls["status"] != "active":
        report.add_mismatch(
            table, row_id, "inactive_catalog", academic_year, class_name, section_name
        )
        return None
    return str(cls["id"])


def resolve_section(
    sections: list[dict[str, Any]],
    org_id: str,
    school_id: str,
    class_id: str,
    section_name: str,
    report: BackfillReport,
    table: str,
    row_id: str,
    academic_year: str,
    class_name: str,
) -> str | None:
    if section_name is None or section_name.strip() == "":
        return None
    trimmed = section_name.strip()
    matches = [
        s
        for s in sections
        if s["organization_id"] == org_id
        and s["school_id"] == school_id
        and s["class_id"] == class_id
        and s["section_name"] == trimmed
    ]
    if not matches:
        report.add_mismatch(
            table, row_id, "section_not_found", academic_year, class_name, section_name
        )
        return None
    if len(matches) > 1:
        report.add_mismatch(
            table, row_id, "ambiguous_section", academic_year, class_name, section_name
        )
        return None
    sec = matches[0]
    if sec["status"] != "active":
        report.add_mismatch(
            table, row_id, "inactive_catalog", academic_year, class_name, section_name
        )
        return None
    return str(sec["id"])


def backfill_sis_enrollments(
    conn: psycopg.Connection,
    years: list[dict],
    classes: list[dict],
    sections: list[dict],
    report: BackfillReport,
    dry_run: bool,
) -> None:
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT id, organization_id, school_id, academic_year, class_name, section_name,
                   academic_year_id, class_id, section_id
            FROM sis_student_enrollments
            WHERE academic_year_id IS NULL OR class_id IS NULL OR section_id IS NULL
            """
        )
        rows = cur.fetchall()
    updated = 0
    for row in rows:
        row_id, org_id, school_id, ay, cn, sn, ay_id, c_id, s_id = row
        year_id = ay_id or resolve_year(
            years, org_id, school_id, ay or "", report,
            "sis_student_enrollments", str(row_id), cn or "", sn or "",
        )
        class_id = c_id
        section_id = s_id
        if year_id and class_id is None and cn:
            class_id = resolve_class(
                classes, org_id, school_id, year_id, cn, report,
                "sis_student_enrollments", str(row_id), ay or "", sn or "",
            )
        if class_id and section_id is None and sn and str(sn).strip():
            section_id = resolve_section(
                sections, org_id, school_id, class_id, sn, report,
                "sis_student_enrollments", str(row_id), ay or "", cn or "",
            )
        if not dry_run and (year_id or class_id or section_id):
            with conn.cursor() as cur:
                cur.execute(
                    """
                    UPDATE sis_student_enrollments
                    SET academic_year_id = COALESCE(academic_year_id, %s),
                        class_id = COALESCE(class_id, %s),
                        section_id = COALESCE(section_id, %s)
                    WHERE id = %s
                      AND (academic_year_id IS NULL OR class_id IS NULL OR section_id IS NULL)
                    """,
                    (year_id, class_id, section_id, row_id),
                )
            updated += 1
    report.updated["sis_student_enrollments"] = updated


def backfill_admissions_enrollments(
    conn: psycopg.Connection,
    years: list[dict],
    classes: list[dict],
    sections: list[dict],
    report: BackfillReport,
    dry_run: bool,
) -> None:
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT id, organization_id, school_id, academic_year, seeking_class, section,
                   academic_year_id, class_id, section_id
            FROM admissions_enrollments
            WHERE academic_year_id IS NULL OR class_id IS NULL OR section_id IS NULL
            """
        )
        rows = cur.fetchall()
    updated = 0
    for row in rows:
        row_id, org_id, school_id, ay, cn, sn, ay_id, c_id, s_id = row
        year_id = ay_id or resolve_year(
            years, org_id, school_id, ay or "", report,
            "admissions_enrollments", str(row_id), cn or "", sn or "",
        )
        class_id = c_id
        section_id = s_id
        if year_id and class_id is None and cn:
            class_id = resolve_class(
                classes, org_id, school_id, year_id, cn, report,
                "admissions_enrollments", str(row_id), ay or "", sn or "",
            )
        if class_id and section_id is None and sn and str(sn).strip():
            section_id = resolve_section(
                sections, org_id, school_id, class_id, sn, report,
                "admissions_enrollments", str(row_id), ay or "", cn or "",
            )
        if not dry_run and (year_id or class_id or section_id):
            with conn.cursor() as cur:
                cur.execute(
                    """
                    UPDATE admissions_enrollments
                    SET academic_year_id = COALESCE(academic_year_id, %s),
                        class_id = COALESCE(class_id, %s),
                        section_id = COALESCE(section_id, %s)
                    WHERE id = %s
                      AND (academic_year_id IS NULL OR class_id IS NULL OR section_id IS NULL)
                    """,
                    (year_id, class_id, section_id, row_id),
                )
            updated += 1
    report.updated["admissions_enrollments"] = updated


def backfill_finance_fee_structures(
    conn: psycopg.Connection,
    years: list[dict],
    report: BackfillReport,
    dry_run: bool,
) -> None:
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT id, organization_id, school_id, academic_year, academic_year_id
            FROM finance_fee_structures
            WHERE academic_year_id IS NULL
            """
        )
        rows = cur.fetchall()
    updated = 0
    for row in rows:
        row_id, org_id, school_id, ay, ay_id = row
        year_id = ay_id or resolve_year(
            years, org_id, school_id, ay or "", report,
            "finance_fee_structures", str(row_id), "", "",
        )
        if not dry_run and year_id:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    UPDATE finance_fee_structures
                    SET academic_year_id = COALESCE(academic_year_id, %s)
                    WHERE id = %s AND academic_year_id IS NULL
                    """,
                    (year_id, row_id),
                )
            updated += 1
    report.updated["finance_fee_structures"] = updated


def write_reports(report: BackfillReport, out_dir: str) -> None:
    os.makedirs(out_dir, exist_ok=True)
    json_path = os.path.join(out_dir, "backfill_mismatch_report.json")
    csv_path = os.path.join(out_dir, "backfill_mismatch_report.csv")
    payload = {
        "updated": report.updated,
        "mismatches": [
            {
                "table": m.table,
                "row_id": m.row_id,
                "reason": m.reason,
                "academic_year": m.academic_year,
                "class_name": m.class_name,
                "section_name": m.section_name,
            }
            for m in report.mismatches
        ],
    }
    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(payload, f, indent=2)
    with open(csv_path, "w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=[
                "table",
                "row_id",
                "reason",
                "academic_year",
                "class_name",
                "section_name",
            ],
        )
        writer.writeheader()
        for m in report.mismatches:
            writer.writerow(
                {
                    "table": m.table,
                    "row_id": m.row_id,
                    "reason": m.reason,
                    "academic_year": m.academic_year,
                    "class_name": m.class_name,
                    "section_name": m.section_name,
                }
            )
    print(json.dumps(payload, indent=2))


def main() -> int:
    parser = argparse.ArgumentParser(description="Backfill 5C.2a academic soft FK columns")
    parser.add_argument(
        "--database-url",
        default=os.environ.get("DATABASE_URL", ""),
        help="Postgres connection string",
    )
    parser.add_argument("--dry-run", action="store_true", help="Report only, no updates")
    parser.add_argument(
        "--out-dir",
        default="reports/backfill_5c2a",
        help="Mismatch report output directory",
    )
    args = parser.parse_args()
    if not args.database_url:
        print("Set DATABASE_URL or pass --database-url", file=sys.stderr)
        return 1

    report = BackfillReport()
    with psycopg.connect(args.database_url) as conn:
        years = load_years(conn)
        classes = load_classes(conn)
        sections = load_sections(conn)
        backfill_sis_enrollments(conn, years, classes, sections, report, args.dry_run)
        backfill_admissions_enrollments(conn, years, classes, sections, report, args.dry_run)
        backfill_finance_fee_structures(conn, years, report, args.dry_run)
        if not args.dry_run:
            conn.commit()

    write_reports(report, args.out_dir)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
