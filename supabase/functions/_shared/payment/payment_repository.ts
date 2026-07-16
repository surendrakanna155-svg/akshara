import type { TenantQueryClient } from "../tenant_db.ts";

export const PAYMENT_INTENT_PROBE_SCHOOL_A = "d0000000-0000-4000-8000-000000000001";
export const PAYMENT_INTENT_PROBE_SCHOOL_B = "d0000000-0000-4000-8000-000000000002";

export const PAYMENT_WEBHOOK_PROBE_SCHOOL_A = "d0300000-0000-4000-8000-000000000001";
export const PAYMENT_WEBHOOK_PROBE_SCHOOL_B = "d0300000-0000-4000-8000-000000000002";

export const PAYMENT_INTENT_PROBE_DETAIL_SQL = `
  SELECT count(*)::text AS count
  FROM payment_intents
  WHERE id = $1::uuid
`;

export const PAYMENT_WEBHOOK_PROBE_DETAIL_SQL = `
  SELECT count(*)::text AS count
  FROM payment_webhook_events
  WHERE id = $1
`;

export interface PaymentRequestRow {
  id: string;
  organization_id: string;
  school_id: string;
  student_id: string;
  payer_user_id: string;
  source_type: string;
  source_id: string;
  invoice_id: string | null;
  amount: number;
  currency: string;
  status: string;
  idempotency_key: string | null;
}

export interface PaymentIntentRow {
  id: string;
  organization_id: string;
  school_id: string;
  request_id: string;
  payer_user_id: string;
  gateway: string;
  gateway_order_id: string | null;
  gateway_payment_id: string | null;
  status: string;
  amount: number;
  payment_method: string | null;
  invoice_id: string | null;
  collection_id: string | null;
  receipt_id: string | null;
  refund_id: string | null;
  idempotency_key: string | null;
  transaction_ref: string | null;
  metadata: Record<string, unknown>;
  expires_at: string | null;
}

export class PaymentIntentNotFoundError extends Error {
  constructor(id: string) {
    super(`Payment intent not found: ${id}`);
    this.name = "PaymentIntentNotFoundError";
  }
}

export class PaymentIntentStateError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "PaymentIntentStateError";
  }
}

export async function findIntentByIdempotencyKey(
  db: TenantQueryClient,
  organizationId: string,
  idempotencyKey: string,
): Promise<PaymentIntentRow | null> {
  const rows = await db.queryObject<PaymentIntentRow>(
    `SELECT *
     FROM payment_intents
     WHERE organization_id = $1
       AND idempotency_key = $2`,
    [organizationId, idempotencyKey],
  );
  return rows[0] ?? null;
}

export async function getPaymentIntent(
  db: TenantQueryClient,
  organizationId: string,
  intentId: string,
): Promise<PaymentIntentRow> {
  const rows = await db.queryObject<PaymentIntentRow>(
    `SELECT *
     FROM payment_intents
     WHERE organization_id = $1
       AND id = $2`,
    [organizationId, intentId],
  );
  const row = rows[0];
  if (!row) {
    throw new PaymentIntentNotFoundError(intentId);
  }
  return row;
}

export async function upsertPaymentRequest(
  db: TenantQueryClient,
  input: {
    organizationId: string;
    schoolId: string;
    studentId: string;
    payerUserId: string;
    sourceType: string;
    sourceId: string;
    invoiceId: string | null;
    amount: number;
    idempotencyKey: string | null;
  },
): Promise<PaymentRequestRow> {
  const existing = await db.queryObject<PaymentRequestRow>(
    `SELECT *
     FROM payment_requests
     WHERE organization_id = $1
       AND source_type = $2
       AND source_id = $3
       AND payer_user_id = $4`,
    [input.organizationId, input.sourceType, input.sourceId, input.payerUserId],
  );
  if (existing[0]) {
    return existing[0];
  }

  const rows = await db.queryObject<PaymentRequestRow>(
    `INSERT INTO payment_requests (
       organization_id, school_id, student_id, payer_user_id,
       source_type, source_id, invoice_id, amount, idempotency_key, status
     ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, 'pending')
     RETURNING *`,
    [
      input.organizationId,
      input.schoolId,
      input.studentId,
      input.payerUserId,
      input.sourceType,
      input.sourceId,
      input.invoiceId,
      input.amount,
      input.idempotencyKey,
    ],
  );
  return rows[0]!;
}

export async function createPaymentIntent(
  db: TenantQueryClient,
  input: {
    organizationId: string;
    schoolId: string;
    requestId: string;
    payerUserId: string;
    amount: number;
    paymentMethod: string;
    invoiceId: string | null;
    gatewayOrderId: string;
    idempotencyKey: string | null;
    expiresAt: Date;
  },
): Promise<PaymentIntentRow> {
  const rows = await db.queryObject<PaymentIntentRow>(
    `INSERT INTO payment_intents (
       organization_id, school_id, request_id, payer_user_id,
       amount, payment_method, invoice_id, gateway_order_id,
       status, idempotency_key, expires_at
     ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'initiated', $9, $10)
     RETURNING *`,
    [
      input.organizationId,
      input.schoolId,
      input.requestId,
      input.payerUserId,
      input.amount,
      input.paymentMethod,
      input.invoiceId,
      input.gatewayOrderId,
      input.idempotencyKey,
      input.expiresAt.toISOString(),
    ],
  );
  await db.queryObject(
    `UPDATE payment_requests SET status = 'initiated', updated_at = timezone('utc', now())
     WHERE id = $1`,
    [input.requestId],
  );
  return rows[0]!;
}

export async function markIntentCaptured(
  db: TenantQueryClient,
  intentId: string,
  input: {
    transactionRef: string;
    gatewayPaymentId?: string;
    collectionId?: string;
    receiptId?: string;
  },
): Promise<PaymentIntentRow> {
  const rows = await db.queryObject<PaymentIntentRow>(
    `UPDATE payment_intents
     SET status = 'captured',
         transaction_ref = $2,
         gateway_payment_id = COALESCE($3, gateway_payment_id),
         collection_id = COALESCE($4, collection_id),
         receipt_id = COALESCE($5, receipt_id),
         updated_at = timezone('utc', now())
     WHERE id = $1 AND status <> 'captured'
     RETURNING *`,
    [
      intentId,
      input.transactionRef,
      input.gatewayPaymentId ?? null,
      input.collectionId ?? null,
      input.receiptId ?? null,
    ],
  );
  const row = rows[0];
  if (!row) {
    throw new PaymentIntentNotFoundError(intentId);
  }
  await db.queryObject(
    `UPDATE payment_requests SET status = 'captured', updated_at = timezone('utc', now())
     WHERE id = $1`,
    [row.request_id],
  );
  return row;
}

export async function findPaymentIntentByGatewayOrderId(
  db: TenantQueryClient,
  gatewayOrderId: string,
): Promise<PaymentIntentRow | null> {
  const rows = await db.queryObject<PaymentIntentRow>(
    `SELECT * FROM payment_intents WHERE gateway_order_id = $1 LIMIT 1`,
    [gatewayOrderId],
  );
  return rows[0] ?? null;
}

export async function recordWebhookEvent(
  db: TenantQueryClient,
  eventId: string,
  eventType: string,
  payload: Record<string, unknown>,
  organizationId: string | null,
  schoolId: string | null = null,
): Promise<boolean> {
  // PRC-A Batch 5 — atomic replay guard (owner-idea 25). The old SELECT-then-INSERT
  // was check-then-act: two concurrent deliveries of the SAME webhook could both
  // see zero rows and both proceed to process the event (e.g. credit a payment)
  // twice; and the loser's bare INSERT would raise a PK violation that surfaces as
  // a 500, provoking yet another provider retry. `id` is the primary key, so
  // Postgres already serialises concurrent inserts — `ON CONFLICT DO NOTHING
  // RETURNING id` lets it pick the single winner in ONE statement. A returned row
  // means WE claimed this event first (process it); no row means a concurrent or
  // earlier delivery already claimed it (skip, cleanly, no throw).
  const inserted = await db.queryObject<{ id: string }>(
    `INSERT INTO payment_webhook_events (
       id, organization_id, event_type, payload,
       resolved_organization_id, resolved_school_id
     ) VALUES ($1, $2, $3, $4::jsonb, $5, $6)
     ON CONFLICT (id) DO NOTHING
     RETURNING id`,
    [eventId, organizationId, eventType, JSON.stringify(payload), organizationId, schoolId],
  );
  return inserted.length > 0;
}

export async function findRequestByInstallment(
  db: TenantQueryClient,
  organizationId: string,
  payerUserId: string,
  installmentId: string,
): Promise<PaymentRequestRow | null> {
  const rows = await db.queryObject<PaymentRequestRow>(
    `SELECT *
     FROM payment_requests
     WHERE organization_id = $1
       AND payer_user_id = $2
       AND source_type = 'fee_installment'
       AND source_id = $3`,
    [organizationId, payerUserId, installmentId],
  );
  return rows[0] ?? null;
}
