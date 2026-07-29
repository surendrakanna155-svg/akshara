# WS5 — DAI Certification (Digital Academic Intelligence)

**Workstream 5** · Branch `release/v1.0-playstore` · 2026-07-29
**Scope:** `lib/core/dai/dai_resolver.dart`, `lib/core/dai/dai_intent.dart`,
`lib/core/dai/dai_brief.dart`, and the single production consumer
`lib/features/admin/global_search/global_search_overlay.dart`.

**Verdict: NOT CERTIFIED.** 16 defects — 2 P0 · 7 P1 · 5 P2 · 2 P3 — recorded as
`DAI-001…016` in `docs/certification/DEFECT_REGISTER.md`.

---

## 0. Method — what actually ran

The resolver is pure Dart with only two dependencies (`route_names.dart`,
`permissions.dart`), so it was **extracted into a standalone harness and executed**
rather than reasoned about. 209 queries were resolved against the shipping source:
a realistic-phrasing corpus (what a principal, clerk, teacher or parent would type),
an adversarial/edge corpus (injection, unicode, out-of-range numbers, typos,
whitespace, casing, 300-char input), and a module-coverage corpus (one query per
inventory module).

Every claim below carries its observed output. Where a claim could not be
executed — router behaviour needs a live `GoRouter` + `AuthState` — it is derived
from the guard source and labelled as such.

**Boundaries.** No device run (release binaries need production + live API, per the
charter). `AdaptiveSearchResults` (the entity list rendered beneath the DAI card)
is backend-backed and was read, not exercised. The 55-confidence floor was probed
by input, not by mutation.

---

## 1. Where DAI actually lives — the fact everything else depends on

`DaiResolver` has **exactly one production call site**:
`global_search_overlay.dart:83`, inside `showGlobalSearchOverlay`, which is
raised from **one** place — `admin_content_scaffold.dart:82`, the search icon in
the admin ERP chrome.

Therefore:

- **DAI is a staff-only surface.** Parent, teacher and student shells never
  build `AdminContentScaffold`, so they can never open the overlay. A parent has
  no path to the DAI card at all.
- Everything the resolver knows about parents and students
  (`myAttendance`, `myFees`, and the `own` branch of `exams`) is reachable only
  by a **staff** user typing "my fees" into the admin search box.

That single fact drives DAI-001, DAI-002 and DAI-003 below.

## 2. Guardrail re-verification (previously certified) — HOLDS

Re-checked against current source, not the prior report:

| Guardrail | Status | Evidence |
|---|---|---|
| No I/O imports | **HOLDS** | `dai_resolver.dart:1-3` imports only `route_names.dart`, `permissions.dart`, `dai_intent.dart`. `dai_intent.dart:1` imports only `permissions.dart`. No `dart:io`, no `http`, no repository, no provider. |
| No async | **HOLDS** | Zero `async`/`await`/`Future`/`Stream` tokens in either file. `resolve` is a synchronous static. |
| Intent carries no callback | **HOLDS** | Every `DaiIntent` field is `String`, `int`, `bool`, an enum, or `Permission?`. No `Function`, no `VoidCallback`, no widget. It cannot carry an executable. |
| No clock / no randomness | **HOLDS** | No `DateTime`, no `Random`. Confirmed by repeated invocation in the harness — identical output across runs. |
| Cannot execute | **HOLDS** | The consumer's only action is `context.go(intent.route!)` (`global_search_overlay.dart:170`) — navigation, never a mutation. There is no write path from DAI to any repository. |
| Deterministic answer text | **HOLDS** | `answer` is composed by string interpolation from resolved fields; no model, no template store, no locale lookup. |

**This half of DAI is genuinely sound.** The architecture note in the file header
("not an LLM, because a school's search vocabulary is small and closed") is a
defensible engineering position and the implementation honours it. The defects
below are about *what the resolver says and where it sends you*, not about
safety.

## 3. Permission enforcement — the mechanism is right, its coverage is not

`_resolveDai` (`global_search_overlay.dart:81-89`) filters **before render**:

```dart
if (_query.length < 3) return null;
final intent = DaiResolver.resolve(_query);
if (!intent.isResolved) return null;
if (intent.needsDirectoryLookup || intent.route == null) return null;
final permission = intent.requiredPermission;
if (permission != null && !hasPermission(permission)) return null;
```

**Filter-before-render is the correct shape** and is confirmed: a user without
`viewFinance` typing "fee defaulters" sees no card at all — the *existence* of the
defaulters screen is not disclosed, which is stronger than rendering a card that
then fails. Same for `viewSis`, `viewTransport`, `viewExams`, `viewAttendance`.

But the guard only checks a **permission**. It never checks **role/shell
reachability**, and five intents route outside the admin shell. Three of those
carry `requiredPermission: null`, so the guard is a no-op for them; a fourth
(`attendanceToday`) carries a permission that principals *do* hold, so it passes
the guard and still dead-ends. Detail in DAI-001/002.

## 4. Intent routing — all 12 kinds, executed

Observed resolver output (harness run, shipping source):

| # | `DaiIntentKind` | Reaches the card? | Route | Permission | Verdict |
|---|---|---|---|---|---|
| 1 | `feeDefaulters` | yes | `/finance/defaulters` | `viewFinance` | routes correctly; **answer over-claims scope** (DAI-004) |
| 2 | `lowAttendance` | yes | `/sis/students` | `viewSis` | **P0 — answer claims a filter the destination does not apply** (DAI-004) |
| 3 | `attendanceToday` | yes | `/teacher/attendance` | `viewAttendance` | **P0 — passes the guard, then the router bounces staff to `/admin`** (DAI-001) |
| 4 | `openPerson` | **never** | `null` | none | structurally filtered — 100% dead in production (DAI-005) |
| 5 | `openClass` | yes | `/sis/students` | `viewSis` | routes correctly; **class scope silently dropped** (DAI-004) |
| 6 | `openTransport` | yes | `/transport/routes` | `viewTransport` | routes correctly; **bus number silently dropped** (DAI-004) |
| 7 | `homework` | yes | `/teacher/homework` | **null** | **bounces staff to `/admin`** (DAI-002) |
| 8 | `exams` (school) | yes | `/school/exam-administration` | `viewExams` | correct |
| 8b | `exams` (own, "my exam schedule") | yes | `/student/exams` | **null** | **bounces staff to `/admin`** (DAI-002) |
| 9 | `openReceipt` | yes | `/finance/collections` | `viewFinance` | reaches the right screen; receipt number dropped, wording honest (DAI-004 note) |
| 10 | `myAttendance` | yes | `/student/attendance` | **null** | **bounces staff to `/admin`** (DAI-002) |
| 11 | `myFees` | yes | `/parent/fees` | **null** | **bounces staff to `/admin`** (DAI-002) |
| 12 | `unknown` | n/a | — | — | correct: no card, falls through to registry search |

**7 of the 11 resolving kinds either dead-end or mis-describe their result.**
Only `exams` (school branch) is fully correct end to end. `feeDefaulters`,
`openClass`, `openTransport`, `openReceipt` land on the right *screen* with a
sentence that promises more than the screen delivers.

### 4.1 Realistic phrasings — a principal's actual vocabulary

The golden corpus in `test/core/dai/dai_resolver_test.dart` pins the phrasings
the rules were written for. This certification typed what a school actually says.

**Works (representative):** `fee defaulters` · `pending fees` · `outstanding dues`
· `overdue fee` · `unpaid fees list` · `grade 10 fee defaulters` ·
`class 8a fee defaulters` · `students below 75% attendance` ·
`attendance less than 80% in class 9` · `who is below 75 percent attendance` ·
`today's attendance` · `attendance today` · `current attendance` ·
`class 8a` · `grade 10` · `10th` · `bus 5` · `where is bus 7` · `vehicle 22` ·
`exam schedule` · `marks` · `result` · `unit test marks` · `pending homework` ·
`receipt 1023` · `fee receipt 1023` · casing and extra whitespace are handled ·
`fee-defaulters` (hyphen normalised).

**Fails on phrasings a school will certainly type:**

| Query | Resolved as | Should be |
|---|---|---|
| `who has not paid fees` | **unknown** | feeDefaulters |
| `fee dues class 8` | **openClass** → "Opening Class 8 students." | feeDefaulters, class 8 |
| `low attendance students` | openPerson (dead) → no card | lowAttendance |
| `poor attendance` | openPerson (dead) | lowAttendance |
| `shortage of attendance` | openPerson (dead) | lowAttendance |
| `who is absent today` | **unknown** | attendanceToday |
| `how many students are present today` | **unknown** | attendanceToday |
| `absentees today` | openPerson (dead) | attendanceToday |
| `staff attendance today` | **attendanceToday → `/teacher/attendance`** | HR staff attendance — **wrong module** |
| `teacher attendance` | openPerson "Looking for Attendance…" | HR staff attendance |
| `is Rohan present today` | **unknown** | person + attendance |
| `did Rohan pay fees` | **unknown** | person + fees |
| `Rohan attendance` / `Rohan fees` | openPerson (dead) | person dossier |
| `Rohan marks` | **exams → school exam administration** | Rohan's report card |
| `8A` (no "class") | **unknown** | openClass |
| `section B` | openPerson (dead) | openClass |
| `Rohan Sharma Kumar Verma` (4 tokens) | **unknown** | openPerson |
| `atendance below 75` (one typo) | **unknown** | lowAttendance |
| `mark attendance for class 8` | openClass → SIS roster | attendanceToday |
| `receipt RCP-2024-19` (alphanumeric receipt no.) | **unknown** | openReceipt |
| `रोहन` (Devanagari) | **unknown** | openPerson |
| `fee_defaulters` (underscore) | openPerson "Looking for Fee_defaulters…" | feeDefaulters |

The hint text in the search box is **"Ask anything — 'fee defaulters', 'Class 8A'…"**
(`global_search_overlay.dart:137`). "Ask anything" is not what this is; it is a
~40-phrase keyword router, and the honest failures above are the product of a
deliberate, defensible design choice that the *copy* misrepresents (DAI-006).

## 5. Module coverage — what DAI cannot answer

The inventory (`FEATURE_INVENTORY.md`) enumerates **28 modules**. DAI has 11
resolving intents, and one of those (`openPerson`) never surfaces. Mapping the
intents onto the module index:

**Covered (7 of 28, and 3 of them only partially):**

| Module | Covered by | Completeness |
|---|---|---|
| M9 Finance | `feeDefaulters`, `openReceipt` | defaulters + collections only. No fee structure, no collection summary, no concessions, no refunds, no day book. |
| M10 SIS | `openClass`, `lowAttendance` (routes to SIS) | roster screen only, unfiltered. |
| M13 Transport | `openTransport` | routes list only. No vehicles, no drivers, no allocations, no live tracking. |
| M17 Academics | `exams` | exam administration only. Timetable, syllabus, subjects, grading scales all unreachable. |
| M5 Teacher | `homework`, `attendanceToday` | both dead-end for the staff persona that can actually open the overlay (DAI-001/002). |
| M6 Student | `exams` (own), `myAttendance` | dead-end (DAI-002). |
| M4 Parent | `myFees` | dead-end (DAI-002). |

**Zero DAI coverage (21 of 28):**

M1 Auth/Legal · M2 Shared surfaces (settings, sync centre, AI assistant,
notifications) · M3 Support · M7 Admin hub · **M8 Admissions** ·
**M11 HR & Payroll** (employees, payroll, staff attendance, leave, documents) ·
**M12 Management** (approvals, analytics, intelligence, workflow) · M14 Hostel ·
M15 Library · **M16 Inventory & Procurement** · **M18 Communication**
(notices, circulars, messages, broadcasts) · M19 Intelligence & AI ·
M20 Education/QIE · **M21 PRC-A desks** (certificates, gate passes, complaints,
student health) · M22 Alumni · M23 Control Center · M24 Director ·
M25 Multi-school/config/entitlements · M26 Verticals · M27 Evolution ·
M28 Dead code (correctly uncovered).

Confirmed by probe — every one of these returns `unknown` or a dead `openPerson`:
`pending approvals` · `admission enquiries` · `new admissions this month` ·
`salary slip` · `payroll` · `who is on leave today` · `apply leave` ·
`approve leave` · `library books issued` · `hostel rooms` · `inventory stock` ·
`notices` · `circular` · `send message to parents` · `transfer certificate for
Rohan` · `generate report card` · `timetable` · `my timetable` ·
`syllabus progress` · `lesson plan` · `events this week` · `fee structure` ·
`discount approval` · `audit log` · `support ticket` · `alumni` · `settings`.

**The gap that matters most for a principal:** approvals, admissions, HR/leave
and communication are the four modules a head of school touches every single
morning, and DAI answers none of them. The unwired `DaiBriefComposer` was built
around exactly those facts (approvals, admissions, staff absence) — the
intelligence layer knows they are the important ones and the *search* layer
cannot reach them.

This gap is not itself a defect — a deterministic router is allowed to have a
closed vocabulary. **The defect is the copy that claims otherwise** (DAI-006)
and the absence of any "I do not handle that" acknowledgement (DAI-007).

## 6. Ambiguity handling

| Situation | Behaviour | Assessment |
|---|---|---|
| Two students named "Rohan" | DAI never resolves it — `openPerson` always has `route == null` → `needsDirectoryLookup` → the card is suppressed. The **`AdaptiveSearchResults`** entity list below handles the disambiguation, RBAC-scoped, showing both records for the user to choose. | **Correct by design.** The resolver deliberately holds no name index and defers. This is the best-handled ambiguity case in the layer. |
| Vague query (`help`, `summary`, `urgent`, `anything`, `what should I do today`) | `what should I do today` → unknown (no card). `help`/`summary`/`urgent`/`anything` → `openPerson` conf 60 → suppressed → no card. Net: no card, registry search still runs. | **Correct outcome, wrong reason.** The user sees nothing misleading, but only because `openPerson` is filtered downstream — the resolver itself confidently returned "Looking for Urgent…". A second consumer would render it. (DAI-005) |
| Below the 55 floor | **Never happens.** Every rule returns 60, 78, 82, 85, 88, 90, 92, 93, 94 or 95. No code path can produce 1–54. | The floor is **decorative** — rejection is actually done by rules returning `null`. The doc comment "Below `minConfidence` it returns `unknown` rather than guess" describes a branch that cannot execute. (DAI-008) |
| Multi-intent (`fee defaulters and low attendance`) | Silently resolves to `feeDefaulters` only, conf 90, answer "Showing students with outstanding fees." | **No ambiguity disclosure.** The user asked two questions and is told, confidently, that one of them was answered. (DAI-009) |
| Multi-scope (`fee defaulters class 8 and class 9`) | Resolves Class 8 only; answer says "for Class 8". | Half-honest — it names what it took, but never says it dropped the rest. (DAI-009) |
| Competing rules (`attendance and fees today`) | `attendanceToday` wins by rule order. | Rule order is the only tie-break; there is no scoring contest between rules. Documented in source, but it means the *first* matching rule always wins regardless of how much better a later rule fits. |
| `homework attendance fees` (three modules) | `homework`, conf 85. | Same. |

## 7. Are the `answer` strings honest?

This is the question the layer's own documentation stakes its credibility on:

> "Every word of it was composed deterministically by `DaiResolver` from the
> user's own query, so **it can never say something the system will not then do**."
> — `global_search_overlay.dart:277-278`

**That claim is false in the shipping build.** The resolver extracts
`className`, `section`, `threshold`, `routeNumber` and `receiptNumber`, writes
them into the sentence, and then the consumer navigates with
`context.go(_daiAnswer!.route!)` (`global_search_overlay.dart:170`) — **the bare
route constant. Every extracted parameter is discarded.**

Observed pairs:

| Typed | Sentence shown | Where the user actually lands |
|---|---|---|
| `students below 75% attendance` | "Showing students below 75% attendance." | `/sis/students` — **the complete student roster, no attendance filter of any kind** |
| `grade 10 fee defaulters` | "Showing students with outstanding fees for Class 10." | `/finance/defaulters` — every defaulter in the school |
| `class 8a` | "Opening Class 8A students." | `/sis/students` — every student in the school |
| `bus 5` | "Opening transport route 5." | `/transport/routes` — the full route list |
| `receipt 1023` | "Opening fee collections to find receipt 1023." | `/finance/collections` — honest phrasing ("to find"), still unfiltered |

Only the receipt sentence survives, and only because someone chose the verb
"to find" instead of "showing".

The infrastructure to do this properly exists and is used elsewhere:
`teacherAttendanceRouteBuilder` (`app_router.dart:2606`) already reads
`?class=<label>`. DAI simply never passes it.

`lowAttendance` is the release-blocking case: a principal is told a screen is the
below-75% list when it is the whole roster. Attendance shortage drives exam
eligibility and detention notices in an Indian school — this is the register's
"a false claim shown to a user" clause landing squarely on attendance data.
Recorded **P0** as DAI-004.

## 8. `dai_brief.dart` — correctly not shipped

`DaiBriefComposer` has **zero production call sites** (verified: the only
references outside `lib/core/dai/` are none; `dai_brief_test.dart` is the sole
consumer). The file's own header states this and lists four honest reasons.
Spot-checks confirm the header is accurate rather than aspirational:

- `DaiBriefFacts` is 11 bare scalars; nothing computes it. **Confirmed** — no
  producer exists anywhere in `lib/`.
- Route reachability was genuinely fixed: `actionRoute` values are
  `/management/approvals`, `/school/exam-administration`, `/finance/defaulters`,
  `/sis/students`, `RouteNames.managementAnalytics`,
  `RouteNames.substituteManager`, `/hr/employees` — all admin-ERP routes, none
  under `/teacher/`, `/student/` or `/parent/`. **This is exactly the discipline
  the resolver's own routes lack** (DAI-001/002).

**Not shipping this was the right call**, and the header comment is a model of
honest engineering documentation. No defect recorded. Two observations for the
remediation roadmap, not defects:

1. The brief's route hygiene should be back-ported to `dai_resolver.dart` — the
   same class of bug is *live* in the resolver while it is *fixed* in the dormant
   composer.
2. `headline()` returns "Nothing needs your attention this morning." for an empty
   list. On a brand-new school with no data, that reads as an assertion that
   everything was checked and is fine. Worth revisiting when the facts producer
   is built; not a v1.0 defect since nothing renders it.

## 9. Consistency with an already-taken decision

`global_search_registry.dart:193-212` records that on 2026-07-28 the **Parent /
Teacher / Student Dashboard entries were REMOVED** from the search registry —
not gated, removed — with this reasoning:

> "a staff user can never enter `/parent/*` or `/student/*`, and reaches
> `/teacher/*` only when their claims carry `ErpRole.teacher`. Tapping any of the
> three therefore bounced the user to `/admin` … the correct fix is no tile
> rather than a tile that silently bounces."

**The DAI card, rendered directly above that registry in the same sheet, still
does precisely what the registry was cleaned up to stop doing** — for five
intents. The defect class was identified, correctly diagnosed and fixed on one
half of the surface while the other half kept shipping it. That is the strongest
single piece of evidence in this certification: it is not a difference of
opinion about severity, it is the project's own recorded decision, unapplied.

## 10. Defects — summary

| ID | Sev | One line |
|---|---|---|
| DAI-001 | **P0** | "Today's attendance" passes the permission guard, then the router bounces a principal to `/admin`. |
| DAI-002 | **P1** | Four intents with `requiredPermission: null` route outside the admin shell and dead-end. |
| DAI-003 | **P2** | `myFees`/`myAttendance`/`exams(own)` serve personas that can never open the surface. |
| DAI-004 | **P0** | Every extracted filter is discarded on navigation; the answer sentence claims a filter the screen does not apply. `lowAttendance` mis-describes attendance data. |
| DAI-005 | **P1** | `openPerson` — 1 of 12 intents — is structurally unreachable; its answers can never be seen. |
| DAI-006 | **P1** | "Ask anything" hint text over-promises a 40-phrase keyword router. |
| DAI-007 | **P1** | No "I do not handle that" state — 21 of 28 modules fail silently. |
| DAI-008 | **P2** | The 55-confidence floor is unreachable dead code; the documented "never guesses" branch cannot execute. |
| DAI-009 | **P1** | Multi-intent and multi-scope queries silently drop half the question. |
| DAI-010 | **P1** | `staff attendance today` opens *student* class attendance. Wrong module, confident wording. |
| DAI-011 | **P2** | `fee dues class 8` opens a class roster instead of the dues list. |
| DAI-012 | **P2** | Natural attendance phrasings (`who is absent today`, `low attendance students`, `poor attendance`) all fail. |
| DAI-013 | **P2** | Alphanumeric receipt numbers (`RCP-2024-19`) cannot be resolved. |
| DAI-014 | **P3** | No threshold/class range validation — "below 200%", "grade 0", "class 99" accepted verbatim. |
| DAI-015 | **P3** | Person rule caps at 3 tokens and is ASCII-only; 4-part and Devanagari names unresolvable. |
| DAI-016 | **P1** | `_person` is a junk drawer: any unmatched 1–3 word phrase becomes a confident person lookup. |

Full entries with repro/expected/actual/root-cause/fix are in
`docs/certification/DEFECT_REGISTER.md`.

## 11. What is genuinely good

Recorded deliberately, because a certification that only lists faults is not an
assessment:

- **The safety architecture is correct and verified.** Pure, synchronous, no I/O,
  no callbacks, cannot execute. The decision to make this deterministic rather
  than a model is well-argued and well-implemented.
- **Filter-before-render** is the right permission shape and it works — it does
  not leak the existence of a screen the user may not open.
- **Ambiguous names defer to the RBAC-scoped directory** instead of guessing.
- **Injection input is handled**: `DROP TABLE students`, `select * from fees`,
  `<script>alert(1)</script>`, `Rohan; DROP TABLE students` all resolve to
  `unknown` — the `_nonNameTokens` rejection list works as documented.
- **`dai_brief.dart` was correctly withheld**, with the clearest STATUS comment
  in the codebase.

The gap between this layer's engineering quality and its product behaviour is
unusually wide. Nothing here is unsafe. What is wrong is that it tells the user
it did something it did not do, and sends them to screens they cannot open.
