import type {
  AssignmentWithAccount,
  FinanceFeeAssignmentRow,
} from "./finance_assignments_repository.ts";
import type {
  CollectionListRow,
  CollectionWithReceipt,
  FinanceCollectionRow,
  FinanceReceiptRow,
} from "./finance_collections_repository.ts";
import type { FinanceInvoiceRow } from "./finance_invoices_repository.ts";
import {
  collectionStatusToApi,
  installmentStatusFromInvoice,
} from "./finance_status_codec.ts";
import type { DailySummaryData, StudentAccountSnapshot } from "./finance_collections_repository.ts";
import type { RefundListRow } from "./finance_refunds_repository.ts";

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

function mapAccountStatus(status: string): string {
  return status === "closed" ? "closed" : "active";
}

export function assignmentToApi(
  row: FinanceFeeAssignmentRow,
): Record<string, unknown> {
  return {
    id: row.id,
    studentId: row.student_id,
    feeStructureId: row.fee_structure_id,
    academicYear: row.academic_year,
    assignmentStatus: row.assignment_status,
    assignedBy: row.assigned_by,
    assignedAt: row.assigned_at,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

export function studentAccountToApi(
  data: AssignmentWithAccount,
): Record<string, unknown> {
  const { assignment, account } = data;
  return {
    id: account.id,
    studentId: account.student_id,
    studentName: data.studentName ?? "",
    admissionNumber: data.admissionNumber ?? "",
    classLabel: data.classLabel ?? "",
    feeStructureName: data.feeStructureName ?? "",
    feeStructureId: assignment.fee_structure_id,
    feeAssignmentId: assignment.id,
    academicYear: account.academic_year,
    totalDue: formatAmount(account.total_fee),
    totalPaid: formatAmount(account.amount_paid),
    balance: formatAmount(account.outstanding_amount),
    status: mapAccountStatus(account.status),
    lastPaymentDate: "",
    installmentPlan: "",
  };
}

function paidAmount(total: string, outstanding: string): string {
  const totalNum = parseFloat(total);
  const outstandingNum = parseFloat(outstanding);
  if (!Number.isFinite(totalNum) || !Number.isFinite(outstandingNum)) return "0";
  return formatAmount(Math.max(0, totalNum - outstandingNum));
}

export function invoiceToApi(row: FinanceInvoiceRow): Record<string, unknown> {
  return {
    id: row.id,
    studentId: row.student_id,
    feeAssignmentId: row.fee_assignment_id,
    academicYear: row.academic_year,
    invoiceNumber: row.invoice_number,
    invoiceDate: row.invoice_date,
    dueDate: row.due_date,
    subtotalAmount: formatAmount(row.subtotal_amount),
    discountAmount: formatAmount(row.discount_amount),
    totalAmount: formatAmount(row.total_amount),
    outstandingAmount: formatAmount(row.outstanding_amount),
    paidAmount: paidAmount(row.total_amount, row.outstanding_amount),
    invoiceStatus: row.invoice_status,
    termLabel: "Annual",
    createdBy: row.created_by,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

export function dailySummaryToApi(data: DailySummaryData): Record<string, unknown> {
  return {
    todayCollections: formatAmount(data.todayCollections),
    todayCollectionCount: data.todayCollectionCount,
    pendingInvoices: data.pendingInvoices,
    paidInvoices: data.paidInvoices,
    partiallyPaidInvoices: data.partiallyPaidInvoices,
    outstandingAmount: formatAmount(data.outstandingAmount),
    dateLabel: data.dateLabel,
    totalCollected: formatAmount(data.todayCollections),
    transactionCount: data.todayCollectionCount,
    cashAmount: formatAmount(data.cashAmount),
    upiAmount: formatAmount(data.upiAmount),
    pendingReconciliation: data.draftCollectionsToday,
  };
}

export function collectionPaymentToApi(row: CollectionListRow): Record<string, unknown> {
  return {
    id: row.id,
    receiptNumber: row.receipt_number,
    studentName: row.student_name ?? "",
    admissionNumber: row.admission_number ?? "",
    amount: formatAmount(row.amount_collected),
    mode: row.payment_method,
    collectedAt: row.collection_date,
    collectedBy: row.collected_by,
    status: collectionStatusToApi(row.collection_status),
    classLabel: row.class_label ?? "",
  };
}

export function collectionCreateToApi(result: CollectionWithReceipt): Record<string, unknown> {
  return {
    collection: {
      id: result.collection.id,
      invoiceId: result.collection.invoice_id,
      studentAccountId: result.collection.student_account_id,
      receiptNumber: result.collection.receipt_number,
      amountCollected: formatAmount(result.collection.amount_collected),
      paymentMethod: result.collection.payment_method,
      collectionStatus: result.collection.collection_status,
      collectionDate: result.collection.collection_date,
    },
    receipt: receiptToApi(result.receipt),
    invoice: invoiceToApi(result.invoice),
  };
}

export function receiptToApi(row: FinanceReceiptRow): Record<string, unknown> {
  return {
    id: row.id,
    collectionId: row.collection_id,
    receiptNumber: row.receipt_number,
    receiptDate: row.receipt_date,
    amount: formatAmount(row.amount),
    generatedBy: row.generated_by,
    createdAt: row.created_at,
  };
}

export function collectionDetailToApi(
  row: CollectionListRow,
  invoice: FinanceInvoiceRow,
  account: StudentAccountSnapshot,
  accountCollections: FinanceCollectionRow[],
  accountReceipts: FinanceReceiptRow[],
): Record<string, unknown> {
  const paidAmount = parseFloat(invoice.total_amount) - parseFloat(invoice.outstanding_amount);
  return {
    payment: collectionPaymentToApi(row),
    feeAccountId: row.student_account_id,
    aiInsight: "",
    summaryKpis: [
      {
        id: "amount",
        value: formatAmount(row.amount_collected),
        label: "Payment amount",
        icon: "payments_outlined",
        accentName: "success",
      },
      {
        id: "balance",
        value: formatAmount(account.outstanding_amount),
        label: "Remaining balance",
        icon: "account_balance_wallet_outlined",
        accentName: "warning",
      },
      {
        id: "totalDue",
        value: formatAmount(account.total_fee),
        label: "Total fee",
        icon: "account_balance_outlined",
        accentName: "primary",
      },
      {
        id: "totalPaid",
        value: formatAmount(account.amount_paid),
        label: "Total paid",
        icon: "payments_outlined",
        accentName: "success",
      },
      {
        id: "mode",
        value: row.payment_method,
        label: "Payment mode",
        icon: "credit_card_outlined",
        accentName: "neutral",
      },
    ],
    paymentTimeline: accountCollections.map((entry) => ({
      id: entry.id,
      label: entry.receipt_number,
      amount: formatAmount(entry.amount_collected),
      timestamp: entry.collection_date,
      status: collectionStatusToApi(entry.collection_status),
      mode: entry.payment_method,
    })),
    installmentHistory: [
      {
        id: invoice.id,
        termLabel: "Annual",
        dueDate: invoice.due_date,
        amount: formatAmount(invoice.total_amount),
        paidAmount: formatAmount(Math.max(0, paidAmount)),
        status: installmentStatusFromInvoice(invoice.invoice_status),
      },
    ],
    receiptLinks: accountReceipts.map((receipt) => ({
      receiptNumber: receipt.receipt_number,
      amount: formatAmount(receipt.amount),
      dateLabel: receipt.receipt_date,
      parentReceiptRoute: `/parent/receipts/${receipt.receipt_number}`,
    })),
  };
}

export function refundRequestToApi(row: RefundListRow): Record<string, unknown> {
  return {
    id: row.id,
    studentName: row.student_name ?? "",
    admissionNumber: row.admission_number ?? "",
    classLabel: row.class_label ?? "",
    amount: formatAmount(row.refund_amount),
    reason: row.refund_reason,
    requestedAt: row.created_at,
    status: row.refund_status,
    approver: row.approved_by ?? "",
    feeAccountId: row.student_account_id,
    originalReceipt: row.receipt_number ?? "",
    collectionId: row.collection_id,
    invoiceId: row.invoice_id,
  };
}
