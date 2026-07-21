"""`kie.qie.inventory` — the R4-1 unified certified/verified inventory (manifest + reconciliation).

One reconciled provenance registry across qie.db + qpl_question_bank.db + factory_corpus.db + the frozen-index
crosswalk. NOT a second question bank: product surfaces read QUESTIONS only from qpl_question_bank (RI-6); they
may read THIS manifest for provenance/coverage.

Public surface:
  * `manifest.build()` / `manifest.promotion_counts()` / `manifest.build_fingerprint()`
  * `reconcile.iter_*` (per-source classifiers)
  * `crosswalk.build()` (legacy/topic -> KC_, honest-null unresolved)
  * `register_evidence.register()` (stamp qie.db role='evidence_source' — the one qie.db write)
  * `promote.assess()` / `promote.ri6_followon()`
"""
