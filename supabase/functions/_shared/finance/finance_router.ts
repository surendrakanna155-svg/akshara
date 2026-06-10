import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import {
  handleCancelCollection,
  handleCreateCollection,
  handleDailySummary,
  handleGetCollection,
  handleGetReceipt,
  handleListCollections,
} from "./finance_collections_handlers.ts";
import {
  handleAssignFeePlan,
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

const UUID_SEGMENT =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function matchFinanceRoute(
  method: string,
  path: string,
): { handler: (req: Request, config: AppConfig, ...args: string[]) => Promise<Response>; args: string[] } | null {
  if (path === "/finance/dashboard" && method === "GET") {
    return { handler: handleDashboard, args: [] };
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
