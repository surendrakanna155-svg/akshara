"""Program D — QIE → ERP certified-bank export lane (OFFLINE, AI-free at request time).

This package is the OFFLINE bridge between the QIE certified question bank
(qpl_question_bank.db, Python/SQLite) and the ERP Education Suite
(Supabase/Postgres). It is deliberately one-directional and read-only on the
certified bank:

    corpus.certified_bank()  ──(deterministic, read-only)──►  export artifact
    (certified/certified only)                                 (JSON manifest + rows)

Nothing here judges, certifies, generates, or mutates the certified bank. It
only reads already-certified rows and emits a versioned, freeze-pinned artifact
the ERP importer ingests. See docs/roadmap/PROGRAM_D_IMPLEMENTATION_BLUEPRINT.md.

Modules:
  * fixtures     — deterministic synthetic certified-bank generator (TEST-ONLY),
                   so the whole pipeline is buildable before a real bank fills.
  * erp_promote  — the deterministic exporter (M1.2).
  * manifest     — the freeze-pinned export manifest (M1.2 / D4).
"""
