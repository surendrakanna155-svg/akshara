import {
  assertEquals,
  assertNotEquals,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildComplaintPhotoStoragePath,
  COMPLAINT_PHOTO_UPLOAD_CONSTRAINTS,
  validateComplaintPhotoUpload,
} from "./complaints_storage.ts";

const ORG = "11111111-1111-1111-1111-111111111111";
const SCHOOL = "22222222-2222-2222-2222-222222222222";
const COMPLAINT = "33333333-3333-3333-3333-333333333333";

Deno.test("buildComplaintPhotoStoragePath is tenant + complaint prefixed", () => {
  const path = buildComplaintPhotoStoragePath(ORG, SCHOOL, COMPLAINT, "Broken Fan.jpg");
  assertStringIncludes(path, `${ORG}/${SCHOOL}/${COMPLAINT}/`);
  assertStringIncludes(path, "Broken_Fan.jpg");
});

Deno.test("buildComplaintPhotoStoragePath is unique per call (no silent overwrite)", () => {
  const a = buildComplaintPhotoStoragePath(ORG, SCHOOL, COMPLAINT, "a.jpg");
  const b = buildComplaintPhotoStoragePath(ORG, SCHOOL, COMPLAINT, "a.jpg");
  assertNotEquals(a, b);
});

Deno.test("validateComplaintPhotoUpload accepts an allowed image type", () => {
  const err = validateComplaintPhotoUpload("photo.jpg", {
    contentType: "image/jpeg",
    sizeBytes: 1024,
  });
  assertEquals(err, null);
});

Deno.test("validateComplaintPhotoUpload rejects a disallowed extension (e.g. a PDF)", () => {
  const err = validateComplaintPhotoUpload("report.pdf", {
    contentType: "application/pdf",
    sizeBytes: 1024,
  });
  assertNotEquals(err, null);
});

Deno.test("validateComplaintPhotoUpload rejects an oversized declared size", () => {
  const err = validateComplaintPhotoUpload("photo.png", {
    contentType: "image/png",
    sizeBytes: COMPLAINT_PHOTO_UPLOAD_CONSTRAINTS.maxBytes + 1,
  });
  assertNotEquals(err, null);
});

Deno.test("validateComplaintPhotoUpload rejects a mismatched declared content-type", () => {
  const err = validateComplaintPhotoUpload("photo.jpg", {
    contentType: "application/zip",
    sizeBytes: 1024,
  });
  assertNotEquals(err, null);
});
