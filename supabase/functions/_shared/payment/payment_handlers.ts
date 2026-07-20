import type { AppConfig } from "../config.ts";
import { envelope, errorEnvelope, jsonResponse, readJson } from "../http.ts";
import {
  authenticateRequest,
  organizationIdFromClaims,
} from "../permission_middleware.ts";
import { createServiceClient } from "../db.ts";
import { TenantDbNotConfiguredError, withTenantContext } from "../tenant_db.ts";
import { tenantDbNotConfiguredResponse } from "../tenant_handlers.ts";
import { getPaymentProvider } from "./payment_provider_registry.ts";
import { RAZORPAY_PROVIDER_ID } from "./razorpay_provider.ts";
import {
  getPaymentIntent,
  PaymentIntentNotFoundError,
  PaymentIntentStateError,
  recordWebhookEvent,
} from "./payment_repository.ts";
import {
  confirmPayment,
  initiatePayment,
  processRazorpayWebhook,
} from "./payment_service.ts";

function idempotencyKey(req: Request): string | null {
  return req.headers.get("Idempotency-Key") ?? req.headers.get("idempotency-key");
}

/**
 * RT-19 — payment intents are created/confirmed only under parent scope (the
 * payer), with a school context. The `payment_intents` RLS already pins writes
 * to `payer_user_id = app_current_user_id()` under `parent` scope (and school
 * scope is read-only), so this is the matching authorization gate that turns a
 * wrong-scope caller into a clean 403 instead of relying on RLS alone.
 */
function requirePaymentWriteScope(
  claims: { scope: string; school_id: string | null },
): Response | null {
  if (claims.scope !== "parent" || !claims.school_id) {
    return errorEnvelope(
      "FORBIDDEN",
      "Payment initiation requires parent scope",
      403,
    );
  }
  return null;
}

function snakeStr(body: Record<string, unknown>, key: string): string {
  return String(body[key] ?? "");
}

function optionalSnakeStr(body: Record<string, unknown>, key: string): string | undefined {
  const value = body[key];
  return value == null ? undefined : String(value);
}

export async function handleInitiatePayment(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const scopeDenied = requirePaymentWriteScope(auth.claims);
  if (scopeDenied) return scopeDenied;

  const body = await readJson<Record<string, unknown>>(req);
  if (!body) {
    return errorEnvelope("VALIDATION_ERROR", "Invalid JSON body", 422);
  }

  try {
    const result = await withTenantContext(config, auth.claims, async (db) =>
      await initiatePayment(
        db,
        auth.claims,
        {
          installmentId: snakeStr(body, "installment_id"),
          paymentMethod: snakeStr(body, "payment_method") || "upi",
          amount: Number(body.amount ?? 0),
          idempotencyKey: idempotencyKey(req),
        },
        req,
      )
    );
    return jsonResponse(envelope(result), { status: 201 });
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    if (error instanceof PaymentIntentStateError) {
      return errorEnvelope("VALIDATION_ERROR", error.message, 422);
    }
    console.error("initiate payment error:", error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to initiate payment", 500);
  }
}

export async function handleConfirmPayment(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  const scopeDenied = requirePaymentWriteScope(auth.claims);
  if (scopeDenied) return scopeDenied;

  const body = await readJson<Record<string, unknown>>(req);
  if (!body) {
    return errorEnvelope("VALIDATION_ERROR", "Invalid JSON body", 422);
  }

  try {
    const result = await withTenantContext(config, auth.claims, async (db) =>
      await confirmPayment(
        db,
        auth.claims,
        {
          paymentIntentId: snakeStr(body, "payment_intent_id"),
          transactionRef: snakeStr(body, "transaction_ref"),
          razorpayPaymentId: optionalSnakeStr(body, "razorpay_payment_id"),
          razorpaySignature: optionalSnakeStr(body, "razorpay_signature"),
        },
        req,
      )
    );
    return jsonResponse(envelope(result));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    if (error instanceof PaymentIntentNotFoundError) {
      return errorEnvelope("NOT_FOUND", error.message, 404);
    }
    if (error instanceof PaymentIntentStateError) {
      return errorEnvelope("VALIDATION_ERROR", error.message, 422);
    }
    console.error("confirm payment error:", error);
    return errorEnvelope("INTERNAL_ERROR", "Failed to confirm payment", 500);
  }
}

export async function handleGetPaymentIntent(
  req: Request,
  config: AppConfig,
  intentId: string,
): Promise<Response> {
  const auth = await authenticateRequest(req, config);
  if (!auth.ok) return auth.response;

  if (auth.claims.scope !== "parent" && auth.claims.scope !== "school") {
    return errorEnvelope("FORBIDDEN", "Payment intent access denied", 403);
  }

  const orgId = organizationIdFromClaims(auth.claims);

  try {
    const intent = await withTenantContext(config, auth.claims, async (db) =>
      await getPaymentIntent(db, orgId, intentId)
    );
    if (auth.claims.scope === "parent" && intent.payer_user_id !== auth.claims.sub) {
      return errorEnvelope("FORBIDDEN", "Payment intent access denied", 403);
    }
    return jsonResponse(envelope({
      paymentIntentId: intent.id,
      status: intent.status,
      amount: intent.amount,
      installmentId: null,
      gatewayOrderId: intent.gateway_order_id,
      collectionId: intent.collection_id,
      invoiceId: intent.invoice_id,
      refundId: intent.refund_id,
    }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    if (error instanceof PaymentIntentNotFoundError) {
      return errorEnvelope("NOT_FOUND", error.message, 404);
    }
    return errorEnvelope("INTERNAL_ERROR", "Failed to load payment intent", 500);
  }
}

export async function handleRazorpayWebhook(
  req: Request,
  config: AppConfig,
): Promise<Response> {
  const rawBody = await req.text();
  let payload: Record<string, unknown>;
  try {
    payload = JSON.parse(rawBody) as Record<string, unknown>;
  } catch {
    return errorEnvelope("VALIDATION_ERROR", "Invalid webhook JSON", 422);
  }

  // The /webhooks/razorpay route is Razorpay's own callback, so resolve the
  // Razorpay provider from the registry (rather than importing the client
  // directly) and verify the inbound signature through the same seam every other
  // gateway would use. A second gateway with webhooks would add its own
  // /webhooks/<gateway> route + handler.
  const razorpayProvider = getPaymentProvider(RAZORPAY_PROVIDER_ID);
  const signature = req.headers.get("X-Razorpay-Signature");
  const valid = await razorpayProvider.verifyWebhookSignature(rawBody, signature);
  // RT-23 — fail-closed on the signature. Previously a forged webhook was
  // accepted whenever `stubMode` was on (the default, and live on the pilot),
  // which would let anyone forge payment events the moment real credentials
  // were added. Signature enforcement is now decoupled from stubMode: an
  // invalid/forged signature is always rejected unless an operator has
  // *explicitly* opted into unsigned webhooks for local development.
  const allowUnsigned =
    (Deno.env.get("RAZORPAY_ALLOW_UNSIGNED") ?? "false").toLowerCase() === "true";
  if (!valid && !allowUnsigned) {
    return errorEnvelope("FORBIDDEN", "Invalid Razorpay webhook signature", 403);
  }

  const eventId = String(payload.id ?? `evt_${crypto.randomUUID()}`);
  const eventType = String(payload.event ?? "unknown");

  const paymentEntity = payload.payload as Record<string, unknown> | undefined;
  const entity = paymentEntity?.payment as Record<string, unknown> | undefined;
  const orderId = entity?.order_id as string | undefined;

  try {
    const serviceClient = createServiceClient(config);
    let tenantClaims: Parameters<typeof withTenantContext>[1];

    if (orderId) {
      const intentLookup = await serviceClient
        .from("payment_intents")
        .select("organization_id,school_id,payer_user_id")
        .eq("gateway_order_id", orderId)
        .maybeSingle();
      const intent = intentLookup.data;
      if (!intent?.organization_id || !intent?.school_id) {
        return errorEnvelope("NOT_FOUND", "Payment intent not found for webhook order", 404);
      }
      tenantClaims = {
        sub: intent.payer_user_id as string,
        tenant_id: intent.organization_id as string,
        organization_id: intent.organization_id as string,
        school_id: intent.school_id as string,
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
    } else if (!razorpayProvider.requiresGatewaySignature()) {
      // Stub mode (no live Razorpay credentials): an order-less stub webhook is
      // attributed to the seed tenant. requiresGatewaySignature()===false is the
      // provider's stub signal (was `razorpay.stubMode`).
      tenantClaims = {
        sub: "00000000-0000-4000-8000-000000000000",
        tenant_id: "a1000000-0000-4000-8000-000000000001",
        organization_id: "a1000000-0000-4000-8000-000000000001",
        school_id: "a2000000-0000-4000-8000-000000000001",
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
    } else {
      return errorEnvelope("VALIDATION_ERROR", "Webhook missing order_id for tenant resolution", 422);
    }

    const result = await withTenantContext(config, tenantClaims, async (db) => {
      const isNew = await recordWebhookEvent(
        db,
        eventId,
        eventType,
        payload,
        tenantClaims.organization_id,
        tenantClaims.school_id,
      );
      if (!isNew) {
        return { duplicate: true };
      }
      return await processRazorpayWebhook(db, tenantClaims, eventId, eventType, payload, req);
    });

    return jsonResponse(envelope({
      accepted: true,
      duplicate: "duplicate" in result && result.duplicate === true,
      intentId: "intentId" in result ? result.intentId : null,
    }));
  } catch (error) {
    if (error instanceof TenantDbNotConfiguredError) {
      return tenantDbNotConfiguredResponse(error);
    }
    console.error("razorpay webhook error:", error);
    return errorEnvelope("INTERNAL_ERROR", "Webhook processing failed", 500);
  }
}
