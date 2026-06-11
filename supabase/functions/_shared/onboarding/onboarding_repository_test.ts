import { assertEquals } from "jsr:@std/assert@1";
import {
  parseCsvLine,
  parseCsvText,
  parseStudentImportRow,
  parseTeacherImportRow,
} from "./onboarding_repository.ts";

Deno.test("parseCsvText maps headers to row objects", () => {
  const rows = parseCsvText(
    "studentName,admissionNumber,classLabel\nRavi,ADM-1,8-A\n",
  );
  assertEquals(rows.length, 1);
  assertEquals(rows[0]?.studentName, "Ravi");
  assertEquals(rows[0]?.admissionNumber, "ADM-1");
});

Deno.test("parseCsvText strips UTF-8 BOM", () => {
  const rows = parseCsvText(
    "\uFEFFstudentName,admissionNumber\nRavi,ADM-1\n",
  );
  assertEquals(rows.length, 1);
  assertEquals(rows[0]?.studentName, "Ravi");
});

Deno.test("parseCsvLine handles quoted fields with commas", () => {
  const values = parseCsvLine('"Kumar, Ravi",ADM-1,5');
  assertEquals(values, ["Kumar, Ravi", "ADM-1", "5"]);
});

Deno.test("parseCsvText handles quoted student names", () => {
  const rows = parseCsvText(
    'studentName,admissionNumber,classLabel,sectionLabel,academicYear,parentName,parentPhone\n"Kumar, Ravi",ADM-1,5,A,2026-27,Parent,9876500001\n',
  );
  assertEquals(rows.length, 1);
  assertEquals(rows[0]?.studentName, "Kumar, Ravi");
});

Deno.test("parseStudentImportRow rejects invalid parentPhone", () => {
  const result = parseStudentImportRow({
    studentName: "Ravi",
    admissionNumber: "ADM-1",
    classLabel: "5",
    sectionLabel: "A",
    academicYear: "2026-27",
    parentName: "Parent",
    parentPhone: "abc",
  });
  assertEquals(result.row, undefined);
  assertEquals(result.errors.includes("parentPhone must be 10–15 digits (optional + prefix)"), true);
});

Deno.test("parseStudentImportRow rejects invalid studentPhone", () => {
  const result = parseStudentImportRow({
    studentName: "Ravi",
    admissionNumber: "ADM-1",
    classLabel: "5",
    sectionLabel: "A",
    academicYear: "2026-27",
    parentName: "Parent",
    parentPhone: "9876500001",
    studentPhone: "12",
  });
  assertEquals(result.row, undefined);
  assertEquals(result.errors.includes("studentPhone must be 10–15 digits (optional + prefix)"), true);
});

Deno.test("parseTeacherImportRow rejects invalid phone", () => {
  const result = parseTeacherImportRow({
    displayName: "Teacher",
    phone: "bad",
    role: "teacher",
  });
  assertEquals(result.row, undefined);
  assertEquals(result.errors.includes("phone must be 10–15 digits (optional + prefix)"), true);
});

Deno.test("parseTeacherImportRow accepts schoolAdmin role alias", () => {
  const result = parseTeacherImportRow({
    displayName: "Admin",
    phone: "9876500001",
    role: "schoolAdmin",
  });
  assertEquals(result.row?.role, "schoolAdmin");
});

Deno.test("buildWhatsAppInviteLink encodes message", async () => {
  const { buildWhatsAppInviteLink } = await import("./onboarding_repository.ts");
  const link = buildWhatsAppInviteLink("https://app.test/i/abc", "Parent A");
  assertEquals(link.includes("wa.me"), true);
  assertEquals(link.includes("Parent"), true);
});
