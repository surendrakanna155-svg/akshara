import type { AppConfig } from "../config.ts";
import { envelope, errorEnvelope, jsonResponse, readJson } from "../http.ts";
import {
  authenticateRequest,
  organizationIdFromClaims,
  requirePermission,
  requireSchoolOperationalScope,
  schoolIdFromClaims,
} from "../permission_middleware.ts";
import { TenantDbNotConfiguredError, withTenantContext } from "../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../tenant_handlers.ts";
import { emitMutationAudit, financeAudit } from "../audit/mutation_audit_catalog.ts";
import {
  getSettingsRow,
  type SettingUpdate,
  settingsToApi,
  upsertSettings,
} from "./finance_settings_repository.ts";

function requireFinanceWrite(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requirePermission(claims, "manageFinance") ??
    requireSchoolOperationalScope(claims);
}

function requireFinanceRead(claims: Parameters<typeof requirePermission>[0]): Response | null {
  return requirePermission(claims, "viewFinance") ??
    requireSchoolOperationalScope(claims);
}

export async function handleGetSettings(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireFinanceRead(auth.claims);
  if (denied) return denied;

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const row = await withTenantContext(config, auth.claims, (db) =>
      getSettingsRow(db, orgId, schoolId));
    return jsonResponse(
      envelope(settingsToApi(row?.academic_year ?? "", row?.settings ?? {})),
    );
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse();
    }
    throw error;
  }
}

function parseUpdates(body: Record<string, unknown>): SettingUpdate[] {
  const raw = body.updates;
  if (!Array.isArray(raw)) return [];
  const out: SettingUpdate[] = [];
  for (const entry of raw) {
    if (entry == null || typeof entry !== "object") continue;
    const row = entry as Record<string, unknown>;
    const sectionId = String(row.section_id ?? row.sectionId ?? "").trim();
    const itemId = String(row.item_id ?? row.itemId ?? "").trim();
    if (!sectionId || !itemId) continue;
    out.push({ sectionId, itemId, value: String(row.value ?? "") });
  }
  return out;
}

export async function handleUpdateSettings(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const denied = requireFinanceWrite(auth.claims);
  if (denied) return denied;

  const body = await readJson<Record<string, unknown>>(req);
  if (!body) {
    return errorEnvelope("VALIDATION_ERROR", "Request body is required", 422);
  }

  const academicYear = body.academic_year != null
    ? String(body.academic_year)
    : body.academicYear != null
    ? String(body.academicYear)
    : undefined;
  const updates = parseUpdates(body);

  const orgId = organizationIdFromClaims(auth.claims);
  const schoolId = schoolIdFromClaims(auth.claims);

  try {
    const row = await withTenantContext(config, auth.claims, async (db) => {
      const saved = await upsertSettings(
        db,
        orgId,
        schoolId,
        academicYear,
        updates,
        auth.claims.sub,
      );
      await emitMutationAudit(
        db,
        auth.claims,
        financeAudit.financeSettingsUpdated(schoolId, saved.updated_at),
        req,
      );
      return saved;
    });
    return jsonResponse(envelope(settingsToApi(row.academic_year, row.settings)));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse();
    }
    throw error;
  }
}
