import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildPreview,
  type InterviewDraftView,
  type OrgBuilderPack,
  rolesForPack,
  widgetsForPack,
  workflowsForPack,
} from "./organization_builder_repository.ts";
import { baselineRecommendation } from "./organization_builder_ai.ts";

const SCHOOL_PACK: OrgBuilderPack = {
  id: "pack_school",
  type: "school",
  name: "Education",
  description: "",
  primaryEntities: ["Students", "Classes"],
  moduleSeeds: ["SIS", "Finance", "Education Suite"],
  dashboardFocus: "",
  brandLabel: null,
};

const SALON_PACK: OrgBuilderPack = {
  ...SCHOOL_PACK,
  id: "pack_salon",
  type: "salon",
  name: "Salon",
  moduleSeeds: ["Appointments", "Loyalty"],
  brandLabel: "Velora",
};

function draft(packId: string): InterviewDraftView {
  return {
    id: "draft_1",
    packId,
    organizationName: "Acme",
    currentStep: 6,
    answers: {},
    recommendations: [],
    status: "ready_for_preview",
    createdAt: "2026-06-25T00:00:00.000Z",
    updatedAt: "2026-06-25T00:00:00.000Z",
  };
}

Deno.test("buildPreview includes seed modules plus universal-employee/auth/analytics", () => {
  const preview = buildPreview(draft("pack_school"), SCHOOL_PACK, "2026-06-25T10:00:00.000Z");
  const ids = preview.modules.map((m) => m.id);
  assertEquals(preview.draftId, "draft_1");
  assertEquals(preview.organizationName, "Acme");
  assertEquals(preview.packId, "pack_school");
  // seeds normalized to snake_case + the three appended modules
  assertEquals(ids.includes("sis"), true);
  assertEquals(ids.includes("education_suite"), true);
  assertEquals(ids.includes("universal_employee"), true);
  assertEquals(ids.includes("auth"), true);
  assertEquals(ids.includes("analytics"), true);
  // seed modules flagged new; auth/analytics are not
  assertEquals(preview.modules.find((m) => m.id === "sis")?.isNew, true);
  assertEquals(preview.modules.find((m) => m.id === "auth")?.isNew, false);
  assertEquals(preview.generatedAt, "2026-06-25T10:00:00.000Z");
});

Deno.test("preview roles/widgets/workflows vary by vertical", () => {
  assertEquals(rolesForPack("school")[0].name, "Principal");
  assertEquals(rolesForPack("salon")[0].name, "Salon Manager");
  assertEquals(rolesForPack("hospital")[0].name, "Hospital Admin");
  assertEquals(rolesForPack("restaurant")[0].name, "Restaurant Manager");
  // unknown vertical falls back to school
  assertEquals(rolesForPack("unknown")[0].name, "Principal");

  assertEquals(widgetsForPack("salon")[0].widgetName, "Chair utilization");
  assertEquals(workflowsForPack("hospital")[1].name, "Insurance claim");

  const salonPreview = buildPreview(draft("pack_salon"), SALON_PACK, "2026-06-25T10:00:00.000Z");
  assertEquals(salonPreview.roles[0].name, "Salon Manager");
});

Deno.test("baselineRecommendation is deterministic, valid, and stable per step", () => {
  const a = baselineRecommendation("pack_salon", "salon", 2);
  const b = baselineRecommendation("pack_salon", "salon", 2);
  assertEquals(a.id, b.id);
  assertEquals(a.id, "rec_pack_salon_2");
  assertEquals(a.title.length > 0, true);
  assertEquals(a.detail.length > 0, true);
  assertEquals(a.confidence, 0.8);
  // unknown vertical → school baseline
  assertEquals(baselineRecommendation("pack_x", "unknown", 0).title, "Fee reminder workflow");
});
