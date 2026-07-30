// EIP-6 Learning Evidence spine — self-contained router.
//
// Owns the `/education/evidence/*` surface. `matchLearningEvidenceRoute` is
// delegated to from `matchEducationRoute` so these routes go live through the
// already-wired `routeEducation` entry — NO change to api/app.ts. A standalone
// `routeLearningEvidence` is also exported so the surface can be mounted on its
// own if ever split out.

import type { AppConfig } from "../config.ts";
import { errorEnvelope } from "../http.ts";
import {
  handleItemResponseAggregate,
  handleListStudentResponses,
  handleRecordItemResponse,
  handleStudentConceptMastery,
} from "./learning_evidence_handlers.ts";

const UUID_SEGMENT =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function matchLearningEvidenceRoute(
  method: string,
  path: string,
): {
  handler: (req: Request, config: AppConfig, ...args: string[]) => Promise<Response>;
  args: string[];
} | null {
  // POST /education/evidence/responses — record one item interaction.
  if (path === "/education/evidence/responses" && method === "POST") {
    return { handler: handleRecordItemResponse, args: [] };
  }

  // GET /education/evidence/students/:studentId/responses — per-student history.
  const historyMatch = path.match(
    /^\/education\/evidence\/students\/([^/]+)\/responses$/,
  );
  if (historyMatch && method === "GET" && UUID_SEGMENT.test(historyMatch[1]!)) {
    return { handler: handleListStudentResponses, args: [historyMatch[1]!] };
  }

  // GET /education/evidence/students/:studentId/concept-mastery — EIP-7/W5 seed.
  const masteryMatch = path.match(
    /^\/education\/evidence\/students\/([^/]+)\/concept-mastery$/,
  );
  if (masteryMatch && method === "GET" && UUID_SEGMENT.test(masteryMatch[1]!)) {
    return { handler: handleStudentConceptMastery, args: [masteryMatch[1]!] };
  }

  // GET /education/evidence/items/:itemId/aggregate — per-item item-analysis.
  const aggregateMatch = path.match(
    /^\/education\/evidence\/items\/([^/]+)\/aggregate$/,
  );
  if (aggregateMatch && method === "GET" && UUID_SEGMENT.test(aggregateMatch[1]!)) {
    return { handler: handleItemResponseAggregate, args: [aggregateMatch[1]!] };
  }

  return null;
}

export async function routeLearningEvidence(
  req: Request,
  config: AppConfig,
  method: string,
  path: string,
): Promise<Response | null> {
  const match = matchLearningEvidenceRoute(method, path);
  if (!match) return null;

  try {
    return await match.handler(req, config, ...match.args);
  } catch (error) {
    const message = error instanceof Error
      ? error.message
      : "Learning-evidence route failed";
    return errorEnvelope("LEARNING_EVIDENCE_ROUTE_ERROR", message, 500);
  }
}
