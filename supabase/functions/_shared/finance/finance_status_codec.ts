/** Centralized finance collection/invoice status mapping for API ↔ client contracts. */

export function collectionStatusToApi(status: string): string {
  switch (status) {
    case "completed":
      return "completed";
    case "draft":
      return "pending";
    case "cancelled":
      return "failed";
    default:
      return "completed";
  }
}

export function installmentStatusFromInvoice(invoiceStatus: string): string {
  switch (invoiceStatus) {
    case "paid":
      return "completed";
    case "partially_paid":
      return "pending";
    case "cancelled":
      return "failed";
    default:
      return "pending";
  }
}
