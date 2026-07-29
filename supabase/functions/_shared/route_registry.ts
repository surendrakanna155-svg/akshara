// ICA-F4 — declarative module-route registry.
//
// Before F4, api/app.ts held a hand-ordered `moduleRouters` array whose CORRECTNESS
// depended on comments like "MUST precede routeFinance because it greedily owns its
// prefix and returns its own 404 (never null)". Two production shadow bugs shipped
// that way (PRA-P0-12: pilot shadowed a governed exam-mark route; PRA-N-13: a dead
// teacher handler shadowed the governed messages route).
//
// F4 makes routing declarative and order-robust:
//   1. Every module router now returns `null` (not its own 404) when it does not own
//      a path — the SINGLE source of a route-level 404 is the central dispatcher in
//      app.ts. (Enforced statically by route_registry_test.ts.)
//   2. This table declares, per router, the path prefix(es) it owns. Ownership is
//      DISJOINT — no (method, path) is claimed by two entries — so the iteration
//      order below is documentation, not correctness (proven by the single-ownership
//      test). New routers are added by declaring a prefix, not by reasoning about
//      where in a 60-line array they must sit.
//
// The array order is preserved verbatim from the pre-F4 app.ts as a belt-and-suspenders
// measure and to keep the cross-prefix "precede" relationships legible; because every
// router is now non-greedy, that order no longer affects which router wins a path.

import type { AppConfig } from "./config.ts";
import { isPublicModuleSurfaceRoute, PUBLIC_ROUTES } from "./public_routes.ts";

import { routeAdmissions } from "./admissions/admissions_router.ts";
import { routeFinance } from "./finance/finance_router.ts";
import { routeInventoryFinance } from "./inventory_finance/inventory_finance_router.ts";
import { routeSis } from "./sis/sis_router.ts";
import { routeExamAdministration } from "./academics/exam_administration/exam_administration_router.ts";
import { routeAttendance } from "./attendance/attendance_router.ts";
import { routeStaffAttendance } from "./staff_attendance/staff_attendance_router.ts";
import { routeAttendanceAuth } from "./attendance_auth/attendance_auth_router.ts";
import { routeAcademic } from "./academic/academic_router.ts";
import { routeTimetable } from "./timetable/timetable_router.ts";
import { routeTransport } from "./transport/transport_router.ts";
import { routeHr } from "./hr/hr_router.ts";
import { routeHostel } from "./hostel/hostel_router.ts";
import { routeLibrary } from "./library/library_router.ts";
import { routeInventory } from "./inventory/inventory_router.ts";
import { routeAlumni } from "./alumni/alumni_router.ts";
import { routeManagement } from "./management/management_router.ts";
import { routeControlCenter } from "./control_center/control_center_router.ts";
import { routeParent } from "./parent/parent_router.ts";
import { routeTeacher } from "./teacher/teacher_router.ts";
import { routeStudent } from "./student/student_router.ts";
import { routeApproval } from "./approval/approval_router.ts";
import { routeAudit } from "./audit/audit_router.ts";
import { routeSupport } from "./support/support_router.ts";
import { routeIdentity } from "./identity/identity_router.ts";
import { routePayment } from "./payment/payment_router.ts";
import { routeCommunication } from "./communication/communication_router.ts";
import { routePilotOperations } from "./pilot/pilot_operations_router.ts";
import { routeOnboarding } from "./onboarding/onboarding_router.ts";
import { routeCopilot } from "./copilot/copilot_router.ts";
import { routeAiWallet } from "./ai/ai_wallet_router.ts";
import { routeStorageQuota } from "./storage/storage_quota_router.ts";
import { routeSearch } from "./search/search_router.ts";
import { routeAnalytics } from "./analytics/analytics_router.ts";
import { routeDashboard } from "./dashboard/dashboard_router.ts";
import { routeEducation } from "./education/education_router.ts";
import { routeIntelligence } from "./intelligence/intelligence_router.ts";
import { routeEmployee } from "./employee/employee_router.ts";
import { routeInventoryDistribution } from "./inventory_distribution/inventory_distribution_router.ts";
import { routeOperations } from "./operations/operations_router.ts";
import { routeMemories } from "./memories/school_memories_router.ts";
import { routePromotion } from "./promotion/achievement_promotion_router.ts";
import { routeSchoolCalendar } from "./school_calendar/school_calendar_router.ts";
import { routeSocial } from "./social/social_router.ts";
import { routeSetupWizard } from "./setup_wizard/setup_wizard_router.ts";
import { routeWidgetPlatform } from "./widget_platform/widget_platform_router.ts";
import { routeTeacherAssistant } from "./teacher_assistant/teacher_assistant_router.ts";
import { routeParentInsights } from "./parent_insights/parent_insights_router.ts";
import { routePrincipalCommand } from "./principal_command/principal_command_router.ts";
import { routeGrowth } from "./growth/growth_router.ts";
import { routeSchoolCompletion } from "./school_completion/school_completion_router.ts";
import { routeParentExperience } from "./parent_experience/parent_experience_router.ts";
import { routeDirector } from "./director/director_router.ts";
import { routePredictions } from "./predictions/predictions_router.ts";
import { routeOrganizationBuilder } from "./organization_builder/organization_builder_router.ts";
import { routeLegal } from "./legal/legal_router.ts";
import { routeCertificateDesk } from "./certificate_desk/certificate_desk_router.ts";
import { routeGatePass } from "./gate_pass/gate_pass_router.ts";
import { routeComplaints } from "./complaints/complaints_router.ts";
import { routeStudentHealth } from "./student_health/student_health_router.ts";
import { routeSchoolConfig } from "./school_config/school_config_router.ts";
import { routeEntitlements } from "./entitlements/entitlement_router.ts";
import { withEntitlement } from "./entitlements/entitlement_middleware.ts";

/** A module router: returns a Response when it OWNS the path, `null` otherwise. */
export type ModuleRouter = (
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
) => Promise<Response | null>;

export interface ModuleRouteEntry {
  /** Stable debug/label name (used by the route-registry guard). */
  readonly name: string;
  /**
   * Path prefix(es) this entry may claim. Declarative documentation + the basis for
   * the single-ownership guard. A prefix is either an exact path (`/search`) or a
   * subtree root (`/finance`, matching `/finance` and `/finance/...`). Cross-prefix
   * owners (a router that also claims paths under another module's prefix) list every
   * prefix they own.
   */
  readonly prefixes: readonly string[];
  readonly route: ModuleRouter;
  /** Optional rationale (entitlement gating, cross-prefix ownership, ordering). */
  readonly note?: string;
}

/**
 * The ordered module-route registry. Order is preserved from the pre-F4 app.ts but,
 * because every router is now non-greedy (returns null when it does not own a path),
 * it no longer determines which router wins — that is guaranteed by disjoint ownership
 * (route_registry_test.ts::single-ownership).
 */
export const MODULE_ROUTES: readonly ModuleRouteEntry[] = [
  { name: "legal", prefixes: ["/legal"], route: routeLegal },
  { name: "approval", prefixes: ["/approvals"], route: routeApproval },
  { name: "admissions", prefixes: ["/admissions"], route: routeAdmissions },
  {
    name: "inventory_finance",
    prefixes: ["/finance/inventory-reconciliation", "/inventory/vendors", "/inventory/procurement", "/inventory/stock"],
    route: routeInventoryFinance,
    note:
      "ICA-F6: one router owns two disjoint sub-prefixes — /finance/inventory-reconciliation/* (reads) and " +
      "/inventory/{vendors,procurement,stock}/* (procurement+stock). Listed before finance and inventory so the " +
      "'precede' relationship stays legible; both are non-greedy so order is not load-bearing. Self-enforces " +
      "module.inventory on its /inventory/* surface internally, so it is intentionally NOT withEntitlement-wrapped.",
  },
  { name: "finance", prefixes: ["/finance"], route: routeFinance },
  { name: "sis", prefixes: ["/sis"], route: routeSis },
  // PRC-A Batch 2: core school operations (issuing a certificate, releasing a child at
  // the gate, recording an infirmary visit, raising a complaint). Deliberately NOT
  // entitlement-gated — a safety/records capability must not be made purchasable here.
  { name: "certificate_desk", prefixes: ["/certificate-requests"], route: routeCertificateDesk },
  { name: "gate_pass", prefixes: ["/gate-passes"], route: routeGatePass },
  { name: "complaints", prefixes: ["/complaints"], route: routeComplaints },
  {
    name: "student_health",
    prefixes: ["/student-health"],
    route: routeStudentHealth,
    note: "`/student-health`, not `/health` — the system health/readiness endpoints are matched earlier in app.ts and must never be shadowed.",
  },
  { name: "exam_administration", prefixes: ["/academics/exams"], route: routeExamAdministration },
  { name: "attendance", prefixes: ["/attendance"], route: routeAttendance },
  { name: "staff_attendance", prefixes: ["/staff-attendance"], route: routeStaffAttendance },
  { name: "attendance_auth", prefixes: ["/attendance-auth"], route: routeAttendanceAuth },
  {
    name: "academic",
    prefixes: ["/academic/years", "/academic/classes", "/academic/sections", "/academic/subjects", "/academic/class-subjects"],
    route: routeAcademic,
    note: "Owns /academic/* EXCEPT /academic/timetables/* (that subtree belongs to timetable). Already non-greedy pre-F4.",
  },
  { name: "timetable", prefixes: ["/academic/timetables"], route: routeTimetable },
  // B2: optional modules gated by plan entitlement (402 PLAN_UPGRADE_REQUIRED when
  // enforcement is enabled; pass-through by default). The wrapper enforces the slug
  // only for paths under the given prefix and delegates otherwise.
  { name: "transport", prefixes: ["/transport"], route: withEntitlement(routeTransport, "/transport", "module.transport"), note: "entitlement: module.transport" },
  { name: "hr", prefixes: ["/hr"], route: withEntitlement(routeHr, "/hr", "module.hr_payroll"), note: "entitlement: module.hr_payroll; composes staff_duty (/hr/staff-duties) + statutory (/hr/payroll/statutory) sub-routers." },
  { name: "hostel", prefixes: ["/hostel"], route: withEntitlement(routeHostel, "/hostel", "module.hostel"), note: "entitlement: module.hostel" },
  { name: "library", prefixes: ["/library"], route: withEntitlement(routeLibrary, "/library", "module.library"), note: "entitlement: module.library" },
  { name: "inventory_distribution", prefixes: ["/inventory/distribution"], route: routeInventoryDistribution, note: "Sub-prefix of /inventory; listed before inventory." },
  { name: "inventory", prefixes: ["/inventory"], route: withEntitlement(routeInventory, "/inventory", "module.inventory"), note: "entitlement: module.inventory" },
  { name: "employee", prefixes: ["/employees"], route: routeEmployee },
  { name: "operations", prefixes: ["/operations"], route: routeOperations },
  { name: "memories", prefixes: ["/memories"], route: routeMemories },
  { name: "promotion", prefixes: ["/promotions"], route: routePromotion },
  { name: "school_calendar", prefixes: ["/school-calendar"], route: routeSchoolCalendar },
  { name: "social", prefixes: ["/social"], route: routeSocial },
  { name: "alumni", prefixes: ["/alumni"], route: withEntitlement(routeAlumni, "/alumni", "module.alumni"), note: "entitlement: module.alumni" },
  { name: "management", prefixes: ["/management"], route: routeManagement },
  { name: "control_center", prefixes: ["/control-center"], route: routeControlCenter },
  {
    name: "pilot_operations",
    prefixes: ["/teacher/homework", "/teacher/attendance/draft", "/teacher/attendance/submit", "/student/homework", "/parent/leave", "/homework/attachment"],
    route: routePilotOperations,
    note:
      "Cross-prefix: owns specific pilot task paths under /teacher, /student, /parent, /homework. Listed before the " +
      "generic teacher/student/parent routers. PRA-P0-12 removed its shadow of the governed PUT /teacher/exams/marks/:id; " +
      "ownership is disjoint from those routers (locked by dispatch_uniqueness_test).",
  },
  // B7: only the AI pre-fill path is plan-gated; the rest of /onboarding stays open.
  { name: "onboarding", prefixes: ["/onboarding"], route: withEntitlement(routeOnboarding, "/onboarding/startup/ai-prefill", "feature.ai_school_builder"), note: "entitlement (narrow): feature.ai_school_builder on /onboarding/startup/ai-prefill only." },
  { name: "setup_wizard", prefixes: ["/setup-wizard"], route: routeSetupWizard },
  { name: "widget_platform", prefixes: ["/widgets"], route: routeWidgetPlatform },
  { name: "teacher_assistant", prefixes: ["/teacher-assistant"], route: routeTeacherAssistant },
  { name: "parent_insights", prefixes: ["/parent-insights"], route: withEntitlement(routeParentInsights, "/parent-insights", "feature.parent_insights"), note: "entitlement: feature.parent_insights" },
  { name: "principal_command", prefixes: ["/principal-command"], route: routePrincipalCommand },
  { name: "growth", prefixes: ["/growth"], route: withEntitlement(routeGrowth, "/growth", "module.marketing"), note: "entitlement: module.marketing" },
  { name: "school_completion", prefixes: ["/school/"], route: routeSchoolCompletion, note: "Owns /school/* (distinct from /school-config)." },
  { name: "parent_experience", prefixes: ["/parent/experience/"], route: routeParentExperience, note: "Sub-prefix of /parent; listed before parent." },
  { name: "director", prefixes: ["/director"], route: withEntitlement(routeDirector, "/director", "module.multi_branch"), note: "entitlement: module.multi_branch" },
  { name: "predictions", prefixes: ["/predictions"], route: withEntitlement(routePredictions, "/predictions", "feature.ai_predictions"), note: "entitlement: feature.ai_predictions" },
  {
    name: "organization_builder",
    prefixes: ["/platform/org-builder", "/platform/provisioning-jobs"],
    route: routeOrganizationBuilder,
    note: "Self-enforces feature.organization_builder internally (owns two disjoint prefixes a single withEntitlement wrapper cannot cover).",
  },
  { name: "school_config", prefixes: ["/school-config"], route: routeSchoolConfig },
  {
    name: "entitlements",
    prefixes: ["/plans", "/subscription", "/platform/subscriptions", "/platform/organizations"],
    route: routeEntitlements,
    note: "B2 entitlement layer: plan/subscription reads + platform subscription admin.",
  },
  { name: "analytics", prefixes: ["/analytics"], route: routeAnalytics },
  { name: "dashboard", prefixes: ["/dashboard"], route: routeDashboard },
  { name: "education", prefixes: ["/education"], route: routeEducation },
  { name: "intelligence", prefixes: ["/intelligence"], route: routeIntelligence },
  { name: "copilot", prefixes: ["/copilot"], route: routeCopilot },
  { name: "ai_wallet", prefixes: ["/ai-wallet"], route: routeAiWallet, note: "The wallet IS the AI-usage metering, so it is not itself entitlement-gated." },
  { name: "storage_quota", prefixes: ["/storage/quota"], route: routeStorageQuota },
  { name: "search", prefixes: ["/search"], route: routeSearch },
  {
    name: "communication",
    prefixes: ["/communications", "/parent/messages", "/parent/notifications", "/parent/device-tokens", "/student/notifications", "/student/device-tokens", "/teacher/messages"],
    route: routeCommunication,
    note:
      "Cross-prefix: owns /communications/* plus the governed messaging/notification/device-token paths under " +
      "/parent, /student, /teacher. Listed before the generic persona routers. PRA-N-13 locks that it (not the teacher " +
      "router) owns GET /teacher/messages.",
  },
  { name: "parent", prefixes: ["/parent"], route: routeParent },
  { name: "teacher", prefixes: ["/teacher"], route: routeTeacher },
  { name: "student", prefixes: ["/student"], route: routeStudent },
  { name: "payment", prefixes: ["/payments", "/webhooks/razorpay"], route: routePayment },
  { name: "audit", prefixes: ["/audit"], route: routeAudit },
  { name: "support", prefixes: ["/support"], route: routeSupport, note: "ASIP platform-support: schools report Akshara product issues to the Akshara Support Team." },
  { name: "identity", prefixes: ["/identity"], route: routeIdentity, note: "PRA-P1-05: identity-plane admin — per-user permission overrides + custom roles (ICA-G3)." },
] as const;

/**
 * ICA-F1 — public module routes: the ONLY module routes that legitimately reach a
 * handler WITHOUT a user session, because they authenticate by another means.
 *
 * SEC-AUTH-FIRST: this list is no longer declared here. It is DERIVED from the one
 * allow-list in `_shared/public_routes.ts`, which also drives the central gate in
 * `api/app.ts`. Two separately-maintained lists could drift apart and make a route
 * public on one surface but not the other; one table cannot. Add entries there.
 */
export const PUBLIC_MODULE_ROUTE_PREFIXES: readonly string[] = PUBLIC_ROUTES
  .filter((e) => e.surface === "module")
  .map((e) => e.match.kind === "prefix" ? e.match.path : e.match.path);

/** True when (method, path) is an explicitly-allowlisted public (non-session) module route. */
export function isPublicModuleRoute(method: string, path: string): boolean {
  return isPublicModuleSurfaceRoute(method, path);
}

/**
 * Iterate the registry in order and return the first router that OWNS the path (a
 * non-null Response). Returns null when no module router claims the path — the caller
 * (app.ts) turns that single null into the one canonical 404. Because ownership is
 * disjoint, "first" is deterministic regardless of order.
 */
export async function matchModuleRoute(
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
): Promise<Response | null> {
  for (const entry of MODULE_ROUTES) {
    const matched = await entry.route(req, config, method, path);
    if (matched) return matched;
  }
  return null;
}
