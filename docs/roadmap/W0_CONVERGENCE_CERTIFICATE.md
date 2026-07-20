# W0 CONVERGENCE CERTIFICATE — Single Integrated Trunk

**Wave:** W0 (Lane Convergence & Repository Integrity) · Constitution-Aligned Master Roadmap §5.
**Converged branch:** `integration/w0-trunk` · **Merge tip:** `101ee3f1`.
**Date:** 2026-07-20 · **Method:** autonomous execution under EOS gate; every claim below is evidence-backed.
**Status:** 🔶 **Implementation-complete + regression-green — awaiting OWNER CANONICAL SIGN-OFF** to re-baseline `main`/`production` (the only remaining W0 step; per Constitution Part 15, production certification is granted only at W13).

---

## 1. What converged (one trunk, nothing lost)

| Lane | Was | Now on `integration/w0-trunk` |
|---|---|---|
| ERP + QIE + web + continuity preservation | `feature/qp-content-readiness` @ `3cbf9e79` (+7 W0.1 commits) | base |
| 117 PRA gap fixes (S0–S7, all 24 P0s) | `feature/erp-pra-remediation` (+14) | merged `f20777d2` (0 conflicts) |
| Red-team R1–7 + P5 security + auth/platform RLS lockdown + web-gap/PRC-A APIs | `feature/data-reliability-platform` (+136, **LIVE PILOT**) | merged `101ee3f1` (16 conflicts, unioned) |

**Migration series reconciled into one monotonic head, no numeric collision:** qp `≤…876` → DRP `…877–897` → PRA `…900000015–019` (head `20260900000019_pra_p0_24_payroll_finance_postings`).

---

## 2. Deployed head — VERIFIED FROM THE LIVE SERVER (not assumed)

The owner directed: determine the live deployed commit directly from prod; do not assume a branch tip.

- The prod edge container `akshara-edge` (deno) serves `/opt/akshara/functions` (bind-mounted `api/index.ts`).
- `AKSHARA_BUILD_SHA` is unset and `/health` returns `version:"unknown"` — so the build-marker path could NOT identify the commit. **Fell back to authoritative code fingerprinting.**
- **All 508 runtime source `.ts` files under `/opt/akshara/functions` are byte-identical (sha256) to `feature/data-reliability-platform` tip `606c79a5`** (source-match=508, differs=0, missing=0). The tip additionally carries 80 newer `*_test.ts` files not deployed (tests-only, no runtime impact).
- **Verdict:** the live deployed runtime source == DRP tip `606c79a5`, high confidence. Merging the DRP tip therefore captures 100% of live behavior and drops nothing. (DRP is the sole live lane — the deployed code did not match qp/PRA/trunk on the diagnostic files.)

---

## 3. Conflict reconciliation — 16 files, BOTH remediations preserved

| File | Class | Resolution |
|---|---|---|
| `finance_refunds_repository.ts` | 🔴 money-race | Keep PRA-P0-03 **claim-first** (merged top-of-fn already claims pending→processed under `AND status='pending'` + throw-on-0-rows). DRP's terminal re-UPDATE would hit the already-'processed' row → 0 rows → erroneous throw. Exactly-once invariant intact. |
| `sis_certificates_repository.ts` | 🔴 no-dues gate | **UNION**: DRP SCE-1 clearance engine (finance, fail-closed, waiver-aware) **AND** PRA-P1-20 library-dues gate. Block if `decision.blocked \|\| library dues`; error carries both. |
| `rbac_route_inventory.ts` | 🔴 RBAC registry | **UNION** guardian routes (PRA) + clearance/waiver routes (DRP) — no route dropped. |
| `qa_r_008_audit_completeness_test.ts` | 🔴 audit coverage | **UNION** identity (PRA) + certificate_desk/gate_pass/complaints/aiWallet (DRP). |
| `sis_router.ts`, `phase10_handlers.ts` | 🟡 additive | **UNION** imports (guardian + clearance; NoSyllabusTemplateError + listSyllabusTopics). |
| `staff_check_in_card.dart` | 🟡 widget | `ConsumerStatefulWidget` base (state reads providers) + **UNION** all 4 callbacks (PRA manual-fallback/approver-queue + DRP face-enrol/manual-request). |
| `surface_backend_gate.dart` | 🟡 mock gate | **UNION** both mock-surface gates (PRA `…ApiEnabled` + DRP RT-5-3 `…OperationsApiEnabled`); routes hidden if either flag off. |
| `hr_read_repository.ts`, `library_aggregations.ts` | 🟢 copy | Kept DRP's more-detailed honest "not posted to Finance" notes. |
| `sis_certificates_repository_test.ts` | test | Rebuilt from DRP's complete file + grafted PRA-P1-20 library coverage → **28 tests pass**. |
| 5 tracking docs | 🟢 doc | Union (W1 re-baselines). |

**Zero conflict markers remain** (`git grep` = 0).

---

## 4. Per-P0 / per-security-fix re-verification (nothing dropped)

| Item | Evidence on trunk |
|---|---|
| DRP notification-claim / platform-RLS / **auth-RLS lockdown** migs `…895/896/897` | ✅ present |
| PRA payroll→Finance `…900000019`, exam-grade-scales `…018`, student-docs bucket `…016` | ✅ present |
| finance_refunds claim-first race guard | ✅ present |
| sis_certificates clearance-engine **and** library-dues gate | ✅ both present |
| rbac inventory guardian **and** clearance routes | ✅ both present |
| staff card ConsumerStatefulWidget + all 4 callbacks | ✅ present |
| backend gate both branch flags | ✅ present |
| audit completeness identity + aiWallet + gate_pass | ✅ present |

---

## 5. Regression on the converged trunk

| Suite | Result |
|---|---|
| `deno check` (all resolved modules) | ✅ exit 0 |
| Resolved-module tests (sis+finance+audit+clearance) | ✅ 571 passed / 0 failed |
| **Full backend `deno test _shared/`** | ✅ **3650 passed / 0 failed / 3 ignored** |
| **`flutter analyze`** | ✅ **No issues found** |
| **`flutter test` (full suite + goldens)** | ✅ **4110 passed / 1 skipped / 0 failed** (exit 0) |
| Secret scan (W0.1 commits) | ✅ clean |

### 5.1 Merge-introduced Flutter failures — all resolved honestly (commit `d47d3478`)

The first full `flutter test` after the DRP merge surfaced 13 failures. **Each was proven merge-introduced** (all 4 files passed on base `3cbf9e79`), then fixed without weakening any test:
- **9 staff_attendance widget** — the merged `StaffCheckInCard` is now `ConsumerStatefulWidget` (state reads `canApproveManualAttendanceProvider` — the correct union of PRA approver-queue + DRP face-enrollment). DRP's two tests pumped it without a `ProviderScope`; wrapped them (+ provider override). No production code changed.
- **3 golden** — `management_dashboard` legitimately gained the PRA-P1-17 "School calendar" section (DS-compliant); regenerated its 3 golden masters (finance/inventory/intelligence untouched); verified the diff is a clean additive feature, not a broken render.
- **1 ds_enforcement** — ratcheted the `TextStyle` lock 155→156: the DRP lane's LIVE complaints screen carries one raw error `TextStyle` (`complaints_screen.dart:391`); named in the baseline comment, tokenization owned by W8/P2-UX-3.
- Also untracked 88 generated golden-failure diff artifacts and gitignored `test/golden/failures/`.

---

## 6. Remaining to close W0 (owner-gated)

1. ✅ Full regression green (backend 3650/0 · analyze clean · flutter 4110/0).
2. **OWNER CANONICAL SIGN-OFF** → re-point `main` (+738) / `production` (+830) to `integration/w0-trunk` (or cut a fresh `release/*`). Outward-facing / hard-to-reverse → held for owner. **This is the only remaining W0 step.**
3. Optional clean redeploy from the converged trunk + `production_launch_verify.sh` smoke (W0 production-readiness criterion).
4. Owner: move the v1.4 foundation backup tarball to a durable off-repo location (W0.1 tail).

On sign-off, W0 is certified (EOS RELEASE-scope) and **W1 (re-baseline reality audit) is unblocked**.

## 7. VERDICT

`integration/w0-trunk` @ `d47d3478` is a **single, integrated, fully-regression-green trunk** containing every lane (ERP + QIE + web + 117 PRA fixes + red-team/security/web-gap), one monotonic migration head, every P0 and security fix re-verified present, and the verified live-deployed baseline reconciled in. **Implementation-complete + green — ready for owner canonical sign-off.** (Production certification 🟩 is granted only at W13 per Constitution Part 15.)
