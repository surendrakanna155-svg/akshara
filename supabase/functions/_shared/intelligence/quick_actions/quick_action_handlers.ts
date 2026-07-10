// Adaptive AI — P3-AI-2 / W2-GATE-2: Quick Action Registry route handler.
//
// GET /intelligence/quick-actions?persona=<persona>
//
// Returns the RBAC-filtered list of predefined actions for the persona — the
// server-driven catalog the client renders instead of hardcoded stub buttons.
// Pure catalog read (no DB, no model): auth + school scope + permission filter.

import type { AppConfig } from "../../config.ts";
import { envelope, errorEnvelope, jsonResponse } from "../../http.ts";
import { authenticateRequest, requireSchoolOperationalScope } from "../../permission_middleware.ts";
import { isPersona, quickActionsFor } from "./quick_action_catalog.ts";

/** GET /intelligence/quick-actions — persona quick actions the caller may use. */
export function handleQuickActions(req: Request, config: AppConfig): Promise<Response> {
  return (async () => {
    const auth = await authenticateRequest(req, config);
    if (!auth.ok) return auth.response;
    const denied = requireSchoolOperationalScope(auth.claims);
    if (denied) return denied;

    const url = new URL(req.url);
    const personaParam = (url.searchParams.get("persona") ?? "").toLowerCase();
    if (!isPersona(personaParam)) {
      return errorEnvelope("VALIDATION_ERROR", "a valid persona query param is required", 422);
    }

    const items = quickActionsFor(personaParam, auth.claims.permissions).map((a) => ({
      id: a.id,
      label: a.label,
      tier: a.tier,
      requiresEntity: a.requiresEntity ?? null,
      resolver: a.resolver,
    }));

    return jsonResponse(envelope({ persona: personaParam, items }));
  })();
}
