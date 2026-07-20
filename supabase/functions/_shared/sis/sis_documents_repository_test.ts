import { assertEquals, assertRejects } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  documentToApi,
  StudentDocumentNotFoundError,
  type StudentDocumentRow,
  verifyStudentDocument,
} from "./sis_documents_repository.ts";

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL_A = "a2000000-0000-4000-8000-000000000001";
const SCHOOL_B = "a2000000-0000-4000-8000-000000000002";
const STUDENT_A = "a4000000-0000-4000-8000-000000000001";
const VERIFIER = "a3000000-0000-4000-8000-000000000001";
const DOC_ID = "d5000000-0000-4000-8000-000000000009";
const OTHER_DOC = "d5000000-0000-4000-8000-00000000000a";

type Row = Record<string, unknown>;

// Mock that emulates the RLS + explicit-scope UPDATE ... RETURNING contract of
// verifyStudentDocument: only rows matching id + org + school are updated.
class DocsMockDb {
  documents: Row[] = [
    {
      id: DOC_ID,
      organization_id: ORG,
      school_id: SCHOOL_A,
      student_id: STUDENT_A,
      document_type: "birth_certificate",
      status: "pending",
      // PRA-P1-19: the human label lives in file_uri; the real object is storage_path.
      file_uri: "bc.pdf",
      storage_path: `${ORG}/${SCHOOL_A}/${STUDENT_A}/abc_bc.pdf`,
      uploaded_by: STUDENT_A,
      uploaded_at: "2026-06-10T00:00:00.000Z",
      verified_by: null,
      verified_at: null,
      created_at: "2026-06-10T00:00:00.000Z",
      updated_at: "2026-06-10T00:00:00.000Z",
    },
    {
      // Belongs to another school — must never be reachable from SCHOOL_A.
      id: OTHER_DOC,
      organization_id: ORG,
      school_id: SCHOOL_B,
      student_id: STUDENT_A,
      document_type: "transfer_certificate",
      status: "pending",
      file_uri: null,
      storage_path: null,
      uploaded_by: STUDENT_A,
      uploaded_at: "2026-06-10T00:00:00.000Z",
      verified_by: null,
      verified_at: null,
      created_at: "2026-06-10T00:00:00.000Z",
      updated_at: "2026-06-10T00:00:00.000Z",
    },
  ];

  // deno-lint-ignore require-await
  async queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    if (sql.includes("UPDATE student_documents")) {
      const [docId, org, school, status, verifier] = args;
      const row = this.documents.find((d) =>
        d.id === docId && d.organization_id === org && d.school_id === school
      );
      if (!row) return [] as T[];
      row.status = status;
      row.verified_by = verifier;
      row.verified_at = "2026-06-11T09:00:00.000Z";
      row.updated_at = "2026-06-11T09:00:00.000Z";
      return [{ ...row }] as T[];
    }
    return [] as T[];
  }
}

Deno.test("SIS-3 verifyStudentDocument stamps status, verified_by, verified_at", async () => {
  const db = new DocsMockDb();
  const row = await verifyStudentDocument(
    db as unknown as TenantQueryClient,
    ORG,
    SCHOOL_A,
    DOC_ID,
    { status: "verified", verifierId: VERIFIER },
  );
  assertEquals(row.status, "verified");
  assertEquals(row.verified_by, VERIFIER);
  assertEquals(row.verified_at, "2026-06-11T09:00:00.000Z");
});

Deno.test("SIS-3 verifyStudentDocument supports rejected", async () => {
  const db = new DocsMockDb();
  const row = await verifyStudentDocument(
    db as unknown as TenantQueryClient,
    ORG,
    SCHOOL_A,
    DOC_ID,
    { status: "rejected", verifierId: VERIFIER, note: "blurry scan" },
  );
  assertEquals(row.status, "rejected");
  assertEquals(row.verified_by, VERIFIER);
});

Deno.test("SIS-3 verifyStudentDocument 404s when no row in scope", async () => {
  const db = new DocsMockDb();
  await assertRejects(
    () =>
      verifyStudentDocument(
        db as unknown as TenantQueryClient,
        ORG,
        SCHOOL_A,
        "d5000000-0000-4000-8000-ffffffffffff",
        { status: "verified", verifierId: VERIFIER },
      ),
    StudentDocumentNotFoundError,
  );
});

Deno.test("SIS-3 verifyStudentDocument cannot reach another school's document", async () => {
  const db = new DocsMockDb();
  // OTHER_DOC belongs to SCHOOL_B; requesting it under SCHOOL_A must 404.
  await assertRejects(
    () =>
      verifyStudentDocument(
        db as unknown as TenantQueryClient,
        ORG,
        SCHOOL_A,
        OTHER_DOC,
        { status: "verified", verifierId: VERIFIER },
      ),
    StudentDocumentNotFoundError,
  );
});

Deno.test("SIS-3 documentToApi exposes verifiedBy + status", () => {
  const row: StudentDocumentRow = {
    id: DOC_ID,
    organization_id: ORG,
    school_id: SCHOOL_A,
    student_id: STUDENT_A,
    document_type: "birth_certificate",
    status: "verified",
    file_uri: "bc.pdf",
    storage_path: `${ORG}/${SCHOOL_A}/${STUDENT_A}/abc_bc.pdf`,
    uploaded_by: STUDENT_A,
    uploaded_at: "2026-06-10T00:00:00.000Z",
    verified_by: VERIFIER,
    verified_at: "2026-06-11T09:00:00.000Z",
    created_at: "2026-06-10T00:00:00.000Z",
    updated_at: "2026-06-11T09:00:00.000Z",
  };
  const api = documentToApi(row);
  assertEquals(api.status, "verified");
  assertEquals(api.verifiedBy, VERIFIER);
  assertEquals(api.verifiedAt, "2026-06-11T09:00:00.000Z");
  // PRA-P1-19 — a stored object is retrievable.
  assertEquals(api.hasFile, true);
});

Deno.test("PRA-P1-19 documentToApi flags a metadata-only row as not retrievable", () => {
  const row: StudentDocumentRow = {
    id: DOC_ID,
    organization_id: ORG,
    school_id: SCHOOL_A,
    student_id: STUDENT_A,
    document_type: "birth_certificate",
    status: "pending",
    file_uri: null,
    storage_path: null,
    uploaded_by: STUDENT_A,
    uploaded_at: "2026-06-10T00:00:00.000Z",
    verified_by: null,
    verified_at: null,
    created_at: "2026-06-10T00:00:00.000Z",
    updated_at: "2026-06-10T00:00:00.000Z",
  };
  assertEquals(documentToApi(row).hasFile, false);
});
