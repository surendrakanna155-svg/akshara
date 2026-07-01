import type { TenantQueryClient } from "../tenant_db.ts";

export interface FinanceSettingsRow {
  id: string;
  organization_id: string;
  school_id: string;
  academic_year: string;
  settings: Record<string, string>;
  updated_by: string | null;
  created_at: string;
  updated_at: string;
}

interface SettingItemTemplate {
  id: string;
  label: string;
  defaultValue: string;
  description: string;
  editable: boolean;
}

interface SettingSectionTemplate {
  id: string;
  title: string;
  items: SettingItemTemplate[];
}

/**
 * Canonical finance-settings catalogue. Stored overrides (keyed
 * "<sectionId>.<itemId>") are merged over these defaults so the GET always
 * returns a complete, render-ready structure even before any write.
 */
export const FINANCE_SETTINGS_TEMPLATE: SettingSectionTemplate[] = [
  {
    id: "receipts",
    title: "Receipts & Invoicing",
    items: [
      {
        id: "receipt_prefix",
        label: "Receipt Number Prefix",
        defaultValue: "RCP",
        description: "Prefix used on generated fee receipts.",
        editable: true,
      },
      {
        id: "invoice_prefix",
        label: "Invoice Number Prefix",
        defaultValue: "INV",
        description: "Prefix used on generated invoices.",
        editable: true,
      },
      {
        id: "auto_receipt_sms",
        label: "Send Receipt SMS",
        defaultValue: "true",
        description: "Notify guardians by SMS when a payment is received.",
        editable: true,
      },
    ],
  },
  {
    id: "reminders",
    title: "Payment Reminders",
    items: [
      {
        id: "due_reminder_days",
        label: "Reminder Lead Time (days)",
        defaultValue: "3",
        description: "Days before the due date to send a payment reminder.",
        editable: true,
      },
      {
        id: "overdue_reminder",
        label: "Overdue Reminders",
        defaultValue: "true",
        description: "Automatically remind guardians of overdue fees.",
        editable: true,
      },
    ],
  },
  {
    id: "payments",
    title: "Payment Options",
    items: [
      {
        id: "allow_partial",
        label: "Allow Partial Payments",
        defaultValue: "true",
        description: "Permit collecting less than the full outstanding amount.",
        editable: true,
      },
      {
        id: "late_fee_percent",
        label: "Late Fee (%)",
        defaultValue: "0",
        description: "Percentage late fee applied to overdue invoices.",
        editable: true,
      },
      // FIN-D5 — late-fee accrual controls.
      {
        id: "grace_days",
        label: "Late Fee Grace (days)",
        defaultValue: "0",
        description:
          "Days after the due date before a late fee starts accruing.",
        editable: true,
      },
      {
        id: "late_fee_flat",
        label: "Late Fee (flat)",
        defaultValue: "0",
        description:
          "Optional flat amount added on top of the percentage late fee.",
        editable: true,
      },
      {
        id: "late_fee_cap",
        label: "Late Fee Cap",
        defaultValue: "0",
        description:
          "Maximum late fee per invoice (0 = no cap).",
        editable: true,
      },
      // FIN-6 — due-date & installment schedule controls.
      {
        id: "due_days",
        label: "Invoice Due (days)",
        defaultValue: "30",
        description:
          "Days after issue that a new invoice is due (single annual term).",
        editable: true,
      },
      {
        id: "installment_terms",
        label: "Installment Terms",
        defaultValue: "1",
        description:
          "Number of terms, or a CSV of per-term due-day offsets (e.g. '0,90,180'). '1' = single annual due schedule.",
        editable: true,
      },
      // FIN-D2 — per-head allocation priority.
      {
        id: "head_allocation_priority",
        label: "Fee-head Allocation Priority",
        defaultValue: "tuition_first",
        description:
          "Order part-payments are allocated across fee heads. Currently only 'tuition_first' is implemented.",
        editable: true,
      },
    ],
  },
];

export interface SettingUpdate {
  sectionId: string;
  itemId: string;
  value: string;
}

function settingsKey(sectionId: string, itemId: string): string {
  return `${sectionId}.${itemId}`;
}

/** Build the client-facing `{ academicYear, sections[] }` shape. */
export function settingsToApi(
  academicYear: string,
  overrides: Record<string, string>,
): Record<string, unknown> {
  return {
    academicYear,
    sections: FINANCE_SETTINGS_TEMPLATE.map((section) => ({
      id: section.id,
      title: section.title,
      items: section.items.map((item) => {
        const key = settingsKey(section.id, item.id);
        return {
          id: item.id,
          label: item.label,
          value: overrides[key] ?? item.defaultValue,
          description: item.description,
          editable: item.editable,
        };
      }),
    })),
  };
}

/**
 * Reads a single finance setting value (keyed "<sectionId>.<itemId>") from the
 * stored overrides, falling back to the canonical template default and then to
 * the supplied `fallback`. Used by the money path (FIN-6 due-days / installment
 * terms, FIN-D2 allocation priority) to read config WITHOUT altering behaviour:
 * an unconfigured school always resolves to the documented default.
 */
export async function getFinanceSettingValue(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  sectionId: string,
  itemId: string,
  fallback: string,
): Promise<string> {
  const row = await getSettingsRow(db, organizationId, schoolId);
  const key = settingsKey(sectionId, itemId);
  const stored = row?.settings?.[key];
  if (stored != null && String(stored).trim() !== "") return String(stored);
  const templateDefault = FINANCE_SETTINGS_TEMPLATE
    .find((s) => s.id === sectionId)?.items
    .find((i) => i.id === itemId)?.defaultValue;
  return templateDefault ?? fallback;
}

export async function getSettingsRow(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
): Promise<FinanceSettingsRow | null> {
  const rows = await db.queryObject<FinanceSettingsRow>(
    `SELECT * FROM finance_settings
     WHERE organization_id = $1 AND school_id = $2`,
    [organizationId, schoolId],
  );
  return rows[0] ?? null;
}

/**
 * Upsert finance settings for the school: merges `updates` into the stored
 * JSON map and optionally sets the academic year. One row per school
 * (UNIQUE org+school). erp_tenant has SELECT/INSERT/UPDATE only, so this uses
 * INSERT ... ON CONFLICT DO UPDATE (no DELETE).
 */
export async function upsertSettings(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  academicYear: string | undefined,
  updates: SettingUpdate[],
  updatedBy: string,
): Promise<FinanceSettingsRow> {
  const existing = await getSettingsRow(db, organizationId, schoolId);
  const merged: Record<string, string> = { ...(existing?.settings ?? {}) };
  for (const u of updates) {
    merged[settingsKey(u.sectionId, u.itemId)] = u.value;
  }
  const year = academicYear ?? existing?.academic_year ?? "";

  const rows = await db.queryObject<FinanceSettingsRow>(
    `INSERT INTO finance_settings (
       organization_id, school_id, academic_year, settings, updated_by
     ) VALUES ($1, $2, $3, $4::jsonb, $5)
     ON CONFLICT (organization_id, school_id) DO UPDATE
       SET academic_year = EXCLUDED.academic_year,
           settings = EXCLUDED.settings,
           updated_by = EXCLUDED.updated_by,
           updated_at = timezone('utc', now())
     RETURNING *`,
    [organizationId, schoolId, year, JSON.stringify(merged), updatedBy],
  );
  return rows[0]!;
}
