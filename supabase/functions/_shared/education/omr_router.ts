// Smart OMR — self-contained router.
//
// Owns the `/education/omr/*` surface. `matchOmrRoute` is delegated to from
// `matchEducationRoute` so these routes go live through the already-wired
// `routeEducation` entry — NO change to api/app.ts. A standalone `routeOmr` is
// also exported so the surface can be mounted on its own if ever split out.

import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import {
  handleGetPaperItemAnalysis,
  handleIngestOmrScan,
} from "./omr_handlers.ts";

const UUID_SEGMENT =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function matchOmrRoute(
  method: string,
  path: string,
): {
  handler: (
    req: Request,
    config: AppConfig,
    ...args: string[]
  ) => Promise<Response>;
  args: string[];
} | null {
  // POST /education/omr/scans — ingest + score a scanned OMR sheet.
  if (path === "/education/omr/scans" && method === "POST") {
    return { handler: handleIngestOmrScan, args: [] };
  }

  // GET /education/omr/papers/:paperId/item-analysis — per-item difficulty/heatmap.
  const analysisMatch = path.match(
    /^\/education\/omr\/papers\/([^/]+)\/item-analysis$/,
  );
  if (
    analysisMatch && method === "GET" && UUID_SEGMENT.test(analysisMatch[1]!)
  ) {
    return { handler: handleGetPaperItemAnalysis, args: [analysisMatch[1]!] };
  }

  return null;
}

export async function routeOmr(
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
): Promise<Response | null> {
  const match = matchOmrRoute(method, path);
  if (!match) return null;

  try {
    return await match.handler(req, config, ...match.args);
  } catch (error) {
    const message = error instanceof Error ? error.message : "OMR route failed";
    return errorEnvelope("OMR_ROUTE_ERROR", message, 500);
  }
}
