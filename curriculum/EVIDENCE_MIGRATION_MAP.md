# Akshara — Evidence Migration Map (old-path → canonical-path)

**Date:** 2026-07-14 · **Companion to** `EVIDENCE_REGISTRY.json` / `.md`.
**Decision: NO physical files were moved.** Logical canonical identities are established now (in the registry);
the physical relocation is **deferred** with this deterministic map, because active code and the in-flight
governed-conversion + qpgen product path hard-reference the current physical paths. This follows the owner's
Safe-Migration Rule: *establish canonical logical identities now; document the target layout; keep
compatibility; defer only the unsafe physical moves to a safe checkpoint.*

## Why physical moves are deferred (proof of dependency)
Moving these paths would break running code with zero benefit to the conversion in flight:

| Current path | Hard-referenced by | Effect of a naive move |
|---|---|---|
| `staging/qcorpus_noncert/` | `kie/qie/qcorpus_adapter.py` (`STAGING_ROOT`), `scripts/staging/qcorpus/config.py` | Governed conversion loses its entire input corpus |
| `resources/foundation/Cursor_Downloads/` | `scripts/staging/qcorpus/config.py` (`SOURCE_ROOT`), `scripts/acquisition/sequential_board_fetch.py` | qcorpus re-extraction + acquisition break |
| `resources/foundation/` | `kie/config.py` (`CORPORA`), `repository_verifier.py`, `intake/detect.py` | KIE ingestion + verification break |
| `resources/curriculum/{cbse,ap}/` | `scripts/staging/board_curriculum/config.py`, `scaffold_workspace.py` | Board staging breaks |
| `knowledge/kie/{kie,qie}.db` | `kie/config.py`, `kie/store.py`, `kie/qie/store.py` | Both knowledge substrates break |

The registry's `canonical_id` (e.g. `STG_QCORPUS`, `RAW_CURSOR_DOWNLOADS`) is the **stable logical identity**
that survives any future relocation — code and reports should refer to stores by canonical_id, resolved to a
physical path through one function, so a later move is a one-line change, not a hunt.

## Target canonical physical layout (deferred)
Derived from the current architecture (lifecycle-first, indexable by scope/exam/class/subject/doc/concept):

```
curriculum/
  raw_sources/           # was resources/foundation + resources/curriculum (in-scope) + Cursor_Downloads
    foundation/          #   JEE/NEET/NCERT-STEM (RAW_FOUNDATION, RAW_CURSOR_DOWNLOADS)
    ncert_cbse/          #   NCERT/CBSE 6-12 STEM (RAW_CURRICULUM_CBSE, in-scope subset)
  ocr/                   # was knowledge/kie/parsed + staging/*/normalized
  extracted/             # was staging/qcorpus_noncert (manifests + extracted questions)
  recovered/             # NEW — notation-recovery outputs (quantitative relations)
  verified_knowledge/    # was knowledge/kie/{kie,qie}.db (the governed substrate)
  quarantine/            # was resources/archive/*, downloads/{duplicates,failed}
  held/                  # was resources/curriculum/{ap,telangana,icse}, archive/NCERT_non_stem
  manifests/             # was PROVENANCE_MANIFEST.json, indexes/, reports/, discovery/ (git-tracked)
```

### old → canonical mapping (by canonical_id)
| canonical_id | current physical path | target physical path |
|---|---|---|
| RAW_FOUNDATION | `resources/foundation` | `raw_sources/foundation` |
| RAW_CURSOR_DOWNLOADS | `resources/foundation/Cursor_Downloads` | `raw_sources/foundation/cursor` |
| RAW_CURRICULUM_CBSE | `resources/curriculum/cbse` | `raw_sources/ncert_cbse` |
| RAW_CURRICULUM_AP/TS/ICSE | `resources/curriculum/{ap,telangana,icse}` | `held/{ap,telangana,icse}` |
| STG_QCORPUS | `staging/qcorpus_noncert` | `extracted/qcorpus` |
| STG_BOARD_CURRICULUM | `staging/board_curriculum` | `ocr/board_curriculum` |
| KDB_KIE / KDB_QIE | `knowledge/kie/{kie,qie}.db` | `verified_knowledge/{kie,qie}.db` |
| KDB_PARSED | `knowledge/kie/parsed` | `ocr/parsed` |
| ARCH_* / DL_* | `resources/archive/*`, `downloads/*` | `quarantine/*` |
| GOV_* | `PROVENANCE_MANIFEST.json`, `indexes/`, `reports/`, `discovery/` | `manifests/*` |

## Safe-move procedure (execute only at the deferred checkpoint)
1. Land a `store_path(canonical_id)` resolver + update all hard-coded paths to call it (compat shim: resolver
   returns the OLD path until the move flag flips).
2. Move ONE store, re-run `python -m kie.evidence.registry`, run the full `kie` test suite + a qp_bridge
   smoke — prove green — before the next store.
3. Preserve gitignore behavior (all raw/derived bulk stays local-only; only manifests/DBs-schema tracked).
4. De-duplicate `downloads/duplicates` + `resources/archive/duplicates` against `indexes/duplicate_map.json`
   by sha256 **only after** the registry confirms every kept copy has a live canonical source.

## What is safe to do now (and was done)
- Canonical registry + lifecycle state established (`EVIDENCE_REGISTRY.*`) — the source of truth.
- No bytes moved; no active pipeline touched; governed conversion proceeds on current paths.
