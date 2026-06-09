export interface FinanceFeeStructureRow {
  id: string;
  organization_id: string;
  school_id: string;
  name: string;
  academic_year: string;
  description: string | null;
  status: string;
  created_by: string;
  created_at: string;
  updated_at: string;
}

export interface FinanceFeeStructureItemRow {
  id: string;
  fee_structure_id: string;
  organization_id: string;
  school_id: string;
  fee_head: string;
  amount: string;
  sort_order: number;
  created_at: string;
}

export interface FeeStructureItemInput {
  feeHead: string;
  amount: number;
  sortOrder: number;
}

/** Encodes category + label into fee_head for client round-trip. */
export function encodeFeeHead(category: string, label: string): string {
  const cat = category.trim() || "tuition";
  const lbl = label.trim() || cat;
  return `${cat}:${lbl}`;
}

export function decodeFeeHead(feeHead: string): { category: string; label: string } {
  const idx = feeHead.indexOf(":");
  if (idx <= 0) {
    return { category: "tuition", label: feeHead };
  }
  return {
    category: feeHead.slice(0, idx),
    label: feeHead.slice(idx + 1),
  };
}

function formatAmount(value: number | string): string {
  const num = typeof value === "string" ? parseFloat(value) : value;
  if (!Number.isFinite(num)) return "0";
  return Number.isInteger(num) ? String(num) : num.toFixed(2);
}

function sumItemAmounts(items: FinanceFeeStructureItemRow[]): string {
  const total = items.reduce((sum, item) => sum + parseFloat(item.amount), 0);
  return formatAmount(total);
}

export function feeStructureToApi(
  structure: FinanceFeeStructureRow,
  items: FinanceFeeStructureItemRow[],
): Record<string, unknown> {
  const categories = items
    .sort((a, b) => a.sort_order - b.sort_order)
    .map((item) => {
      const { category, label } = decodeFeeHead(item.fee_head);
      return {
        category,
        label,
        amount: formatAmount(item.amount),
      };
    });

  return {
    id: structure.id,
    name: structure.name,
    academicYear: structure.academic_year,
    description: structure.description,
    status: structure.status,
    classRange: structure.description ?? "",
    totalAnnual: sumItemAmounts(items),
    installmentOptions: [] as number[],
    categories,
    createdBy: structure.created_by,
    createdAt: structure.created_at,
    updatedAt: structure.updated_at,
  };
}

export function listEnvelope(
  items: Record<string, unknown>[],
  pagination: {
    page: number;
    pageSize: number;
    total: number;
    hasMore: boolean;
  },
): Record<string, unknown> {
  return {
    items,
    pagination: {
      page: pagination.page,
      pageSize: pagination.pageSize,
      total: pagination.total,
      hasMore: pagination.hasMore,
    },
  };
}

export function parseItemInputsFromBody(
  body: Record<string, unknown>,
): FeeStructureItemInput[] {
  const rawItems = body.items;
  if (Array.isArray(rawItems) && rawItems.length > 0) {
    return rawItems.map((entry, index) => {
      const row = entry as Record<string, unknown>;
      const feeHead = String(row.fee_head ?? row.feeHead ?? "").trim();
      const amount = parseFloat(String(row.amount ?? "0"));
      return {
        feeHead: feeHead || "fee",
        amount: Number.isFinite(amount) ? amount : 0,
        sortOrder: Number(row.sort_order ?? row.sortOrder ?? index) || index,
      };
    });
  }

  const categories = body.categories;
  if (Array.isArray(categories)) {
    return categories.map((entry, index) => {
      const row = entry as Record<string, unknown>;
      const category = String(row.category ?? "tuition");
      const label = String(row.label ?? category);
      const amount = parseFloat(String(row.amount ?? "0"));
      return {
        feeHead: encodeFeeHead(category, label),
        amount: Number.isFinite(amount) ? amount : 0,
        sortOrder: index,
      };
    });
  }

  return [];
}
