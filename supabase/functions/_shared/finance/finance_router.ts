import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import {
  handleCancelCollection,
  handleCreateCollection,
  handleDailySummary,
  handleGetCollection,
  handleGetReceipt,
  handleListCancelledCollections,
  handleListCollections,
} from "./finance_collections_handlers.ts";
import {
  handleAccrueLateFees,
  handleWaiveLateFee,
} from "./finance_late_fee_handlers.ts";
import {
  handleCloseDay,
  handleListDayClose,
  handleReopenDay,
} from "./finance_day_close_handlers.ts";
import { handleStudentLedger } from "./finance_ledger_handlers.ts";
import {
  handleAssignFeePlan,
  handleBulkAssignFeeStructures,
  handleCancelFeeAssignment,
  handleCreateFeeAssignment,
  handleGetFeeAssignment,
  handleGetStudentAccount,
  handleListFeeAssignments,
} from "./finance_assignments_handlers.ts";
import {
  handleArchiveFeeStructure,
  handleCreateFeeStructure,
  handleGetFeeStructure,
  handleListFeeStructures,
  handleUpdateFeeStructure,
} from "./finance_handlers.ts";
import {
  handleCancelInvoice,
  handleGetInvoice,
  handleIssueInvoice,
  handleListInvoices,
} from "./finance_invoices_handlers.ts";
import { handleDashboard } from "./finance_dashboard_handlers.ts";
import {
  handleFinanceCopilot,
  handleFinanceExecutiveDashboard,
} from "./finance_intelligence_handlers.ts";
import { handleListInvoiceInstallments } from "./finance_installments_handlers.ts";
import { handleHeadWiseDues } from "./finance_analytics_handlers.ts";
import {
  handleGetGoodsReceipt,
  handleInventoryFinanceTimeline,
  handleListGoodsReceipts,
  handleListInventoryFinancePostings,
  handleReconciliationDashboard,
  handleVendorTransactions,
} from "../inventory_finance/inventory_finance_reconciliation_handlers.ts";
import {
  handleApproveRefund,
  handleCreateRefund,
  handleGetRefund,
  handleListRefunds,
  handleRejectRefund,
} from "./finance_refunds_handlers.ts";
import {
  handleCreateDiscountRule,
  handleDiscountsDashboard,
  handleUpdateDiscountRule,
} from "./finance_discounts_handlers.ts";
import {
  handleBounceOfflinePayment,
  handleListOfflinePayments,
  handleReconcileOfflinePayment,
  handleRecordOfflinePayment,
} from "./finance_offline_payments_handlers.ts";
import {
  handleConfirmQrPaymentSession,
  handleCreateQrPaymentSession,
  handleGetQrPaymentSession,
} from "./finance_qr_handlers.ts";
import { handleFinanceDefaulters } from "./finance_defaulters_handlers.ts";
import {
  handleCreatePromiseToPay,
  handleFinanceCallQueue,
  handleListPromisesToPay,
  handleListRecoveryContacts,
  handleListRecoveryTargets,
  handleLogRecoveryContact,
  handleRecoveryDashboard,
  handleResolvePromiseToPay,
  handleUpsertRecoveryTarget,
} from "./finance_recovery_handlers.ts";
import { handleFinanceReports } from "./finance_reports_handlers.ts";
import {
  handleGetTallyLedgerMap,
  handleTallyExport,
  handleUpsertTallyLedgerMap,
} from "./finance_tally_handlers.ts";
import {
  handleGetSettings,
  handleUpdateSettings,
} from "./finance_settings_handlers.ts";
import {
  handleCreateScholarship,
  handleUpdateScholarship,
} from "./finance_scholarships_handlers.ts";
import {
  handleApproveFeeReduction,
  handleListFeeReductions,
  handleProposeDiscountApplication,
  handleProposeScholarshipAward,
  handleRejectFeeReduction,
  handleReverseFeeReduction,
} from "./finance_fee_reductions_handlers.ts";

const UUID_SEGMENT =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function matchFinanceRoute(
  method: string,
  path: string,
): { handler: (req: Request, config: AppConfig, ...args: string[]) => Promise<Response>; args: string[] } | null {
  if (path === "/finance/dashboard" && method === "GET") {
    return { handler: handleDashboard, args: [] };
  }

  if (path === "/finance/intelligence/copilot" && method === "GET") {
    return { handler: handleFinanceCopilot, args: [] };
  }
  if (path === "/finance/intelligence/executive" && method === "GET") {
    return { handler: handleFinanceExecutiveDashboard, args: [] };
  }

  // FIN-9: head-wise dues + outstanding analytics (read → viewFinance).
  if (path === "/finance/analytics/head-wise-dues" && method === "GET") {
    return { handler: handleHeadWiseDues, args: [] };
  }

  if (path === "/finance/inventory-reconciliation/dashboard" && method === "GET") {
    return { handler: handleReconciliationDashboard, args: [] };
  }
  if (path === "/finance/inventory-reconciliation/timeline" && method === "GET") {
    return { handler: handleInventoryFinanceTimeline, args: [] };
  }
  if (path === "/finance/inventory-reconciliation/goods-receipts" && method === "GET") {
    return { handler: handleListGoodsReceipts, args: [] };
  }
  if (path === "/finance/inventory-reconciliation/postings" && method === "GET") {
    return { handler: handleListInventoryFinancePostings, args: [] };
  }

  const goodsReceiptMatch = path.match(
    /^\/finance\/inventory-reconciliation\/goods-receipts\/([^/]+)$/,
  );
  if (goodsReceiptMatch && method === "GET") {
    return { handler: handleGetGoodsReceipt, args: [goodsReceiptMatch[1]!] };
  }

  const vendorTxMatch = path.match(
    /^\/finance\/inventory-reconciliation\/vendors\/([^/]+)\/transactions$/,
  );
  if (vendorTxMatch && method === "GET") {
    return { handler: handleVendorTransactions, args: [vendorTxMatch[1]!] };
  }

  if (path === "/finance/fee-structures" && method === "GET") {
    return { handler: handleListFeeStructures, args: [] };
  }
  if (path === "/finance/fee-structures" && method === "POST") {
    return { handler: handleCreateFeeStructure, args: [] };
  }

  const archiveMatch = path.match(/^\/finance\/fee-structures\/([^/]+)\/archive$/);
  if (archiveMatch && method === "PATCH") {
    return { handler: handleArchiveFeeStructure, args: [archiveMatch[1]!] };
  }

  const structureMatch = path.match(/^\/finance\/fee-structures\/([^/]+)$/);
  if (structureMatch) {
    const structureId = structureMatch[1]!;
    if (method === "GET") {
      return { handler: handleGetFeeStructure, args: [structureId] };
    }
    if (method === "PUT") {
      return { handler: handleUpdateFeeStructure, args: [structureId] };
    }
  }

  if (path === "/finance/fee-assignments" && method === "GET") {
    return { handler: handleListFeeAssignments, args: [] };
  }
  if (path === "/finance/fee-assignments" && method === "POST") {
    return { handler: handleCreateFeeAssignment, args: [] };
  }

  // PRC-A gap fix: bulk/class-wide assignment — a literal path checked BEFORE
  // the /fee-assignments/:id regexes below so "bulk" is never treated as an id.
  if (path === "/finance/fee-assignments/bulk" && method === "POST") {
    return { handler: handleBulkAssignFeeStructures, args: [] };
  }
  if (path === "/finance/fee-assignment/assign" && method === "POST") {
    return { handler: handleAssignFeePlan, args: [] };
  }

  const cancelAssignmentMatch = path.match(/^\/finance\/fee-assignments\/([^/]+)\/cancel$/);
  if (cancelAssignmentMatch && method === "PATCH") {
    return { handler: handleCancelFeeAssignment, args: [cancelAssignmentMatch[1]!] };
  }

  const assignmentMatch = path.match(/^\/finance\/fee-assignments\/([^/]+)$/);
  if (assignmentMatch && method === "GET") {
    return { handler: handleGetFeeAssignment, args: [assignmentMatch[1]!] };
  }

  // FIN-2: printable student ledger — matched BEFORE the bare student-account
  // GET so the /ledger suffix isn't swallowed by the single-segment regex.
  const studentLedgerMatch = path.match(
    /^\/finance\/student-accounts\/([^/]+)\/ledger$/,
  );
  if (studentLedgerMatch && method === "GET") {
    return { handler: handleStudentLedger, args: [studentLedgerMatch[1]!] };
  }

  const studentAccountMatch = path.match(/^\/finance\/student-accounts\/([^/]+)$/);
  if (studentAccountMatch && method === "GET") {
    return { handler: handleGetStudentAccount, args: [studentAccountMatch[1]!] };
  }

  if (path === "/finance/collections" && method === "GET") {
    return { handler: handleListCollections, args: [] };
  }
  if (path === "/finance/collections" && method === "POST") {
    return { handler: handleCreateCollection, args: [] };
  }

  if (path === "/finance/collections/daily-summary" && method === "GET") {
    return { handler: handleDailySummary, args: [] };
  }

  // FIN-D3: cancelled register — literal, registered before the /{id} regex.
  if (path === "/finance/collections/cancelled" && method === "GET") {
    return { handler: handleListCancelledCollections, args: [] };
  }

  const cancelCollectionMatch = path.match(/^\/finance\/collections\/([^/]+)\/cancel$/);
  if (cancelCollectionMatch && method === "POST") {
    return { handler: handleCancelCollection, args: [cancelCollectionMatch[1]!] };
  }

  const collectionMatch = path.match(/^\/finance\/collections\/([^/]+)$/);
  if (collectionMatch && method === "GET") {
    return { handler: handleGetCollection, args: [collectionMatch[1]!] };
  }

  const receiptMatch = path.match(/^\/finance\/receipts\/([^/]+)$/);
  if (receiptMatch && method === "GET") {
    return { handler: handleGetReceipt, args: [receiptMatch[1]!] };
  }

  if (path === "/finance/invoices" && method === "GET") {
    return { handler: handleListInvoices, args: [] };
  }

  const issueInvoiceMatch = path.match(/^\/finance\/invoices\/([^/]+)\/issue$/);
  if (issueInvoiceMatch && method === "POST") {
    return { handler: handleIssueInvoice, args: [issueInvoiceMatch[1]!] };
  }

  const cancelInvoiceMatch = path.match(/^\/finance\/invoices\/([^/]+)\/cancel$/);
  if (cancelInvoiceMatch && method === "POST") {
    return { handler: handleCancelInvoice, args: [cancelInvoiceMatch[1]!] };
  }

  // FIN-D5: waive a single invoice's accrued late fee.
  const waiveLateFeeMatch = path.match(
    /^\/finance\/invoices\/([^/]+)\/waive-late-fee$/,
  );
  if (waiveLateFeeMatch && method === "POST") {
    return { handler: handleWaiveLateFee, args: [waiveLateFeeMatch[1]!] };
  }

  // FIN-6: invoice installment schedule — matched BEFORE the bare invoice GET so
  // the /installments suffix isn't swallowed by the single-segment regex.
  const invoiceInstallmentsMatch = path.match(
    /^\/finance\/invoices\/([^/]+)\/installments$/,
  );
  if (invoiceInstallmentsMatch && method === "GET") {
    return { handler: handleListInvoiceInstallments, args: [invoiceInstallmentsMatch[1]!] };
  }

  const invoiceMatch = path.match(/^\/finance\/invoices\/([^/]+)$/);
  if (invoiceMatch && method === "GET") {
    return { handler: handleGetInvoice, args: [invoiceMatch[1]!] };
  }

  if (path === "/finance/refunds" && method === "GET") {
    return { handler: handleListRefunds, args: [] };
  }
  if (path === "/finance/refunds" && method === "POST") {
    return { handler: handleCreateRefund, args: [] };
  }

  const approveRefundMatch = path.match(/^\/finance\/refunds\/([^/]+)\/approve$/);
  if (approveRefundMatch && method === "POST") {
    return { handler: handleApproveRefund, args: [approveRefundMatch[1]!] };
  }

  const rejectRefundMatch = path.match(/^\/finance\/refunds\/([^/]+)\/reject$/);
  if (rejectRefundMatch && method === "POST") {
    return { handler: handleRejectRefund, args: [rejectRefundMatch[1]!] };
  }

  const refundMatch = path.match(/^\/finance\/refunds\/([^/]+)$/);
  if (refundMatch && method === "GET") {
    return { handler: handleGetRefund, args: [refundMatch[1]!] };
  }

  if (path === "/finance/discounts" && method === "GET") {
    return { handler: handleDiscountsDashboard, args: [] };
  }
  if (path === "/finance/discounts" && method === "POST") {
    return { handler: handleCreateDiscountRule, args: [] };
  }

  const discountMatch = path.match(/^\/finance\/discounts\/([^/]+)$/);
  if (discountMatch && method === "PUT") {
    return { handler: handleUpdateDiscountRule, args: [discountMatch[1]!] };
  }

  // ─── STF-1: offline payments ───────────────────────────────────────────────
  if (path === "/finance/payments/offline" && method === "POST") {
    return { handler: handleRecordOfflinePayment, args: [] };
  }
  if (path === "/finance/payments/offline" && method === "GET") {
    return { handler: handleListOfflinePayments, args: [] };
  }
  const offlineReconcileMatch = path.match(
    /^\/finance\/payments\/offline\/([^/]+)\/reconcile$/,
  );
  if (offlineReconcileMatch && method === "POST") {
    return { handler: handleReconcileOfflinePayment, args: [offlineReconcileMatch[1]!] };
  }
  // FIN-R7: instrument dishonoured (cheque / DD / PDC bounce) — tracking-only.
  const offlineBounceMatch = path.match(
    /^\/finance\/payments\/offline\/([^/]+)\/bounce$/,
  );
  if (offlineBounceMatch && method === "POST") {
    return { handler: handleBounceOfflinePayment, args: [offlineBounceMatch[1]!] };
  }

  // ─── STF-2: QR / UPI payment sessions ──────────────────────────────────────
  if (path === "/finance/payments/qr" && method === "POST") {
    return { handler: handleCreateQrPaymentSession, args: [] };
  }
  const qrConfirmMatch = path.match(/^\/finance\/payments\/qr\/([^/]+)\/confirm$/);
  if (qrConfirmMatch && method === "POST") {
    return { handler: handleConfirmQrPaymentSession, args: [qrConfirmMatch[1]!] };
  }
  const qrSessionMatch = path.match(/^\/finance\/payments\/qr\/([^/]+)$/);
  if (qrSessionMatch && method === "GET") {
    return { handler: handleGetQrPaymentSession, args: [qrSessionMatch[1]!] };
  }

  // ─── FIN-R: fee-recovery CRM ───────────────────────────────────────────────
  if (path === "/finance/recovery/dashboard" && method === "GET") {
    return { handler: handleRecoveryDashboard, args: [] };
  }
  if (path === "/finance/recovery/call-queue" && method === "GET") {
    return { handler: handleFinanceCallQueue, args: [] };
  }
  if (path === "/finance/recovery/contacts" && method === "POST") {
    return { handler: handleLogRecoveryContact, args: [] };
  }
  const recoveryContactsMatch = path.match(
    /^\/finance\/recovery\/contacts\/([^/]+)$/,
  );
  if (recoveryContactsMatch && method === "GET") {
    return { handler: handleListRecoveryContacts, args: [recoveryContactsMatch[1]!] };
  }
  if (path === "/finance/recovery/promises" && method === "GET") {
    return { handler: handleListPromisesToPay, args: [] };
  }
  if (path === "/finance/recovery/promises" && method === "POST") {
    return { handler: handleCreatePromiseToPay, args: [] };
  }
  const ptpResolveMatch = path.match(
    /^\/finance\/recovery\/promises\/([^/]+)\/resolve$/,
  );
  if (ptpResolveMatch && method === "POST") {
    return { handler: handleResolvePromiseToPay, args: [ptpResolveMatch[1]!] };
  }
  if (path === "/finance/recovery/targets" && method === "GET") {
    return { handler: handleListRecoveryTargets, args: [] };
  }
  if (path === "/finance/recovery/targets" && method === "POST") {
    return { handler: handleUpsertRecoveryTarget, args: [] };
  }

  // ─── FIN-D5: late-fee accrual ──────────────────────────────────────────────
  if (path === "/finance/late-fees/accrue" && method === "POST") {
    return { handler: handleAccrueLateFees, args: [] };
  }

  // ─── FIN-D1: day-close lock ────────────────────────────────────────────────
  if (path === "/finance/day-close" && method === "GET") {
    return { handler: handleListDayClose, args: [] };
  }
  if (path === "/finance/day-close" && method === "POST") {
    return { handler: handleCloseDay, args: [] };
  }
  const reopenDayMatch = path.match(/^\/finance\/day-close\/([^/]+)\/reopen$/);
  if (reopenDayMatch && method === "POST") {
    return { handler: handleReopenDay, args: [reopenDayMatch[1]!] };
  }

  // ─── STF-3: defaulters / reports / settings ────────────────────────────────
  if (path === "/finance/defaulters" && method === "GET") {
    return { handler: handleFinanceDefaulters, args: [] };
  }
  if (path === "/finance/reports" && method === "GET") {
    return { handler: handleFinanceReports, args: [] };
  }
  // Batch 7: Tally accounting export (owner-idea 11).
  if (path === "/finance/reports/tally-export" && method === "GET") {
    return { handler: handleTallyExport, args: [] };
  }
  if (path === "/finance/tally-ledger-map" && method === "GET") {
    return { handler: handleGetTallyLedgerMap, args: [] };
  }
  if (path === "/finance/tally-ledger-map" && method === "PUT") {
    return { handler: handleUpsertTallyLedgerMap, args: [] };
  }
  if (path === "/finance/settings" && method === "GET") {
    return { handler: handleGetSettings, args: [] };
  }
  if (path === "/finance/settings" && method === "PUT") {
    return { handler: handleUpdateSettings, args: [] };
  }

  // ─── STF-5: scholarships ───────────────────────────────────────────────────
  if (path === "/finance/scholarships" && method === "POST") {
    return { handler: handleCreateScholarship, args: [] };
  }
  const scholarshipMatch = path.match(/^\/finance\/scholarships\/([^/]+)$/);
  if (scholarshipMatch && method === "PUT") {
    return { handler: handleUpdateScholarship, args: [scholarshipMatch[1]!] };
  }

  // ─── STEP-5: fee reductions (scholarship awards + discount applications) ─────
  // A reduction is proposed (maker), then approved/rejected/reversed (checker,
  // approver != proposer). Approval is what actually reduces the payable.
  if (path === "/finance/fee-reductions" && method === "GET") {
    return { handler: handleListFeeReductions, args: [] };
  }
  if (path === "/finance/fee-reductions/scholarship-awards" && method === "POST") {
    return { handler: handleProposeScholarshipAward, args: [] };
  }
  if (path === "/finance/fee-reductions/discount-applications" && method === "POST") {
    return { handler: handleProposeDiscountApplication, args: [] };
  }
  const approveReductionMatch = path.match(/^\/finance\/fee-reductions\/([^/]+)\/approve$/);
  if (approveReductionMatch && method === "POST") {
    return { handler: handleApproveFeeReduction, args: [approveReductionMatch[1]!] };
  }
  const rejectReductionMatch = path.match(/^\/finance\/fee-reductions\/([^/]+)\/reject$/);
  if (rejectReductionMatch && method === "POST") {
    return { handler: handleRejectFeeReduction, args: [rejectReductionMatch[1]!] };
  }
  const reverseReductionMatch = path.match(/^\/finance\/fee-reductions\/([^/]+)\/reverse$/);
  if (reverseReductionMatch && method === "POST") {
    return { handler: handleReverseFeeReduction, args: [reverseReductionMatch[1]!] };
  }

  return null;
}

export async function routeFinance(
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
): Promise<Response | null> {
  if (!path.startsWith("/finance")) return null;

  const match = matchFinanceRoute(method, path);
  if (!match) {
    return errorEnvelope("NOT_FOUND", `Route not found: ${method} ${path}`, 404);
  }

  for (const arg of match.args) {
    if (arg.includes("-") && !UUID_SEGMENT.test(arg)) {
      // Allow non-UUID legacy mock ids in path for compatibility
    }
  }

  return await match.handler(req, config, ...match.args);
}
