import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  validateForGoLive,
  type StartupOnboardingRow,
} from "./startup_onboarding_repository.ts";

function baseRow(overrides: Partial<StartupOnboardingRow> = {}): StartupOnboardingRow {
  return {
    id: "id",
    organization_id: "org",
    school_id: "school",
    current_step: "review",
    school_name: "Akshara",
    board: "CBSE",
    curriculum: "CBSE",
    address: "123 Road",
    contact_phone: "9999999999",
    contact_email: "admin@school.edu",
    academic_year: "2026-27",
    classes: ["Grade 1"],
    sections: ["A"],
    fee_model: "term_wise",
    fee_categories: ["Tuition"],
    logo_url: "",
    theme_primary: "#1565C0",
    theme_secondary: "#42A5F5",
    branding_preferences: {},
    default_language: "en",
    modules_enabled: ["sis"],
    is_live: false,
    go_live_at: null,
    updated_at: new Date().toISOString(),
    ...overrides,
  };
}

Deno.test("validateForGoLive accepts complete startup onboarding", () => {
  assertEquals(validateForGoLive(baseRow()), []);
});

Deno.test("validateForGoLive blocks missing school profile and fees", () => {
  const errors = validateForGoLive(baseRow({
    school_name: "",
    address: "",
    fee_model: "",
    fee_categories: [],
    theme_primary: "",
  }));
  assertEquals(errors.includes("School name is required"), true);
  assertEquals(errors.includes("School address is required"), true);
  assertEquals(errors.includes("Fee model is required"), true);
});
