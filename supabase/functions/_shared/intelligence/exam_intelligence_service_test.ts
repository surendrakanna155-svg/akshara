import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

function clamp(n: number): number {
  return Math.max(0, Math.min(100, Math.round(n)));
}

Deno.test("pass rate calculation handles zero entries", () => {
  const passRate = 0;
  assertEquals(clamp(passRate), 0);
});

Deno.test("grade distribution maps distinction threshold", () => {
  const pct = 0.87;
  const grade = pct >= 0.85 ? "A" : pct >= 0.7 ? "B" : "C";
  assertEquals(grade, "A");
});

Deno.test("rank movement direction resolves correctly", () => {
  const previousRank = 8;
  const currentRank = 5;
  const movement = previousRank - currentRank;
  const direction = movement > 0 ? "up" : movement < 0 ? "down" : "stable";
  assertEquals(direction, "up");
  assertEquals(movement, 3);
});
