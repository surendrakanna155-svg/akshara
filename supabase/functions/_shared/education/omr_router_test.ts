// Smart OMR — router tests. Confirms the self-contained matcher owns
// `/education/omr/*` and that the education router DELEGATES to it (so the surface
// goes live through routeEducation with no api/app.ts change).

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { matchOmrRoute } from "./omr_router.ts";
import { matchEducationRoute } from "./education_router.ts";
import {
  handleGetPaperItemAnalysis,
  handleIngestOmrScan,
} from "./omr_handlers.ts";

const PAPER = "a3000000-0000-4000-8000-000000000001";

Deno.test("matchOmrRoute: POST /education/omr/scans → ingest handler", () => {
  const m = matchOmrRoute("POST", "/education/omr/scans");
  assertEquals(m?.handler, handleIngestOmrScan);
  assertEquals(m?.args, []);
});

Deno.test("matchOmrRoute: GET item-analysis with a UUID paper → analysis handler", () => {
  const m = matchOmrRoute(
    "GET",
    `/education/omr/papers/${PAPER}/item-analysis`,
  );
  assertEquals(m?.handler, handleGetPaperItemAnalysis);
  assertEquals(m?.args, [PAPER]);
});

Deno.test("matchOmrRoute: a non-UUID paper id does not match (guards the segment)", () => {
  assertEquals(
    matchOmrRoute("GET", "/education/omr/papers/not-a-uuid/item-analysis"),
    null,
  );
});

Deno.test("matchOmrRoute: wrong method does not match", () => {
  assertEquals(matchOmrRoute("GET", "/education/omr/scans"), null);
  assertEquals(
    matchOmrRoute("POST", `/education/omr/papers/${PAPER}/item-analysis`),
    null,
  );
});

Deno.test("education router DELEGATES the OMR subtree", () => {
  const ingest = matchEducationRoute("POST", "/education/omr/scans");
  assertEquals(ingest?.handler, handleIngestOmrScan);

  const analysis = matchEducationRoute(
    "GET",
    `/education/omr/papers/${PAPER}/item-analysis`,
  );
  assertEquals(analysis?.handler, handleGetPaperItemAnalysis);
});

Deno.test("education router still resolves an existing route (no regression)", () => {
  const bank = matchEducationRoute("GET", "/education/question-bank");
  assertEquals(bank !== null, true);
});
