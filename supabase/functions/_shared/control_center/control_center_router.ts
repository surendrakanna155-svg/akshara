import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import {
  handleAnalytics,
  handleBilling,
  handleCrmPipeline,
  handleCustomerSuccess,
  handleDashboard,
  handleMonitoring,
  handleRoles,
  handleSchools,
  handleSettings,
  handleSubscriptions,
  handleSupportTickets,
  handleWhiteLabel,
} from "./control_center_handlers.ts";
import {
  handleCheckVaultHealth,
  handleGetPlatformUsage,
  handleListFeatureEnablements,
  handleListPlatformProviders,
  handleRotateVaultSecret,
  handleSetFeatureEnablement,
  handleUpsertPlatformProvider,
} from "./platform_providers_handlers.ts";
import { handleReencryptVaultSecrets } from "../vault/vault_reencrypt.ts";
import {
  handleCreateLead,
  handleCreateSchool,
} from "./control_center_write_handlers.ts";

function matchControlCenterRoute(
  method: string,
  path: string,
): { handler: (req: Request, config: AppConfig) => Promise<Response> } | null {
  const getRoutes: Record<string, (req: Request, config: AppConfig) => Promise<Response>> = {
    "/control-center/dashboard": handleDashboard,
    "/control-center/schools": handleSchools,
    "/control-center/subscriptions": handleSubscriptions,
    "/control-center/billing": handleBilling,
    "/control-center/crm-pipeline": handleCrmPipeline,
    "/control-center/support-tickets": handleSupportTickets,
    "/control-center/customer-success": handleCustomerSuccess,
    "/control-center/white-label": handleWhiteLabel,
    "/control-center/analytics": handleAnalytics,
    "/control-center/monitoring": handleMonitoring,
    "/control-center/roles": handleRoles,
    "/control-center/settings": handleSettings,
    "/control-center/providers": handleListPlatformProviders,
    "/control-center/usage": handleGetPlatformUsage,
    "/control-center/features": handleListFeatureEnablements,
    "/control-center/vault/health": handleCheckVaultHealth,
  };

  const postRoutes: Record<string, (req: Request, config: AppConfig) => Promise<Response>> = {
    "/control-center/providers": handleUpsertPlatformProvider,
    "/control-center/features": handleSetFeatureEnablement,
    "/control-center/vault/rotate": handleRotateVaultSecret,
    // One-shot backfill: re-encrypts legacy Base64 (key_version=1) secrets under
    // AES-256-GCM. Idempotent — safe to re-run; already-v2 rows are skipped.
    "/control-center/vault/reencrypt": handleReencryptVaultSecrets,
    "/control-center/schools": handleCreateSchool,
    "/control-center/crm-pipeline": handleCreateLead,
  };

  if (method === "GET") {
    const handler = getRoutes[path] as (typeof getRoutes)[string] | undefined;
    return handler ? { handler } : null;
  }
  if (method === "POST" || method === "PUT") {
    const handler = postRoutes[path] as (typeof postRoutes)[string] | undefined;
    return handler ? { handler } : null;
  }
  return null;
}

export async function routeControlCenter(
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
): Promise<Response | null> {
  if (!path.startsWith("/control-center")) return null;

  const match = matchControlCenterRoute(method, path);
  if (!match) {
    return errorEnvelope("NOT_FOUND", `Route not found: ${method} ${path}`, 404);
  }

  return await match.handler(req, config);
}
