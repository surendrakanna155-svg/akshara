"""Phase D golden tests — certified-model-driven generation bridge (NEET Biology factual).
Contract: new authored stems, verified-evidence answers, governed cross-concept distractors, hard gates
(boundary / unsupported / near-copy / duplicate / answer-disagreement / uncertainty), full provenance,
no fabrication. Hermetic, deterministic, stub verifier."""
import unittest

from kie.qie import generate as G, mine

TITLES = {"BIO_ENDO": "Human Endocrine System", "BIO_EXCR": "Excretory System",
          "BIO_NEUR": "Neural Control"}
TOKENS = {"BIO_ENDO": ["Glucagon", "Insulin", "Cortisol"],
          "BIO_EXCR": ["Nephron", "Ureter", "Malpighian"],
          "BIO_NEUR": ["Neuron", "Synapse", "Axon"]}


def _evidence(source_options=None):
    stream, verified = [], set()
    for c, toks in TOKENS.items():
        for t in toks:
            stream.append((c, t, None))
            verified.add(mine.fact_key(c, t))
    if source_options:
        stream.append(("BIO_ENDO", "Glucagon", source_options))
    return G.build_evidence(stream, verified, TITLES)


def _models():
    return [{"subject": "Biology", "profile": "NEET", "certifiable": True,
             "archetype": "factual_single_best_answer", "concept": c} for c in TOKENS] + [
            {"subject": "Biology", "profile": "NEET", "certifiable": False,   # not certified -> excluded
             "archetype": "factual_single_best_answer", "concept": "BIO_DRAFT"},
            {"subject": "Physics", "profile": "NEET", "certifiable": True,     # wrong subject -> excluded
             "archetype": "factual_single_best_answer", "concept": "PHY_X"}]


class TestEntityToken(unittest.TestCase):
    def test_accepts_clean_entities(self):
        for t in ("Glucagon", "Nephron", "SA node", "Human insulin"):
            self.assertTrue(G.is_entity_token(t), t)

    def test_rejects_phrases_labels_numbers(self):
        for t in ("Depletion of oxygen", "no antibody", "All of the above", "12", "During S-phase",
                  "Pyruvate and ATP", ""):
            self.assertFalse(G.is_entity_token(t), t)


class TestSelect(unittest.TestCase):
    def test_only_certified_biology_neet_factual(self):
        self.assertEqual(sorted(G.select_certified_concepts(_models())), sorted(TOKENS))


class TestGenerate(unittest.TestCase):
    def test_candidates_are_boundary_correct_and_new(self):
        ev = _evidence()
        cands = G.generate_candidates(list(TOKENS), ev, seed="D1", per_concept=2)
        self.assertTrue(cands)
        for c in cands:
            self.assertEqual(len(c["options"]), 4)
            self.assertIn(c["answer_text"], TOKENS[c["concept"]])          # answer is a verified concept token
            distractors = [o for o in c["options"].values() if o != c["answer_text"]]
            for d in distractors:
                self.assertNotIn(d, TOKENS[c["concept"]])                  # distractors never from this concept
            self.assertIn(TITLES[c["concept"]], c["stem"])                 # authored frame carries the topic
            # the stem is an authored frame, not any source-question wording
            self.assertTrue(c["stem"].endswith("?"))


class TestGates(unittest.TestCase):
    def setUp(self):
        self.ev = _evidence()

    def _cand(self, concept="BIO_ENDO", answer="Glucagon", opts=None):
        opts = opts or {"1": "Glucagon", "2": "Nephron", "3": "Neuron", "4": "Synapse"}
        return {"concept": concept, "answer_text": answer, "options": opts}

    def test_unsupported_answer_rejected(self):
        c = self._cand(answer="Adrenaline", opts={"1": "Adrenaline", "2": "Nephron", "3": "Neuron", "4": "Axon"})
        self.assertEqual(G.gate(c, self.ev, set()), "UNSUPPORTED_ANSWER")   # not a verified token

    def test_tautology_rejected(self):
        # answer that merely restates the concept topic must be rejected deterministically
        ev = G.build_evidence([("BIO_MITO", "Mitochondria", None)],
                              {mine.fact_key("BIO_MITO", "Mitochondria")}, {"BIO_MITO": "Mitochondria"})
        c = {"concept": "BIO_MITO", "answer_text": "Mitochondria",
             "options": {"1": "Mitochondria", "2": "Nephron", "3": "Neuron", "4": "Axon"}}
        self.assertEqual(G.gate(c, ev, set()), "TAUTOLOGY")

    def test_distractor_from_same_concept_rejected(self):
        c = self._cand(opts={"1": "Glucagon", "2": "Insulin", "3": "Neuron", "4": "Axon"})  # Insulin is endo
        self.assertEqual(G.gate(c, self.ev, set()), "DISTRACTOR_IN_CONCEPT")

    def test_near_copy_of_source_rejected(self):
        ev = _evidence(source_options=["Glucagon", "Nephron", "Neuron", "Synapse"])
        self.assertEqual(G.gate(self._cand(), ev, set()), "NEAR_COPY_OF_SOURCE")

    def test_duplicate_generated_rejected(self):
        seen = set()
        self.assertIsNone(G.gate(self._cand(), self.ev, seen))
        self.assertEqual(G.gate(self._cand(), self.ev, seen), "DUPLICATE_GENERATED")


class TestRunClassification(unittest.TestCase):
    def test_pass_reject_quarantine(self):
        ev = _evidence()
        concepts = list(TOKENS)
        agree = G.run(concepts, ev, lambda c: "agree", per_concept=1)
        self.assertEqual(agree["passed"], agree["attempted"])
        self.assertEqual(agree["rejected"] + agree["quarantined"], 0)
        dis = G.run(concepts, ev, lambda c: "disagree", per_concept=1)
        self.assertEqual(dis["rejected"], dis["attempted"])
        self.assertTrue(all(i["reason"] == "ANSWER_DISAGREEMENT" for i in dis["items"]))
        quar = G.run(concepts, ev, lambda c: "unverifiable", per_concept=1)
        self.assertEqual(quar["quarantined"], quar["attempted"])

    def test_provenance_and_no_fabrication(self):
        ev = _evidence()
        res = G.run(list(TOKENS), ev, lambda c: "agree", per_concept=1)
        for it in res["items"]:
            for key in ("gen_id", "item_model_id", "concept", "correct_fact_key", "distractor_fact_keys",
                        "frame_id", "verification"):
                self.assertIn(key, it)
            # correct_fact_key must equal the verified fact_key of (concept, answer) — never fabricated
            self.assertEqual(it["correct_fact_key"], mine.fact_key(it["concept"], it["answer_text"]))


if __name__ == "__main__":
    unittest.main()
