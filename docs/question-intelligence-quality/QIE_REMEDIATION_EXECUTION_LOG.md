# QIE/QDI Remediation — Execution Log

**Session:** dedicated QIE/QDI remediation · **Started:** 2026-07-21 · **Branch:**
`feature/qie-question-planning-layer`

**SSOT:** [`QIE_REMEDIATION_ROADMAP.md`](QIE_REMEDIATION_ROADMAP.md) (the audit is permanently
closed; this log records execution only, it never re-plans).

This log is the running record of what has actually been implemented, verified, tested,
certified, documented, and committed — one row per roadmap item.

---

## ⛔ ACTIVE GOVERNANCE HALT (R0-3)

**No new certification runs until Phase R1 exits.** In force since 2026-07-21.

Specifically prohibited until every R1 item (R1-1…R1-5) has landed and the permanent
invariant suite (RI) is green:

- ❌ `certify_run` / any `status → 'certified'` transition in the factory lane
- ❌ `--register` / `--apply` conversions (governed facts, relations, topics, chains)
- ❌ QDI pattern certification (`ingest_qdi_audit`)
- ❌ any new KIE index freeze / version promotion

Rationale (audit): today's gates verify self-consistency, not truth; the replay bypass is
proven; QDI provenance is false; the frozen-substrate evidence has drifted. Certifying
anything on the current machinery would mint more un-trustworthy "certified" artifacts.
The halt lifts automatically when R1 + RI are complete and this log records the exit.

---

## Progress ledger

Legend: ✅ done (committed) · 🔵 in progress · ⏸ owner-gated (prepared, not executed) ·
⏳ blocked (external dep) · ⬜ not started

### Phase R0 — Immediate safeguards

| Item | State | Commit | Notes |
|---|---|---|---|
| R0-1 Off-machine backup | ✅ / ⏳ owner tail | `00508275` | Encrypted, restore-verified backup tooling built + proven (fingerprint EXACT MATCH `e3a146f3…`). 3 previously-unbacked DBs now copied into the archive. **Owner/external tail:** provide an off-machine `AKSHARA_BACKUP_DEST` + passphrase and install the LaunchAgent (README). |
| R0-2 Quarantine 22 + 7 | ⏸ owner-gated | — | Guarded quarantine script prepared + dry-run-verified; **execution is an explicit OWNER decision** (roadmap tags it so). Not flipped. |
| R0-3 Halt cert runs | ✅ | (this doc) | Halt recorded above + handoff banner. |
| R0-4 Directory hygiene | ✅ | `d45a03f9` | Stray qie.db deleted; backups relocated + chmod a-w; wal/shm gitignored; `assert_under_kie_home()` added. |

### Phase R1 — Certification integrity (closes the 4 P0s) — HALT gate

| Item | State | Commit | Notes |
|---|---|---|---|
| R1-1 Blocking grounding gates | ⬜ | — | brief ready |
| R1-2 Append-only cert records | ⬜ | — | brief ready |
| R1-3 QDI provenance truth | ⬜ | — | brief ready |
| R1-4 Content-addressed evidence | ⬜ | — | brief ready |
| R1-5 Enforce the freeze | ⬜ | — | brief ready |
| RI  Invariant suite | ⬜ | — | built alongside R1–R3 |

*(Later phases R2–R6 tracked in the roadmap; rows added here as they are executed.)*

---

## Owner-decision / external-dependency queue (surfaced, not auto-run)

1. **R0-1 off-machine target** *(external)* — provide `AKSHARA_BACKUP_DEST` on an
   off-machine volume + passphrase; install the daily LaunchAgent.
2. **R0-2 quarantine execution** *(owner)* — approve flipping the 22 factory questions +
   7 QDI patterns `certified → quarantined`. Script is ready (`quarantine_audited_estate.py`,
   dry-run verified); it uses guarded transitions and preserves prior state.
3. Downstream owner-gated items (R4-1 lane reconciliation, R5-3 ERP promotion, all of R6)
   remain in the roadmap; not reached yet.
