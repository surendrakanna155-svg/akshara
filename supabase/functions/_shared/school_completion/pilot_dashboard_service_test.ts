import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { computePilotScore } from "./pilot_dashboard_service.ts";

Deno.test("computePilotScore weights onboarding and activation", () => {
  assertEquals(
    computePilotScore({
      setupWizardCompleted: true,
      importCommitted: true,
      teacherRate: 100,
      parentRate: 100,
      otpRate: 100,
    }),
    100,
  );
  assertEquals(
    computePilotScore({
      setupWizardCompleted: false,
      importCommitted: false,
      teacherRate: 0,
      parentRate: 0,
      otpRate: 0,
    }),
    0,
  );
});
