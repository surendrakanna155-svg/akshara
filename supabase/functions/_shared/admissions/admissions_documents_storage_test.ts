import {
  assertEquals,
  assertNotEquals,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import { buildAdmissionsDocumentStoragePath } from "../storage/storage_service.ts";
import { documentToApi } from "./admissions_mapper.ts";
import type { AdmissionsDocumentRow } from "./admissions_mapper.ts";

const ORG = "11111111-1111-1111-1111-111111111111";
const SCHOOL = "22222222-2222-2222-2222-222222222222";
const LEAD = "33333333-3333-3333-3333-333333333333";

Deno.test("buildAdmissionsDocumentStoragePath is tenant-prefixed", () => {
  const path = buildAdmissionsDocumentStoragePath(
    ORG,
    SCHOOL,
    LEAD,
    "Birth Certificate.pdf",
  );
  // First two folder segments isolate the tenant for storage RLS.
  assertStringIncludes(path, `${ORG}/${SCHOOL}/${LEAD}/`);
  // Unsafe characters in the file name are sanitised.
  assertStringIncludes(path, "Birth_Certificate.pdf");
});

Deno.test("buildAdmissionsDocumentStoragePath is unique per call", () => {
  const a = buildAdmissionsDocumentStoragePath(ORG, SCHOOL, LEAD, "a.pdf");
  const b = buildAdmissionsDocumentStoragePath(ORG, SCHOOL, LEAD, "a.pdf");
  // A random object id keeps repeated uploads from overwriting each other.
  assertNotEquals(a, b);
});

function row(overrides: Partial<AdmissionsDocumentRow>): AdmissionsDocumentRow {
  return {
    id: "doc-1",
    organization_id: ORG,
    school_id: SCHOOL,
    lead_id: LEAD,
    application_id: null,
    student_name: "Ananya",
    class_label: "5",
    document_type: "birth_certificate",
    file_name: "bc.pdf",
    is_required: true,
    status: "uploaded",
    uploaded_at: "2026-06-01T10:00:00.000Z",
    verified_by: null,
    reviewer_note: null,
    storage_path: null,
    created_at: "2026-06-01T10:00:00.000Z",
    updated_at: "2026-06-01T10:00:00.000Z",
    ...overrides,
  };
}

Deno.test("documentToApi flags a stored file as retrievable", () => {
  const api = documentToApi(row({ storage_path: `${ORG}/${SCHOOL}/${LEAD}/x_bc.pdf` }));
  assertEquals(api.hasFile, true);
});

Deno.test("documentToApi flags a metadata-only row as not retrievable", () => {
  const api = documentToApi(row({ storage_path: null }));
  assertEquals(api.hasFile, false);
});
