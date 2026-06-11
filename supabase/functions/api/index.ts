import { loadConfig } from "../_shared/config.ts";
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
import { handleTenantAccessHealth, handleOperationsHealth } from "../_shared/tenant_handlers.ts";
import { routeAdmissions } from "../_shared/admissions/admissions_router.ts";
import { routeFinance } from "../_shared/finance/finance_router.ts";
import { routeSis } from "../_shared/sis/sis_router.ts";
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
import { routeAudit } from "../_shared/audit/audit_router.ts";
import { routePayment } from "../_shared/payment/payment_router.ts";
import { routeCommunication } from "../_shared/communication/communication_router.ts";
import { routePilotOperations } from "../_shared/pilot/pilot_operations_router.ts";
import { routeOnboarding } from "../_shared/onboarding/onboarding_router.ts";
import { routeCopilot } from "../_shared/copilot/copilot_router.ts";
import { routeAnalytics } from "../_shared/analytics/analytics_router.ts";
import { routeEducation } from "../_shared/education/education_router.ts";
import { routeIntelligence } from "../_shared/intelligence/intelligence_router.ts";
import { routeEmployee } from "../_shared/employee/employee_router.ts";
import { routeInventoryDistribution } from "../_shared/inventory_distribution/inventory_distribution_router.ts";
import { routeOperations } from "../_shared/operations/operations_router.ts";
import { routeMemories } from "../_shared/memories/school_memories_router.ts";
import { routePromotion } from "../_shared/promotion/achievement_promotion_router.ts";
import { routeSetupWizard } from "../_shared/setup_wizard/setup_wizard_router.ts";
import { routeWidgetPlatform } from "../_shared/widget_platform/widget_platform_router.ts";
import { routeTeacherAssistant } from "../_shared/teacher_assistant/teacher_assistant_router.ts";
import { routeParentInsights } from "../_shared/parent_insights/parent_insights_router.ts";
import { routePrincipalCommand } from "../_shared/principal_command/principal_command_router.ts";
import { routeGrowth } from "../_shared/growth/growth_router.ts";
import { routeSchoolCompletion } from "../_shared/school_completion/school_completion_router.ts";
import { routeParentExperience } from "../_shared/parent_experience/parent_experience_router.ts";
import { errorEnvelope, routePath } from "../_shared/http.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-api-version, x-correlation-id, x-tenant-id, x-school-id, x-organization-id, idempotency-key, x-internal-health-token",
  "Access-Control-Allow-Methods": "GET, POST, PUT, PATCH, OPTIONS",
};

async function routeModuleRequest(
  req: Request,
  config: ReturnType<typeof loadConfig>,
  method: string,
  path: string,
): Promise<Response> {
  const moduleRouters = [
    routeAdmissions,
    routeFinance,
    routeSis,
    routeAcademic,
    routeTimetable,
    routeTransport,
    routeHr,
    routeHostel,
    routeLibrary,
    routeInventoryDistribution,
    routeInventory,
    routeEmployee,
    routeOperations,
    routeMemories,
    routePromotion,
    routeAlumni,
    routeManagement,
    routeControlCenter,
    routePilotOperations,
    routeOnboarding,
    routeSetupWizard,
    routeWidgetPlatform,
    routeTeacherAssistant,
    routeParentInsights,
    routePrincipalCommand,
    routeGrowth,
    routeSchoolCompletion,
    routeParentExperience,
    routeAnalytics,
    routeEducation,
    routeIntelligence,
    routeCopilot,
    routeCommunication,
    routeParent,
    routeTeacher,
    routeStudent,
    routePayment,
    routeAudit,
  ] as const;

  for (const route of moduleRouters) {
    const matched = await route(req, config, method, path);
    if (matched) return matched;
  }

  return errorEnvelope(
    "NOT_FOUND",
    `Route not found: ${method} ${path}`,
    404,
  );
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  let config;
  try {
    config = loadConfig();
  } catch (error) {
    return errorEnvelope(
      "CONFIG_ERROR",
      error instanceof Error ? error.message : "Configuration error",
      500,
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

    const headers = new Headers(response.headers);
    for (const [key, value] of Object.entries(corsHeaders)) {
      headers.set(key, value);
    }
    return new Response(response.body, { status: response.status, headers });
  } catch (error) {
    return errorEnvelope(
      "SERVER_ERROR",
      error instanceof Error ? error.message : "Unexpected error",
      500,
    );
  }
});
