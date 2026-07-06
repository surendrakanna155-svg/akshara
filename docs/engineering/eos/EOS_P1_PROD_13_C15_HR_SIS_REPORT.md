# EOS Report — P1-PROD-13 · C15 HR & SIS productivity

- **Date:** 2026-07-06
- **Commit:** `4b65ce1`
- **Scope:** FEATURE (HR/SIS) — C15 (HR-3, HR-4, HR-7, SIS-2, SIS-5)
- **Verdict:** **PASS** — closes a leave separation-of-duties control gap; no automatic-failure condition.
- **Standard:** `docs/engineering/AKSHARA_ENGINEERING_CONSTITUTION.md` (Part 7B / Part 8). Not restated here.

---

## 1. Method — multi-agent, discovery-first

Two disjoint modules (HR, SIS) → parallel read-only discovery (one agent each),
then parallel implementation under **disjoint file ownership**: HR-3 SoD by the
main loop (HR backend), SIS-2/5 by a delegated implementation agent (all SIS
files). `qa_test_keys.dart` was touched only by the SIS side and
`hr_write_handlers.ts` only by the HR side — no shared-file contention, honouring
the agent-orchestration file-ownership rule.

## 2. Per-item outcome

| Item | Verdict | Evidence |
|---|---|---|
| **HR-3** batch leave approve/reject | **Verified built + SoD gap closed** | own `/hr/leave/batch-decide` (`handleBatchDecideLeave`) + multi-select UI + per-decision audit + partial success. §3. |
| **HR-4** leave-balance report/export | **Verified built** | `handleLeaveBalances`/`buildLeaveBalanceReport`; `HrReportExporters.shareLeaveBalancesCsv/Pdf`. |
| **HR-7** employee directory export | **Verified built** | `handleEmployeeDirectory`; `HrReportExporters.shareDirectoryCsv/Pdf`. |
| **SIS-2** richer registry + class-list/contact-sheet | **Verified (registry) + gaps closed** | §4. |
| **SIS-5** transfer/exit log | **Verified built + reason added** | §4. |

## 3. HR-3 — leave separation-of-duties (owner-decided)

**Owner decision (2026-07-06): DENY self-approval of leave.** The batch feature
was already complete, but leave decisions performed **no** approver-vs-requester
check, and `staffLeave`/`studentLeave` are absent from the C10
`SELF_APPROVE_DENIED_TYPES`. A leave request records `createdBy` (the acting
filer) in the **same auth-`sub` identity space** as the approver, so:

- `applyLeaveDecision`/`applyBatchLeaveDecision` gained an `actorUserId` param.
- When a request's `createdBy === actorUserId`, the single path raises **403
  `LEAVE_SELF_APPROVE_DENIED`**; the batch path **skips** it (partial success),
  the rest of the batch still decides.
- Backward-compatible: legacy rows without `createdBy` (or an empty actor) are
  unaffected, and existing 4-arg call sites keep passing.
- Mirrors the C10 money maker-checker (approver ≠ requester).

## 4. SIS-2 / SIS-5 (delegated, then reviewed)

- **SIS-2** — the richer registry export already existed (incl. guardian
  name/phone). Added two dedicated artifacts on the shared XCT-1 grid:
  a **class-list** export (roster) and a **parent contact-sheet** export, with
  registry-screen buttons (Row→Wrap to fit six buttons) + QA keys.
- **SIS-5** — the transfer/exit log existed and exported, but had no **reason**.
  Added it via a **read-only correlated sub-select** to the latest
  `sis_certificate_issues` transfer-certificate `reason`
  (`certificate_type='transfer'`, `ORDER BY issued_at DESC LIMIT 1`,
  org/school-scoped, null when no TC). No new write path or migration. Threaded
  through the API mapper → `SisTransferRecord.reason` → client mapper → a
  "Reason" column on the transfers exporter → a per-row subtitle.

**Review of the delegated diff (I own the quality):** independently verified the
SIS-5 join's table/column/type against `sis_certificates_repository.ts`
(`sis_certificate_issues`, `certificate_type='transfer'`, `reason`, `issued_at`
— all correct); confirmed the transfers screen test was **strengthened** (7→8
columns + a populated-reason case), not weakened; re-ran the SIS deno suite
myself rather than trusting the agent's report.

## 5. Regression evidence

- `flutter analyze` → **0 issues**.
- Full `flutter test` → **no NEW failures** (2 known UX-7 `TeacherDashboardScreen`
  overflow, unrelated).
- `deno test` HR → **90 / 0**; SIS → **139 / 0 + 1 pre-existing failure**.
- The single SIS failure is `sis_probe_validation_test.ts` (tenant-isolation
  **probe count**) — the tracked `ISO-COUNT` defect; neither change touched
  `tenant_isolation_probes.ts`, and it reproduces with the changes stashed.
- `deno check` on all touched `supabase/functions/**` → green.
- New tests: **~11** — HR SoD single ×4 + batch ×1; SIS class-list/contact-sheet
  row builders + button render; transfers Reason column ×2; backend join test.

## 6. Tripwire check

No automatic-failure condition: the leave-SoD change **closes** an
escalation-adjacent control gap (like C10); no data loss, no tenant-isolation
regression (the probe-count failure is pre-existing), exports are read-only, and
the SIS-5 join is read-only + tenant-scoped with no new PII. **PASS.**

## 7. Next

C16 — Transport & Inventory productivity (TRN-5/6/7/8, INV-3/4/5/6/7). Disjoint
modules again (Transport ∥ Inventory) → parallel-agent-eligible. Inventory
value-reducing moves stay maker-checker per the stock-governance decision.
