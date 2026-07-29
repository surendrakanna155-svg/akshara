# W0 · D1 — Official Answer-Key Acquisition & PYQ Reconstruction — FEASIBILITY REPORT

**Status:** 🔬 **Investigation only (2026-07-23).** No production code, no schema change, no certification-logic
change, no live API call, no architecture change was produced. All findings are from **read-only** inspection of
the frozen `kie.db` + Program-B `pyq_corpus.db` and the existing mining logic (reused, not modified).
**Scope of D1:** can official-authority answer keys be **legally + reliably acquired**, and is a **deterministic
PYQ → key/stem/options reconstruction** feasible? **Downstream (D2 — a `source_proven` certification writer) is
NOT touched; the certification law is unchanged.**

---

## 0. Verdict up front

🟡 **CONDITIONAL GO — feasibility PROVEN for a narrow, honestly-bounded pilot; NO-GO on the broad ambition.**

- **Feasible now (no new external acquisition, no booklet-code dependency):** a `source_proven` pilot drawn from
  the **45 official-authority PYQ documents that embed their own answers inline** — restricted to **text-heavy
  MCQ items that reconstruct clean**. Estimated **~200–350 pilot-quality items** (owner asked for 100–500 ✓).
  Answer + stem + options are all deterministically recoverable for this subset; **$0 API**.
- **NOT feasible deterministically:** mapping *external* official keys (NTA/IIT) onto the ~180 official
  question-only papers — blocked by a **missing booklet-code** field and per-code option shuffling (below).
- **NOT feasible / low quality:** the broad "certify all 15,803 PYQ" — dominated by **third-party mirrors** (not
  primary sources), **formula-mangled OCR** (Math 10% / Chemistry 26% clean), missing booklet codes, and missing
  curriculum metadata.
- **Unresolved gate:** **licensing/IP** of reproducing official question papers — an **owner/legal decision**,
  not resolvable by engineering. Answer keys (facts) are low-risk; verbatim question reproduction is not.

**Per instruction: STOP here. Do not implement.** Two owner gates below must clear before any build.

---

## 1. Official data sources

| Source | Body | What it publishes | In-corpus today |
|---|---|---|---|
| `jeeadv.ac.in` archive | IIT / JAB (JEE Advanced) | Official papers **with answer keys** (many answer-annotated) | ✅ 32 official docs already held |
| `nta.nic.in` / `neet.nta.nic.in` | NTA (NEET) | Official papers + per-code answer keys (provisional + final) | ✅ 23 official docs held |
| `jeemain.nta.nic.in` | NTA (JEE Main) | Official papers + per-shift keys | ✅ 26 official docs held |
| Coaching mirrors (Careers360, Allen, etc.) | third-party | Reproductions, usually paper+answers | ⚠ ~144 docs — **NOT primary sources** |

**Key structural fact discovered:** the official `jeeadv.ac.in` archive PDFs already in the corpus are
**answer-annotated** — the correct option is printed inline after each question (`ANSWER: D`). Several official
NEET/JEE-Main docs likewise embed answers. **This means the highest-value keys are already acquired** and need no
external fetch. (Established knowledge, to be legally verified by owner: NTA and IIT-JAB publish papers + keys
publicly on the official sites above; NEET/JEE-Main keys are published **per booklet/shift code**.)

## 2. Coverage

- **Corpus:** `pyq_item` = **15,803** provenance rows (item_id, doc_id, exam, year, subject, q#, type, chunk_ids
  …). It stores **no stem, no options, no answer** — those live in the frozen `kie.db` chunks and must be
  reconstructed.
- **Genuine-PYQ docs:** 225 eligible. **By authority: ~81 official** (JEE-Adv 32, JEE-Main 26, NEET 23) vs
  **~144 third-party/unknown mirrors** (JEE-Main 42, NEET 82, JEE-Adv 20).
- **Inline answers:** **147/225** eligible docs embed answers — but heavily in *mirrors*. Official-authority **AND**
  answer-embedded = **45 docs** → **1,023 reconstructable items** (the feasible universe).
- **Numeric (autonomous-sympy) items:** only **180** total, all JEE, **0 NEET** — the autonomous lane is tiny.
- **Curriculum metadata:** KC-linked = **132 / 15,803 (0.8 %)**; of the 1,023 feasible items, **738 have no
  subject** (honest-null). Retrieval-addressability will be thin.

## 3. Licensing / provenance

- **Answer keys** ("Q46 → option 1") are essentially **factual data** with minimal copyrightability — low risk.
- **Question papers** carry copyright; NTA and IIT-JAB typically assert reproduction restrictions. Storing +
  serving **verbatim official questions** in a product is a **genuine IP question requiring legal sign-off** —
  **this report does NOT clear it.** (No external legal research was performed; investigation-only.)
- **Provenance discipline holds:** only **official-authority** docs qualify as a `source_proven` primary source.
  The ~144 third-party mirrors are provenance-usable for exam DNA but are **NOT** primary sources — **excluded**.
- The corpus already tags `source_authority` (official | third_party | unknown), so the official/mirror split is
  **queryable and enforceable** at selection time.

## 4. Reconstruction feasibility  *(the decisive engineering test)*

Reconstructed (stem + options + inline answer) for all **1,023 items** in the 45 official+answer docs, using the
**existing frozen mining logic** (read-only, deterministic):

| subject | items | stem ok | all 4 options | inline answer | **clean** (low OCR-mangling) |
|---|--:|--:|--:|--:|--:|
| (null) | 738 | 100 % | 86 % | 76 % | **41 %** |
| Physics | 103 | 100 % | 82 % | 86 % | **39 %** |
| Chemistry | 81 | 100 % | 86 % | 65 % | **26 %** |
| Mathematics | 101 | 100 % | 65 % | 65 % | **10 %** |
| **TOTAL** | **1,023** | **100 %** | **84 %** | **75 %** | **37 %** |

**What is feasible (deterministic):**
- **Stem/option reconstruction** from chunks — yes, the mining span logic recovers them; **84 %** have all four
  options; item-ids are content-addressed so reconstruction is reproducible.
- **Answer recovery via inline annotation** — **75 %** of items carry a recoverable `ANSWER:`/`Ans.` token *inside
  their own span*. Because the answer is embedded **in the paper's own option ordering**, this **sidesteps the
  booklet-code problem entirely** and needs no external key.

**What is NOT feasible / unreliable:**
- **Formula-heavy OCR is mangled** even in "high-confidence" docs: e.g. N₂→`N,`, NH₃→`NH,`, (NH₄)₂Cr₂O₇→`(NH,),Cr,O,`.
  Only **10 % of Math** and **26 % of Chemistry** stems reconstruct clean → **not shippable** without re-OCR or the
  original born-digital PDFs. The clean core is **text-heavy (biology/conceptual)** questions.
- **`match` / `assertion_reason` types linearize badly** (option groupings collapse in the chunk text) — exclude.
- **External-key mapping is deterministically blocked:** **no booklet-code field exists** anywhere (mining even
  treats "booklet code" as an instruction to reject); **2,682 (doc, q#) collisions** confirm multiple codes per
  doc. NEET/JEE keys are per-code with **shuffled option order**, so an external key's "option 2" is meaningless
  without the matching code's paper. The ~180 official *question-only* papers therefore **cannot** be keyed
  deterministically.
- **Inline-answer precision is unverified** — the 75 % is a *recall* upper bound; correct association (answer
  belongs to *this* question, parsed to the right label) needs a sampled QA pass before it can be trusted.

## 5. Risks

1. **IP / licensing (highest)** — reproducing official copyrighted questions; **owner/legal gate**, unresolved.
2. **OCR fidelity** — a mangled formula silently produces a *wrong* certified question. Mitigation: hard clean-text
   gate + type/subject restriction (text-heavy only) + exclude formula subjects until re-OCR.
3. **Inline-answer mis-association** — a parsed answer bleeding from an adjacent question would certify a wrong key.
   Mitigation: strict same-span binding + sampled human QA of the extractor before any certification.
4. **Thin metadata** — 0.8 % KC-linked, most items subject-null → low retrieval value; the pilot proves the *path*,
   not a curriculum-complete bank.
5. **Mirror contamination** — a third-party answer treated as a primary source. Mitigation: hard
   `source_authority='official'` filter (already available).
6. **Small yield vs. ambition** — feasible cohort ≈ hundreds, not the headline 15,803.

## 6. Estimated effort  *(for a LATER, owner-approved implementation — NOT now)*

- Deterministic reconstruction + inline-answer extractor + confidence/clean-text/authority gates: **~2–4 days**,
  **$0 API** (pure compute over local stores).
- Sampled QA of extractor precision (answer association, option fidelity): **~1 day** + reviewer time.
- Curriculum tagging of the pilot cohort (subject/KC where derivable): **~1–2 days**, mostly honest-null.
- External-key / booklet-code path: **descoped** (deterministically infeasible without new per-code paper data).
- Legal/IP review: **owner/legal, unknown** — a hard predecessor to any product exposure.

## 7. GO / NO-GO recommendation

- 🟡 **CONDITIONAL GO** on a **narrow `source_proven` pilot**: official-authority + inline-answer docs → text-heavy
  clean MCQs → **~200–350 items**, deterministic, $0 external acquisition, no booklet-code dependency. This proves
  the Lane-K path end-to-end on **real** data. **Gated on two owner decisions:**
  1. **Legal/IP sign-off** to store + (eventually) serve reconstructed official question content.
  2. Acceptance that the pilot cohort is **biology/conceptual-heavy with thin metadata**, and that a **precision QA**
     of the inline-answer extractor runs before any item is certified.
- 🔴 **NO-GO** on: certifying formula-heavy subjects from current OCR (Math/Chem); using third-party mirrors as
  primary sources; mapping external keys onto question-only papers (booklet-code gap); any claim of certifying the
  full 15,803.

**Reminder honored:** D2 (the `source_proven` writer) is **not** built; the certification law is **unchanged**; no
architecture change was made. Awaiting owner decision before any implementation.
