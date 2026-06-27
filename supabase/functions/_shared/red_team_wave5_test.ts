// Red Team Wave 5 — Input/Upload Hardening (RT-31/32/33) unit evidence.
import {
  assertEquals,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  intOr,
  MAX_FIELD_LEN,
  MAX_INT_MAGNITUDE,
  str,
  WriteValidationError,
} from "./entity_write/module_write_handlers.ts";
import {
  ADMISSIONS_UPLOAD_CONSTRAINTS,
  MEMORY_UPLOAD_CONSTRAINTS,
  validateUpload,
} from "./storage/storage_service.ts";

Deno.test("RT-32 str() accepts a normal value and bounds over-long input", () => {
  assertEquals(str({ name: "Asha" }, "name"), "Asha");
  assertEquals(str({ name: "x".repeat(MAX_FIELD_LEN) }, "name")?.length, MAX_FIELD_LEN);
  assertThrows(
    () => str({ name: "x".repeat(MAX_FIELD_LEN + 1) }, "name"),
    WriteValidationError,
  );
});

Deno.test("RT-33 intOr() accepts in-range and rejects absurd magnitudes", () => {
  assertEquals(intOr({ n: "42" }, 0, "n"), 42);
  assertEquals(intOr({ n: "-7" }, 0, "n"), -7);
  assertEquals(intOr({}, 5, "n"), 5);
  assertEquals(intOr({ n: String(MAX_INT_MAGNITUDE) }, 0, "n"), MAX_INT_MAGNITUDE);
  assertThrows(
    () => intOr({ n: String(MAX_INT_MAGNITUDE + 1) }, 0, "n"),
    WriteValidationError,
  );
});

Deno.test("RT-31 validateUpload accepts allowed files", () => {
  assertEquals(
    validateUpload("photo.jpg", { contentType: "image/jpeg", sizeBytes: 1024 },
      MEMORY_UPLOAD_CONSTRAINTS),
    null,
  );
  assertEquals(
    validateUpload("doc.pdf", { contentType: "application/pdf", sizeBytes: 2048 },
      ADMISSIONS_UPLOAD_CONSTRAINTS),
    null,
  );
});

Deno.test("RT-31 validateUpload rejects disallowed type / oversized", () => {
  // wrong extension for the memories bucket
  assertEquals(
    validateUpload("malware.exe", {}, MEMORY_UPLOAD_CONSTRAINTS) != null,
    true,
  );
  // disallowed declared content-type
  assertEquals(
    validateUpload("note.pdf", { contentType: "application/x-msdownload" },
      ADMISSIONS_UPLOAD_CONSTRAINTS) != null,
    true,
  );
  // oversized
  assertEquals(
    validateUpload("big.mp4", { sizeBytes: MEMORY_UPLOAD_CONSTRAINTS.maxBytes + 1 },
      MEMORY_UPLOAD_CONSTRAINTS) != null,
    true,
  );
  // missing extension
  assertEquals(validateUpload("noext", {}, MEMORY_UPLOAD_CONSTRAINTS) != null, true);
});
