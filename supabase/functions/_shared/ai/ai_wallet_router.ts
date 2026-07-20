// PRC-A Batch 3 (caps 37–43) — AI credit wallet router. Prefix: /ai-wallet.
//
// Deliberately a small self-contained router mirroring the self-contained
// `_shared/ai/ai_wallet_*` data plane, rather than folding into an unrelated
// module. Both audiences share the base path; the per-route permission differs
// (org-level read vs platform-only grant), gated in the handlers.

import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import {
  handleGetAiWallet,
  handleGrantAiCredits,
} from "./ai_wallet_handlers.ts";

function matchAiWalletRoute(
  method: string,
  path: string,
): { handler: (req: Request, config: AppConfig) => Promise<Response> } | null {
  if (path === "/ai-wallet" && method === "GET") {
    return { handler: handleGetAiWallet };
  }
  if (path === "/ai-wallet/grant" && method === "POST") {
    return { handler: handleGrantAiCredits };
  }
  return null;
}

export async function routeAiWallet(
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
): Promise<Response | null> {
  if (!path.startsWith("/ai-wallet")) return null;

  const match = matchAiWalletRoute(method, path);
  if (!match) {
    return errorEnvelope("NOT_FOUND", `Route not found: ${method} ${path}`, 404);
  }

  return await match.handler(req, config);
}
