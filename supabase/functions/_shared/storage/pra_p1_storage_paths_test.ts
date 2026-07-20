// PRA-P1-19 / PRA-P1-30 — the new storage path builders are tenant-prefixed,
// sanitise unsafe file names, and stay unique per call (so upsert:false never
// silently overwrites a sibling upload). Mirrors admissions_documents_storage_test.

import {
  assertEquals,
  assertNotEquals,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildHomeworkSubmissionStoragePath,
  buildHomeworkTeacherAttachmentStoragePath,
  buildStudentDocumentStoragePath,
  HOMEWORK_UPLOAD_CONSTRAINTS,
  STUDENT_DOCUMENT_UPLOAD_CONSTRAINTS,
  validateUpload,
} from "./storage_service.ts";

const ORG = "11111111-1111-1111-1111-111111111111";
const SCHOOL = "22222222-2222-2222-2222-222222222222";
const STUDENT = "33333333-3333-3333-3333-333333333333";
const TEACHER = "44444444-4444-4444-4444-444444444444";
const HW = "hw_5555";

// ── P1-19 student documents ───────────────────────────────────────────────────

Deno.test("buildStudentDocumentStoragePath is tenant-prefixed and sanitised", () => {
  const path = buildStudentDocumentStoragePath(
    ORG,
    SCHOOL,
    STUDENT,
    "Transfer Certificate.pdf",
  );
  assertStringIncludes(path, `${ORG}/${SCHOOL}/${STUDENT}/`);
  assertStringIncludes(path, "Transfer_Certificate.pdf");
});

Deno.test("buildStudentDocumentStoragePath is unique per call", () => {
  const a = buildStudentDocumentStoragePath(ORG, SCHOOL, STUDENT, "tc.pdf");
  const b = buildStudentDocumentStoragePath(ORG, SCHOOL, STUDENT, "tc.pdf");
  assertNotEquals(a, b);
});

Deno.test("student document constraints reject an executable, allow a PDF", () => {
  assertEquals(
    validateUpload("ok.pdf", { contentType: "application/pdf", sizeBytes: 1000 },
      STUDENT_DOCUMENT_UPLOAD_CONSTRAINTS),
    null,
  );
  assertStringIncludes(
    validateUpload("malware.exe", { sizeBytes: 1000 },
      STUDENT_DOCUMENT_UPLOAD_CONSTRAINTS)!,
    "not allowed",
  );
});

// ── P1-30 homework attachments ────────────────────────────────────────────────

Deno.test("buildHomeworkTeacherAttachmentStoragePath is tenant-prefixed under the teacher id", () => {
  const path = buildHomeworkTeacherAttachmentStoragePath(
    ORG,
    SCHOOL,
    TEACHER,
    "Worksheet 1.pdf",
  );
  assertStringIncludes(path, `${ORG}/${SCHOOL}/${TEACHER}/`);
  assertStringIncludes(path, "Worksheet_1.pdf");
});

Deno.test("buildHomeworkSubmissionStoragePath is tenant-prefixed under student/homework", () => {
  const path = buildHomeworkSubmissionStoragePath(
    ORG,
    SCHOOL,
    STUDENT,
    HW,
    "My Answer.jpg",
  );
  assertStringIncludes(path, `${ORG}/${SCHOOL}/${STUDENT}/${HW}/`);
  assertStringIncludes(path, "My_Answer.jpg");
});

Deno.test("homework submission path is unique per call", () => {
  const a = buildHomeworkSubmissionStoragePath(ORG, SCHOOL, STUDENT, HW, "a.jpg");
  const b = buildHomeworkSubmissionStoragePath(ORG, SCHOOL, STUDENT, HW, "a.jpg");
  assertNotEquals(a, b);
});

Deno.test("homework constraints reject oversize, allow an image", () => {
  assertEquals(
    validateUpload("photo.jpg", { contentType: "image/jpeg", sizeBytes: 1000 },
      HOMEWORK_UPLOAD_CONSTRAINTS),
    null,
  );
  assertStringIncludes(
    validateUpload("photo.jpg",
      { contentType: "image/jpeg", sizeBytes: HOMEWORK_UPLOAD_CONSTRAINTS.maxBytes + 1 },
      HOMEWORK_UPLOAD_CONSTRAINTS)!,
    "maximum size",
  );
});
