# WS8 — AI Certification Suite (six sub-suites)

**Workstream 8** · Branch `release/v1.0-playstore` · 2026-07-29
**Scope:** `lib/core/dai/` — the deterministic intent layer — measured through
the production overlay filter (`global_search_overlay.dart:81-89`) and the
production router guard (`app_router.dart:2262-2292`).

**Verdict: NOT CERTIFIED.** 6 new defects — 3 P1 · 3 P2 — recorded as
`AI-001…006`. WS5's 16 findings are re-confirmed mechanically, one of them
**corrected** and one **quantified into a release-sequencing risk**.

**Deliverable:** a runnable harness, not a report.
`flutter test test/core/dai/` → **+121 −0** (5.0s).

| File | Role |
|---|---|
| `test/core/dai/dai_certification_suite_test.dart` | the six sub-suites |
| `test/core/dai/dai_certification_corpus.dart` | 200 labelled queries · 6 persona streams · 166 fuzz inputs |
| `build/dai_certification_report.txt` | the metrics report, regenerated on every run |

---

## 0. Method — what actually ran, and why it is a test

WS5 established the baseline by extracting the resolver into a throwaway
harness and firing 209 queries at it. That was the right first move and its
findings hold. But the charter mandates a **second full certification cycle
after remediation**, and an analysis that cannot be re-run is nearly worthless
on that cycle — it has to be redone by hand, by someone who may read the source
differently.

So WS8's primary output is a test. Every number below is printed by
`flutter test test/core/dai/` and can be reproduced in five seconds. Every WS5
finding this workstream touches is now a `test(...)` that fails if the defect is
fixed — deliberately, so the fixer must update the pin and the register together
rather than letting the certification silently go stale.

**This is not an LLM, and that governs the standard applied.** `DaiResolver` is
~350 lines of keyword and regex rules. It is judged here on determinism, honest
refusal and containment — not on fluency, helpfulness or recall of paraphrase.
A closed vocabulary is a legitimate design; answering outside it is not.

**Boundaries.** No device run (release binaries need production + live API, per
the charter). The router guard is *modelled* in the harness from the real
`isAdminErpRoute` (imported from production) plus the segment-ownership rule at
`app_router.dart:2233-2292`; no live `GoRouter` was instantiated.
`AdaptiveSearchResults` — the backend-backed entity list under the DAI card — is
out of scope and was not exercised.

---

## 1. Corpus-based NLU evaluation

**200 labelled queries.** The gold label is *what the person meant*, not what
the rules return — measuring a rule engine against its own rules proves nothing.
Where NIKSHA OS has no intent for the question (HR, admissions, approvals,
notices, library, timetable …) the gold label is `unknown`, meaning **the honest
answer is to refuse**. Phrasings are ordinary Indian-school register: "fees
pending", "3rd standard", "shortage of attendance", "bus 12", "roll number 23",
"TC for Rohan", noun-first word order.

| intent | gold | pred | TP | FP | FN | prec | recall | F1 |
|---|---|---|---|---|---|---|---|---|
| feeDefaulters | 31 | 24 | 23 | 1 | 8 | 0.96 | 0.74 | **0.84** |
| lowAttendance | 20 | 9 | 9 | 0 | 11 | 1.00 | 0.45 | **0.62** |
| attendanceToday | 17 | 8 | 7 | 1 | 10 | 0.88 | 0.41 | **0.56** |
| openPerson | 22 | **67** | 14 | **53** | 8 | **0.21** | 0.64 | **0.31** |
| openClass | 14 | 15 | 12 | 3 | 2 | 0.80 | 0.86 | 0.83 |
| openTransport | 12 | 11 | 11 | 0 | 1 | 1.00 | 0.92 | **0.96** |
| homework | 10 | 10 | 10 | 0 | 0 | 1.00 | 1.00 | **1.00** |
| exams | 14 | 12 | 11 | 1 | 3 | 0.92 | 0.79 | 0.85 |
| openReceipt | 7 | 6 | 6 | 0 | 1 | 1.00 | 0.86 | 0.92 |
| myAttendance | 4 | 4 | 4 | 0 | 0 | 1.00 | 1.00 | 1.00 |
| myFees | 7 | 7 | 7 | 0 | 0 | 1.00 | 1.00 | 1.00 |
| **unknown** | 42 | 27 | 7 | 20 | 35 | **0.26** | **0.17** | **0.20** |

**Overall accuracy: 121 / 200 = 60.5%.**

### 1.1 The headline number: honest refusal is 16.7%

`unknown` recall is **7 / 42**. The resolver refuses correctly **one time in
six**. That single figure is the most important output of this workstream,
because honest refusal is the property a deterministic router exists to
guarantee — it is the entire argument in the file's own header for not using a
model.

### 1.2 Confusion pairs

| count | gold → predicted |
|---|---|
| **34** | `unknown → openPerson` |
| 7 | `lowAttendance → openPerson` |
| 6 | `attendanceToday → openPerson` |
| 6 | `openPerson → unknown` |
| 5 | `feeDefaulters → unknown` |
| 3 | `lowAttendance → unknown` · `attendanceToday → unknown` · `exams → openPerson` |
| 2 | `feeDefaulters → openPerson` |
| 1 | `lowAttendance → feeDefaulters` · `attendanceToday → openClass` · `feeDefaulters → openClass` · `openPerson → exams` · `openClass → openPerson` · 5 others |

**One pair accounts for 43% of all errors.** `_person` is the last rule in the
chain and accepts any unmatched one-to-three-word alphabetic phrase, so the
entire out-of-vocabulary space drains into it: `payroll`, `timetable`,
`gate pass`, `audit log`, `settings`, `alumni`, `notices`, `hostel rooms`,
`lesson plan`, `inventory stock`, `salary slip`, `apply leave`, `report card`,
`fee structure`, `help`, `summary`, `urgent`, `anything` — all become
"Looking for Payroll…", "Looking for Gate Pass…", at confidence 60.

This is WS5's DAI-016, now measured. What is **new** is what it implies for the
remediation order — see §7, AI-001.

### 1.3 The intents a school leans on hardest are the weakest

`lowAttendance` recall **0.45** and `attendanceToday` recall **0.41** are the
two numbers a principal would feel every morning. The vocabulary that fails is
not exotic — it is the standard register:

- `attendance shortage list`, `shortage of attendance`, `detention list`,
  `irregular students`, `poor attendance`, `low attendance students` → all
  become a *person*.
- `who is absent today`, `who all are absent`, `how many students are present
  today` → `unknown`.
- `absentees today`, `absent students today`, `present today`, `take
  attendance`, `mark attendance`, `daily attendance` → all become a *person*.

`_lowAttendance` requires a numeric threshold to fire at all
(`dai_resolver.dart:154-155`), so every phrasing that names the concept without
naming a number is structurally unreachable. `_attendanceToday` requires the
literal token `today`/`todays`/`now`/`current`, so "who is absent" — where the
"today" is implied by the present tense — cannot match.

By contrast `feeDefaulters` (F1 0.84), `openTransport` (0.96) and `homework`
(1.00) are genuinely strong. The rules that were written against real phrasings
work well; the gap is which concepts got that attention.

### 1.4 Notable individual misses

| typed | resolved as | consequence |
|---|---|---|
| `attendance defaulters` | **feeDefaulters**, conf 90 | opens `/finance/defaulters`, card says *"Showing students with outstanding fees."* — an attendance question answered with a money list (**AI-002**) |
| `Rohan marks` | **exams**, conf 88 | opens whole-school exam administration for a one-student question (**AI-002**) |
| `roll number 23` · `admission number 4471` | **unknown** | the two identifiers Indian schools actually use are unsupported (**AI-003**) |
| `roll no 12 class 8a` | **openClass**, conf 82 | the roll number is dropped; opens the whole class |
| `staff attendance today` | **attendanceToday**, conf 90 | opens *student* attendance (WS5 DAI-010, re-confirmed) |
| `fee dues class 8` | **openClass**, conf 82 | opens a roster (WS5 DAI-011, re-confirmed) |
| `teacher attendance` | **openPerson**, conf **88** | staff-qualified person hint — the *highest*-confidence junk-drawer hit |
| `atendance below 75` | **unknown** | one transposed letter defeats the whole rule |
| `receipt RCP-2024-19` | **unknown** | alphanumeric receipt series (WS5 DAI-013) |
| `8A` · `section B` | unknown · openPerson | bare class labels (see **AI-005**) |
| `van 3` | **unknown** | many schools run vans, not buses |
