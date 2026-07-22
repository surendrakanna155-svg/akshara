"""R5 knowledge-graph derived tables (built ON TOP of the frozen index, never mutating it).

  * prereq_edges  — R5-1 [C13]: prerequisite NAME strings resolved to KC_ concept_ids, honest-null on
    unresolved/ambiguous.
  * namespace     — R5-2 [C14]: the three concept ontologies converged onto the KC_ spine; OCR-junk retired.
  * revisits      — R5-5 [#knowledge-ia-8]: cross-class "revisits/deepens" edges over recurring concept names.
  * evidence_clean — R5-6 [#data-integrity-2]: cleaned evidence_text beside the raw chunk pointer + mangled flag.

Derived, versioned, reproducible; the frozen index / kie.db are opened mode=ro only. Writes only graph_edges.db.
"""
