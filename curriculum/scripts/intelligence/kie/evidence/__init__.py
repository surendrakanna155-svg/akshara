"""Canonical Evidence & Knowledge Governance registry (owner correction 2026-07-14).

The single store-level source of truth for ALL project-owned QIE/curriculum evidence: what exists, where,
what scope, and — critically — WHICH LIFECYCLE STATE it has reached (raw -> ocr -> extracted -> recovered ->
verified -> concept-bound -> QIE-available). This layer sits ABOVE the existing per-file/per-doc manifests
(PROVENANCE_MANIFEST.json, qcorpus corpus_inventory.jsonl, kie.db/qie.db) — it references them, never
duplicates them. Deterministic and re-runnable so the inventory stays current as evidence progresses.
"""
