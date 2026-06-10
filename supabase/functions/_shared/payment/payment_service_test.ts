import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import type { PaymentIntentRow } from "./payment_repository.ts";
import { processRazorpayWebhook } from "./payment_service.ts";

const INTENT: PaymentIntentRow = {
  id: "d0000000-0000-4000-8000-000000000099",
  organization_id: "a1000000-0000-4000-8000-000000000001",
  school_id: "a2000000-0000-4000-8000-000000000001",
  request_id: "req-1",
  payer_user_id: "a3000000-0000-4000-8000-000000000003",
  gateway: "razorpay",
  gateway_order_id: "order_test_1",
  gateway_payment_id: null,
  status: "initiated",
  amount: 4200,
  payment_method: "upi",
  invoice_id: "b9000000-0000-4000-8000-000000000001",
  collection_id: null,
  receipt_id: null,
  refund_id: null,
  idempotency_key: null,
  transaction_ref: null,
  metadata: {},
  expires_at: null,
};

class WebhookCaptureDb {
  collectionCreated = false;
  intentCaptured = false;
  auditWritten = false;

  async queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    if (sql.includes("FROM payment_intents WHERE gateway_order_id")) {
      return [INTENT] as T[];
    }
    if (sql.includes("FROM finance_invoices fi")) {
      return [{
        id: INTENT.invoice_id,
        organization_id: INTENT.organization_id,
        school_id: INTENT.school_id,
        student_id: "a4000000-0000-4000-8000-000000000001",
        student_account_id: "acct-1",
        invoice_status: "issued",
        outstanding_amount: "4200",
        total_amount: "4200",
        fee_assignment_id: "fa-1",
      }] as T[];
    }
    if (sql.includes("INSERT INTO finance_collections")) {
      this.collectionCreated = true;
      return [{
        id: "col-1",
        organization_id: INTENT.organization_id,
        school_id: INTENT.school_id,
        student_id: "a4000000-0000-4000-8000-000000000001",
        invoice_id: INTENT.invoice_id,
        student_account_id: "acct-1",
        receipt_number: "APS-TEST",
        collection_date: "2026-06-10",
        payment_method: "upi",
        reference_number: args[8] ?? null,
        amount_collected: String(args[9] ?? INTENT.amount),
        notes: null,
        collection_status: "completed",
        collected_by: args[11],
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      }] as T[];
    }
    if (sql.includes("INSERT INTO finance_receipts")) {
      return [{
        id: "rcpt-1",
        organization_id: INTENT.organization_id,
        school_id: INTENT.school_id,
        collection_id: "col-1",
        receipt_number: "APS-TEST",
        receipt_date: "2026-06-10",
        amount: String(INTENT.amount),
        generated_by: args[6],
        created_at: new Date().toISOString(),
      }] as T[];
    }
    if (sql.includes("UPDATE finance_invoices")) {
      return [] as T[];
    }
    if (sql.includes("UPDATE payment_intents") && sql.includes("captured")) {
      this.intentCaptured = true;
      return [{
        ...INTENT,
        status: "captured",
        collection_id: "col-1",
        receipt_id: "rcpt-1",
        transaction_ref: args[1],
        gateway_payment_id: args[2],
      }] as T[];
    }
    if (sql.includes("INSERT INTO audit_events")) {
      this.auditWritten = true;
      return [{ id: crypto.randomUUID() }] as T[];
    }
    if (sql.includes("INSERT INTO domain_events")) {
      return [{ id: crypto.randomUUID() }] as T[];
    }
    if (sql.includes("FROM domain_events")) {
      return [] as T[];
    }
    return [] as T[];
  }
}

function webhookClaims(): AccessTokenClaims {
  return {
    sub: INTENT.payer_user_id,
    tenant_id: INTENT.organization_id,
    organization_id: INTENT.organization_id,
    school_id: INTENT.school_id,
    role: "schoolAdmin",
    role_slugs: ["schoolAdmin"],
    primary_role: "schoolAdmin",
    permissions: ["manageFinance"],
    permissions_version: 1,
    scope: "school",
    school_group_id: null,
    student_id: null,
    child_ids: [],
    session_id: "webhook",
  };
}

Deno.test("payment.captured webhook creates finance collection when invoice linked", async () => {
  const spy = new WebhookCaptureDb();
  const db = spy as unknown as TenantQueryClient;
  const result = await processRazorpayWebhook(
    db,
    webhookClaims(),
    "evt_capture_1",
    "payment.captured",
    {
      payload: {
        payment: {
          id: "pay_test_1",
          order_id: INTENT.gateway_order_id,
        },
      },
    },
  );
  assertEquals(result.processed, true);
  assertEquals(result.intentId, INTENT.id);
  assertEquals(result.collectionId, "col-1");
  assertEquals(spy.collectionCreated, true);
  assertEquals(spy.intentCaptured, true);
  assertEquals(spy.auditWritten, true);
});
