import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { handoffToApi, leadToApi } from "./admissions_mapper.ts";

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

Deno.test("handoffToApi maps fee handoff row to client contract", () => {
  const api = handoffToApi({
    id: "handoff-1",
    organization_id: "org-1",
    school_id: "school-1",
    student_id: "student-1",
    application_id: "app-1",
    enrollment_id: "enroll-1",
    academic_year: "2026-27",
    recommended_fee_plan_id: "fee_std_5",
    handoff_status: "sent_to_finance",
    student_name: "Ananya",
    class_label: "5",
    admission_number: "ADM-2026-ABC",
    needs_transport: true,
    needs_hostel: false,
    sis_handoff_label: "Sent to Finance",
    created_at: "2026-06-12T10:00:00.000Z",
    updated_at: "2026-06-12T11:00:00.000Z",
  });

  assertEquals(api.studentName, "Ananya");
  assertEquals(api.handoffStatus, "sent_to_finance");
  assertEquals(api.selectedFeeStructureId, "fee_std_5");
  assertEquals(api.previewStudentId, "student-1");
  assertEquals(api.academicYear, "2026-27");
});
