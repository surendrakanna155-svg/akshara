import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  balanceDifficultyMix,
  buildPaperBlueprint,
  generateStubHomeworkContent,
  generateStubQuestion,
  generateStubRemark,
} from "./education_generator.ts";

Deno.test("generateStubQuestion returns typed question with marks", () => {
  const q = generateStubQuestion("Math", "Algebra", "medium", "mcq", 2);
  assertEquals(q.questionType, "mcq");
  assertEquals(q.marks, 2);
  assertEquals(q.options.length, 4);
});

Deno.test("generateStubHomeworkContent returns requested count", () => {
  const items = generateStubHomeworkContent("Science", "Motion", "easy", "homework", 3);
  assertEquals(items.length, 3);
  assertEquals(items[0]!.prompt.includes("Science"), true);
});

Deno.test("generateStubRemark supports english principal template", () => {
  const remark = generateStubRemark("principal", "english", {
    attendancePercent: 92,
    strengths: ["leadership"],
  });
  assertEquals(remark.includes("92"), true);
  assertEquals(remark.includes("leadership"), true);
});

Deno.test("generateStubRemark supports telugu class teacher template", () => {
  const remark = generateStubRemark("class_teacher", "telugu", {
    averageMarks: 78,
  });
  assertEquals(remark.includes("78"), true);
});

Deno.test("balanceDifficultyMix spreads easy medium hard", () => {
  const mix = balanceDifficultyMix(10);
  assertEquals(mix.length, 10);
  assertEquals(mix.filter((d) => d === "easy").length, 3);
  assertEquals(mix.filter((d) => d === "hard").length, 2);
});

Deno.test("buildPaperBlueprint includes marks distribution", () => {
  const blueprint = buildPaperBlueprint(
    50,
    [
      { marks: 5, questionType: "mcq", source: "bank" },
      { marks: 10, questionType: "short_answer", source: "ai_generated" },
    ],
    ["Algebra"],
  );
  assertEquals(blueprint.totalMarks, 50);
  assertEquals((blueprint.marksDistribution as unknown[]).length, 2);
});
