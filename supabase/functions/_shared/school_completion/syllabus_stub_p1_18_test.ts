// PRA-P1-18 (S6): syllabus auto-generation must NOT fabricate a fake syllabus.
//
// Before: any grade/board without a real curriculum template (everything except
// the seeded Grade 10) got a silent 2-chapter "Unit 1 / Unit 2" stub with no
// flag — indistinguishable from real curriculum and counted into the Principal's
// coverage-%. Now the generator refuses (NoSyllabusTemplateError) and writes
// nothing when no real template matches; a present template still generates
// normally.

import { assert, assertEquals, assertRejects } from "jsr:@std/assert@1";
import {
  generateSyllabusFromTemplates,
  NoSyllabusTemplateError,
} from "./syllabus_automation_service.ts";
import type { TenantQueryClient } from "../tenant_db.ts";

interface Captured {
  sql: string;
  args: unknown[];
}

/**
 * Fake db: returns `templateRows` for the subject_templates SELECT, records every
 * other call so the test can assert whether any chapter/topic INSERT happened.
 */
function fakeDb(
  templateRows: unknown[],
): { db: TenantQueryClient; calls: Captured[] } {
  const calls: Captured[] = [];
  const db = {
    queryObject(sql: string, args: unknown[] = []): Promise<unknown[]> {
      calls.push({ sql, args });
      if (sql.includes("FROM subject_templates")) {
        return Promise.resolve(templateRows);
      }
      if (sql.includes("INSERT INTO syllabus_chapters")) {
        return Promise.resolve([{ id: "chap-1" }]);
      }
      if (sql.includes("INSERT INTO syllabus_generations")) {
        return Promise.resolve([{ id: "gen-1" }]);
      }
      return Promise.resolve([]);
    },
  } as unknown as TenantQueryClient;
  return { db, calls };
}

const baseInput = {
  academicYearId: "yr-1",
  className: "5",
  subjectId: "sub-1",
  subjectName: "Mathematics",
  gradeLabel: "Grade 5",
  createdBy: "user-1",
};

Deno.test("P1-18 no matching template → throws, writes ZERO chapters (no fabricated stub)", async () => {
  const { db, calls } = fakeDb([]); // no templates for Grade 5
  await assertRejects(
    () => generateSyllabusFromTemplates(db, "org", "school", baseInput),
    NoSyllabusTemplateError,
  );
  const inserts = calls.filter((c) => c.sql.includes("INSERT INTO syllabus_chapters"));
  assertEquals(inserts.length, 0, "must not insert a Unit 1/Unit 2 stub");
  // And no "Unit 1"/"Unit 2" literal ever reached the db.
  assert(!calls.some((c) => JSON.stringify(c.args).includes("Unit 1")));
});

Deno.test("P1-18 a real template still generates its chapters", async () => {
  const { db, calls } = fakeDb([{
    id: "tmpl-1",
    board: "CBSE",
    subject_code: "MAT",
    subject_name: "Mathematics",
    category: "core",
    grade_label: "Grade 10",
    chapters: [{ name: "Real Numbers", topics: ["Euclid's lemma", "HCF"] }],
  }]);
  const result = await generateSyllabusFromTemplates(db, "org", "school", {
    ...baseInput,
    gradeLabel: "Grade 10",
  });
  assertEquals(result.chaptersCreated, 1);
  assertEquals(result.topicsCreated, 2);
  assert(calls.some((c) => JSON.stringify(c.args).includes("Real Numbers")));
  // The fabricated stub names never appear for a real template either.
  assert(!calls.some((c) => JSON.stringify(c.args).includes("Unit 1")));
});
