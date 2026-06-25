// Organization Builder router (B10, P3).
//
// Owns two disjoint path prefixes from the frozen Flutter contract:
//   /platform/org-builder/...      (packs, interview, preview, provision)
//   /platform/provisioning-jobs/:id (job status polling)
// Because a single `withEntitlement(...)` wrapper only matches one prefix, the
// `feature.organization_builder` entitlement is enforced HERE, once, for every
// matched path (covering both prefixes) — gated on the same enforcement flag the
// middleware uses, so behaviour matches the rest of the platform.

import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import { enforceEntitlement } from "../entitlements/entitlement_middleware.ts";
import { entitlementEnforcementEnabled } from "../entitlements/entitlement_enforcement.ts";
import {
  handleDraft,
  handleDrafts,
  handlePacks,
  handlePreview,
  handleProvision,
  handleProvisioningJob,
  handleSaveStep,
} from "./organization_builder_handlers.ts";

const ENTITLEMENT = "feature.organization_builder";

const DRAFT_RE = /^\/platform\/org-builder\/interview\/drafts\/([^/]+)$/;
const STEP_RE = /^\/platform\/org-builder\/interview\/drafts\/([^/]+)\/step$/;
const JOB_RE = /^\/platform\/provisioning-jobs\/([^/]+)$/;

function owns(path: string): boolean {
  return path.startsWith("/platform/org-builder") ||
    path.startsWith("/platform/provisioning-jobs");
}

export async function routeOrganizationBuilder(
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
): Promise<Response | null> {
  if (!owns(path)) return null;

  // Single entitlement gate for both prefixes (see file header).
  if (entitlementEnforcementEnabled()) {
    const denied = await enforceEntitlement(req, config, ENTITLEMENT);
    if (denied) return denied;
  }

  if (method === "GET") {
    if (path === "/platform/org-builder/packs") return await handlePacks(req, config);
    if (path === "/platform/org-builder/interview/drafts") return await handleDrafts(req, config);

    const draft = DRAFT_RE.exec(path);
    if (draft) return await handleDraft(req, config, decodeURIComponent(draft[1]));

    const job = JOB_RE.exec(path);
    if (job) return await handleProvisioningJob(req, config, decodeURIComponent(job[1]));
  }

  if (method === "POST") {
    const step = STEP_RE.exec(path);
    if (step) return await handleSaveStep(req, config, decodeURIComponent(step[1]));
    if (path === "/platform/org-builder/preview") return await handlePreview(req, config);
    if (path === "/platform/org-builder/provision") return await handleProvision(req, config);
  }

  return errorEnvelope("NOT_FOUND", `Route not found: ${method} ${path}`, 404);
}
