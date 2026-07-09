// Gap-remediation #6 — pure validation helpers for the dismiss/complete route
// contract (no DB required; the DB-touching persistence/filter logic is
// covered by the route-contract test's 503-passthrough + the live cert).

import { assertEquals } from "jsr:@std/assert@1";
import {
  isKnownOperationsActionId,
  isKnownOperationsAlertId,
  KNOWN_OPERATIONS_ACTION_IDS,
  KNOWN_OPERATIONS_ALERT_IDS,
} from "./operations_hub_service.ts";

Deno.test("isKnownOperationsAlertId accepts every id buildOperationsHub can emit", () => {
  for (const id of KNOWN_OPERATIONS_ALERT_IDS) {
    assertEquals(isKnownOperationsAlertId(id), true);
  }
});

Deno.test("isKnownOperationsAlertId rejects an unrecognised / tampered id", () => {
  assertEquals(isKnownOperationsAlertId("not-a-real-alert"), false);
  assertEquals(isKnownOperationsAlertId(""), false);
  // An action id is not a valid alert id (collections are distinct).
  assertEquals(isKnownOperationsAlertId("inv-pending"), false);
});

Deno.test("isKnownOperationsActionId accepts every id buildOperationsHub can emit", () => {
  for (const id of KNOWN_OPERATIONS_ACTION_IDS) {
    assertEquals(isKnownOperationsActionId(id), true);
  }
});

Deno.test("isKnownOperationsActionId rejects an unrecognised / tampered id", () => {
  assertEquals(isKnownOperationsActionId("not-a-real-action"), false);
  // An alert id is not a valid action id (collections are distinct).
  assertEquals(isKnownOperationsActionId("student-risk"), false);
});
