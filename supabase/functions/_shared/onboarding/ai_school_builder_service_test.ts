import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { buildSchoolBlueprint, normalizeBrief } from "./ai_school_builder_service.ts";

Deno.test("blueprint slices the grade ladder from a low→high range", () => {
  const bp = buildSchoolBlueprint({ lowestGrade: "Grade 1", highestGrade: "Grade 5" });
  assertEquals(bp.proposal.classes, ["Grade 1", "Grade 2", "Grade 3", "Grade 4", "Grade 5"]);
  assertEquals(bp.source, "deterministic");
});

Deno.test("blueprint tolerates loose grade labels and reversed range", () => {
  const bp = buildSchoolBlueprint({ lowestGrade: "10", highestGrade: "class 6" });
  assertEquals(bp.proposal.classes, ["Grade 6", "Grade 7", "Grade 8", "Grade 9", "Grade 10"]);
});

Deno.test("preschool default window is Nursery→UKG", () => {
  const bp = buildSchoolBlueprint({ schoolType: "preschool" });
  assertEquals(bp.proposal.classes, ["Nursery", "LKG", "UKG"]);
});

Deno.test("explicit grades win over range", () => {
  const bp = buildSchoolBlueprint({ grades: ["Grade 11", "Grade 12"], lowestGrade: "Grade 1" });
  assertEquals(bp.proposal.classes, ["Grade 11", "Grade 12"]);
});

Deno.test("section count derives from students when not given, capped", () => {
  // 600 students over 5 grades = 120/grade ⇒ ceil(120/40) = 3 sections
  const bp = buildSchoolBlueprint({
    lowestGrade: "Grade 1",
    highestGrade: "Grade 5",
    estimatedStudents: 600,
  });
  assertEquals(bp.proposal.sections, ["A", "B", "C"]);
});

Deno.test("residential school enables hostel + transport and adds hostel fee", () => {
  const bp = buildSchoolBlueprint({ schoolType: "residential" });
  assert(bp.proposal.modulesEnabled!.includes("hostel"));
  assert(bp.proposal.modulesEnabled!.includes("transport"));
  assert(bp.proposal.feeCategories!.includes("Hostel"));
  assert(bp.proposal.feeCategories!.includes("Transport"));
});

Deno.test("board defaults to CBSE; curriculum mirrors board when one side missing", () => {
  assertEquals(buildSchoolBlueprint({}).proposal.board, "CBSE");
  assertEquals(buildSchoolBlueprint({ board: "ICSE" }).proposal.curriculum, "ICSE");
  assertEquals(buildSchoolBlueprint({ curriculum: "IB" }).proposal.board, "IB");
});

Deno.test("default language taken from first language, lowercased", () => {
  const bp = buildSchoolBlueprint({ languages: ["Hindi", "English"] });
  assertEquals(bp.proposal.defaultLanguage, "hindi");
  assertEquals(buildSchoolBlueprint({}).proposal.defaultLanguage, "en");
});

Deno.test("warns on missing required fields and bad ratio", () => {
  const bp = buildSchoolBlueprint({ estimatedStudents: 1000, estimatedTeachers: 10 });
  assert(bp.warnings.some((w) => w.includes("School name")));
  assert(bp.warnings.some((w) => w.includes("address")));
  assert(bp.warnings.some((w) => w.includes("ratio")));
});

Deno.test("proposal always has a complete, go-live-shaped payload", () => {
  const bp = buildSchoolBlueprint({ schoolName: "Test Public School", board: "CBSE" });
  const p = bp.proposal;
  assertEquals(p.feeModel, "term_wise");
  assert((p.classes ?? []).length > 0);
  assert((p.sections ?? []).length > 0);
  assert((p.feeCategories ?? []).length > 0);
  assert((p.modulesEnabled ?? []).includes("sis"));
  assert(typeof p.themePrimary === "string" && p.themePrimary.startsWith("#"));
  assert(bp.rationale.length > 0);
});

Deno.test("normalizeBrief drops junk and trims strings", () => {
  const b = normalizeBrief({
    schoolName: "  Akshara  ",
    estimatedStudents: 200,
    sectionsPerGrade: "nope",
    grades: ["Grade 1", 5, "Grade 2"],
    bogus: true,
  });
  assertEquals(b.schoolName, "Akshara");
  assertEquals(b.estimatedStudents, 200);
  assertEquals(b.sectionsPerGrade, undefined);
  assertEquals(b.grades, ["Grade 1", "Grade 2"]);
});
