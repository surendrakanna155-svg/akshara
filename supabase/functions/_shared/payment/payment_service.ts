import type { AccessTokenClaims } from "../jwt.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import { correlationIdFromRequest, recordMutationAudit } from "../audit/audit_repository.ts";
import { createCollection } from "../finance/finance_collections_repository.ts";
import {
  DEFAULT_PROVIDER_ID,
  getPaymentProvider,
  resolvePaymentProvider,
} from "./payment_provider_registry.ts";
import {
  createPaymentIntent,
  findIntentByIdempotencyKey,
  findRequestByInstallment,
  getPaymentIntent,
  markIntentCaptured,
  PaymentIntentNotFoundError,
  PaymentIntentStateError,
  upsertPaymentRequest,
  type PaymentIntentRow,
} from "./payment_repository.ts";

export interface InitiatePaymentInput {
  installmentId: string;
  paymentMethod: string;
  amount: number;
  idempotencyKey: string | null;
}

export interface InitiatePaymentResult {
  paymentIntentId: string;
  installmentId: string;
  amount: number;
  status: string;
  expiresAtLabel: string;
  razorpayOrderId: string;
  razorpayKeyId: string | null;
}

export interface ConfirmPaymentInput {
  paymentIntentId: string;
  transactionRef: string;
  razorpayPaymentId?: string;
  razorpaySignature?: string;
}

export interface ConfirmPaymentResult {
  receiptId: string;
  receiptNumber: string;
  paidAmount: number;
  paymentMethod: string;
  paidAtLabel: string;
  collectionId: string | null;
  invoiceId: string | null;
}

function requireParentChild(claims: AccessTokenClaims): string {
  if (claims.child_ids.length === 0) {
    throw new PaymentIntentStateError("No linked children on parent account");
  }
  return claims.child_ids[0];
}

function expiresLabel(expiresAt: Date): string {
  const minutes = Math.max(1, Math.round((expiresAt.getTime() - Date.now()) / 60000));
  return `Expires in ${minutes} minutes`;
}

function toApiPaymentMethod(method: string | null): string {
  return method ?? "upi";
}

/// PRA-P0-02 (S1): resolve the invoice backing a fee installment so a captured
/// payment can be posted to the school's books as a real collection. Returns null
/// when the installment (or its invoice) does not exist — the caller fails closed.
async function resolveInstallmentInvoiceId(
  db: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  installmentId: string,
): Promise<string | null> {
  const rows = await db.queryObject<{ invoice_id: string }>(
    `SELECT invoice_id FROM finance_invoice_installments
     WHERE id = $1 AND organization_id = $2 AND school_id = $3`,
    [installmentId, organizationId, schoolId],
  );
  return rows[0]?.invoice_id ?? null;
}

export async function initiatePayment(
  db: TenantQueryClient,
  claims: AccessTokenClaims,
  input: InitiatePaymentInput,
  req?: Request,
): Promise<InitiatePaymentResult> {
  if (claims.scope !== "parent" || !claims.school_id) {
    throw new PaymentIntentStateError("Payment initiation requires parent scope");
  }
  if (!input.installmentId || input.amount <= 0) {
    throw new PaymentIntentStateError("installment_id and positive amount are required");
  }

  const orgId = claims.tenant_id;
  const schoolId = claims.school_id;
  const studentId = requireParentChild(claims);

  // W3: resolve the school's configured provider (default 'razorpay'). All
  // gateway calls below go through this seam, never a hard-coded gateway. A
  // missing config → razorpay; an unknown/disabled configured provider throws
  // (fail-closed) rather than silently capturing money.
  const provider = await resolvePaymentProvider(db, orgId, schoolId);

  if (input.idempotencyKey) {
    const existing = await findIntentByIdempotencyKey(db, orgId, input.idempotencyKey);
    if (existing) {
      return {
        paymentIntentId: existing.id,
        installmentId: input.installmentId,
        amount: existing.amount,
        status: existing.status,
        expiresAtLabel: existing.expires_at ? expiresLabel(new Date(existing.expires_at)) : "Expires soon",
        razorpayOrderId: existing.gateway_order_id ?? "",
        razorpayKeyId: provider.publicClientKey(),
      };
    }
  }

  // PRA-P0-02 (S1): resolve the installment's invoice and FAIL CLOSED when it
  // cannot be found. Previously this hard-coded `invoiceId: null`, so the capture
  // path's `if (intent.invoice_id)` gate was always false — Razorpay took the
  // money, NO finance_collections/finance_receipts row was written, and the parent
  // was shown a fabricated receipt number. A payment that cannot be tied to an
  // invoice must not proceed rather than silently lose money.
  const resolvedInvoiceId = await resolveInstallmentInvoiceId(
    db,
    orgId,
    schoolId,
    input.installmentId,
  );
  if (!resolvedInvoiceId) {
    throw new PaymentIntentStateError(
      `No invoice found for installment ${input.installmentId} — cannot initiate payment`,
    );
  }

  const seeded = await findRequestByInstallment(db, orgId, claims.sub, input.installmentId);
  const request = seeded ?? await upsertPaymentRequest(db, {
    organizationId: orgId,
    schoolId,
    studentId,
    payerUserId: claims.sub,
    sourceType: "fee_installment",
    sourceId: input.installmentId,
    invoiceId: resolvedInvoiceId,
    amount: input.amount,
    idempotencyKey: input.idempotencyKey,
  });

  const order = await provider.createOrder({
    amount: input.amount,
    receipt: request.id,
    notes: {
      installment_id: input.installmentId,
      payer_user_id: claims.sub,
    },
  });

  const expiresAt = new Date(Date.now() + 15 * 60 * 1000);
  const intent = await createPaymentIntent(db, {
    organizationId: orgId,
    schoolId,
    requestId: request.id,
    payerUserId: claims.sub,
    amount: input.amount,
    paymentMethod: input.paymentMethod,
    invoiceId: request.invoice_id,
    gatewayOrderId: order.id,
    idempotencyKey: input.idempotencyKey,
    expiresAt,
    // Persist WHICH provider opened this intent so confirm/webhook resolve the
    // same one.
    gateway: provider.id,
  });

  await recordMutationAudit(
    db,
    claims,
    {
      eventType: "paymentInitiated",
      category: "workflow",
      entityType: "payment_intent",
      entityId: intent.id,
      metadata: {
        installmentId: input.installmentId,
        gatewayOrderId: order.id,
        amount: input.amount,
      },
      correlationId: req ? correlationIdFromRequest(req) : undefined,
    },
    {
      eventType: "payment.initiated",
      payload: { intentId: intent.id, orderId: order.id, amount: input.amount },
      sourceModule: "payment",
      idempotencyKey: input.idempotencyKey ?? `payment.initiated:${intent.id}`,
    },
    req,
  );

  return {
    paymentIntentId: intent.id,
    installmentId: input.installmentId,
    amount: input.amount,
    status: "initiated",
    expiresAtLabel: expiresLabel(expiresAt),
    razorpayOrderId: order.id,
    razorpayKeyId: provider.publicClientKey(),
  };
}

export async function confirmPayment(
  db: TenantQueryClient,
  claims: AccessTokenClaims,
  input: ConfirmPaymentInput,
  req?: Request,
): Promise<ConfirmPaymentResult> {
  if (claims.scope !== "parent" || !claims.school_id) {
    throw new PaymentIntentStateError("Payment confirmation requires parent scope");
  }

  const orgId = claims.tenant_id;
  const schoolId = claims.school_id;

  let intent: PaymentIntentRow;
  try {
    intent = await getPaymentIntent(db, orgId, input.paymentIntentId);
  } catch (error) {
    if (error instanceof PaymentIntentNotFoundError) {
      throw error;
    }
    throw error;
  }

  if (intent.payer_user_id !== claims.sub) {
    throw new PaymentIntentStateError("Payment intent does not belong to current user");
  }
  if (intent.status === "captured" || intent.status === "settled") {
    return buildConfirmResult(intent);
  }
  if (intent.status !== "initiated" && intent.status !== "authorized") {
    throw new PaymentIntentStateError(`Payment intent is not confirmable: ${intent.status}`);
  }

  // W3: confirm through the SAME provider that opened the intent (intent.gateway),
  // via the registry — never a hard-coded gateway. An unknown persisted gateway
  // throws (fail-closed) rather than defaulting.
  const provider = getPaymentProvider(intent.gateway || DEFAULT_PROVIDER_ID);

  // FAIL-CLOSED: when the provider requires a gateway signature (a LIVE Razorpay
  // gateway, or any provider whose payments cannot be self-confirmed by the payer
  // — e.g. the offline/manual provider), verification is MANDATORY before any
  // capture. Previously this block was Razorpay-`stubMode`-gated and skipped when
  // the client omitted razorpayPaymentId/signature (the Flutter app sends only
  // transactionRef), which meant flipping RAZORPAY_STUB_MODE=false without
  // integrating the SDK would capture + issue a finance receipt with ZERO proof
  // of payment. Now a confirm with missing or invalid proof throws BEFORE any
  // collection/receipt/capture is created. A stub gateway (the current default
  // with no RAZORPAY_* env) reports requiresGatewaySignature()=false: it never
  // touches real money, so capture proceeds without a gateway signature — the
  // exact prior stub behaviour, preserved.
  if (provider.requiresGatewaySignature()) {
    if (!input.razorpayPaymentId || !input.razorpaySignature || !intent.gateway_order_id) {
      throw new PaymentIntentStateError(
        "Live payment requires a verified Razorpay payment id and signature",
      );
    }
    const valid = await provider.verifyPaymentSignature(
      intent.gateway_order_id,
      input.razorpayPaymentId,
      input.razorpaySignature,
    );
    if (!valid) {
      throw new PaymentIntentStateError("Invalid Razorpay payment signature");
    }
  }

  // PRA-M-2 (S1): serialize capture. Lock the intent row and re-read its status
  // BEFORE creating a collection. Without this, a duplicate confirm or a Razorpay
  // webhook racing the confirm would each pass the status check and each
  // createCollection — double-posting the student's ledger (a race that only
  // becomes live now that P0-02 makes the capture actually record a collection).
  // The lock is held to commit, so the concurrent caller blocks here, then re-reads
  // 'captured' and is rejected rather than posting a second collection.
  const captureLock = await db.queryObject<{ status: string }>(
    `SELECT status FROM payment_intents
     WHERE id = $1 AND organization_id = $2
     FOR UPDATE`,
    [intent.id, orgId],
  );
  if (captureLock[0]?.status === "captured") {
    throw new PaymentIntentStateError(
      `Payment already captured for intent ${intent.id}`,
    );
  }

  // PRA-P0-02 (S1): fail closed. A capture that cannot be tied to an invoice must
  // NOT fabricate a receipt number and report success while writing nothing to the
  // books. initiatePayment now resolves + persists the invoice, so this only fires
  // for a legacy/null-invoice intent — where erroring is the safe outcome, not a
  // fake "Payment successful — Receipt APS-…".
  if (!intent.invoice_id) {
    throw new PaymentIntentStateError(
      "Payment intent has no invoice — refusing to capture without recording a collection",
    );
  }
  const collection = await createCollection(db, orgId, schoolId, {
    invoiceId: intent.invoice_id,
    amountCollected: intent.amount,
    paymentMethod: intent.payment_method ?? "upi",
    referenceNumber: input.transactionRef,
    notes: "Universal Payment Engine capture",
    collectedBy: claims.sub,
  });
  const collectionId: string = collection.collection.id;
  const receiptId: string = collection.receipt.id;
  const receiptNumber: string = collection.receipt.receipt_number;

  const captured = await markIntentCaptured(db, intent.id, {
    transactionRef: input.transactionRef,
    gatewayPaymentId: input.razorpayPaymentId,
    collectionId: collectionId ?? undefined,
    receiptId: receiptId ?? undefined,
  });

  await recordMutationAudit(
    db,
    claims,
    {
      eventType: "paymentCaptured",
      category: "workflow",
      entityType: "payment_intent",
      entityId: captured.id,
      metadata: {
        transactionRef: input.transactionRef,
        collectionId,
        invoiceId: captured.invoice_id,
        amount: captured.amount,
      },
      correlationId: req ? correlationIdFromRequest(req) : undefined,
    },
    {
      eventType: "payment.captured",
      payload: {
        intentId: captured.id,
        collectionId,
        invoiceId: captured.invoice_id,
        amount: captured.amount,
      },
      sourceModule: "payment",
      idempotencyKey: `payment.captured:${captured.id}`,
    },
    req,
  );

  return buildConfirmResult(captured, receiptNumber);
}

function buildConfirmResult(
  intent: PaymentIntentRow,
  receiptNumberOverride?: string,
): ConfirmPaymentResult {
  return {
    receiptId: intent.receipt_id ?? intent.id,
    receiptNumber: receiptNumberOverride ?? `APS-${intent.id.slice(0, 8).toUpperCase()}`,
    paidAmount: intent.amount,
    paymentMethod: toApiPaymentMethod(intent.payment_method),
    paidAtLabel: "Just now",
    collectionId: intent.collection_id,
    invoiceId: intent.invoice_id,
  };
}

export async function processRazorpayWebhook(
  db: TenantQueryClient,
  claims: AccessTokenClaims,
  eventId: string,
  eventType: string,
  payload: Record<string, unknown>,
  req?: Request,
): Promise<{ processed: boolean; intentId?: string; collectionId?: string | null }> {
  const paymentEntity = payload.payload as Record<string, unknown> | undefined;
  const entity = paymentEntity?.payment as Record<string, unknown> | undefined;
  const orderId = entity?.order_id as string | undefined;
  const paymentId = entity?.id as string | undefined;

  if (!orderId) {
    return { processed: false };
  }

  const intents = await db.queryObject<PaymentIntentRow>(
    `SELECT * FROM payment_intents WHERE gateway_order_id = $1 LIMIT 1`,
    [orderId],
  );
  const intent = intents[0];
  if (!intent) {
    return { processed: false };
  }

  if (eventType === "payment.captured" && paymentId) {
    if (intent.status === "captured") {
      return { processed: true, intentId: intent.id, collectionId: intent.collection_id };
    }

    let collectionId: string | null = null;
    let receiptId: string | null = null;

    if (intent.invoice_id) {
      const collection = await createCollection(
        db,
        intent.organization_id,
        intent.school_id,
        {
          invoiceId: intent.invoice_id,
          amountCollected: intent.amount,
          paymentMethod: intent.payment_method ?? "upi",
          referenceNumber: paymentId,
          notes: "Razorpay webhook capture",
          collectedBy: claims.sub,
        },
      );
      collectionId = collection.collection.id;
      receiptId = collection.receipt.id;
    }

    const captured = await markIntentCaptured(db, intent.id, {
      transactionRef: paymentId,
      gatewayPaymentId: paymentId,
      collectionId: collectionId ?? undefined,
      receiptId: receiptId ?? undefined,
    });

    await recordMutationAudit(
      db,
      claims,
      {
        eventType: "paymentCaptured",
        category: "workflow",
        entityType: "payment_intent",
        entityId: captured.id,
        metadata: {
          transactionRef: paymentId,
          collectionId,
          invoiceId: captured.invoice_id,
          amount: captured.amount,
          source: "webhook",
          eventId,
        },
        correlationId: req ? correlationIdFromRequest(req) : undefined,
      },
      {
        eventType: "payment.captured",
        payload: {
          intentId: captured.id,
          collectionId,
          invoiceId: captured.invoice_id,
          amount: captured.amount,
          webhookEventId: eventId,
        },
        sourceModule: "payment",
        idempotencyKey: `payment.captured.webhook:${eventId}`,
      },
      req,
    );

    return { processed: true, intentId: intent.id, collectionId };
  }

  if (eventType === "payment.failed") {
    // GUARDED terminal write. Razorpay does not guarantee webhook ordering, and
    // a single order can produce a `payment.failed` for one attempt and a
    // `payment.captured` for the retry. An unguarded write here let a late
    // failure demote an intent whose money HAD been captured — leaving a
    // 'failed' intent alongside a real collection and a credited invoice, so
    // the parent sees "payment failed" for money the school actually took.
    //
    // Money-terminal states ('captured', 'settled') are never walked back by a
    // failure event. The capture path is already guarded the same way
    // (`markPaymentIntentCaptured`); this closes the asymmetry.
    const failed = await db.queryObject<{ id: string }>(
      `UPDATE payment_intents SET status = 'failed', updated_at = timezone('utc', now())
       WHERE id = $1 AND status NOT IN ('captured', 'settled')
       RETURNING id`,
      [intent.id],
    );
    // Zero rows means the intent is money-terminal. Deliberately NOT an error:
    // throwing would make the gateway redeliver this event forever. It is
    // correctly processed — the correct action was to ignore it.
    return {
      processed: true,
      intentId: intent.id,
      collectionId: failed.length === 0 ? intent.collection_id : undefined,
    };
  }

  return { processed: true, intentId: intent.id };
}
