import {
  assertEquals,
  assertRejects,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import {
  PaymentIntentStateError,
  type PaymentIntentRow,
} from "./payment_repository.ts";
import { confirmPayment, processRazorpayWebhook } from "./payment_service.ts";

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

// --- ICA-A6: paise are preserved through the capture path (NUMERIC amount) ---

// A ₹1500.50 intent. With the pre-fix INTEGER `amount` column the 0.50 was
// truncated at persistence; migration 20260920000062 retypes payment_requests/
// payment_intents.amount to NUMERIC(12,2). This asserts the SERVICE passes the
// exact decimal into finance_collections.amount_collected (already NUMERIC(12,2)),
// so with the NUMERIC column the ₹1500.50 round-trips end-to-end.
const PAISE_INTENT: PaymentIntentRow = {
  ...INTENT,
  id: "d0000000-0000-4000-8000-0000000000aa",
  gateway_order_id: "order_paise_1",
  amount: 1500.5,
};

class WebhookPaiseCaptureDb {
  capturedCollectionAmount: string | null = null;
  intentCaptured = false;

  async queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    if (sql.includes("FROM payment_intents WHERE gateway_order_id")) {
      return [PAISE_INTENT] as T[];
    }
    if (sql.includes("FROM finance_invoices fi")) {
      return [{
        id: PAISE_INTENT.invoice_id,
        organization_id: PAISE_INTENT.organization_id,
        school_id: PAISE_INTENT.school_id,
        student_id: "a4000000-0000-4000-8000-000000000001",
        student_account_id: "acct-1",
        invoice_status: "issued",
        outstanding_amount: "1500.50",
        total_amount: "1500.50",
        fee_assignment_id: "fa-1",
      }] as T[];
    }
    if (sql.includes("INSERT INTO finance_collections")) {
      this.capturedCollectionAmount = String(args[9]); // amount_collected arg
      return [{
        id: "col-paise-1",
        organization_id: PAISE_INTENT.organization_id,
        school_id: PAISE_INTENT.school_id,
        student_id: "a4000000-0000-4000-8000-000000000001",
        invoice_id: PAISE_INTENT.invoice_id,
        student_account_id: "acct-1",
        receipt_number: "APS-PAISE",
        collection_date: "2026-06-10",
        payment_method: "upi",
        reference_number: args[8] ?? null,
        amount_collected: String(args[9]),
        notes: null,
        collection_status: "completed",
        collected_by: args[11],
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      }] as T[];
    }
    if (sql.includes("INSERT INTO finance_receipts")) {
      return [{
        id: "rcpt-paise-1",
        organization_id: PAISE_INTENT.organization_id,
        school_id: PAISE_INTENT.school_id,
        collection_id: "col-paise-1",
        receipt_number: "APS-PAISE",
        receipt_date: "2026-06-10",
        amount: "1500.50",
        generated_by: args[6],
        created_at: new Date().toISOString(),
      }] as T[];
    }
    if (sql.includes("UPDATE finance_invoices")) return [] as T[];
    if (sql.includes("UPDATE payment_intents") && sql.includes("captured")) {
      this.intentCaptured = true;
      return [{
        ...PAISE_INTENT,
        status: "captured",
        collection_id: "col-paise-1",
        receipt_id: "rcpt-paise-1",
      }] as T[];
    }
    if (sql.includes("INSERT INTO audit_events")) return [{ id: crypto.randomUUID() }] as T[];
    if (sql.includes("INSERT INTO domain_events")) return [{ id: crypto.randomUUID() }] as T[];
    if (sql.includes("FROM domain_events")) return [] as T[];
    return [] as T[];
  }
}

Deno.test("ICA-A6: a ₹1500.50 capture posts amount_collected = 1500.50 (paise preserved, no INTEGER truncation)", async () => {
  const spy = new WebhookPaiseCaptureDb();
  const db = spy as unknown as TenantQueryClient;
  const result = await processRazorpayWebhook(
    db,
    webhookClaims(),
    "evt_paise_1",
    "payment.captured",
    {
      payload: {
        payment: {
          id: "pay_paise_1",
          order_id: PAISE_INTENT.gateway_order_id,
        },
      },
    },
  );
  assertEquals(result.processed, true);
  assertEquals(spy.intentCaptured, true);
  // The exact decimal reaches the (NUMERIC) collection — 0.50 is NOT truncated.
  assertEquals(spy.capturedCollectionAmount, "1500.5");
  assertEquals(Number(spy.capturedCollectionAmount), 1500.5);
});

// --- confirmPayment fail-closed gateway verification (MJ-H11) ---

const CONFIRM_INTENT: PaymentIntentRow = {
  ...INTENT,
  status: "initiated",
  // invoice_id left set so that, if capture were (wrongly) reached, a collection
  // would be created — the spy below would flip collectionCreated.
};

function parentClaims(): AccessTokenClaims {
  return {
    sub: CONFIRM_INTENT.payer_user_id,
    tenant_id: CONFIRM_INTENT.organization_id,
    organization_id: CONFIRM_INTENT.organization_id,
    school_id: CONFIRM_INTENT.school_id,
    role: "parent",
    role_slugs: ["parent"],
    primary_role: "parent",
    permissions: [],
    permissions_version: 1,
    scope: "parent",
    school_group_id: null,
    student_id: null,
    child_ids: ["a4000000-0000-4000-8000-000000000001"],
    session_id: "confirm-test",
  };
}

class ConfirmSpyDb {
  collectionCreated = false;
  intentCaptured = false;
  // When invoiceLinked is false the intent has no invoice, so capture proceeds
  // without creating a collection — used to assert stub capture works on its own.
  constructor(private readonly invoiceLinked = true) {}

  async queryObject<T>(sql: string, _args: unknown[] = []): Promise<T[]> {
    if (sql.includes("FROM payment_intents") && sql.includes("AND id = $2")) {
      const intent = this.invoiceLinked
        ? CONFIRM_INTENT
        : { ...CONFIRM_INTENT, invoice_id: null };
      return [intent] as T[];
    }
    if (sql.includes("INSERT INTO finance_collections")) {
      this.collectionCreated = true;
      return [] as T[];
    }
    if (sql.includes("UPDATE payment_intents") && sql.includes("captured")) {
      this.intentCaptured = true;
      return [{ ...CONFIRM_INTENT, status: "captured" }] as T[];
    }
    return [] as T[];
  }
}

function withRazorpayEnv(
  env: Record<string, string | undefined>,
  fn: () => Promise<void>,
): () => Promise<void> {
  const keys = ["RAZORPAY_KEY_ID", "RAZORPAY_KEY_SECRET", "RAZORPAY_STUB_MODE"];
  return async () => {
    const prev: Record<string, string | undefined> = {};
    for (const k of keys) prev[k] = Deno.env.get(k);
    try {
      for (const k of keys) {
        const v = env[k];
        if (v === undefined) Deno.env.delete(k);
        else Deno.env.set(k, v);
      }
      await fn();
    } finally {
      for (const k of keys) {
        const v = prev[k];
        if (v === undefined) Deno.env.delete(k);
        else Deno.env.set(k, v);
      }
    }
  };
}

Deno.test(
  "confirmPayment fails closed in live mode without Razorpay payment id/signature",
  withRazorpayEnv(
    {
      RAZORPAY_KEY_ID: "rzp_live_test",
      RAZORPAY_KEY_SECRET: "secret_test",
      RAZORPAY_STUB_MODE: "false",
    },
    async () => {
      const spy = new ConfirmSpyDb();
      const db = spy as unknown as TenantQueryClient;

      await assertRejects(
        () =>
          confirmPayment(db, parentClaims(), {
            paymentIntentId: CONFIRM_INTENT.id,
            transactionRef: "TXN-NO-PROOF",
            // no razorpayPaymentId / razorpaySignature — exactly what the
            // current Flutter app sends.
          }),
        PaymentIntentStateError,
        "Live payment requires a verified Razorpay payment id and signature",
      );

      assertEquals(spy.collectionCreated, false, "must NOT create a collection");
      assertEquals(spy.intentCaptured, false, "must NOT capture the intent");
    },
  ),
);

Deno.test(
  "PRA-P0-02: stub mode skips the signature check but FAILS CLOSED without an invoice",
  withRazorpayEnv(
    {
      RAZORPAY_KEY_ID: undefined,
      RAZORPAY_KEY_SECRET: undefined,
      RAZORPAY_STUB_MODE: "true",
    },
    async () => {
      // A null-invoice intent must no longer "capture" by fabricating a receipt
      // while writing nothing to the books. Reaching the invoice check (rather
      // than throwing a signature error) also proves stub mode skipped signature
      // verification.
      const spy = new ConfirmSpyDb(false);
      const db = spy as unknown as TenantQueryClient;

      await assertRejects(
        () =>
          confirmPayment(db, parentClaims(), {
            paymentIntentId: CONFIRM_INTENT.id,
            transactionRef: "TXN-STUB",
          }),
        Error,
        "no invoice",
      );

      assertEquals(
        spy.collectionCreated,
        false,
        "must not record a collection without an invoice",
      );
      assertEquals(
        spy.intentCaptured,
        false,
        "must not mark captured without recording a collection",
      );
    },
  ),
);
