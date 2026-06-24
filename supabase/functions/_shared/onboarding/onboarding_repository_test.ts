import { assertEquals } from "jsr:@std/assert@1";
import {
  isValidIsoDate,
  parseCsvLine,
  parseCsvText,
  parseStudentImportRow,
  parseTeacherImportRow,
} from "./onboarding_repository.ts";
import {
  buildPlaceholderIdentity,
  hashAadhaar,
  isValidAadhaar,
  maskAadhaar,
  normalizeAadhaar,
} from "./onboarding_user_provisioning.ts";

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

Deno.test("parseStudentImportRow accepts a valid 12-digit aadhaar (normalized)", () => {
  const result = parseStudentImportRow({
    studentName: "Ravi",
    admissionNumber: "ADM-1",
    classLabel: "5",
    sectionLabel: "A",
    academicYear: "2026-27",
    parentName: "Parent",
    parentPhone: "9876500001",
    aadhaar: "1234 5678 9012",
  });
  assertEquals(result.errors, []);
  assertEquals(result.row?.aadhaar, "123456789012");
});

Deno.test("parseStudentImportRow rejects aadhaar that is not 12 digits", () => {
  const result = parseStudentImportRow({
    studentName: "Ravi",
    admissionNumber: "ADM-1",
    classLabel: "5",
    sectionLabel: "A",
    academicYear: "2026-27",
    parentName: "Parent",
    parentPhone: "9876500001",
    aadhaar: "12345",
  });
  assertEquals(result.row, undefined);
  assertEquals(result.errors.includes("aadhaar must be 12 digits"), true);
});

Deno.test("parseStudentImportRow parses motherName/dob/gender (camel + snake)", () => {
  const result = parseStudentImportRow({
    studentName: "Ravi",
    admission_number: "ADM-1",
    class: "5",
    section: "A",
    academic_year: "2026-27",
    parent_name: "Parent",
    parent_phone: "9876500001",
    mother_name: "Sita",
    dob: "2015-08-09",
    gender: "Female",
  });
  assertEquals(result.errors, []);
  assertEquals(result.row?.motherName, "Sita");
  assertEquals(result.row?.dateOfBirth, "2015-08-09");
  assertEquals(result.row?.gender, "Female");
});

Deno.test("parseStudentImportRow rejects malformed dob", () => {
  const result = parseStudentImportRow({
    studentName: "Ravi",
    admissionNumber: "ADM-1",
    classLabel: "5",
    sectionLabel: "A",
    academicYear: "2026-27",
    parentName: "Parent",
    parentPhone: "9876500001",
    dob: "09-08-2015",
  });
  assertEquals(result.row, undefined);
  assertEquals(result.errors.includes("dob must be a valid date (yyyy-mm-dd)"), true);
});

Deno.test("isValidIsoDate enforces real calendar dates", () => {
  assertEquals(isValidIsoDate("2015-08-09"), true);
  assertEquals(isValidIsoDate("2015-13-09"), false);
  assertEquals(isValidIsoDate("2015-02-30"), false);
  assertEquals(isValidIsoDate("2015/08/09"), false);
});

Deno.test("aadhaar validation / normalization / masking", () => {
  assertEquals(isValidAadhaar("123456789012"), true);
  assertEquals(isValidAadhaar("1234 5678 9012"), true);
  assertEquals(isValidAadhaar("12345678901"), false);
  assertEquals(isValidAadhaar("12345678901a"), false);
  assertEquals(normalizeAadhaar("1234-5678-9012"), "123456789012");
  assertEquals(maskAadhaar("123456789012"), "XXXXXXXX9012");
});

Deno.test("hashAadhaar is stable sha256 hex, ignores formatting", async () => {
  const a = await hashAadhaar("123456789012");
  const b = await hashAadhaar("1234 5678 9012");
  assertEquals(a, b);
  assertEquals(a.length, 64);
  assertEquals(/^[0-9a-f]{64}$/.test(a), true);
});

Deno.test("buildPlaceholderIdentity is deterministic and sanitized", () => {
  const first = buildPlaceholderIdentity("Grade 6", "A", 1);
  assertEquals(first.studentName, "Grade 6A — Roll 1");
  assertEquals(first.admissionNumber, "PH-Grade6-A-1");
  const second = buildPlaceholderIdentity("Grade 6", "A", 1);
  assertEquals(first.admissionNumber, second.admissionNumber);
});

Deno.test("buildWhatsAppInviteLink encodes message", async () => {
  const { buildWhatsAppInviteLink } = await import("./onboarding_repository.ts");
  const link = buildWhatsAppInviteLink("https://app.test/i/abc", "Parent A");
  assertEquals(link.includes("wa.me"), true);
  assertEquals(link.includes("Parent"), true);
});
