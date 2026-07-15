# Decision B — concept granularity for the qualitative lane (OWNER DECISION REQUIRED)

**Raised:** 2026-07-15 · **Branch:** `feature/qp-content-readiness` · **Status:** ⏸ awaiting owner
**Nothing has been built for this.** No gate weakened, no scope opened. This is a measured finding + a choice.

---

## 1. The finding

The qualitative (KVS fact) lane binds a governed fact to its **chapter**
(`governed_fact.concept_candidate`, e.g. `Biology :: Excretory Products And Their Elimination`).

qpgen dedups by **`(concept_code, question_type)`**, and `used_ct` is **global across the whole paper**
(`qp_bridge.generate_paper`). Every KVS item is an `mcq`. Therefore:

> **one chapter = exactly ONE question in the entire paper.**

So the qualitative lane's coverage is capped by **distinct chapters**, not by facts — no matter how much
evidence is examined.

### Measured ceiling (whole candidate pool, `candidates.prepare()`)

| subject | clean candidates | **distinct chapters** | NEET demand | **hard ceiling** |
|---|---|---|---|---|
| Biology | 938 | **38** | 90 | **42% — forever** |
| Chemistry | 267 | **29** | 45 | **64% — forever** |
| Physics | 569 | 216 | 45 | not capped |

Biology has **938 candidates but only 38 chapters**. Today 27 chapters carry facts and 20 land in a paper.
**Examining all 938 remaining Biology candidates would buy at most +11 slots** (27 → 38) and then stop dead.

### This invalidates the handoff's #1 priority
`QIE_SESSION_HANDOFF.md` §7.1 says Biology (20 of 70) is the largest gap and the qualitative batch lane
("~1,660 candidates at 76–88% yield") is the way to move it. **The lane is real but it cannot move Biology
past 38.** Spending an examiner run on ~900 Biology candidates would return ~11 slots — the other ~890 facts
would be correct, verified, admitted, and *invisible*, collapsing into chapters already filled.

## 2. Why relations do not have this problem

Lesson 5 (already learned, already in the handoff): relations bind at **relation granularity**
(`Physics :: Ohm's law`), not chapter. Chapter-level binding made 7 new relations buy **+1** slot;
relation-level gave **+8**. `qp_bridge._governed_concepts` was fixed for relations — **the qualitative lane
was never given the same fix.** Decision A's wording froze it at chapters:

> "verified **governed-fact chapters** … are first-class in-scope concepts"

## 3. The choice

**Option A — keep chapter granularity (status quo).**
NEET Biology is permanently capped at ~42%, Chemistry at ~64% for the qualitative lane. A full NEET paper
becomes impossible from this lane; the shortfall stays honest but permanent.

**Option B — bind a governed fact at TOPIC granularity** (`Biology :: Uricotelism`), exactly as relations
bind at relation granularity — subject-gated and `sanitize.is_clean_concept`-gated identically. A fact whose
topic is not sanitizer-clean falls back to its chapter, so the change is strictly additive.

Each fact then carries its own concept, the ceiling lifts from *chapters* to *topics*, and every future
examined fact becomes additive instead of collapsing.

### What Option B costs — measured, not assumed
Facts already carry a natural topic (`structure` / `process` / `subject_term`), the same role a relation's
`name` plays. Of the 92 verified facts, **69 have a topic that passes the sanitizer today** (Biology 45 vs
its 27 chapters). But the sanitizer caps titles at 5 words, and `subject_term` is natural-language prose, so
`_clean_title` **truncates** it into fragments:

```
"Hydrolysis of a nitrile (from alkyl halide + KCN) with aqueous NaOH"
    -> "Hydrolysis of nitrile (from alkyl"        <- shipped as a concept title
"Kepler's second law (constant areal velocity)"
    -> "Kepler's second law (constant areal"
```

A relation's `name` is *authored short* ("Ohm's law"), which is why truncation never bit that lane. So
Option B is only safe with **a short, authored `topic` per fact** (≤5 words, sanitizer-clean) — authored at
**examiner** time alongside the structured slots, and back-filled for the 92 already-verified facts.

Without authored topics, Option B ships truncated fragments as concept titles — which is why this is not
being done unilaterally.

## 4. Recommendation

**Option B, with authored topics.** It is the same principle already proven for relations (lesson 5), it uses
the same two guards (subject gate + concept sanitizer), it is strictly additive with an honest chapter
fallback, and it is the only thing that lets NEET Biology exceed 42%. The topic-authoring cost is bounded:
one short title per fact, folded into the examiner pass that must run for new facts anyway, plus a one-off
back-fill of 92.

## 5. Why this is an owner decision, not an implementation detail
1. It changes what **Decision A** explicitly locked (governed-fact **chapters** as the in-scope unit).
2. It changes what a generated paper *shows as its concept* — `Uricotelism` instead of
   `Excretory Products And Their Elimination`. That is a product-visible judgment about what a "concept" is.
3. It re-orders the roadmap: under Option A, the qualitative batch lane is near-exhausted for Biology; under
   Option B it becomes the highest-value lane again.

## 6. Scope guard
In scope either way: NEET/JEE Main/JEE Advanced + NCERT/CBSE as already locked. **No** new acquisition, **no**
new subjects, **no** gate weakened, **no** bank promotion. Option B is a binding-granularity change plus a
title field — it admits no new knowledge.
