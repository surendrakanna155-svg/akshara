import type {
  AssignmentWithAccount,
  FinanceFeeAssignmentRow,
  StudentAccountListRow,
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
import type { FinanceDashboardSnapshot } from "./finance_dashboard_repository.ts";
import type { RefundListRow } from "./finance_refunds_repository.ts";
import type { StudentLedger } from "./finance_ledger_repository.ts";

export interface FinanceFeeStructureRow {
  id: string;
  organization_id: string;
  school_id: string;
  name: string;
  academic_year: string;
  academic_year_id: string | null;
  // Cap 67 — real class/section binding (soft FK, nullable = "unbound").
  class_id: string | null;
  section_id: string | null;
  description: string | null;
  status: string;
  created_by: string;
  created_at: string;
  updated_at: string;
}

/** Cap 67 — resolved class/section labels for a bound structure (looked up by the caller). */
export interface FeeStructureClassBindingLabels {
  className: string | null;
  sectionName: string | null;
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
  classBinding: FeeStructureClassBindingLabels = { className: null, sectionName: null },
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
    academicYearId: structure.academic_year_id,
    // Cap 67 — real class/section binding; null = unbound (free-text
    // description below remains the only "class range" for those rows).
    classId: structure.class_id,
    className: classBinding.className,
    sectionId: structure.section_id,
    sectionName: classBinding.sectionName,
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

/** Cap 73 — the applied mid-year admission proration, exposed as one unit. */
function prorationToApi(
  row: Pick<
    FinanceFeeAssignmentRow,
    | "proration_policy"
    | "proration_basis"
    | "proration_total_months"
    | "proration_months_charged"
    | "proration_reference_date"
    | "proration_annual_amount"
    | "proration_charged_amount"
    | "proration_fallback_reason"
    | "proration_is_override"
    | "proration_override_reason"
    | "proration_overridden_by"
  >,
): Record<string, unknown> {
  return {
    policy: row.proration_policy,
    basis: row.proration_basis,
    totalMonths: row.proration_total_months,
    monthsCharged: row.proration_months_charged,
    referenceDate: row.proration_reference_date,
    annualAmount: row.proration_annual_amount != null
      ? formatAmount(row.proration_annual_amount)
      : null,
    chargedAmount: row.proration_charged_amount != null
      ? formatAmount(row.proration_charged_amount)
      : null,
    fallbackReason: row.proration_fallback_reason,
    isOverride: row.proration_is_override,
    overrideReason: row.proration_override_reason,
    overriddenBy: row.proration_overridden_by,
  };
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
    // Cap 73 — which mid-year admission proration policy applied, and how it
    // was derived (months charged / total months / basis), not just a number.
    proration: prorationToApi(row),
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
    // Cap 73 — surfaced here too: this is the response shape callers actually
    // consume for assign/bulk-assign, so the proration explanation travels
    // with the result instead of requiring a second GET-assignment call.
    proration: prorationToApi(assignment),
  };
}

/**
 * WEB-007 — maps one lightweight list row to the client contract. Same field
 * names as `studentAccountToApi` for the fields the list actually shows, minus
 * the per-account enrichment (invoice/proration/installment) the list omits.
 */
export function studentAccountListItemToApi(
  row: StudentAccountListRow,
): Record<string, unknown> {
  return {
    id: row.id,
    studentId: row.student_id,
    studentName: row.student_name ?? "",
    admissionNumber: row.admission_number ?? "",
    classLabel: row.class_label ?? "",
    feeStructureName: row.fee_structure_name ?? "",
    feeStructureId: row.fee_structure_id ?? "",
    feeAssignmentId: row.fee_assignment_id,
    academicYear: row.academic_year,
    totalDue: formatAmount(row.total_fee),
    totalPaid: formatAmount(row.amount_paid),
    balance: formatAmount(row.outstanding_amount),
    status: mapAccountStatus(row.status),
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
    lateFeeAmount: formatAmount(row.late_fee_amount ?? "0"),
    lateFeeAccruedAt: row.late_fee_accrued_at ?? "",
    termLabel: "Annual",
    createdBy: row.created_by,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

// FIN-6 — one installment (term) of the invoice's informational due schedule.
export function installmentToApi(
  row: {
    id: string;
    invoice_id: string;
    term_no: number;
    due_date: string;
    amount_minor: string;
    status: string;
  },
): Record<string, unknown> {
  return {
    id: row.id,
    invoiceId: row.invoice_id,
    termNo: row.term_no,
    termLabel: `Term ${row.term_no}`,
    dueDate: row.due_date,
    amount: formatAmount(row.amount_minor),
    status: row.status,
  };
}

// FIN-D2 — one head-allocation row (per-head total + paid + remaining).
export function headAllocationToApi(
  row: {
    fee_head: string;
    head_label: string;
    head_total_minor: string;
    head_paid_minor: string;
    sort_order: number;
    priority: number;
  },
): Record<string, unknown> {
  const total = parseFloat(row.head_total_minor) || 0;
  const paid = parseFloat(row.head_paid_minor) || 0;
  const { category } = decodeFeeHead(row.fee_head);
  return {
    feeHead: row.fee_head,
    category,
    label: row.head_label,
    total: formatAmount(total),
    paid: formatAmount(paid),
    remaining: formatAmount(Math.max(0, total - paid)),
    sortOrder: row.sort_order,
    priority: row.priority,
  };
}

// FIN-9 — one head-wise dues row (per fee head, outstanding across open invoices).
export function headWiseDueToApi(
  row: { fee_head: string; head_label: string; dues: string },
): Record<string, unknown> {
  const { category } = decodeFeeHead(row.fee_head);
  return {
    feeHead: row.fee_head,
    category,
    label: row.head_label,
    dues: formatAmount(row.dues),
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

// FIN-D3 — cancelled register entry (student, receipt, amount, date, reason,
// who cancelled it + when).
export function cancelledCollectionToApi(
  row: CollectionListRow & { cancelled_by_name?: string; cancelled_by?: string | null; cancelled_at?: string | null; cancellation_reason?: string | null },
): Record<string, unknown> {
  return {
    id: row.id,
    receiptNumber: row.receipt_number,
    studentName: row.student_name ?? "",
    admissionNumber: row.admission_number ?? "",
    classLabel: row.class_label ?? "",
    amount: formatAmount(row.amount_collected),
    mode: row.payment_method,
    collectedAt: row.collection_date,
    reason: row.cancellation_reason ?? "",
    cancelledBy: row.cancelled_by ?? "",
    cancelledByName: row.cancelled_by_name ?? "",
    cancelledAt: row.cancelled_at ?? "",
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

/**
 * ENG-1: single collection row for the 409 CONFLICT body. Includes `rowVersion`
 * so the Data Reliability Platform can re-submit with the correct expected
 * version (it reads `row_version`/`rowVersion` off the returned server row).
 */
export function collectionRowToApi(row: FinanceCollectionRow): Record<string, unknown> {
  return {
    id: row.id,
    invoiceId: row.invoice_id,
    studentAccountId: row.student_account_id,
    receiptNumber: row.receipt_number,
    amountCollected: formatAmount(row.amount_collected),
    paymentMethod: row.payment_method,
    collectionStatus: row.collection_status,
    collectionDate: row.collection_date,
    rowVersion: row.row_version,
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
    // FIN-6: expose the invoice id so the client can load the installment
    // schedule for this collection's invoice (additive; existing fields unchanged).
    invoiceId: row.invoice_id,
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

export function dashboardToApi(data: FinanceDashboardSnapshot): Record<string, unknown> {
  return {
    totalStudents: data.totalStudents,
    activeFeeAssignments: data.activeFeeAssignments,
    totalInvoiced: data.totalInvoiced,
    totalCollected: data.totalCollected,
    totalOutstanding: data.totalOutstanding,
    collectionRate: data.collectionRate,
    pendingInvoices: data.pendingInvoices,
    partiallyPaidInvoices: data.partiallyPaidInvoices,
    paidInvoices: data.paidInvoices,
    pendingRefunds: data.pendingRefunds,
    processedRefunds: data.processedRefunds,
    todayCollections: data.todayCollections,
    todayCollectionCount: data.todayCollectionCount,
    recentCollections: data.recentCollections.map((row) => ({
      id: row.id,
      receiptNumber: row.receipt_number,
      studentName: row.student_name,
      amount: row.amount,
      paymentMethod: row.payment_method,
      collectionDate: row.collection_date,
    })),
    recentRefunds: data.recentRefunds.map((row) => ({
      id: row.id,
      studentName: row.student_name,
      amount: row.amount,
      status: row.status,
      requestedAt: row.requested_at,
    })),
  };
}

// FIN-2 — printable student fee statement / ledger. Chronologically merges
// invoices (debits) and completed collections (credits) into a running-balance
// ledger, plus the raw invoice/payment lists and an account summary.
export function studentLedgerToApi(ledger: StudentLedger): Record<string, unknown> {
  // PRA-P1-11 (S1): `refunds` is optional on StudentLedger; default to none so
  // legacy callers keep working.
  const { account, invoices, collections, refunds = [] } = ledger;

  const invoiceRows = invoices.map((inv) => ({
    id: inv.id,
    invoiceNumber: inv.invoice_number,
    invoiceDate: inv.invoice_date,
    dueDate: inv.due_date,
    totalAmount: formatAmount(inv.total_amount),
    outstandingAmount: formatAmount(inv.outstanding_amount),
    lateFeeAmount: formatAmount(inv.late_fee_amount ?? "0"),
    status: inv.invoice_status,
  }));

  const paymentRows = collections.map((c) => ({
    id: c.id,
    receiptNumber: c.receipt_number,
    date: c.collection_date,
    mode: c.payment_method,
    amount: formatAmount(c.amount_collected),
    status: collectionStatusToApi(c.collection_status),
  }));

  // Build a running-balance ledger: an invoice debits (raises balance owed), a
  // completed collection credits (reduces it), and a processed refund debits it
  // back. Cancelled collections do not move the balance. Sorted by date then a
  // stable tiebreak (invoice → payment → refund) so on a single day the money
  // is paid before it is refunded.
  interface LedgerEntry {
    date: string;
    kind: "invoice" | "payment" | "refund";
    reference: string;
    description: string;
    debit: number;
    credit: number;
    order: number;
  }
  const entries: LedgerEntry[] = [];
  for (const inv of invoices) {
    entries.push({
      date: inv.invoice_date,
      kind: "invoice",
      reference: inv.invoice_number,
      description: `Invoice ${inv.invoice_number}`,
      debit: parseFloat(inv.total_amount) || 0,
      credit: 0,
      order: 0,
    });
  }
  for (const c of collections) {
    if (c.collection_status === "cancelled") continue;
    entries.push({
      date: c.collection_date,
      kind: "payment",
      reference: c.receipt_number,
      description: `Payment ${c.receipt_number} (${c.payment_method})`,
      debit: 0,
      credit: parseFloat(c.amount_collected) || 0,
      order: 1,
    });
  }
  // PRA-P1-11 (S1): debit each processed refund. A refunded collection keeps
  // status 'refunded'/'partially_refunded' (NOT 'cancelled'), so it survives the
  // filter above and still credits its full original amount — while the summary
  // reads account.outstanding_amount, which applyProcessedRefund already raised
  // by the refunded amount. Without this debit the ledger's running balance ends
  // below the summary and the printed statement contradicts itself. We debit
  // each refund row's own refund_amount (the partial portion, for a
  // partially_refunded collection), so partial refunds are never double-counted.
  for (const r of refunds) {
    entries.push({
      date: r.refund_date,
      kind: "refund",
      reference: r.receipt_number ?? r.id,
      description: r.receipt_number
        ? `Refund against ${r.receipt_number}`
        : "Refund",
      debit: parseFloat(r.refund_amount) || 0,
      credit: 0,
      order: 2,
    });
  }
  entries.sort((a, b) => {
    if (a.date !== b.date) return a.date < b.date ? -1 : 1;
    return a.order - b.order;
  });

  let running = 0;
  const ledgerRows = entries.map((e) => {
    running += e.debit - e.credit;
    return {
      date: e.date,
      kind: e.kind,
      reference: e.reference,
      description: e.description,
      debit: formatAmount(e.debit),
      credit: formatAmount(e.credit),
      balance: formatAmount(running),
    };
  });

  return {
    account: {
      id: account.id,
      studentId: account.student_id,
      studentName: account.student_name,
      admissionNumber: account.admission_number,
      classLabel: account.class_label,
      academicYear: account.academic_year,
      totalDue: formatAmount(account.total_fee),
      totalPaid: formatAmount(account.amount_paid),
      balance: formatAmount(account.outstanding_amount),
      status: account.status === "closed" ? "closed" : "active",
    },
    invoices: invoiceRows,
    payments: paymentRows,
    ledger: ledgerRows,
    summary: {
      totalDue: formatAmount(account.total_fee),
      totalPaid: formatAmount(account.amount_paid),
      balance: formatAmount(account.outstanding_amount),
      invoiceCount: invoiceRows.length,
      paymentCount: paymentRows.length,
    },
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
