# Version 2 — Question Intelligence: what we ship, and what has to be true first

> **Status:** plan (2026-07-28). Written when V1 shipped with the Question Paper /
> QIE module hidden (`V1-SCOPE-1`).
> **Audience:** owner + engineering. Slide-facing summary lives in the demo deck.
> **Companion documents:** `CERTIFIED_KNOWLEDGE_POPULATION_MASTER_PLAN.md` (how the
> bank gets filled), `PROGRAM_D_EXECUTION_LOG.md` (what is already built),
> `QIE_ENGINE_COMPLETION_INVENTORY.md` (engine state).

---

## 1. Why the module is hidden in V1

The generation engine is **built**. The question bank it generates from is
**empty**. That is the whole story, and it is worth being precise about it,
because the fix is a content-supply problem, not an engineering problem.

Akshara's design decision — locked, and not up for renegotiation in V2 — is:

> **Teacher → Question Review → Certified Bank → Deterministic Assembly.**
> AI proposes offline. Deterministic rules certify. Nothing reaches a child's
> question paper on the strength of a model's say-so.

That is the opposite of how most "AI question generator" products work, and it is
the reason Akshara can put a generated paper in front of a principal without
flinching. It is also why we cannot ship V2 by simply switching the module on: an
empty certified bank produces either nothing, or — if the bar were lowered —
plausible-looking questions nobody has verified. Shipping the second option would
be the single fastest way to destroy trust with a school.

So V1 hides the tab. V2 un-hides it when the bank is real.

**Restoring the module is one line** — remove `RouteNames.education` from
`SchoolBuildScope.hiddenRoutePrefixes`. Nothing was deleted.

---

## 2. What is already built (and paid for)

| Asset | State | Evidence |
|---|---|---|
| Knowledge Intelligence Engine (KIE) v1.4 | **Frozen, complete** — 2,023 certified NCERT items, Class 6–12 | 681 tests |
| PYQ corpus | **15,803 provenance-linked past questions** mined and structured | Program B |
| Knowledge-bank integration spine | **Engineering-complete on fixtures**, additive + dormant + flag-gated | Program D, 13 commits |
| Contracts, exporter, importer, union view | Built; migrations `20260877–80` authored | Program D M0.1–M4.4 |
| Deterministic assembly (solver) | Built; **byte-identical output verified** | Program D e2e |
| Question Review Engine surface | Built (`/education` — hidden in V1) | — |

The V2 work is therefore **mostly content acquisition and certification**, with a
comparatively small amount of UI at the end.

---

## 3. The honest blockers

These are stated plainly because a V2 date that ignores them is fiction.

**B1 — The certified bank is empty.** Everything downstream is gated on this.

**B2 — PYQ papers have no answer keys.** The 15,803 mined questions came without
official answer keys (119 key documents exist, all third-party, zero official).
A question without a certified answer cannot be certified.

**B3 — There is no deterministic `source_proven` write-path.** Today the only
route into the product bank is the live cross-family-judge factory bar. Filling
the bank from official sources needs a ratified deterministic writer.

**B4 — Qualitative questions are not auto-certifiable.** Mathematics and physics
can be certified by symbolic recomputation. "Explain why the Quit India movement
began in 1942" cannot. Those need either an official answer key, a
`source_proven` provenance chain, or **human maker–checker review**. There is no
third option that preserves the guarantee.

**B5 — Exam DNA is statistically insufficient.** Blueprint inference reports
`insufficient_evidence` for **every** exam: it needs ≥30 sittings per exam and we
hold ~10–14. More past papers, not more code.

---

## 4. The two lanes

Everything in V2 flows down one of two lanes, and they have very different costs.

### Lane Q — Quantitative (cheap, scalable, autonomous)
Numeric and symbolic questions certified by independent recomputation (sympy).
A question is accepted only when an independent solver reproduces the answer.
No human in the loop, no model trusted. **This lane scales.**

Covers: Mathematics, Physics, Chemistry (numericals), quantitative aptitude.
This is where IIT/JEE and NEET physics/chemistry/maths live.

### Lane K — Qualitative (expensive, human-gated)
Biology theory, Social Science, languages, reasoning. Certification requires
official keys, `source_proven` provenance, or human maker–checker. **This lane
does not scale without either official content licensing or reviewer hours.**

Covers: NEET biology theory, Navodaya reasoning/language, most school-board
theory papers.

> **The single most important V2 planning fact:** the products schools ask for
> first (regular school papers, Navodaya) are Lane-K heavy. The products that are
> cheapest to build (JEE/NEET quantitative) are Lane-Q. Sequencing must respect
> that, or the programme stalls.

---

## 5. Sequenced plan

Each wave is budget- and owner-gated. Waves do not start until the previous
wave's exit criterion is genuinely met.

### W0 — Unblock the write-path *(no new content)*
- Ratify and build the deterministic `source_proven` writer (**B3**).
- Acquire official answer keys for the highest-value PYQ subset (**B2**).
- **Exit:** one certified item exists in the product bank, written by a
  deterministic path, with provenance to an official source.

### W1 — Quantitative factory *(Lane Q, autonomous)*
- Turn on sympy-certified generation across the numeric pool.
- Scale via question **families** (certify the family, instantiate the members) —
  this is the single biggest volume lever available.
- **Exit:** a school-usable quantitative bank for Maths + Physics, Class 8–10.

### W2 — Regular school question papers *(first shippable product)*
- Board-aligned papers for the classes the pilot school actually teaches.
- CBSE + State Board blueprints; FA/SA and UT/HY/Annual patterns —
  **already supported in V1's exam types.**
- **Exit:** a teacher generates a real unit-test paper and uses it.

### W3 — Review console *(unlocks Lane K)*
- Maker–checker workflow so qualitative questions can be certified by humans at
  a sensible rate. Without this, Lane K cannot move at all.
- **Exit:** measured reviewer throughput (items certified per reviewer-hour).

### W4 — Competitive exams
- **IIT/JEE:** Lane Q covers most of it. Highest ratio of value to effort.
- **NEET:** Physics + Chemistry via Lane Q; Biology theory needs W3.
- **Navodaya (JNVST):** mental ability + language — Lane K heavy, needs W3, and
  needs a Navodaya-specific blueprint.
- **Exit:** per-exam blueprint with sufficient sittings (**B5**) or an explicit,
  visible `insufficient_evidence` state. We show the honest state rather than a
  fabricated blueprint.

### W5 — AI-assisted generation *(kept last, deliberately)*
AI proposes candidates **offline**; the deterministic certifier remains the only
path into the bank. No request-path AI, no model self-certification, no lowering
of the bar to increase volume.

---

## 6. What we will NOT do

Recorded so that schedule pressure later does not quietly erode the product.

1. **No model self-certification.** An AI's confidence in its own answer is not evidence.
2. **No request-path AI.** Papers are assembled deterministically at request time.
3. **No weakening a gate to raise yield.** If yield is low, the answer is more
   certified content, never a lower bar.
4. **No fabricated blueprints.** When evidence is insufficient we say so.
5. **No shipping an empty module.** The reason V1 hides it.

---

## 7. What the demo deck may claim about V2

Accurate, and defensible if a principal probes:

- ✅ "The engine is built and tested; V2 turns it on once the certified bank is filled."
- ✅ "Every generated question is verified by an independent check, not by the AI that wrote it."
- ✅ "V2 targets regular school papers first, then IIT/JEE and NEET, then Navodaya."
- ✅ "AI assists teachers offline; it never puts an unverified question on a child's paper."

Not to be claimed:

- ❌ Any V2 delivery date. The blockers above are content-supply, partly external.
- ❌ That question generation works today.
- ❌ Specific question counts for any exam.
