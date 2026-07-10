// Adaptive AI — P3-AI-2 / W2-GATE: school-only Domain Gate tests (pure, DB-free).

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { classifyDomain } from "./domain_gate.ts";

Deno.test("in-domain: clear school questions pass", () => {
  const inDomain = [
    "who is absent today in 6-B?",
    "show me the fee defaulters",
    "unit 2 maths marks are pending",
    "summarize homework for class 7",
    "which students are at risk",
    "when is the next PTM",
    "bus route 12 timetable",
    "library overdue books",
  ];
  for (const q of inDomain) {
    assertEquals(classifyDomain(q).inDomain, true, `expected in-domain: "${q}"`);
  }
});

Deno.test("tie-break: a school signal wins even when a block word appears", () => {
  // "sports"/"movie"/"medical"/"cooking" are off-domain words, but each of these
  // carries a strong school signal → must stay in-domain (doc 10 §3).
  const ties = [
    "mark attendance for sports day",
    "movie permission slip for the class trip",
    "process the medical leave application for a teacher",
    "cooking competition event for students",
    "science film screening notice for parents",
  ];
  for (const q of ties) {
    assertEquals(classifyDomain(q).inDomain, true, `expected in-domain (tie): "${q}"`);
    assertEquals(classifyDomain(q).reason, "school_signal");
  }
});

Deno.test("off-domain: non-school requests are refused with zero tokens", () => {
  const offDomain = [
    "who won the cricket match yesterday",
    "write python code to sort a list",
    "best recipe for biryani",
    "book me a flight to delhi",
    "who is the prime minister",
    "translate hello into spanish",
    "write me a poem about love",
    "what is the capital of france",
    "latest bollywood movie reviews",
    "should I take this medicine for a headache",
  ];
  for (const q of offDomain) {
    assertEquals(classifyDomain(q).inDomain, false, `expected off-domain: "${q}"`);
    assertEquals(classifyDomain(q).reason, "off_domain");
  }
});

Deno.test("ambiguous no-signal messages are allowed through (bounded downstream)", () => {
  const ambiguous = ["summarize this", "what should I do next", "give me an overview"];
  for (const q of ambiguous) {
    const v = classifyDomain(q);
    assertEquals(v.inDomain, true, `expected allowed: "${q}"`);
    assertEquals(v.reason, "ambiguous_allowed");
  }
});

Deno.test("word-boundary matching avoids false school signals", () => {
  // "classical" must NOT trip the "class" school term (else it'd read as a
  // school signal); with no block term it lands in ambiguous_allowed, not school.
  assertEquals(classifyDomain("recommend some classical music").reason, "ambiguous_allowed");
  // "example" must NOT trip "exam"; the block term "bitcoin" then makes it off-domain.
  assertEquals(classifyDomain("give me an example of a bitcoin trade").inDomain, false);
});

Deno.test("empty / whitespace is treated as in-domain (validated upstream)", () => {
  assertEquals(classifyDomain("").reason, "empty");
  assertEquals(classifyDomain("   ").reason, "empty");
});

Deno.test("classifyDomain is deterministic", () => {
  const q = "who won the football world cup";
  assertEquals(classifyDomain(q), classifyDomain(q));
});

// ─── P2-4: lexicon hardening ─────────────────────────────────────────────────

Deno.test("P2-4: added school-ops vocabulary is in-domain", () => {
  for (
    const q of [
      "when is the unit test for 8-A?",
      "print the hall ticket for Aarav",
      "is the payroll processed this month?",
      "question paper for the science exam",
    ]
  ) {
    assertEquals(classifyDomain(q).inDomain, true, q);
  }
});

Deno.test("P2-4: added off-domain categories are refused with zero tokens", () => {
  for (
    const q of [
      "what does my horoscope say today",
      "best betting odds tonight",
      "recommend a video game",
    ]
  ) {
    assertEquals(classifyDomain(q).inDomain, false, q);
  }
});

Deno.test("P2-4: env extensions widen both lexicons; school signal still wins ties", () => {
  Deno.env.set("AI_DOMAIN_ALLOW_TERMS", "midday meal, anganwadi");
  Deno.env.set("AI_DOMAIN_BLOCK_TERMS", "fantasy league");
  try {
    assertEquals(classifyDomain("midday meal count for today?").inDomain, true);
    assertEquals(classifyDomain("join my fantasy league").inDomain, false);
    // A school signal beats an env block term — same tie-break as built-ins.
    assertEquals(classifyDomain("fantasy league permission slip for students").inDomain, true);
    // Terms under 3 chars are ignored: an accidental "a" must not open the gate.
    Deno.env.set("AI_DOMAIN_ALLOW_TERMS", "a,b");
    assertEquals(classifyDomain("what is bitcoin worth").inDomain, false);
  } finally {
    Deno.env.delete("AI_DOMAIN_ALLOW_TERMS");
    Deno.env.delete("AI_DOMAIN_BLOCK_TERMS");
  }
});
