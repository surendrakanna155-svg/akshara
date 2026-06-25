import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import {
  handleAdmissionConversion,
  handleFeeDefault,
  handleStudentRisk,
} from "./predictions_handlers.ts";

const GET_ROUTES: Record<string, (req: Request, config: AppConfig) => Promise<Response>> = {
  "/predictions/fee-default": handleFeeDefault,
  "/predictions/admission-conversion": handleAdmissionConversion,
  "/predictions/student-risk": handleStudentRisk,
};

export async function routePredictions(
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
): Promise<Response | null> {
  if (!path.startsWith("/predictions")) return null;

  if (method === "GET") {
    const handler = GET_ROUTES[path];
    return handler ? await handler(req, config) : null;
  }
  return errorEnvelope("NOT_FOUND", `Route not found: ${method} ${path}`, 404);
}
