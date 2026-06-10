import type { AccessTokenClaims } from "../jwt.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import { correlationIdFromRequest, recordMutationAudit } from "../audit/audit_repository.ts";
import { createCollection } from "../finance/finance_collections_repository.ts";
import { loadRazorpayConfig } from "./razorpay_config.ts";
import {
  createRazorpayOrder,
  verifyRazorpayPaymentSignature,
} from "./razorpay_client.ts";
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

  const razorpay = loadRazorpayConfig();
  const orgId = claims.tenant_id;
  const schoolId = claims.school_id;
  const studentId = requireParentChild(claims);

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
        razorpayKeyId: razorpay.keyId,
      };
    }
  }

  const seeded = await findRequestByInstallment(db, orgId, claims.sub, input.installmentId);
  const request = seeded ?? await upsertPaymentRequest(db, {
    organizationId: orgId,
    schoolId,
    studentId,
    payerUserId: claims.sub,
    sourceType: "fee_installment",
    sourceId: input.installmentId,
    invoiceId: null,
    amount: input.amount,
    idempotencyKey: input.idempotencyKey,
  });

  const order = await createRazorpayOrder(razorpay, {
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
    razorpayKeyId: razorpay.keyId,
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

  const razorpay = loadRazorpayConfig();
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

  if (!razorpay.stubMode && input.razorpayPaymentId && input.razorpaySignature && intent.gateway_order_id) {
    const valid = await verifyRazorpayPaymentSignature(
      razorpay,
      intent.gateway_order_id,
      input.razorpayPaymentId,
      input.razorpaySignature,
    );
    if (!valid) {
      throw new PaymentIntentStateError("Invalid Razorpay payment signature");
    }
  }

  let collectionId: string | null = null;
  let receiptId: string | null = null;
  let receiptNumber = `APS-${new Date().getFullYear()}-${intent.id.slice(0, 8).toUpperCase()}`;

  if (intent.invoice_id) {
    const collection = await createCollection(db, orgId, schoolId, {
      invoiceId: intent.invoice_id,
      amountCollected: intent.amount,
      paymentMethod: intent.payment_method ?? "upi",
      referenceNumber: input.transactionRef,
      notes: "Universal Payment Engine capture",
      collectedBy: claims.sub,
    });
    collectionId = collection.collection.id;
    receiptId = collection.receipt.id;
    receiptNumber = collection.receipt.receipt_number;
  }

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
    await db.queryObject(
      `UPDATE payment_intents SET status = 'failed', updated_at = timezone('utc', now()) WHERE id = $1`,
      [intent.id],
    );
    return { processed: true, intentId: intent.id };
  }

  return { processed: true, intentId: intent.id };
}
