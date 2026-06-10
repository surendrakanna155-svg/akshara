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
import { errorEnvelope, routePath } from "../_shared/http.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-api-version, x-correlation-id, x-tenant-id, x-school-id, x-organization-id, idempotency-key, x-internal-health-token",
  "Access-Control-Allow-Methods": "GET, POST, PUT, PATCH, OPTIONS",
};

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
      const admissionsResponse = await routeAdmissions(req, config, method, path);
      if (admissionsResponse) {
        response = admissionsResponse;
      } else {
        const financeResponse = await routeFinance(req, config, method, path);
        if (financeResponse) {
          response = financeResponse;
        } else {
          const sisResponse = await routeSis(req, config, method, path);
          if (sisResponse) {
            response = sisResponse;
          } else {
            const academicResponse = await routeAcademic(req, config, method, path);
            if (academicResponse) {
              response = academicResponse;
            } else {
              const timetableResponse = await routeTimetable(req, config, method, path);
              if (timetableResponse) {
                response = timetableResponse;
              } else {
              const transportResponse = await routeTransport(req, config, method, path);
              if (transportResponse) {
                response = transportResponse;
              } else {
                const hrResponse = await routeHr(req, config, method, path);
                if (hrResponse) {
                  response = hrResponse;
                } else {
                  const hostelResponse = await routeHostel(req, config, method, path);
                  if (hostelResponse) {
                    response = hostelResponse;
                  } else {
                    const libraryResponse = await routeLibrary(req, config, method, path);
                    if (libraryResponse) {
                      response = libraryResponse;
                    } else {
                      const inventoryResponse = await routeInventory(req, config, method, path);
                      if (inventoryResponse) {
                        response = inventoryResponse;
                      } else {
                        const alumniResponse = await routeAlumni(req, config, method, path);
                        if (alumniResponse) {
                          response = alumniResponse;
                        } else {
                          const managementResponse = await routeManagement(req, config, method, path);
                          if (managementResponse) {
                            response = managementResponse;
                          } else {
                            const controlCenterResponse = await routeControlCenter(req, config, method, path);
                            if (controlCenterResponse) {
                              response = controlCenterResponse;
                            } else {
                              const pilotResponse = await routePilotOperations(req, config, method, path);
                              if (pilotResponse) {
                                response = pilotResponse;
                              } else {
                                const onboardingResponse = await routeOnboarding(
                                  req,
                                  config,
                                  method,
                                  path,
                                );
                                if (onboardingResponse) {
                                  response = onboardingResponse;
                                } else {
                                const analyticsResponse = await routeAnalytics(
                                  req,
                                  config,
                                  method,
                                  path,
                                );
                                if (analyticsResponse) {
                                  response = analyticsResponse;
                                } else {
                                const copilotResponse = await routeCopilot(
                                  req,
                                  config,
                                  method,
                                  path,
                                );
                                if (copilotResponse) {
                                  response = copilotResponse;
                                } else {
                                const communicationResponse = await routeCommunication(
                                  req,
                                  config,
                                  method,
                                  path,
                                );
                                if (communicationResponse) {
                                  response = communicationResponse;
                                } else {
                                  const parentResponse = await routeParent(req, config, method, path);
                                  if (parentResponse) {
                                    response = parentResponse;
                                  } else {
                                    const teacherResponse = await routeTeacher(req, config, method, path);
                                    if (teacherResponse) {
                                      response = teacherResponse;
                                    } else {
                                      const studentResponse = await routeStudent(req, config, method, path);
                                      if (studentResponse) {
                                        response = studentResponse;
                                      } else {
                                        const paymentResponse = await routePayment(req, config, method, path);
                                        if (paymentResponse) {
                                          response = paymentResponse;
                                        } else {
                                          const auditResponse = await routeAudit(req, config, method, path);
                                          if (auditResponse) {
                                            response = auditResponse;
                                          } else {
                                            response = errorEnvelope(
                                              "NOT_FOUND",
                                              `Route not found: ${method} ${path}`,
                                              404,
                                            );
                                          }
                                        }
                                      }
                                    }
                                  }
                                }
                                }
                                }
                              }
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
              }
            }
          }
        }
      }
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
