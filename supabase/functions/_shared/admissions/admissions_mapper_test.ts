import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { leadToApi } from "./admissions_mapper.ts";

Deno.test("leadToApi maps snake_case row to camelCase response", () => {
  const api = leadToApi({
    id: "lead-1",
    organization_id: "org-1",
    school_id: "school-1",
    parent_name: "Rajesh",
    student_name: "Ananya",
    class_label: "5",
    phone: "9876543210",
    source: "walk_in",
    campaign: "Open Day",
    stage: "new_enquiry",
    counselor: "Meera",
    score: "hot",
    next_follow_up_label: "Tomorrow",
    email: "raj@example.com",
    address: "Hyderabad",
    notes: "Interested",
    created_at: "2026-06-01T10:00:00.000Z",
    updated_at: "2026-06-04T15:15:00.000Z",
  });

  assertEquals(api.parentName, "Rajesh");
  assertEquals(api.studentName, "Ananya");
  assertEquals(api.source, "walk_in");
  assertEquals(api.stage, "new_enquiry");
});
