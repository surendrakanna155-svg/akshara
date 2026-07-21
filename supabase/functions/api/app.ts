import { loadConfig } from "../_shared/config.ts";
import type { AppConfig } from "../_shared/config.ts";
import {
  handleHealth,
  handleContextSwitch,
  handleLogin,
  handleLogout,
  handleLogoutAll,
  handleMe,
  handlePermissions,
  handleReady,
  handleRefresh,
  handleRevokeSession,
  handleVerifyOtp,
} from "../_shared/auth_handlers.ts";
import { handleTenantAccessHealth, handleOperationsHealth, handleStorageHealth, handleProviderHealth, handleBackupHealth } from "../_shared/tenant_handlers.ts";
import { routeAdmissions } from "../_shared/admissions/admissions_router.ts";
import { routeFinance } from "../_shared/finance/finance_router.ts";
import { routeInventoryFinance } from "../_shared/inventory_finance/inventory_finance_router.ts";
import { routeSis } from "../_shared/sis/sis_router.ts";
import { routeExamAdministration } from "../_shared/academics/exam_administration/exam_administration_router.ts";
import { routeAttendance } from "../_shared/attendance/attendance_router.ts";
import { routeStaffAttendance } from "../_shared/staff_attendance/staff_attendance_router.ts";
import { routeAttendanceAuth } from "../_shared/attendance_auth/attendance_auth_router.ts";
import { routeAcademic } from "../_shared/academic/academic_router.ts";
import { routeTimetable } from "../_shared/timetable/timetable_router.ts";
import { routeTransport } from "../_shared/transport/transport_router.ts";
import { routeHr } from "../_shared/hr/hr_router.ts";
import { routeHostel } from "../_shared/hostel/hostel_router.ts";
import { routeLibrary } from "../_shared/library/library_router.ts";
import { routeInventory } from "../_shared/inventory/inventory_router.ts";
import { routeAlumni } from "../_shared/alumni/alumni_router.ts";
import { routeManagement } from "../_shared/management/management_router.ts";
import { routeControlCenter } from "../_shared/control_center/control_center_router.ts";
import { routeParent } from "../_shared/parent/parent_router.ts";
import { routeTeacher } from "../_shared/teacher/teacher_router.ts";
import { routeStudent } from "../_shared/student/student_router.ts";
import { routeApproval } from "../_shared/approval/approval_router.ts";
import { routeAudit } from "../_shared/audit/audit_router.ts";
import { routeSupport } from "../_shared/support/support_router.ts";
import { routeIdentity } from "../_shared/identity/identity_router.ts";
import { routePayment } from "../_shared/payment/payment_router.ts";
import { routeCommunication } from "../_shared/communication/communication_router.ts";
import { routePilotOperations } from "../_shared/pilot/pilot_operations_router.ts";
import { routeOnboarding } from "../_shared/onboarding/onboarding_router.ts";
import { routeCopilot } from "../_shared/copilot/copilot_router.ts";
import { routeAiWallet } from "../_shared/ai/ai_wallet_router.ts";
import { routeStorageQuota } from "../_shared/storage/storage_quota_router.ts";
import { routeSearch } from "../_shared/search/search_router.ts";
import { routeAnalytics } from "../_shared/analytics/analytics_router.ts";
import { routeDashboard } from "../_shared/dashboard/dashboard_router.ts";
import { routeEducation } from "../_shared/education/education_router.ts";
import { routeIntelligence } from "../_shared/intelligence/intelligence_router.ts";
import { routeEmployee } from "../_shared/employee/employee_router.ts";
import { routeInventoryDistribution } from "../_shared/inventory_distribution/inventory_distribution_router.ts";
import { routeOperations } from "../_shared/operations/operations_router.ts";
import { routeMemories } from "../_shared/memories/school_memories_router.ts";
import { routePromotion } from "../_shared/promotion/achievement_promotion_router.ts";
import { routeSchoolCalendar } from "../_shared/school_calendar/school_calendar_router.ts";
import { routeSocial } from "../_shared/social/social_router.ts";
import { routeSetupWizard } from "../_shared/setup_wizard/setup_wizard_router.ts";
import { routeWidgetPlatform } from "../_shared/widget_platform/widget_platform_router.ts";
import { routeTeacherAssistant } from "../_shared/teacher_assistant/teacher_assistant_router.ts";
import { routeParentInsights } from "../_shared/parent_insights/parent_insights_router.ts";
import { routePrincipalCommand } from "../_shared/principal_command/principal_command_router.ts";
import { routeGrowth } from "../_shared/growth/growth_router.ts";
import { routeSchoolCompletion } from "../_shared/school_completion/school_completion_router.ts";
import { routeParentExperience } from "../_shared/parent_experience/parent_experience_router.ts";
import { routeDirector } from "../_shared/director/director_router.ts";
import { routePredictions } from "../_shared/predictions/predictions_router.ts";
import { routeOrganizationBuilder } from "../_shared/organization_builder/organization_builder_router.ts";
import { routeLegal } from "../_shared/legal/legal_router.ts";
// --- PRC-A Batch 2: request-desk / gate-pass / complaints / health ---
import { routeCertificateDesk } from "../_shared/certificate_desk/certificate_desk_router.ts";
import { routeGatePass } from "../_shared/gate_pass/gate_pass_router.ts";
import { routeComplaints } from "../_shared/complaints/complaints_router.ts";
import { routeStudentHealth } from "../_shared/student_health/student_health_router.ts";
// --- end PRC-A Batch 2 ---
// --- B1 school-config (AgentE) ---
import { routeSchoolConfig } from "../_shared/school_config/school_config_router.ts";
// --- end B1 school-config (AgentE) ---
// --- B2 entitlement layer (Step 2) ---
import { routeEntitlements } from "../_shared/entitlements/entitlement_router.ts";
import { withEntitlement } from "../_shared/entitlements/entitlement_middleware.ts";
// --- end B2 entitlement layer ---
import { errorEnvelope, routePath } from "../_shared/http.ts";
import { dispatchWithIdempotency } from "../_shared/idempotency_dispatch.ts";
import {
  recordAccessDenied,
  type AccessDeniedSink,
} from "../_shared/audit/access_denied_audit.ts";

export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-api-version, x-correlation-id, x-tenant-id, x-school-id, x-organization-id, idempotency-key, x-internal-health-token",
  "Access-Control-Allow-Methods": "GET, POST, PUT, PATCH, OPTIONS",
};

export async function routeModuleRequest(
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
): Promise<Response> {
  const moduleRouters = [
    routeLegal,
    routeApproval,
    routeAdmissions,
    // ICA-F6: the inventory_finance domain owns ONE router, registered ONCE here.
    // It owns two disjoint prefixes — /finance/inventory-reconciliation/* (reads)
    // and /inventory/{vendors/catalog,procurement/*,stock/*} (procurement+stock) —
    // and MUST precede BOTH the finance and inventory routers below, because each
    // of those greedily owns its prefix and returns its own 404 (never null) for an
    // unmatched sub-path. Placed here it wins those specific sub-paths first, then
    // returns null for everything else so the finance/inventory routers still own
    // the rest of their prefixes. Self-enforces module.inventory on its /inventory/*
    // surface (see the router header), so it is intentionally NOT withEntitlement-wrapped.
    routeInventoryFinance,
    routeFinance,
    routeSis,
    // --- PRC-A Batch 2 (caps 101–127, 136–148) ---
    // Deliberately NOT wrapped in withEntitlement: these are core school
    // operations (issuing a certificate, releasing a child at the gate,
    // recording an infirmary visit, raising a complaint), not upsell modules.
    // Gating them behind a plan would make a safety/records capability
    // purchasable, which is not a decision to make implicitly here.
    routeCertificateDesk,
    routeGatePass,
    routeComplaints,
    // `/student-health`, not `/health` — the system health/readiness endpoints
    // are matched earlier in handleRequest and must never be shadowed.
    routeStudentHealth,
    // --- end PRC-A Batch 2 ---
    routeExamAdministration,
    routeAttendance,
    routeStaffAttendance,
    routeAttendanceAuth,
    routeAcademic,
    routeTimetable,
    // --- B2: optional modules gated by plan entitlement (402 PLAN_UPGRADE_REQUIRED) ---
    withEntitlement(routeTransport, "/transport", "module.transport"),
    withEntitlement(routeHr, "/hr", "module.hr_payroll"),
    withEntitlement(routeHostel, "/hostel", "module.hostel"),
    withEntitlement(routeLibrary, "/library", "module.library"),
    routeInventoryDistribution,
    withEntitlement(routeInventory, "/inventory", "module.inventory"),
    // --- end B2 gated modules ---
    routeEmployee,
    routeOperations,
    routeMemories,
    routePromotion,
    routeSchoolCalendar,
    routeSocial,
    withEntitlement(routeAlumni, "/alumni", "module.alumni"),
    routeManagement,
    routeControlCenter,
    routePilotOperations,
    // B7: AI School Builder (Phase 1) — only the AI pre-fill path is plan-gated;
    // the rest of /onboarding stays open (it's the certified onboarding foundation).
    withEntitlement(routeOnboarding, "/onboarding/startup/ai-prefill", "feature.ai_school_builder"),
    routeSetupWizard,
    routeWidgetPlatform,
    routeTeacherAssistant,
    // B3: Parent Insights surfaced for parents — gated by plan entitlement.
    withEntitlement(routeParentInsights, "/parent-insights", "feature.parent_insights"),
    routePrincipalCommand,
    // B6: Marketing Engine (growth platform) — gated by plan entitlement.
    withEntitlement(routeGrowth, "/growth", "module.marketing"),
    routeSchoolCompletion,
    routeParentExperience,
    withEntitlement(routeDirector, "/director", "module.multi_branch"),
    // B9: Advanced AI Predictions (fee-default / admission-conversion / student-risk) —
    // gated by the Enterprise feature.ai_predictions entitlement (per-deal override-grantable).
    withEntitlement(routePredictions, "/predictions", "feature.ai_predictions"),
    // B10: Organization Builder (P3) — chains/trusts stand up a new vertical org
    // (packs → interview → preview → provision). Self-enforces the Enterprise
    // feature.organization_builder entitlement internally (it owns two disjoint
    // path prefixes, which a single withEntitlement wrapper cannot cover).
    routeOrganizationBuilder,
    // --- B1 school-config (AgentE) ---
    routeSchoolConfig,
    // --- end B1 school-config (AgentE) ---
    // --- B2 entitlement layer (Step 2): GET /plans, GET /subscription ---
    routeEntitlements,
    // --- end B2 entitlement layer ---
    routeAnalytics,
    // WEB-001: school-admin dashboard overview (core, no entitlement).
    routeDashboard,
    routeEducation,
    routeIntelligence,
    routeCopilot,
    // PRC-A Batch 3 (caps 37–43) — AI credit wallet. NOT withEntitlement-wrapped:
    // the wallet IS the commercial metering for AI usage, so gating it behind a
    // plan entitlement would be circular. Read (viewAiWallet) is org-level; grant
    // (manageAiCredits) is platform-only — both enforced in the handlers.
    routeAiWallet,
    // PRC-A Batch 4 (caps 31-36) - storage quota (read-only usage + plan limit).
    // Not withEntitlement-wrapped: knowing your storage usage is not itself a plan
    // feature. Enforcement lives at the upload presign points, dark by default.
    routeStorageQuota,
    // W2.S — Universal School Search (deterministic, RBAC-scoped entity resolver).
    routeSearch,
    routeCommunication,
    routeParent,
    routeTeacher,
    routeStudent,
    routePayment,
    routeAudit,
    // ASIP — platform-support: customer schools report Akshara product issues to
    // the Akshara Support Team (school-facing Phase 1). Owns /support.
    routeSupport,
    // PRA-P1-05 (S2): identity-plane admin — per-user permission overrides.
    routeIdentity,
  ] as const;

  // Universal store-and-replay idempotency (Data Reliability Platform §8.1):
  // every mutating module route carrying an `Idempotency-Key` replays exactly
  // once. Inert for any request without the header, so existing traffic is
  // unchanged.
  return dispatchWithIdempotency(req, config, async () => {
    for (const route of moduleRouters) {
      const matched = await route(req, config, method, path);
      if (matched) return matched;
    }
    return errorEnvelope(
      "NOT_FOUND",
      `Route not found: ${method} ${path}`,
      404,
    );
  });
}

/**
 * One structured JSON log line per request (Batch 7 observability). Captured by
 * `docker logs akshara-edge`. Carries method/path/status/duration + a correlation
 * id for tracing. Deliberately logs NO request/response bodies, tokens, or query
 * strings, so secrets never leak into logs. Level: 50 server error, 40 client 4xx,
 * 30 ok.
 */
function logRequest(
  fields: {
    method: string;
    path: string;
    status: number;
    durationMs: number;
    correlationId: string;
    clientIp: string | null;
    error?: string;
  },
): void {
  const level = fields.status >= 500 ? 50 : fields.status >= 400 ? 40 : 30;
  console.log(JSON.stringify({
    level,
    time: new Date().toISOString(),
    type: "request",
    service: "akshara-api",
    ...fields,
  }));
}

/**
 * Attaches CORS headers + the correlation id to a response. Applied to EVERY
 * response — success, NOT_FOUND, CONFIG_ERROR and SERVER_ERROR alike — so a
 * browser client always sees the real status (a 500 without CORS headers is
 * masked as an opaque CORS/network error in the browser) and every response is
 * traceable by its correlation id.
 */
function withCors(response: Response, correlationId: string): Response {
  const headers = new Headers(response.headers);
  for (const [key, value] of Object.entries(corsHeaders)) {
    headers.set(key, value);
  }
  headers.set("x-correlation-id", correlationId);
  return new Response(response.body, { status: response.status, headers });
}

/**
 * The full request handler, extracted from `Deno.serve` so it is unit-testable
 * without binding a socket (CI runs `deno test` with no `--allow-net`). `index.ts`
 * serves this verbatim; tests import it directly. `configLoader` is injectable so
 * the CONFIG_ERROR(500) path can be exercised with a throwing loader.
 */
export async function handleRequest(
  req: Request,
  configLoader: () => AppConfig = loadConfig,
  accessDeniedSink?: AccessDeniedSink,
): Promise<Response> {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const startedAt = Date.now();
  const correlationId = req.headers.get("x-correlation-id") ?? crypto.randomUUID();
  const clientIp = req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ?? null;

  let config;
  try {
    config = configLoader();
  } catch (error) {
    // ENG-7 (SEC-6): the real reason (e.g. "SUPABASE_URL missing") is logged
    // server-side only; the client gets a generic message so backend
    // configuration / env internals never leak. The correlation id (response
    // header + log line) is how support ties the two together.
    const detail = error instanceof Error ? error.message : "Configuration error";
    logRequest({
      method: req.method.toUpperCase(),
      path: routePath(req),
      status: 500,
      durationMs: Date.now() - startedAt,
      correlationId,
      clientIp,
      error: detail,
    });
    return withCors(
      errorEnvelope("CONFIG_ERROR", "Server configuration error.", 500),
      correlationId,
    );
  }

  const path = routePath(req);
  const method = req.method.toUpperCase();

  try {
    let response: Response;

    if (method === "GET" && path === "/health") {
      response = handleHealth();
    } else if (method === "GET" && path === "/health/ready") {
      response = await handleReady(config);
    } else if (method === "GET" && path === "/health/tenant-access") {
      response = await handleTenantAccessHealth(req, config);
    } else if (method === "GET" && path === "/health/operations") {
      response = await handleOperationsHealth(req, config);
    } else if (method === "GET" && path === "/health/storage") {
      response = await handleStorageHealth(req, config);
    } else if (method === "GET" && path === "/health/providers") {
      response = await handleProviderHealth(req, config);
    } else if (method === "GET" && path === "/health/backup") {
      response = await handleBackupHealth(req, config);
    } else if (method === "POST" && path === "/auth/login") {
      response = await handleLogin(req, config);
    } else if (method === "POST" && path === "/auth/verify-otp") {
      response = await handleVerifyOtp(req, config);
    } else if (method === "POST" && path === "/auth/refresh") {
      response = await handleRefresh(req, config);
    } else if (method === "POST" && path === "/auth/logout") {
      response = await handleLogout(req, config);
    } else if (method === "POST" && path === "/auth/sessions/logout-all") {
      response = await handleLogoutAll(req, config);
    } else if (method === "POST" && path === "/auth/sessions/revoke") {
      response = await handleRevokeSession(req, config);
    } else if (method === "GET" && path === "/auth/me") {
      response = await handleMe(req, config);
    } else if (method === "GET" && path === "/auth/permissions") {
      response = await handlePermissions(req, config);
    } else if (method === "POST" && path === "/auth/context/switch") {
      response = await handleContextSwitch(req, config);
    } else {
      response = await routeModuleRequest(req, config, method, path);
    }

    // QA-X-017: every RBAC/scope denial (403 FORBIDDEN) is recorded as a
    // server-side access-denied audit event — observed once here rather than at
    // each requirePermission call site. Best-effort + never throws.
    if (response.status === 403) {
      await recordAccessDenied({
        req,
        config,
        response,
        method,
        path,
        correlationId,
        sink: accessDeniedSink,
      });
    }

    logRequest({
      method,
      path,
      status: response.status,
      durationMs: Date.now() - startedAt,
      correlationId,
      clientIp,
    });
    return withCors(response, correlationId);
  } catch (error) {
    // ENG-7 (SEC-6): never surface a raw internal error (DB text, stack detail,
    // driver messages) to the client. The real message is logged server-side;
    // the client gets a generic envelope, traceable via the correlation id.
    const detail = error instanceof Error ? error.message : "Unexpected error";
    logRequest({
      method,
      path,
      status: 500,
      durationMs: Date.now() - startedAt,
      correlationId,
      clientIp,
      error: detail,
    });
    return withCors(
      errorEnvelope("SERVER_ERROR", "An unexpected error occurred.", 500),
      correlationId,
    );
  }
}
