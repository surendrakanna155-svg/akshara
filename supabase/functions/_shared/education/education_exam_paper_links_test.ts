// CI-0b — tests for the exam ↔ paper link repo (edu_exam_paper_links seam).
// Tiny in-memory fake routing the exact SQL these functions issue — no network,
// mirrors education_correction_repository_test.ts. RLS isolation itself is a DB
// concern (FORCE _school_scope in migration 20260852000000); here we confirm the
// functions insert/upsert/read and always filter by org+school.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import { getExamPaperLink, linkExamToPaper } from "./education_repository.ts";

type Row = Record<string, unknown>;
const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL = "a2000000-0000-4000-8000-000000000001";
const OTHER_SCHOOL = "a2000000-0000-4000-8000-000000000009";

class FakeLinkDb {
  links: Row[] = [];
  private seq = 0;

  // deno-lint-ignore no-explicit-any
  queryObject<T>(sql: string, args: any[] = []): Promise<T[]> {
    const s = sql.replace(/\s+/g, " ").trim();

    if (s.startsWith("INSERT INTO edu_exam_paper_links")) {
      const [org, school, examId, paperId, setCode] = args;
      const existing = this.links.find((r) =>
        r.organization_id === org && r.school_id === school &&
        r.exam_id === examId && r.set_code === setCode
      );
      if (existing) {
        existing.paper_id = paperId; // ON CONFLICT DO UPDATE SET paper_id
        return this.rows([existing]);
      }
      const row: Row = {
        id: `link_${++this.seq}`,
        organization_id: org,
        school_id: school,
        exam_id: examId,
        paper_id: paperId,
        set_code: setCode,
        created_at: "t",
      };
      this.links.push(row);
      return this.rows([row]);
    }

    if (s.startsWith("SELECT * FROM edu_exam_paper_links")) {
      const [org, school, examId, setCode] = args;
      return this.rows(
        this.links.filter((r) =>
          r.organization_id === org && r.school_id === school &&
          r.exam_id === examId && r.set_code === setCode
        ).slice(0, 1),
      );
    }

    return this.rows([]);
  }

  private rows<T>(r: Row[]): Promise<T[]> {
    return Promise.resolve(r as T[]);
  }
}

function db(): { client: TenantQueryClient; fake: FakeLinkDb } {
  const fake = new FakeLinkDb();
  return { client: fake as unknown as TenantQueryClient, fake };
}

Deno.test("CI-0b: linkExamToPaper inserts a link (default set A) and getExamPaperLink reads it", async () => {
  const { client } = db();
  const link = await linkExamToPaper(client, ORG, SCHOOL, { examId: "exam-1", paperId: "paper-1" });
  assertEquals(link.exam_id, "exam-1");
  assertEquals(link.paper_id, "paper-1");
  assertEquals(link.set_code, "A");

  const read = await getExamPaperLink(client, ORG, SCHOOL, "exam-1");
  assertEquals(read?.paper_id, "paper-1");
});

Deno.test("CI-0b: re-linking the same exam/set re-points paper_id (upsert, one row)", async () => {
  const { client, fake } = db();
  await linkExamToPaper(client, ORG, SCHOOL, { examId: "exam-1", paperId: "paper-1" });
  const relinked = await linkExamToPaper(client, ORG, SCHOOL, { examId: "exam-1", paperId: "paper-2" });
  assertEquals(relinked.paper_id, "paper-2");
  assertEquals(fake.links.length, 1); // upsert, not a second row
  assertEquals((await getExamPaperLink(client, ORG, SCHOOL, "exam-1"))?.paper_id, "paper-2");
});

Deno.test("CI-0b: getExamPaperLink returns null for an unlinked exam", async () => {
  const { client } = db();
  assertEquals(await getExamPaperLink(client, ORG, SCHOOL, "nope"), null);
});

Deno.test("CI-0b: different set_code is a separate link", async () => {
  const { client } = db();
  await linkExamToPaper(client, ORG, SCHOOL, { examId: "exam-1", paperId: "paper-A", setCode: "A" });
  await linkExamToPaper(client, ORG, SCHOOL, { examId: "exam-1", paperId: "paper-B", setCode: "B" });
  assertEquals((await getExamPaperLink(client, ORG, SCHOOL, "exam-1", "A"))?.paper_id, "paper-A");
  assertEquals((await getExamPaperLink(client, ORG, SCHOOL, "exam-1", "B"))?.paper_id, "paper-B");
});

Deno.test("CI-0b: a read for a different school does not see another school's link (org+school filter)", async () => {
  const { client } = db();
  await linkExamToPaper(client, ORG, SCHOOL, { examId: "exam-1", paperId: "paper-1" });
  assertEquals(await getExamPaperLink(client, ORG, OTHER_SCHOOL, "exam-1"), null);
});
