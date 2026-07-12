"""Phase B10 — governed Biology concept/entity resolution tests (precision + no-forcing guards)."""
import sqlite3
import unittest

from kie.qie import bio_resolve


def _kie():
    """In-memory kie.db with the canonical Biology concepts the lexicon targets (active)."""
    c = sqlite3.connect(":memory:")
    c.execute("CREATE TABLE concepts(concept_code TEXT, title TEXT, subject_domain TEXT, status TEXT)")
    rows = [
        ("BIO_HUMAN_ENDOCRINE_SYSTEM", "Human Endocrine System"),
        ("BIO_EXCRETORY_SYSTEM_IN_HUMANS", "Excretory system in humans"),
        ("BIO_PHOTOSYNTHESIS_FOODMAKING_PROCES", "Photosynthesis Foodmaking Process"),
        ("BIO_NEURAL_CONTROL_ANDCOORDINATION", "Neural Control And coordination"),
        ("BIO_MITOCHONDRIA", "Mitochondria"),
        ("BIO_CELL_STRUCTURE_AND_FUNCTIONS", "Cell: Structure and Functions"),
        ("BIO_HUMAN_REPRODUCTION", "Human Reproduction"),
        ("BIO_RESPIRATION_THE_ENERGY_RELEASING", "Respiration The Energy Releasing"),
        ("BIO_MOLECULAR_BASIS_OFINHERITANCE", "Molecular Basis Of inheritance"),
        ("BIO_GENETIC_DISORDERS", "Genetic Disorders"),
        ("BIO_DIGESTION_IN_HUMANS", "Digestion in Humans"),
        ("BIO_IMMUNITY", "Immunity"),
        ("BIO_HUMAN_RESPIRATORY_SYSTEM", "Human Respiratory System"),
        ("BIO_CIRCULATORY_SYSTEM", "Circulatory System"),
    ]
    for code, title in rows:
        c.execute("INSERT INTO concepts VALUES (?,?,?,?)", (code, title, "Biology", "active"))
    c.commit()
    return c


class TestBioResolve(unittest.TestCase):
    def setUp(self):
        self.k = _kie()
        self.r = bio_resolve.build_resolver(self.k)

    def test_specific_entity_resolution(self):
        self.assertEqual(self.r("Hypoglycemic hormone is", "Insulin", "Biology"), "BIO_HUMAN_ENDOCRINE_SYSTEM")
        self.assertEqual(self.r("The basic functional unit of the human kidney is", "nephron", "Biology"),
                         "BIO_EXCRETORY_SYSTEM_IN_HUMANS")
        self.assertEqual(self.r("End product of glycolysis is", "Pyruvate", "Biology"),
                         "BIO_RESPIRATION_THE_ENERGY_RELEASING")

    def test_no_specific_entity_returns_none(self):
        # a generic stem with no specific biological entity must NOT be forced into a concept
        self.assertIsNone(self.r("Which of the following statements is correct?", "All of these", "Biology"))
        self.assertIsNone(self.r("Choose the odd one out", "option 3", "Biology"))

    def test_ambiguous_tie_returns_none(self):
        # equal specific evidence for two concepts -> unresolved, never a coin-flip
        # 'neuron' (neural) and 'glucagon' (endocrine) each once -> tie -> None
        self.assertIsNone(self.r("The neuron releases glucagon in this hypothetical stem", "x", "Biology"))

    def test_generic_tokens_do_not_map(self):
        # 'plant'/'system'/'hormone' alone are excluded; a plant-growth-regulator stem must not map anywhere
        self.assertIsNone(self.r("Spraying sugarcane crop with plant growth regulators gives", "Gibberellin",
                                 "Biology"))

    def test_non_biology_subject_ignored(self):
        self.assertIsNone(self.r("A neuron fires", "x", "Physics"))

    def test_only_active_existing_concepts(self):
        # lexicon codes all exist here -> none dropped
        self.assertEqual(self.r.dropped_codes, [])


class TestCombinedResolver(unittest.TestCase):
    def test_non_biology_uses_strict_only(self):
        k = _kie()
        # add a Physics concept + strict-resolver machinery works via concept_resolve
        k.execute("INSERT INTO concepts VALUES ('PHY_OHM','Ohms law','Physics','active')")
        k.commit()
        combined = bio_resolve.build_combined_resolver(k)
        # Biology entity resolves via bio lexicon
        self.assertEqual(combined("Hypoglycemic hormone is", "Insulin", "Biology"), "BIO_HUMAN_ENDOCRINE_SYSTEM")
        # Physics goes through strict answer-title path (answer 'Ohms law' matches the title)
        self.assertEqual(combined("state the law", "Ohms law", "Physics"), "PHY_OHM")


if __name__ == "__main__":
    unittest.main()
