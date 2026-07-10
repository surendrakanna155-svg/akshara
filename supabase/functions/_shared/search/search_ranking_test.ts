// Adaptive AI — P3-AI-2 / W2.S: search ranking tests (pure, DB-free).

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  classifyStudentMatch,
  orderResults,
  type StudentCandidate,
  studentSubtitle,
  toStudentResult,
} from "./search_ranking.ts";

function cand(over: Partial<StudentCandidate> = {}): StudentCandidate {
  return {
    id: "s1",
    displayName: "Ramesh Kumar",
    studentCode: "STU-0001",
    admissionNumber: "2024-101",
    publicStudentId: "DPS-0001",
    className: "6",
    sectionName: "B",
    rollNumber: "12",
    status: "active",
    ...over,
  };
}

Deno.test("classifyStudentMatch follows the priority ladder", () => {
  // admission# beats everything
  assertEquals(classifyStudentMatch(cand(), "2024"), "admission_number");
  // entity id (student_code / public id) when admission# doesn't match
  assertEquals(classifyStudentMatch(cand({ admissionNumber: null }), "stu-0001"), "entity_id");
  assertEquals(classifyStudentMatch(cand({ admissionNumber: null, studentCode: "X" }), "dps-0001"), "entity_id");
  // roll exact
  assertEquals(
    classifyStudentMatch(cand({ admissionNumber: null, studentCode: "X", publicStudentId: null }), "12"),
    "roll_class",
  );
  // name prefix
  assertEquals(
    classifyStudentMatch(cand({ admissionNumber: null, studentCode: "X", publicStudentId: null, rollNumber: null }), "ramesh"),
    "name_prefix",
  );
  // name partial (contains, not prefix)
  assertEquals(
    classifyStudentMatch(cand({ admissionNumber: null, studentCode: "X", publicStudentId: null, rollNumber: null }), "kumar"),
    "name_partial",
  );
});

Deno.test("studentSubtitle carries disambiguating identifiers (decision 6)", () => {
  assertEquals(studentSubtitle(cand()), "Class 6-B · Roll 12 · Adm# 2024-101 · ID DPS-0001");
  // Non-active status is surfaced; missing fields are omitted.
  assertEquals(
    studentSubtitle(cand({ sectionName: null, rollNumber: null, publicStudentId: null, status: "alumni" })),
    "Class 6 · Adm# 2024-101 · alumni",
  );
});

Deno.test("toStudentResult builds a navigable result with a deep link", () => {
  const r = toStudentResult(cand(), "ramesh");
  assertEquals(r.category, "students");
  assertEquals(r.deepLink, "/students/s1");
  assertEquals(r.title, "Ramesh Kumar");
  assertEquals(r.matchField, "name_prefix");
  assertEquals(r.rank, 4);
});

Deno.test("orderResults ranks by the ladder, then name, then id (deterministic)", () => {
  const partial = toStudentResult(cand({ id: "p", displayName: "Zeb Kumar", admissionNumber: null, studentCode: "X", publicStudentId: null, rollNumber: null }), "kumar");
  const admission = toStudentResult(cand({ id: "a", displayName: "Aay Kumar" }), "2024");
  const ordered = orderResults([partial, admission]);
  assertEquals(ordered.map((r) => r.id), ["a", "p"]); // admission# (rank 0) first
});

Deno.test("names are not assumed unique — same name, distinct rows both kept", () => {
  const a = toStudentResult(cand({ id: "s1", rollNumber: "10", admissionNumber: null, studentCode: "X", publicStudentId: null }), "ramesh");
  const b = toStudentResult(cand({ id: "s2", rollNumber: "22", admissionNumber: null, studentCode: "Y", publicStudentId: null }), "ramesh");
  const ordered = orderResults([a, b]);
  assertEquals(ordered.length, 2);
  assertEquals(ordered.map((r) => r.id), ["s1", "s2"]); // tie-break by id, both retained
});
