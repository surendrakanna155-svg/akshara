// Program D · M0.1 — ERP-side conformance test for the golden certified corpus.
//
// Proves the committed fixture loads from the ERP (Deno) runtime and is well-formed, so every later
// Program-D ERP test (importer, union, solver feed) can rely on it. Run:
//   deno test --allow-env --allow-read supabase/functions/_shared/education/__tests__/fixtures/

import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { certifiedCorpus, type CertifiedFixtureRow } from "./certified_corpus.ts";

Deno.test("certified corpus: 12 deterministic rows", () => {
  assertEquals(certifiedCorpus.length, 12);
});

Deno.test("certified corpus: rows are well-formed QIE-native certified items", () => {
  for (const r of certifiedCorpus) {
    assertEquals(r.question_type, "MCQ");
    assert(["easy", "moderate", "hard"].includes(r.intended_difficulty));
    assert(["remember", "understand", "apply", "analyze", "hots"].includes(r.bloom));
    assert(r.concept_code.startsWith("KC_"));
    assertEquals(r.concept_code.length, 3 + 14);
    assertEquals(r.certification_class, "certified");
    // options: 4 labels, answer_value agrees with the chosen option.
    assertEquals(Object.keys(r.options).sort().join(""), "ABCD");
    assert(r.answer_label in r.options);
    assertEquals(r.options[r.answer_label], r.answer_value);
    assert(r.item_hash.startsWith("IH_"));
    assert(r.stem_norm_hash.startsWith("NH_"));
    assert(r.marks > 0);
  }
});

Deno.test("certified corpus: content identity is unique per item", () => {
  const ih = new Set(certifiedCorpus.map((r: CertifiedFixtureRow) => r.item_hash));
  const nh = new Set(certifiedCorpus.map((r: CertifiedFixtureRow) => r.stem_norm_hash));
  assertEquals(ih.size, certifiedCorpus.length);
  assertEquals(nh.size, certifiedCorpus.length);
});
