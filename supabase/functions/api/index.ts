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
import { errorEnvelope, routePath } from "../_shared/http.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-api-version, x-correlation-id, x-tenant-id, x-school-id, x-organization-id",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
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
      response = errorEnvelope("NOT_FOUND", `Route not found: ${method} ${path}`, 404);
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
