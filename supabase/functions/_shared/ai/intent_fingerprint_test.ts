import { assert, assertEquals } from "jsr:@std/assert@1";
import { fingerprintQuestion } from "./intent_fingerprint.ts";

Deno.test("fingerprintQuestion collapses paraphrases of the same question", () => {
  const a = fingerprintQuestion("When is Aarav's fee due?");
  const b = fingerprintQuestion("fee due for Aarav??");
  const c = fingerprintQuestion("AARAV  fee — due  when");
  assertEquals(a, b);
  assertEquals(a, c);
  assertEquals(a, "aarav due fee"); // sorted, de-stopworded, de-duped
});

Deno.test("fingerprintQuestion distinguishes genuinely different questions", () => {
  assert(
    fingerprintQuestion("how many students are at risk") !==
      fingerprintQuestion("when is the fee due"),
  );
});

Deno.test("fingerprintQuestion is idempotent and folds all-stopword/empty input", () => {
  const once = fingerprintQuestion("please show me the overdue fees");
  assertEquals(fingerprintQuestion(once), once);
  assertEquals(once, "fees overdue");
  assertEquals(fingerprintQuestion(""), "");
  assertEquals(fingerprintQuestion("the is of a for"), "");
});

// audit F1 — relational/comparative operand order must NOT collide.
Deno.test("fingerprintQuestion distinguishes reversed comparisons (F1)", () => {
  assert(
    fingerprintQuestion("Is class 5 bigger than class 6?") !==
      fingerprintQuestion("Is class 6 bigger than class 5?"),
  );
  assert(
    fingerprintQuestion("Is Aarav absent more than Priya?") !==
      fingerprintQuestion("Is Priya absent more than Aarav?"),
  );
});

Deno.test("fingerprintQuestion distinguishes reversed transitive relations (F1)", () => {
  assert(
    fingerprintQuestion("Did the vendor pay the school?") !==
      fingerprintQuestion("Did the school pay the vendor?"),
  );
});

// F1 fix must not regress the paraphrase-collapse win for non-relational lookups.
Deno.test("fingerprintQuestion still collapses non-relational paraphrases after F1", () => {
  assertEquals(
    fingerprintQuestion("When is Aarav's fee due?"),
    fingerprintQuestion("fee due for Aarav"),
  );
  // A relational question stays order-sensitive and idempotent.
  const rel = fingerprintQuestion("Is class 5 bigger than class 6?");
  assertEquals(fingerprintQuestion(rel), rel);
});

// H2 — transitive relations beyond the comparison set, incl. name-vs-name via
// the 2-entity structural rule (no listed verb needed).
Deno.test("fingerprintQuestion distinguishes reversed transitive-verb relations (H2)", () => {
  assert(
    fingerprintQuestion("Did the principal approve the teacher's leave?") !==
      fingerprintQuestion("Did the teacher approve the principal's leave?"),
  );
});

Deno.test("fingerprintQuestion distinguishes two named entities by order (H2)", () => {
  // "manage" + two proper nouns → order preserved either way.
  assert(
    fingerprintQuestion("Does Ms. Iyer manage Mr. Rao?") !==
      fingerprintQuestion("Does Mr. Rao manage Ms. Iyer?"),
  );
  // A single named entity still collapses (paraphrase win intact).
  assertEquals(
    fingerprintQuestion("Aarav's attendance this week"),
    fingerprintQuestion("attendance this week for Aarav"),
  );
});
