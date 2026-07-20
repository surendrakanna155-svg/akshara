// W4 (Owner decisions #2 + #3) — self-contained router for the HYBRID transport
// fee model. Returns a Response for a matched fee route, or `null` when the path
// is not a fee route (so the parent can fall through to the main transport
// router). The parent mounts this — nothing here touches api/app.ts.
//
// Suggested wiring (one line in the parent transport dispatcher, BEFORE the main
// transport router's NOT_FOUND):
//     const fee = await routeTransportFee(req, config, method, path);
//     if (fee) return fee;

import type { AppConfig } from "../config.ts";
import {
  handleFeePreview,
  handleGetFeeConfig,
  handleGetFeeRate,
  handleGetStudentTransport,
  handlePutFeeConfig,
  handlePutFeeRate,
  handlePutStudentTransport,
} from "./transport_fee_handlers.ts";

/**
 * Route a transport fee-model request. Returns the handler's Response, or null
 * when `path` is not one of the fee routes (caller falls through).
 */
export async function routeTransportFee(
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
): Promise<Response | null> {
  if (!path.startsWith("/transport/")) return null;

  // /transport/fee-config  (GET | PUT)
  if (path === "/transport/fee-config") {
    if (method === "GET") return await handleGetFeeConfig(req, config);
    if (method === "PUT") return await handlePutFeeConfig(req, config);
    return null;
  }

  // /transport/fee-preview  (GET) — compute the payable for one student.
  if (path === "/transport/fee-preview" && method === "GET") {
    return await handleFeePreview(req, config);
  }

  // /transport/fee-rates/{scope}/{entityId}  (GET | PUT)
  const rateMatch = path.match(/^\/transport\/fee-rates\/([^/]+)\/([^/]+)$/);
  if (rateMatch) {
    const scope = decodeURIComponent(rateMatch[1]!);
    const entityId = decodeURIComponent(rateMatch[2]!);
    if (method === "GET") return await handleGetFeeRate(req, config, scope, entityId);
    if (method === "PUT") return await handlePutFeeRate(req, config, scope, entityId);
    return null;
  }

  // /transport/students/{sisStudentId}/transport  (GET | PUT)
  const studentMatch = path.match(/^\/transport\/students\/([^/]+)\/transport$/);
  if (studentMatch) {
    const sisStudentId = decodeURIComponent(studentMatch[1]!);
    if (method === "GET") return await handleGetStudentTransport(req, config, sisStudentId);
    if (method === "PUT") return await handlePutStudentTransport(req, config, sisStudentId);
    return null;
  }

  return null;
}
