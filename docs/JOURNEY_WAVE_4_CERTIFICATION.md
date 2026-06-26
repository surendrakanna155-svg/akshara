# AKSHARA — Journey Wave 4 Completion Certification

**Status:** ✅ **PRODUCTION CERTIFIED (2026-06-27) — live 28/28**
**Wave:** MODULE_JOURNEY_ROADMAP **Wave 4** — "Build missing write surfaces & orphaned-feature wiring — complete partial modules and surface hidden paid features."
**Scope source of truth:** `docs/MODULE_JOURNEY_AUDIT.md` (issue IDs) + `docs/MODULE_JOURNEY_ROADMAP.md` (Wave 4). No new features, no roadmap expansion — this only closes the audit's Wave-4 findings.
**Live cert:** `scripts/qa/live_cert_journey_wave4.py` → **28/28** against the live VPS pilot (`https://akshara.veloraunisexsalon.com`) with real pilot OTP auth (admin JWT), an edge-minted org-scope JWT (Org Builder), real RBAC, real DB rows, real write→read cycles, and a **real Supabase Storage object upload + signed-URL download**.

---

## 1. Verdict

**PRODUCTION CERTIFIED.** All **12 Wave-4 findings** (1 Critical, 6 High, 5 Medium across the roadmap table) are closed at the true root cause. The wave's theme — *modules that were read-only, orphaned, or whose write succeeded but went nowhere* — is resolved: every newly-built write now persists and is reachable, and every orphaned-but-certified surface is now wired into the app.

This wave was executed in two sub-batches:
- **Wave 4A (client-only, 5 items):** MJ-C9 (inventory vendor-create UI + real-vendor PO picker — removes the hardcoded `vendor_if_1`), MJ-H23 (Employee Platform nav entry), MJ-H24 (Promotion Center / Holiday Calendar / Meta-connect nav surfaces), MJ-M5 (unified onboarding wizard nav), MJ-M8 (HR leave/create-employee dialogs now honor user input).
- **Wave 4B (backend write surfaces, 7 items — this certification):** executed by **six parallel agents over disjoint backend modules** (transport, hostel, library, alumni, organization_builder, admissions), then integrated, gated, deployed, and live-certified centrally.

**The live cert caught three real defects the offline gates could not — all fixed and re-certified to 28/28:**
1. **Transport allocation `POST /transport/allocations` returned HTTP 500 — `duplicate key value violates "transport_entities_pkey"`.** The SIS-identity handoff change kept an `INSERT` while the assign flow targets an **existing** unassigned allocation row → PK collision. Fixed to upsert (find → `replace` or `insert`), mirroring the already-correct attendance handler. Mock unit tests passed because a fake DB does not enforce the PK.
2. **All Supabase Storage signed URLs were built with the internal `:8080` gateway port** (`https://akshara.veloraunisexsalon.com:8080/storage/...`), which is unreachable over TLS → admissions upload/download failed. Root cause: the shared `toPublicStorageUrl` set `URL.host = base.host`, and the **WHATWG `host` setter does not clear an existing port when the new value has none**. Fixed to set `hostname` + `port` separately. **This also fixes the device-memories module**, which shared the same helper.
3. **Org Builder provisioning correctly rejected an empty organization name** (`organization name is required`) — confirming the new validation works; the cert's interview step was corrected to set the name via the real answer keys. The SECURITY DEFINER function itself was proven to create real tenant rows.

**The offline flutter gate caught four 1.7–157px RenderFlex overflows** introduced by the new action buttons (transport `Mark`, hostel `Mark roll-call`, library/alumni two-button headers) — all fixed to the app's single-compact-action convention before deploy.

**Deploy:** 2 forward-only migrations applied + ledgered to the live DB; 21 edge `_shared` files synced to the VPS bind-mount (`/opt/akshara/functions/_shared`), edge recreated (`--no-deps`), `/health` ok. Encrypted backup taken before any DB change.

---

## 2. Gate results

| Gate | Result | Baseline | Δ |
|------|--------|----------|---|
| `flutter analyze` | **0 issues** | 0 | — |
| `flutter test` | **2416 passed / 1 skipped / 0 failed** | 2389 | **+27 Wave-4 widget/contract tests**, no regression |
| `deno test _shared/` | **825 passed / 0 failed / 2 ignored** | 790 | **+35 new Wave-4 backend tests** |
| Patrol (emulator) | smoke **2/2** ✅ · navigation **4/5** (1 pre-existing auth OTP-back failure, out of scope) | — | app builds + launches; all 4 module-nav tests pass |
| Live cert (`live_cert_journey_wave4.py`) | ✅ **28/28** vs live VPS pilot | — | real OTP auth + org-JWT + RBAC + write→read + real Storage object |

The +35 deno tests are write-handler RBAC/validation + read-recompute unit tests across the six modules (transport upsert/notify-delay, hostel attendance+mess recompute, library member/fines/resource, alumni donation→campaign, org-builder real-provision success+failure, admissions storage path + hasFile). **Note:** mock-DB unit tests cannot reproduce Postgres PK/grouping semantics or real Storage — the **live cert is the authoritative gate** (it caught the allocation PK 500 and the `:8080` Storage bug the unit tests passed over).

---

## 3. Item-by-item closure (Wave 4B backend)

| ID | Module | Sev | What was missing/broken | Fix | Live evidence (28/28) |
|----|--------|-----|----------|-----|----------|
| **MJ-H19** | Transport | 🟠 High | `POST /transport/attendance` deployed but **zero client wiring**; attendance screen read-only. | `recordAttendance` repo/datasource + mutations provider + per-row mark control (gated `manageTransport`); read already lists live `attendance` entities. | `POST` 201 → `GET /transport/attendance` reflects the row (write→read). |
| **MJ-M9** | Transport | 🟠 High | Assign sent no student identity (server stored `""`); SIS transport-flag never written; no delay-notify. | Allocation now carries `studentName`/`admissionNumber`/`sisStudentId` + idempotent `transportEnrolled` flag (Student-360 overlay matches it back — no `students`-table mutation); new `POST /transport/notify-delay` reuses the certified broadcast pipeline. | `notify-delay` 200 with `recipientCount`; allocation 201 with real SIS identity. |
| **MJ-H20** | Hostel | 🟠 High | Attendance + mess were read-only with **no POST route**. | New `POST /hostel/attendance` (lists live) + `POST /hostel/mess`; `handleMess` now **recomputes** weekly menu / MTD cost from live `mess_record` entities (seed fallback for fresh schools). | Both `POST` 201 → respective `GET` reflects the write. |
| **MJ-H21** | Library | 🟠 High | Issue/return used **mock seed IDs** (garbage member); no member-enroll; fines read-only; resources stored no file. | New `POST /library/members`; **issue now validates the member exists (404 on garbage — no phantom loan)** + activeLoans inc/dec; return persists a `fine` entity + `POST /library/fines/:id/waive`; digital resource stores a real, retrievable URL. | member enroll 201 + listed; garbage-member issue **404**; resource stores real URL. |
| **MJ-H22** | Alumni | 🟠 High | **No donation write path** at all; campaign totals were seeded constants. | New `POST /alumni/donations` (lists live) that also increments the linked campaign's `raisedAmount` + `donorCount` in one tenant transaction. | donation 201 + on ledger; campaign raised `25000→50000`, donors `1→2`. |
| **MJ-M6** | Org Builder | 🟠 High | Provisioning was a documented stub — UI claimed success but **no real tenant rows** were created. | New SECURITY DEFINER `org_builder_provision_tenant` creates **real** `organizations`+`schools`(+roles/permissions/membership), idempotent per draft, true per-step outcomes, failure→`failed` job with rollback; poller now also stops on `failed`. | provision job `completed`; **real org + branch rows created**; re-provision idempotent (1 org). |
| **MJ-M7** | Admissions | 🟡 Medium | Document upload stored **metadata only** — nothing retrievable. | Real Supabase Storage: presign → direct PUT → confirm stores the object on a tenant-isolated `admissions-documents` bucket; download returns a signed URL; `hasFile` surfaced. Reuses the Batch-7 memories storage foundation. | presign→PUT(200)→confirm(201)→`hasFile=true`→**download URL serves the file (45 bytes)**. |

Wave 4A items (MJ-C9, MJ-H23, MJ-H24, MJ-M5, MJ-M8) were completed client-side in the same branch (verified by `flutter analyze`/`flutter test` and the router smoke suite; MJ-C9's create-PO no longer sends the mock `vendor_if_1`).

---

## 4. What was built — backend, migrations, persistence

**Migrations (2, forward-only, applied + ledgered on the live DB):**
- `20260806000010_wave4_org_builder_real_provisioning.sql` — `org_builder_pack_roles` blueprint table (12 rows, RLS, org-scope read) + 9 vertical `role_definitions` + the SECURITY DEFINER `org_builder_provision_tenant(...)` (EXECUTE granted only to `erp_tenant`). Idempotent INSERT/UPDATE-only; respects the `erp_tenant` no-DELETE constraint.
- `20260806000020_wave4_admissions_documents_bucket.sql` — private `admissions-documents` Storage bucket (25 MiB, PDF/image MIME allowlist) + 4 tenant-isolating `storage.objects` policies + `admissions_documents.storage_path` column.

**Persistence model:** transport/hostel/library/alumni writes use the existing per-module JSONB entity stores (`*_entities` tables, school-scope RLS) — **no migration needed** for those; new `entity_type`s (`attendance`/`mess_record`/`member`/`fine`/`donation`) just insert rows the live reads already aggregate. Org Builder writes the real tenant tables via the privileged function. Admissions stores a real object in Storage with the path linked on the document row.

**Storage object-path scheme:** `{organization_id}/{school_id}/{lead_id}/{uuid}_{filename}` — tenant-prefixed, mirroring device-memories; access is service-role-mediated via short-lived signed URLs.

---

## 5. Out of scope (correctly deferred, not regressions)

Per the roadmap, the following remain on **Wave 5** (RBAC hardening / error-state UX / test-gate parity) and are not Wave-4 regressions: MJ-M12 (client↔router path-parity contract tests), MJ-M10/M11 (teacher/attendance granular permission gates), MJ-L2/L4/L5/L3/L6/L7/L8. Transport TR-06 live-GPS map is hardware-dependent and intentionally not built; the certifiable **delay-notification** half of MJ-M9 is delivered.

The admissions Storage upload path is real and retrievable end-to-end; wiring an OS file-picker (the project has no `file_picker`/`image_picker` dependency, the same gap device-memories has) is an isolated client follow-up — the current path uploads a real, valid document object, not a stub.

---

## 6. Live cert evidence (28/28)

```
Journey Wave 4: 28/28 checks passed
  health · admin OTP auth
  MJ-H19 attendance persists + read reflects
  MJ-M9 notify-delay cohort broadcast + allocation SIS identity
  MJ-H20 hostel attendance + mess write→read
  MJ-H21 member enroll + listed · garbage-member issue REJECTED · resource real URL
  MJ-H22 donation recorded + ledger + campaign raised/donors incremented
  MJ-M6 org-JWT · provision completed · REAL org + branch rows · idempotent re-provision
  MJ-M7 presign · PUT to Storage · confirm · hasFile=true · download serves the file
```

Run: `python3 scripts/qa/live_cert_journey_wave4.py` against `https://akshara.veloraunisexsalon.com`.
