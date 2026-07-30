// API-100 / API-103 — the DERIVED half of the RBAC route inventory.
//
// ⚠ GENERATED. Do not hand-author entries here.
//
//   deno run --allow-read --allow-env scripts/rbac/rbac_inventory_report.ts
//
// Every rule below was produced by asking the running dispatcher two questions:
//   1. `matchModuleRoute` — do you claim this (method, path)?
//   2. `handleRequest` with a valid token holding ZERO permissions — what do you
//      do to an authenticated non-holder?
// The `permission` field is the slug named in the resulting 403. It is therefore
// the gate the handler ACTUALLY enforces, not a guess from the route's name.
//
// This file exists because the curated inventory
// (`rbac_route_inventory.ts`) was hand-maintained with no code-derived source:
// adding a route did not require touching it, and 246 mutating routes —
// `POST /finance/collections`, `/finance/refunds`, every
// `/approvals/:id/{approve,reject,cancel}`, every `/academics/exams/*` mark
// write — were simply absent. An unlisted route then passed the entire RBAC
// suite by not being listed.
//
// `rbac_generated_inventory_test.ts` re-derives this table on every run and
// fails when it disagrees with what is checked in, so a route added without
// re-running the generator cannot ship.
//
// NOTE on `:id` — the generator normalises every path parameter to `:id`
// (the curated half uses names like `:followupId`). Nothing compares these
// literally: `routeKey()` substitutes any `:name` with the same probe id before
// matching, so the two halves reconcile regardless of parameter naming.

import type { RbacRouteRule } from "./rbac_route_inventory.ts";

/** Mutating routes recovered from the dispatcher, with their enforced gate. */
export const DERIVED_RBAC_ROUTE_RULES: RbacRouteRule[] = [
  // ── academic ──
  { method: "POST", path: "/academic/classes", permission: "manageSis", scope: "school", module: "academic", derived: true },
  { method: "PUT", path: "/academic/classes/:id", permission: "manageSis", scope: "school", module: "academic", derived: true },
  { method: "POST", path: "/academic/sections", permission: "manageSis", scope: "school", module: "academic", derived: true },
  { method: "PUT", path: "/academic/sections/:id", permission: "manageSis", scope: "school", module: "academic", derived: true },
  { method: "POST", path: "/academic/teacher-assignments", permission: "manageSis", scope: "school", module: "academic", derived: true },
  { method: "PUT", path: "/academic/teacher-assignments/:id", permission: "manageSis", scope: "school", module: "academic", derived: true },
  { method: "POST", path: "/academic/years", permission: "manageSis", scope: "school", module: "academic", derived: true },
  { method: "PUT", path: "/academic/years/:id", permission: "manageSis", scope: "school", module: "academic", derived: true },
  // ── admissions ──
  { method: "POST", path: "/admissions/applications", permission: "manageAdmissions", scope: "school", module: "admissions", derived: true },
  { method: "PUT", path: "/admissions/applications/:id", permission: "manageAdmissions", scope: "school", module: "admissions", derived: true },
  { method: "POST", path: "/admissions/applications/:id/submit", permission: "manageAdmissions", scope: "school", module: "admissions", derived: true },
  { method: "POST", path: "/admissions/approval/:id/approve", permission: "approveAdmissions", scope: "school", module: "admissions", derived: true },
  { method: "POST", path: "/admissions/approval/:id/notes", permission: "manageAdmissions", scope: "school", module: "admissions", derived: true },
  { method: "POST", path: "/admissions/approval/:id/reject", permission: "approveAdmissions", scope: "school", module: "admissions", derived: true },
  { method: "POST", path: "/admissions/documents/:id/approve", permission: "approveAdmissions", scope: "school", module: "admissions", derived: true },
  { method: "POST", path: "/admissions/documents/:id/reject", permission: "approveAdmissions", scope: "school", module: "admissions", derived: true },
  { method: "POST", path: "/admissions/enrollments", permission: "manageAdmissions", scope: "school", module: "admissions", derived: true },
  { method: "PATCH", path: "/admissions/handoffs/:id/status", permission: "manageAdmissions", scope: "school", module: "admissions", derived: true },
  { method: "POST", path: "/admissions/handoffs/send", permission: "manageAdmissions", scope: "school", module: "admissions", derived: true },
  { method: "PUT", path: "/admissions/leads/:id", permission: "manageAdmissions", scope: "school", module: "admissions", derived: true },
  { method: "PATCH", path: "/admissions/leads/:id/assign", permission: "manageAdmissions", scope: "school", module: "admissions", derived: true },
  { method: "POST", path: "/admissions/leads/:id/followups", permission: "manageAdmissions", scope: "school", module: "admissions", derived: true },
  { method: "POST", path: "/admissions/leads/:id/notes", permission: "manageAdmissions", scope: "school", module: "admissions", derived: true },
  { method: "PATCH", path: "/admissions/leads/:id/stage", permission: "manageAdmissions", scope: "school", module: "admissions", derived: true },
  { method: "PUT", path: "/admissions/leads/bulk", permission: "manageAdmissions", scope: "school", module: "admissions", derived: true },
  { method: "PUT", path: "/admissions/leads/check-duplicate", permission: "manageAdmissions", scope: "school", module: "admissions", derived: true },
  // ── alumni ──
  { method: "POST", path: "/alumni/campaigns", permission: "manageAlumni", scope: "school", module: "alumni", derived: true },
  { method: "POST", path: "/alumni/events", permission: "manageAlumni", scope: "school", module: "alumni", derived: true },
  { method: "POST", path: "/alumni/mentorship", permission: "manageAlumni", scope: "school", module: "alumni", derived: true },
  { method: "POST", path: "/alumni/registry", permission: "manageAlumni", scope: "school", module: "alumni", derived: true },
  // ── approval ──
  { method: "POST", path: "/approvals", permission: null, scope: "school", module: "approval", derived: true }, // ungated at dispatch: 422 Missing required approval fields
  { method: "POST", path: "/approvals/:id/approve", permission: null, scope: "school", module: "approval", derived: true }, // ungated at dispatch: 503 ERP_TENANT_DATABASE_URL is not configured — tenant-enforced queries un
  { method: "POST", path: "/approvals/:id/cancel", permission: null, scope: "school", module: "approval", derived: true }, // ungated at dispatch: 500 An unexpected error occurred.
  { method: "POST", path: "/approvals/:id/reject", permission: null, scope: "school", module: "approval", derived: true }, // ungated at dispatch: 503 ERP_TENANT_DATABASE_URL is not configured — tenant-enforced queries un
  { method: "POST", path: "/approvals/audit", permission: "manageManagement", scope: "school", module: "approval", derived: true },
  // ── attendance ──
  { method: "POST", path: "/attendance/corrections", permission: "manageSis", scope: "school", module: "attendance", derived: true },
  { method: "PATCH", path: "/attendance/corrections/:id/status", permission: "approveAttendanceCorrection", scope: "school", module: "attendance", derived: true },
  // ── attendance_auth ──
  { method: "POST", path: "/attendance-auth/face/enroll", permission: null, scope: "school", module: "attendance_auth", derived: true }, // ungated at dispatch: 503 ERP_TENANT_DATABASE_URL is not configured — tenant-enforced queries un
  { method: "POST", path: "/attendance-auth/face/revoke", permission: null, scope: "school", module: "attendance_auth", derived: true }, // ungated at dispatch: 503 ERP_TENANT_DATABASE_URL is not configured — tenant-enforced queries un
  // ── audit ──
  { method: "POST", path: "/domain-events/process-pending", permission: "manageCommunications", scope: "school", module: "audit", derived: true },
  // ── communication ──
  { method: "POST", path: "/communications/broadcasts/run-scheduled", permission: "manageCommunications", scope: "school", module: "communication", derived: true },
  { method: "POST", path: "/communications/notifications/process-queue", permission: "manageCommunications", scope: "school", module: "communication", derived: true },
  { method: "POST", path: "/parent/device-tokens/register", permission: null, scope: "parent", module: "communication", derived: true }, // ungated at dispatch: 422 token is required
  { method: "POST", path: "/parent/device-tokens/unregister", permission: null, scope: "parent", module: "communication", derived: true }, // ungated at dispatch: 422 token is required
  { method: "POST", path: "/parent/messages", permission: null, scope: "parent", module: "communication", derived: true }, // ungated at dispatch: 503 ERP_TENANT_DATABASE_URL is not configured — tenant-enforced queries un
  { method: "POST", path: "/parent/messages/send", permission: null, scope: "parent", module: "communication", derived: true }, // ungated at dispatch: 503 ERP_TENANT_DATABASE_URL is not configured — tenant-enforced queries un
  { method: "POST", path: "/parent/notifications/mark-all-read", permission: null, scope: "parent", module: "communication", derived: true }, // ungated at dispatch: 503 ERP_TENANT_DATABASE_URL is not configured — tenant-enforced queries un
  { method: "POST", path: "/parent/notifications/mark-read", permission: null, scope: "parent", module: "communication", derived: true }, // ungated at dispatch: 422 notification_id is required
  { method: "POST", path: "/student/device-tokens/register", permission: null, scope: "student", module: "communication", derived: true }, // ungated at dispatch: 422 token is required
  { method: "POST", path: "/student/device-tokens/unregister", permission: null, scope: "student", module: "communication", derived: true }, // ungated at dispatch: 422 token is required
  { method: "POST", path: "/student/notifications/mark-all-read", permission: null, scope: "student", module: "communication", derived: true }, // ungated at dispatch: 503 ERP_TENANT_DATABASE_URL is not configured — tenant-enforced queries un
  { method: "POST", path: "/student/notifications/mark-read", permission: null, scope: "student", module: "communication", derived: true }, // ungated at dispatch: 422 notification_id is required
  { method: "POST", path: "/teacher/messages", permission: null, scope: "school", module: "communication", derived: true }, // ungated at dispatch: 503 ERP_TENANT_DATABASE_URL is not configured — tenant-enforced queries un
  { method: "POST", path: "/teacher/messages/send", permission: null, scope: "school", module: "communication", derived: true }, // ungated at dispatch: 503 ERP_TENANT_DATABASE_URL is not configured — tenant-enforced queries un
  // ── complaints ──
  { method: "POST", path: "/complaints/:id/photo", permission: "raiseComplaint", scope: "school", module: "complaints", derived: true }, // OR-gate: raiseComplaint | manageComplaints | viewComplaintsPrincipal
  // ── control_center ──
  { method: "POST", path: "/control-center/crm-pipeline", permission: "manageControlCenter", scope: "organization", module: "control_center", derived: true },
  { method: "PUT", path: "/control-center/crm-pipeline", permission: "manageControlCenter", scope: "organization", module: "control_center", derived: true },
  { method: "POST", path: "/control-center/features", permission: "managePlatformFeatures", scope: "organization", module: "control_center", derived: true },
  { method: "PUT", path: "/control-center/features", permission: "managePlatformFeatures", scope: "organization", module: "control_center", derived: true },
  { method: "POST", path: "/control-center/providers", permission: "managePlatformProviders", scope: "organization", module: "control_center", derived: true },
  { method: "PUT", path: "/control-center/providers", permission: "managePlatformProviders", scope: "organization", module: "control_center", derived: true },
  { method: "POST", path: "/control-center/schools", permission: "manageControlCenter", scope: "organization", module: "control_center", derived: true },
  { method: "PUT", path: "/control-center/schools", permission: "manageControlCenter", scope: "organization", module: "control_center", derived: true },
  { method: "POST", path: "/control-center/vault/reencrypt", permission: "managePlatformVault", scope: "organization", module: "control_center", derived: true },
  { method: "PUT", path: "/control-center/vault/reencrypt", permission: "managePlatformVault", scope: "organization", module: "control_center", derived: true },
  { method: "POST", path: "/control-center/vault/rotate", permission: "managePlatformVault", scope: "organization", module: "control_center", derived: true },
  { method: "PUT", path: "/control-center/vault/rotate", permission: "managePlatformVault", scope: "organization", module: "control_center", derived: true },
  // ── copilot ──
  { method: "POST", path: "/copilot/sessions", permission: "runAiCopilot", scope: "school", module: "copilot", derived: true },
  { method: "POST", path: "/copilot/sessions/:id/messages", permission: "runAiCopilot", scope: "school", module: "copilot", derived: true },
  // ── director ──
  { method: "POST", path: "/director/summary", permission: "viewDirectorPortal", scope: "organization", module: "director", derived: true },
  // ── education ──
  { method: "POST", path: "/education/evidence/responses", permission: "manageEducation", scope: "school", module: "education", derived: true },
  { method: "POST", path: "/education/homework/:id/publish", permission: "manageEducation", scope: "school", module: "education", derived: true },
  { method: "PUT", path: "/education/question-bank/:id", permission: "manageEducation", scope: "school", module: "education", derived: true },
  { method: "DELETE", path: "/education/question-bank/:id", permission: "manageEducation", scope: "school", module: "education", derived: true },
  { method: "POST", path: "/education/question-bank/import", permission: "manageEducation", scope: "school", module: "education", derived: true },
  { method: "PUT", path: "/education/question-papers/:id/items/:id", permission: "manageEducation", scope: "school", module: "education", derived: true },
  { method: "POST", path: "/education/question-papers/:id/items/:id/moderate", permission: "manageEducation", scope: "school", module: "education", derived: true },
  { method: "POST", path: "/education/question-papers/:id/items/:id/promote", permission: "manageEducation", scope: "school", module: "education", derived: true },
  { method: "POST", path: "/education/question-papers/:id/items/:id/regenerate", permission: "manageEducation", scope: "school", module: "education", derived: true },
  { method: "POST", path: "/education/question-papers/:id/submit", permission: "manageEducation", scope: "school", module: "education", derived: true },
  { method: "PUT", path: "/education/report-remarks/:id", permission: "manageEducation", scope: "school", module: "education", derived: true },
  { method: "POST", path: "/education/report-remarks/:id/publish", permission: "manageEducation", scope: "school", module: "education", derived: true },
  // ── exam_administration ──
  { method: "POST", path: "/academics/exams", permission: "manageExams", scope: "school", module: "exam_administration", derived: true },
  { method: "POST", path: "/academics/exams/:id/marks/batch", permission: "manageExamMarks", scope: "school", module: "exam_administration", derived: true },
  { method: "PUT", path: "/academics/exams/:id/remarks/:id", permission: "manageExamMarks", scope: "school", module: "exam_administration", derived: true },
  { method: "POST", path: "/academics/exams/:id/students/:id/grace", permission: "moderateExamMarks", scope: "school", module: "exam_administration", derived: true },
  { method: "PUT", path: "/academics/exams/grade-scale", permission: "manageExams", scope: "school", module: "exam_administration", derived: true },
  { method: "PATCH", path: "/academics/exams/marks/:id", permission: "manageExamMarks", scope: "school", module: "exam_administration", derived: true },
  { method: "POST", path: "/academics/exams/marks/remind", permission: "manageExams", scope: "school", module: "exam_administration", derived: true },
  { method: "PATCH", path: "/academics/exams/marks/remind", permission: "manageExamMarks", scope: "school", module: "exam_administration", derived: true },
  // ── finance ──
  { method: "POST", path: "/finance/collections", permission: "manageFinance", scope: "school", module: "finance", derived: true },
  { method: "POST", path: "/finance/collections/:id/cancel", permission: "manageFinance", scope: "school", module: "finance", derived: true },
  { method: "POST", path: "/finance/day-close", permission: "manageFinance", scope: "school", module: "finance", derived: true },
  { method: "POST", path: "/finance/day-close/:id/reopen", permission: "manageFinance", scope: "school", module: "finance", derived: true },
  { method: "POST", path: "/finance/discounts", permission: "manageFinance", scope: "school", module: "finance", derived: true },
  { method: "PUT", path: "/finance/discounts/:id", permission: "manageFinance", scope: "school", module: "finance", derived: true },
  { method: "POST", path: "/finance/discounts/:id/apply", permission: "manageFinance", scope: "school", module: "finance", derived: true },
  { method: "POST", path: "/finance/fee-assignment/assign", permission: "manageFinance", scope: "school", module: "finance", derived: true },
  { method: "POST", path: "/finance/fee-assignments", permission: "manageFinance", scope: "school", module: "finance", derived: true },
  { method: "PATCH", path: "/finance/fee-assignments/:id/cancel", permission: "manageFinance", scope: "school", module: "finance", derived: true },
  { method: "POST", path: "/finance/fee-assignments/bulk", permission: "manageFinance", scope: "school", module: "finance", derived: true },
  { method: "POST", path: "/finance/fee-reductions/:id/approve", permission: "approveFeeConcession", scope: "school", module: "finance", derived: true },
  { method: "POST", path: "/finance/fee-reductions/:id/reject", permission: "approveFeeConcession", scope: "school", module: "finance", derived: true },
  { method: "POST", path: "/finance/fee-reductions/:id/reverse", permission: "approveFeeConcession", scope: "school", module: "finance", derived: true },
  { method: "POST", path: "/finance/fee-reductions/discount-applications", permission: "manageFinance", scope: "school", module: "finance", derived: true },
  { method: "POST", path: "/finance/fee-reductions/scholarship-awards", permission: "manageFinance", scope: "school", module: "finance", derived: true },
  { method: "PUT", path: "/finance/fee-structures/:id", permission: "manageFinance", scope: "school", module: "finance", derived: true },
  { method: "PATCH", path: "/finance/fee-structures/:id/archive", permission: "manageFinance", scope: "school", module: "finance", derived: true },
  { method: "POST", path: "/finance/invoices/:id/cancel", permission: "manageFinance", scope: "school", module: "finance", derived: true },
  { method: "POST", path: "/finance/invoices/:id/issue", permission: "manageFinance", scope: "school", module: "finance", derived: true },
  { method: "POST", path: "/finance/invoices/:id/waive-late-fee", permission: "manageFinance", scope: "school", module: "finance", derived: true },
  { method: "POST", path: "/finance/late-fees/accrue", permission: "manageFinance", scope: "school", module: "finance", derived: true },
  { method: "POST", path: "/finance/payments/offline/:id/bounce", permission: "manageFinance", scope: "school", module: "finance", derived: true },
  { method: "POST", path: "/finance/recovery/contacts", permission: "manageFinance", scope: "school", module: "finance", derived: true },
  { method: "POST", path: "/finance/recovery/promises", permission: "manageFinance", scope: "school", module: "finance", derived: true },
  { method: "POST", path: "/finance/recovery/promises/:id/resolve", permission: "manageFinance", scope: "school", module: "finance", derived: true },
  { method: "POST", path: "/finance/recovery/targets", permission: "manageFinance", scope: "school", module: "finance", derived: true },
  { method: "POST", path: "/finance/refunds", permission: "manageFinance", scope: "school", module: "finance", derived: true },
  { method: "POST", path: "/finance/refunds/:id/reject", permission: "approveRefunds", scope: "school", module: "finance", derived: true },
  { method: "POST", path: "/finance/scholarships/:id/award", permission: "manageFinance", scope: "school", module: "finance", derived: true },
  // ── growth ──
  { method: "PUT", path: "/growth/campaigns/:id", permission: "manageGrowthPlatform", scope: "school", module: "growth", derived: true }, // OR-gate: manageGrowthPlatform | manageAdmissions
  { method: "POST", path: "/growth/campaigns/:id/pause", permission: "manageGrowthPlatform", scope: "school", module: "growth", derived: true }, // OR-gate: manageGrowthPlatform | manageAdmissions
  { method: "POST", path: "/growth/inquiries", permission: "manageGrowthPlatform", scope: "school", module: "growth", derived: true }, // OR-gate: manageGrowthPlatform | manageAdmissions
  { method: "POST", path: "/growth/inquiries/:id/convert", permission: "manageGrowthPlatform", scope: "school", module: "growth", derived: true }, // OR-gate: manageGrowthPlatform | manageAdmissions
  // ── hostel ──
  { method: "POST", path: "/hostel/rooms", permission: "manageHostel", scope: "school", module: "hostel", derived: true },
  { method: "POST", path: "/hostel/students", permission: "manageHostel", scope: "school", module: "hostel", derived: true },
  { method: "POST", path: "/hostel/students/:id/checkout", permission: "manageHostel", scope: "school", module: "hostel", derived: true },
  { method: "POST", path: "/hostel/students/:id/room", permission: "manageHostel", scope: "school", module: "hostel", derived: true },
  { method: "POST", path: "/hostel/visitors", permission: "manageHostel", scope: "school", module: "hostel", derived: true },
  // ── hr ──
  { method: "POST", path: "/hr/employees", permission: "manageHr", scope: "school", module: "hr", derived: true },
  { method: "PUT", path: "/hr/employees/:id", permission: "manageHr", scope: "school", module: "hr", derived: true },
  { method: "POST", path: "/hr/employees/:id/probation", permission: "manageHr", scope: "school", module: "hr", derived: true },
  { method: "PATCH", path: "/hr/employees/:id/status", permission: "manageHr", scope: "school", module: "hr", derived: true },
  { method: "PUT", path: "/hr/employees/export", permission: "manageHr", scope: "school", module: "hr", derived: true },
  { method: "POST", path: "/hr/leave", permission: "manageHr", scope: "school", module: "hr", derived: true },
  { method: "POST", path: "/hr/leave/:id/approve", permission: "manageHr", scope: "school", module: "hr", derived: true },
  { method: "POST", path: "/hr/leave/:id/reject", permission: "manageHr", scope: "school", module: "hr", derived: true },
  { method: "POST", path: "/hr/leave/accrual/run", permission: "manageHr", scope: "school", module: "hr", derived: true },
  { method: "POST", path: "/hr/leave/batch-decide", permission: "manageHr", scope: "school", module: "hr", derived: true },
  { method: "POST", path: "/hr/payroll/run", permission: "manageHr", scope: "school", module: "hr", derived: true },
  { method: "POST", path: "/hr/payroll/run/generate", permission: "manageHr", scope: "school", module: "hr", derived: true },
  { method: "POST", path: "/hr/payroll/statutory/config", permission: "manageHr", scope: "school", module: "hr", derived: true },
  { method: "POST", path: "/hr/payroll/statutory/pt-slabs", permission: "manageHr", scope: "school", module: "hr", derived: true },
  { method: "POST", path: "/hr/payroll/structures", permission: "manageHr", scope: "school", module: "hr", derived: true },
  { method: "POST", path: "/hr/performance", permission: "manageHr", scope: "school", module: "hr", derived: true },
  { method: "PUT", path: "/hr/performance/:id", permission: "manageHr", scope: "school", module: "hr", derived: true },
  { method: "POST", path: "/hr/recruitment", permission: "manageHr", scope: "school", module: "hr", derived: true },
  { method: "PUT", path: "/hr/recruitment/:id", permission: "manageHr", scope: "school", module: "hr", derived: true },
  { method: "PUT", path: "/hr/settings", permission: "manageHr", scope: "school", module: "hr", derived: true },
  { method: "POST", path: "/hr/staff-duties/invigilations", permission: "manageHr", scope: "school", module: "hr", derived: true },
  { method: "POST", path: "/hr/staff-duties/non-teaching", permission: "manageHr", scope: "school", module: "hr", derived: true },
  { method: "POST", path: "/hr/staff-duties/substitutions", permission: "manageHr", scope: "school", module: "hr", derived: true },
  // ── identity ──
  { method: "POST", path: "/identity/roles", permission: "manageManagement", scope: "school", module: "identity", derived: true },
  { method: "POST", path: "/identity/roles/delete", permission: "manageManagement", scope: "school", module: "identity", derived: true },
  { method: "POST", path: "/identity/roles/update", permission: "manageManagement", scope: "school", module: "identity", derived: true },
  // ── intelligence ──
  { method: "POST", path: "/intelligence/briefs/prewarm", permission: "viewAnalytics", scope: "school", module: "intelligence", derived: true },
  { method: "POST", path: "/intelligence/parent-guidance/generate", permission: "generateIntelligence", scope: "school", module: "intelligence", derived: true },
  { method: "POST", path: "/intelligence/recommendations/feedback", permission: null, scope: "school", module: "intelligence", derived: true }, // ungated at dispatch: 422 itemKey required
  { method: "POST", path: "/intelligence/teacher-effectiveness/parent-meeting-summary", permission: "manageLessonLogs", scope: "school", module: "intelligence", derived: true },
  // ── inventory ──
  { method: "POST", path: "/inventory/allocations", permission: "manageInventory", scope: "school", module: "inventory", derived: true },
  { method: "POST", path: "/inventory/assets", permission: "manageInventory", scope: "school", module: "inventory", derived: true },
  { method: "POST", path: "/inventory/categories", permission: "manageInventory", scope: "school", module: "inventory", derived: true },
  { method: "POST", path: "/inventory/maintenance", permission: "manageInventory", scope: "school", module: "inventory", derived: true },
  // ── inventory_distribution ──
  { method: "POST", path: "/inventory/distribution/items/:id/replacement", permission: "manageInventoryDistribution", scope: "school", module: "inventory_distribution", derived: true }, // OR-gate: manageInventoryDistribution | manageInventory
  { method: "POST", path: "/inventory/distribution/items/:id/status", permission: null, scope: "school", module: "inventory_distribution", derived: true }, // ungated at dispatch: 422 status is required
  // ── inventory_finance ──
  { method: "POST", path: "/inventory/procurement/orders", permission: "manageInventory", scope: "school", module: "inventory_finance", derived: true },
  { method: "POST", path: "/inventory/procurement/orders/:id/approve", permission: "manageInventory", scope: "school", module: "inventory_finance", derived: true },
  { method: "POST", path: "/inventory/procurement/orders/:id/receive", permission: "manageInventory", scope: "school", module: "inventory_finance", derived: true },
  { method: "POST", path: "/inventory/vendors/catalog", permission: "manageInventory", scope: "school", module: "inventory_finance", derived: true },
  // ── legal ──
  { method: "POST", path: "/legal/accept", permission: null, scope: "school", module: "legal", derived: true }, // ungated at dispatch: 422 acceptances must be a non-empty array
  // ── library ──
  { method: "POST", path: "/library/accessions", permission: "manageLibrary", scope: "school", module: "library", derived: true },
  { method: "POST", path: "/library/accessions/:id/lost", permission: "manageLibrary", scope: "school", module: "library", derived: true },
  { method: "POST", path: "/library/accessions/:id/withdraw", permission: "manageLibrary", scope: "school", module: "library", derived: true },
  { method: "POST", path: "/library/catalog", permission: "manageLibrary", scope: "school", module: "library", derived: true },
  { method: "PUT", path: "/library/catalog/import", permission: "manageLibrary", scope: "school", module: "library", derived: true },
  { method: "DELETE", path: "/library/catalog/import", permission: "manageLibrary", scope: "school", module: "library", derived: true },
  { method: "POST", path: "/library/digital-resources", permission: "manageLibrary", scope: "school", module: "library", derived: true },
  { method: "POST", path: "/library/issues", permission: "manageLibrary", scope: "school", module: "library", derived: true },
  { method: "POST", path: "/library/returns", permission: "manageLibrary", scope: "school", module: "library", derived: true },
  // ── management ──
  { method: "PUT", path: "/management/settings", permission: "manageManagement", scope: "school", module: "management", derived: true },
  // ── onboarding ──
  { method: "POST", path: "/onboarding/invites/:id/mark-sent", permission: "manageOnboarding", scope: "school", module: "onboarding", derived: true },
  { method: "PUT", path: "/onboarding/startup", permission: "manageOnboarding", scope: "school", module: "onboarding", derived: true },
  { method: "POST", path: "/onboarding/startup/ai-prefill", permission: "manageOnboarding", scope: "school", module: "onboarding", derived: true },
  { method: "POST", path: "/onboarding/startup/go-live", permission: "manageOnboarding", scope: "school", module: "onboarding", derived: true },
  { method: "POST", path: "/onboarding/students/generate", permission: "manageOnboarding", scope: "school", module: "onboarding", derived: true },
  // ── organization_builder ──
  { method: "POST", path: "/platform/org-builder/preview", permission: "manageOrganizationBuilder", scope: "organization", module: "organization_builder", derived: true },
  // ── parent ──
  { method: "POST", path: "/parent/meetings/:id/rsvp", permission: null, scope: "parent", module: "parent", derived: true }, // ungated at dispatch: 403 No linked children on parent account
  // ── parent_experience ──
  { method: "POST", path: "/parent/experience/summary/refresh", permission: "viewParentAcademicSummary", scope: "parent", module: "parent_experience", derived: true },
  // ── parent_insights ──
  { method: "PUT", path: "/parent-insights/language-preference", permission: "viewParentInsights", scope: "parent", module: "parent_insights", derived: true },
  // ── pilot_operations ──
  { method: "POST", path: "/homework/attachment/download", permission: null, scope: "school", module: "pilot_operations", derived: true }, // ungated at dispatch: 422 storage_path is required
  { method: "POST", path: "/student/homework/attachment/presign", permission: null, scope: "student", module: "pilot_operations", derived: true }, // ungated at dispatch: 403 Student scope required
  { method: "POST", path: "/student/homework/submit", permission: null, scope: "student", module: "pilot_operations", derived: true }, // ungated at dispatch: 403 Student scope required
  { method: "POST", path: "/teacher/homework/:id/notify-non-submitters", permission: "manageHomework", scope: "school", module: "pilot_operations", derived: true },
  { method: "POST", path: "/teacher/homework/attachment/presign", permission: "manageHomework", scope: "school", module: "pilot_operations", derived: true },
  { method: "POST", path: "/teacher/homework/bulk-review", permission: "manageHomework", scope: "school", module: "pilot_operations", derived: true },
  // ── school_completion ──
  { method: "POST", path: "/school/academic/complete-topic", permission: "manageAcademicProgress", scope: "school", module: "school_completion", derived: true },
  { method: "PUT", path: "/school/branding", permission: "manageSchoolBranding", scope: "school", module: "school_completion", derived: true },
  { method: "POST", path: "/school/class-subject-assignments", permission: "manageSubjectAssignments", scope: "school", module: "school_completion", derived: true },
  { method: "DELETE", path: "/school/class-subject-assignments/:id", permission: "manageSubjectAssignments", scope: "school", module: "school_completion", derived: true },
  { method: "POST", path: "/school/communications/send-template", permission: "manageCommunicationTemplates", scope: "school", module: "school_completion", derived: true },
  { method: "POST", path: "/school/exam-timetable/generate", permission: "manageAcademicRooms", scope: "school", module: "school_completion", derived: true },
  { method: "POST", path: "/school/lesson-logs", permission: "manageLessonLogs", scope: "school", module: "school_completion", derived: true },
  { method: "POST", path: "/school/rooms", permission: "manageAcademicRooms", scope: "school", module: "school_completion", derived: true },
  { method: "POST", path: "/school/rooms/allocate", permission: "manageAcademicRooms", scope: "school", module: "school_completion", derived: true },
  { method: "POST", path: "/school/subjects", permission: "manageSubjects", scope: "school", module: "school_completion", derived: true },
  { method: "PATCH", path: "/school/subjects/:id", permission: "manageSubjects", scope: "school", module: "school_completion", derived: true },
  { method: "POST", path: "/school/syllabus/clone", permission: "manageSyllabus", scope: "school", module: "school_completion", derived: true },
  { method: "POST", path: "/school/syllabus/generate", permission: "manageSyllabus", scope: "school", module: "school_completion", derived: true },
  { method: "POST", path: "/school/teacher-subject-assignments", permission: "manageSubjectAssignments", scope: "school", module: "school_completion", derived: true },
  { method: "POST", path: "/school/timetables/automate", permission: "manageTimetableAutomation", scope: "school", module: "school_completion", derived: true }, // OR-gate: manageTimetableAutomation | manageAcademicTimetable
  { method: "POST", path: "/school/timetables/optimize/apply", permission: "manageAcademicTimetable", scope: "school", module: "school_completion", derived: true },
  { method: "POST", path: "/school/timetables/reassign", permission: "manageAcademicTimetable", scope: "school", module: "school_completion", derived: true },
  { method: "POST", path: "/school/timetables/substitute/assign", permission: "manageAcademicTimetable", scope: "school", module: "school_completion", derived: true },
  { method: "PUT", path: "/school/whatsapp-provider", permission: "managePlatformWhatsApp", scope: "school", module: "school_completion", derived: true },
  { method: "POST", path: "/school/whatsapp-provider/test", permission: "managePlatformWhatsApp", scope: "school", module: "school_completion", derived: true },
  // ── setup_wizard ──
  { method: "POST", path: "/setup-wizard/sessions/:id/advance", permission: "manageSchoolSetup", scope: "school", module: "setup_wizard", derived: true },
  // ── sis ──
  { method: "POST", path: "/sis/admissions-conversion", permission: "manageSis", scope: "school", module: "sis", derived: true },
  { method: "POST", path: "/sis/enrollments", permission: "manageSis", scope: "school", module: "sis", derived: true },
  { method: "PUT", path: "/sis/enrollments/:id", permission: "manageSis", scope: "school", module: "sis", derived: true },
  { method: "PUT", path: "/sis/students/:id", permission: "manageSis", scope: "school", module: "sis", derived: true },
  { method: "POST", path: "/sis/students/:id/documents", permission: "manageSis", scope: "school", module: "sis", derived: true },
  { method: "POST", path: "/sis/students/:id/documents/presign", permission: "manageSis", scope: "school", module: "sis", derived: true },
  { method: "PATCH", path: "/sis/students/:id/status", permission: "manageSis", scope: "school", module: "sis", derived: true },
  // ── staff_attendance ──
  { method: "POST", path: "/staff-attendance/enroll-face", permission: "markStaffAttendance", scope: "school", module: "staff_attendance", derived: true },
  { method: "PUT", path: "/staff-attendance/geofence", permission: "manageSchoolGeofence", scope: "school", module: "staff_attendance", derived: true },
  { method: "POST", path: "/staff-attendance/manual-request", permission: "markStaffAttendance", scope: "school", module: "staff_attendance", derived: true },
  { method: "POST", path: "/staff-attendance/manual-request/decide", permission: "approveStaffAttendance", scope: "school", module: "staff_attendance", derived: true },
  // ── teacher ──
  { method: "POST", path: "/teacher/exams/:id/process", permission: "submitExamResults", scope: "school", module: "teacher", derived: true },
  { method: "POST", path: "/teacher/exams/:id/publish", permission: "publishExamResults", scope: "school", module: "teacher", derived: true },
  { method: "POST", path: "/teacher/leave", permission: null, scope: "school", module: "teacher", derived: true }, // ungated at dispatch: 503 ERP_TENANT_DATABASE_URL is not configured — tenant-enforced queries un
  { method: "POST", path: "/teacher/parent-communication", permission: "manageTeacherAssistant", scope: "school", module: "teacher", derived: true },
  { method: "POST", path: "/teacher/parent-communication/concerns", permission: "manageTeacherAssistant", scope: "school", module: "teacher", derived: true },
  { method: "POST", path: "/teacher/parent-communication/concerns/:id/dismiss", permission: "manageTeacherAssistant", scope: "school", module: "teacher", derived: true },
  // ── teacher_assistant ──
  { method: "PATCH", path: "/teacher-assistant/interventions/:id", permission: "manageTeacherAssistant", scope: "school", module: "teacher_assistant", derived: true },
  // ── timetable ──
  { method: "POST", path: "/academic/timetables/:id/publish", permission: "publishAcademicTimetable", scope: "school", module: "timetable", derived: true },
  { method: "POST", path: "/academic/timetables/generate", permission: "manageAcademicTimetable", scope: "school", module: "timetable", derived: true },
  { method: "POST", path: "/academic/timetables/periods/move", permission: "manageAcademicTimetable", scope: "school", module: "timetable", derived: true },
  { method: "POST", path: "/academic/timetables/periods/reassign-teacher", permission: "manageAcademicTimetable", scope: "school", module: "timetable", derived: true },
  { method: "POST", path: "/academic/timetables/validate", permission: "manageAcademicTimetable", scope: "school", module: "timetable", derived: true },
  // ── transport ──
  { method: "DELETE", path: "/transport/allocations/bulk", permission: "manageTransport", scope: "school", module: "transport", derived: true },
  { method: "POST", path: "/transport/attendance/generate", permission: "manageTransport", scope: "school", module: "transport", derived: true },
  { method: "POST", path: "/transport/demands/bulk", permission: "manageTransport", scope: "school", module: "transport", derived: true },
  { method: "PUT", path: "/transport/routes/:id/stops/reorder", permission: "manageTransport", scope: "school", module: "transport", derived: true },
  { method: "DELETE", path: "/transport/routes/:id/stops/reorder", permission: "manageTransport", scope: "school", module: "transport", derived: true },
  // ── widget_platform ──
  { method: "POST", path: "/widgets/data/refresh", permission: "manageDynamicWidgets", scope: "school", module: "widget_platform", derived: true },
  { method: "PUT", path: "/widgets/layouts/versions", permission: "manageDynamicWidgets", scope: "school", module: "widget_platform", derived: true },
];
