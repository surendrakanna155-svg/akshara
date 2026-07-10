// Adaptive AI — P3-AI-2 / W2.0b: Persona Memory learning tests (pure, DB-free).

import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  applyFeedback,
  deriveLearnedWeights,
  dismissedKeysOf,
  emptyPersonaMemory,
} from "./ai_persona_memory_repository.ts";

Deno.test("applyFeedback: accept tallies the type and does not hide the item", () => {
  const m = applyFeedback(emptyPersonaMemory(), {
    itemKey: "k1",
    itemType: "exception",
    action: "accept",
  });
  assertEquals(m.recommendationFeedback.exception, { accepted: 1, dismissed: 0, suppressed: 0 });
  assert(!dismissedKeysOf(m).has("k1"));
});

Deno.test("applyFeedback: dismiss tallies and hides the item", () => {
  const m = applyFeedback(emptyPersonaMemory(), {
    itemKey: "k2",
    itemType: "follow_up",
    action: "dismiss",
  });
  assertEquals(m.recommendationFeedback.follow_up, { accepted: 0, dismissed: 1, suppressed: 0 });
  assert(dismissedKeysOf(m).has("k2"));
});

Deno.test("applyFeedback: suppress tallies heavily and hides the item", () => {
  const m = applyFeedback(emptyPersonaMemory(), {
    itemKey: "k3",
    itemType: "deadline",
    action: "suppress",
  });
  assertEquals(m.recommendationFeedback.deadline, { accepted: 0, dismissed: 0, suppressed: 1 });
  assert(dismissedKeysOf(m).has("k3"));
});

Deno.test("applyFeedback: accepting a previously dismissed item un-hides it", () => {
  let m = applyFeedback(emptyPersonaMemory(), {
    itemKey: "k1",
    itemType: "exception",
    action: "dismiss",
  });
  assert(dismissedKeysOf(m).has("k1"));
  m = applyFeedback(m, { itemKey: "k1", itemType: "exception", action: "accept" });
  assert(!dismissedKeysOf(m).has("k1"));
});

Deno.test("applyFeedback: is pure (does not mutate the input memory)", () => {
  const base = emptyPersonaMemory();
  applyFeedback(base, { itemKey: "k", itemType: "exception", action: "dismiss" });
  assertEquals(base.recommendationFeedback, {});
  assertEquals(base.preferences, {});
});

Deno.test("deriveLearnedWeights: net = accepted − dismissed − 2·suppressed, clamped", () => {
  const accepts = { recommendationFeedback: { exception: { accepted: 3, dismissed: 0, suppressed: 0 } } };
  assertEquals(deriveLearnedWeights({ ...emptyPersonaMemory(), ...accepts }).exception, 1.3);

  const dismiss = { recommendationFeedback: { follow_up: { accepted: 0, dismissed: 1, suppressed: 0 } } };
  assertEquals(deriveLearnedWeights({ ...emptyPersonaMemory(), ...dismiss }).follow_up, 0.9);

  const suppress = { recommendationFeedback: { deadline: { accepted: 0, dismissed: 0, suppressed: 1 } } };
  assertEquals(deriveLearnedWeights({ ...emptyPersonaMemory(), ...suppress }).deadline, 0.8);
});

Deno.test("deriveLearnedWeights: clamps to [0.5, 2.0] and omits neutral weights", () => {
  const heavySuppress = {
    recommendationFeedback: { exception: { accepted: 0, dismissed: 0, suppressed: 9 } },
  };
  assertEquals(deriveLearnedWeights({ ...emptyPersonaMemory(), ...heavySuppress }).exception, 0.5);

  const heavyAccept = {
    recommendationFeedback: { deadline: { accepted: 20, dismissed: 0, suppressed: 0 } },
  };
  assertEquals(deriveLearnedWeights({ ...emptyPersonaMemory(), ...heavyAccept }).deadline, 2.0);

  // A perfectly balanced type nets to the neutral default and is omitted.
  const balanced = {
    recommendationFeedback: { approval: { accepted: 2, dismissed: 2, suppressed: 0 } },
  };
  assertEquals(deriveLearnedWeights({ ...emptyPersonaMemory(), ...balanced }).approval, undefined);
});
