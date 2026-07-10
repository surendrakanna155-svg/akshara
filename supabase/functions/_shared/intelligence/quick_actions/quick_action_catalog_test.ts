// Adaptive AI — P3-AI-2 / W2-GATE-2: Quick Action catalog tests (pure, DB-free).

import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { isPersona } from "../priority/priority_types.ts";
import { QUICK_ACTIONS, quickActionsFor } from "./quick_action_catalog.ts";

Deno.test("catalog integrity: ids unique, personas valid, resolvers well-formed", () => {
  const ids = new Set<string>();
  for (const a of QUICK_ACTIONS) {
    assert(!ids.has(a.id), `duplicate id ${a.id}`);
    ids.add(a.id);
    assert(a.personas.length > 0, `${a.id} has no personas`);
    for (const p of a.personas) assert(isPersona(p), `${a.id} bad persona ${p}`);
    if (a.resolver.kind === "copilot") {
      // Generative (t3) actions open the copilot with a prompt (which then passes
      // the Domain Gate + gateway) and must be gated on runAiCopilot.
      assertEquals(a.tier, "t3");
      assert(a.resolver.prompt, `${a.id} copilot resolver needs a prompt`);
      assertEquals(a.requiredPermission, "runAiCopilot");
    } else {
      // Deterministic (t1) actions resolve to an endpoint — zero tokens.
      assertEquals(a.tier, "t1");
      assert(a.resolver.target.startsWith("/"), `${a.id} endpoint must be a path`);
    }
  }
});

Deno.test("quickActionsFor: filters by persona", () => {
  const principal = quickActionsFor("principal", ["viewAnalytics", "viewStudentRisk", "viewFinance"]);
  assert(principal.some((a) => a.id === "principal_today_priorities"));
  assert(!principal.some((a) => a.id === "parent_homework_summary"));
});

Deno.test("quickActionsFor: filters by permission (RBAC inherited from ERP)", () => {
  // Without viewStudentRisk, the high-risk action is hidden even for a principal.
  const noRisk = quickActionsFor("principal", ["viewAnalytics"]);
  assert(!noRisk.some((a) => a.id === "principal_high_risk_students"));
  const withRisk = quickActionsFor("principal", ["viewAnalytics", "viewStudentRisk"]);
  assert(withRisk.some((a) => a.id === "principal_high_risk_students"));
});

Deno.test("quickActionsFor: permissionless actions are always offered to their persona", () => {
  // Parent homework/fee summaries carry no explicit permission (own-children RLS
  // enforces scope at the endpoint) → offered even with an empty permission set.
  const parent = quickActionsFor("parent", []);
  assert(parent.some((a) => a.id === "parent_homework_summary"));
  assert(parent.some((a) => a.id === "parent_fee_reminder_explanation"));
  // …but a t3 copilot action still needs runAiCopilot.
  assert(!parent.some((a) => a.id === "parent_exam_preparation"));
});

Deno.test("most actions are deterministic (t1) — the action-first majority", () => {
  const t1 = QUICK_ACTIONS.filter((a) => a.tier === "t1").length;
  const t3 = QUICK_ACTIONS.filter((a) => a.tier === "t3").length;
  assert(t1 > t3, `expected more deterministic than generative actions (t1=${t1}, t3=${t3})`);
});
