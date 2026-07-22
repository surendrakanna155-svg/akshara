# Program D — certified-bank test fixtures

**TEST-ONLY.** Nothing here is reachable from a production/edge code path.

Program D's stated precondition is a **non-empty certified bank**, which is empty today (the primary
*operational* blocker — see `docs/roadmap/PROGRAM_D_ENGINEERING_READINESS_REPORT.md` §1.4). These fixtures
decouple **construction** from **data supply**: the whole promotion → import → retrieval → assembly
pipeline is buildable and testable against synthetic certified content before any real certified item
exists.

## Files

| File | What it is |
|---|---|
| `certified_corpus.json` | The golden corpus: **12 deterministic** QIE-native certified rows (`make_certified_fixture(12, 0)`). |
| `certified_corpus.ts` | Typed Deno loader (`certifiedCorpus`, `CertifiedFixtureRow`) — the single import point for ERP-side tests. |
| `certified_corpus_test.ts` | ERP-side conformance test (loads + validates the corpus from the Deno runtime). |

## Source of truth & regeneration

The corpus is **generated**, never hand-edited. Its generator is
`curriculum/scripts/intelligence/kie/qie/export/fixtures.py` (`make_certified_fixture`). A Python drift
guard (`kie/tests/test_export_fixtures.py::GoldenCorpus`) fails if this JSON and the generator ever
diverge. To regenerate after a deliberate generator change:

```bash
cd curriculum/scripts/intelligence
../../.venv/bin/python -c "import json; from pathlib import Path; from kie.qie.export import fixtures as F; \
Path('../../../supabase/functions/_shared/education/__tests__/fixtures/certified_corpus.json')\
.write_text(json.dumps(F.make_certified_fixture(12, 0), indent=2, ensure_ascii=False, sort_keys=True) + '\n')"
```

Then re-run both suites:

```bash
cd curriculum/scripts/intelligence && ../../.venv/bin/python -m unittest kie.tests.test_export_fixtures
deno test --allow-env --allow-read supabase/functions/_shared/education/__tests__/fixtures/
```

## Shape note (QIE-native, pre-export)

The corpus is in the **QIE certified-bank shape** — `question_type='MCQ'`, `intended_difficulty ∈
{easy,moderate,hard}`, `concept_code = KC_<sha14>`. The **M1.2 exporter** maps this to the ERP
platform-bank shape (`mcq`, `medium`, concept UUID, content-hash id) at the offline boundary. ERP tests
that need the mapped shape consume the exporter's artifact; this raw corpus is the shared upstream input
and the near-dup source pairs for M4.3 (two items sharing a skill template are a natural paraphrase pair).

## Isolated test tenant

Live ERP promotion/RLS/exposure tests (from M1.3 onward) run against the isolated
`akshara_tenant_test` clone on the VPS (owner-gated, `scripts/qa/run_tenant_isolation_enforced.sh`) or a
per-test in-memory `FakeDb` that routes the exact SQL under test — never a production tenant.
