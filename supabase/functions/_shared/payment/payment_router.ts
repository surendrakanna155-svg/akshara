import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import {
  handleConfirmPayment,
  handleGetPaymentIntent,
  handleInitiatePayment,
  handleRazorpayWebhook,
} from "./payment_handlers.ts";

function matchPaymentRoute(
  method: string,
  path: string,
): { handler: (req: Request, config: AppConfig) => Promise<Response> } | null {
  if (method === "POST" && path === "/payments/intents/initiate") {
    return { handler: handleInitiatePayment };
  }
  if (method === "POST" && path === "/payments/intents/confirm") {
    return { handler: handleConfirmPayment };
  }
  if (method === "POST" && path === "/webhooks/razorpay") {
    return { handler: handleRazorpayWebhook };
  }

  const intentMatch = path.match(/^\/payments\/intents\/([^/]+)$/);
  if (method === "GET" && intentMatch) {
    const intentId = decodeURIComponent(intentMatch[1]);
    return {
      handler: (req, config) => handleGetPaymentIntent(req, config, intentId),
    };
  }

  return null;
}

export async function routePayment(
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
): Promise<Response | null> {
  if (!path.startsWith("/payments") && !path.startsWith("/webhooks/razorpay")) {
    return null;
  }

  const match = matchPaymentRoute(method, path);
  if (!match) {
    return errorEnvelope("NOT_FOUND", `Route not found: ${method} ${path}`, 404);
  }

  return await match.handler(req, config);
}
