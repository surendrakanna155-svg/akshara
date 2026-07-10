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
