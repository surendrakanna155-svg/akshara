import type { AppConfig } from "./config.ts";
import { errorEnvelope } from "./http.ts";

/** Guards sensitive health probes — requires `x-internal-health-token` when configured. */
export function requireInternalHealthAccess(
  req: Request,
  config: AppConfig,
): Response | null {
  const configured = config.internalHealthToken;
  if (!configured) {
    if (config.environment === "production") {
      return errorEnvelope(
        "FORBIDDEN",
        "Internal health endpoints require INTERNAL_HEALTH_TOKEN in production",
        403,
      );
    }
    return null;
  }
  const provided = req.headers.get("x-internal-health-token");
  if (provided !== configured) {
    return errorEnvelope("FORBIDDEN", "Invalid or missing internal health token", 403);
  }
  return null;
}
