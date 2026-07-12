"""Quality Intelligence Engine (QIE) — the OFFLINE quality layer.

Distinct from `kie.qpgen` (the frozen runtime paper engine). QIE holds the Question-DNA / Item-Model /
Knowledge-Verification-Substrate foundations from the quality-first architecture
(docs/question-intelligence-quality/). Phase A builds the substrate; it does NOT change qpgen behavior and
uses its OWN local store (`qie.db`), separate from the certified `kie.db`.

Deterministic + stdlib-only. Derived knowledge is LOCAL-ONLY (gitignored); only code/schema/tests are committed.
"""
