import type { AppConfig } from "../config.ts";
import {
  createModuleWriteHandlers,
  str,
} from "../entity_write/module_write_handlers.ts";
import { createEntityWriteStore } from "../entity_write/entity_write_store.ts";
import { emitMutationAudit, moduleEntityAudit } from "../audit/mutation_audit_catalog.ts";

/**
 * Management settings persistence. Reads/writes the SAME snapshot document that
 * {@link handleSettings} (management_handlers.ts) serves: entity_type
 * `snapshot_settings`, id `default`, in the `management_entities` table. A PUT
 * therefore round-trips through the GET handler.
 */
const writeStore = createEntityWriteStore("management_entities", "Management");

/**
 * Principal / school-admin / management roles all hold `manageManagement` (the
 * `manage` action of the Management module — see the rbac_foundation seed). It
 * is the write counterpart to the `viewManagement` permission the GET handler
 * enforces.
 */
const { runWrite } = createModuleWriteHandlers("manageManagement");

const SETTINGS_SNAPSHOT_ENTITY_TYPE = "snapshot_settings";

interface SettingUpdate {
  sectionId: string;
  itemId: string;
  value: string;
}

/** Parse the client `updates` array ({section_id,item_id,value}) defensively. */
function parseUpdates(body: Record<string, unknown>): SettingUpdate[] {
  const raw = body.updates;
  if (!Array.isArray(raw)) return [];
  const updates: SettingUpdate[] = [];
  for (const entry of raw) {
    if (entry == null || typeof entry !== "object") continue;
    const record = entry as Record<string, unknown>;
    const sectionId = str(record, "sectionId", "section_id");
    const itemId = str(record, "itemId", "item_id");
    if (sectionId === undefined || itemId === undefined) continue;
    const valueRaw = record.value;
    updates.push({
      sectionId,
      itemId,
      value: valueRaw == null ? "" : String(valueRaw),
    });
  }
  return updates;
}

/**
 * Apply `updates` to the settings snapshot in place, returning a new payload.
 * Each update sets the matching item's `value`; unknown section/item ids are
 * ignored (the snapshot is the source of truth for what is editable).
 */
function applyUpdates(
  current: Record<string, unknown>,
  academicYear: string | undefined,
  updates: SettingUpdate[],
): Record<string, unknown> {
  const sections = Array.isArray(current.sections)
    ? (current.sections as Array<Record<string, unknown>>)
    : [];

  const byUpdate = (sectionId: string, itemId: string): SettingUpdate | undefined =>
    updates.find((u) => u.sectionId === sectionId && u.itemId === itemId);

  const nextSections = sections.map((section) => {
    const sectionId = String(section.id ?? "");
    const items = Array.isArray(section.items)
      ? (section.items as Array<Record<string, unknown>>)
      : [];
    const nextItems = items.map((item) => {
      const update = byUpdate(sectionId, String(item.id ?? ""));
      return update ? { ...item, value: update.value } : item;
    });
    return { ...section, items: nextItems };
  });

  const next: Record<string, unknown> = {
    ...current,
    sections: nextSections,
  };
  if (academicYear !== undefined) {
    next.academicYear = academicYear;
  }
  return next;
}

/**
 * PUT /management/settings — persist edited management settings. Body shape
 * matches the client (`update_management_settings_request_dto.dart`):
 * `{ academic_year?: string, updates?: [{section_id, item_id, value}] }`.
 * Writes the merged snapshot and returns it (so the response matches a
 * subsequent GET /management/settings).
 */
export async function handleUpdateSettings(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  return await runWrite(req, config, async (ctx) => {
    const { db, organizationId, schoolId, body, claims, req: request } = ctx;
    const academicYear = str(body, "academicYear", "academic_year");
    const updates = parseUpdates(body);

    const saved = await writeStore.mutateSnapshot(
      db,
      organizationId,
      schoolId,
      SETTINGS_SNAPSHOT_ENTITY_TYPE,
      (current) => applyUpdates(current, academicYear, updates),
    );

    await emitMutationAudit(
      db,
      claims,
      moduleEntityAudit(
        "management.settings.updated",
        "management_settings",
        schoolId,
        { updates: updates.length, academicYear: academicYear ?? null },
      ),
      request,
    );

    // 200 (not 201): an update of the existing settings document, returned for
    // the client's ManagementSettingsResponseDto (same shape the GET serves).
    return { payload: saved, status: 200 };
  });
}
