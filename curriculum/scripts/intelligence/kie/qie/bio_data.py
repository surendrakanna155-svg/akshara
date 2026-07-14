"""Curated canonical NEET Biology knowledge base — the deterministic, evidence-grounded substrate for
qualitative Biology composition (structure-function, process/pathway order, cause-effect chains).

Why curated (see BIOLOGY_COMPOSITION_MODEL.md): the corpus lacks clean structured biological relations (KVS
sequence/structure-function tables empty; concept edges are document-structure noise), and auto-extracting them
would make an LLM the primary truth source — violating the locked verification hierarchy. So, exactly as
`chem_data.py` uses a verified periodic table rather than noisy OCR, this is canonical textbook knowledge
(human-verifiable; corroborated by the Tier-2 verified set where they overlap). Questions are generated FROM and
verified AGAINST these tables by deterministic lookup/traversal. LLM is used only as a quality examiner.
"""
from __future__ import annotations

from typing import Dict, List, Tuple

# (structure, function, system, category) — canonical NEET structure–function facts. The `category` keeps
# distractors within the SAME kind so questions can't be solved by category-spotting (an examiner-flagged risk).
STRUCTURE_FUNCTION: List[Tuple[str, str, str, str]] = [
    # function wording deliberately avoids the system-name root, so answers need knowledge not word-matching
    ("nephron", "filtration of blood to form urine", "excretory system", "human_system"),
    ("alveoli", "exchange of oxygen and carbon dioxide with the blood", "respiratory system", "human_system"),
    ("neuron", "transmission of electrical impulses through the body", "nervous system", "human_system"),
    ("villi", "absorption of nutrients from the small intestine", "digestive system", "human_system"),
    ("cardiac muscle", "pumping of blood around the body", "circulatory system", "human_system"),
    ("bone marrow", "production of blood cells", "skeletal system", "human_system"),
    ("mitochondrion", "synthesis of ATP by cellular respiration", "the mitochondrion", "organelle"),
    ("chloroplast", "photosynthesis", "the chloroplast", "organelle"),
    ("ribosome", "synthesis of proteins", "the ribosome", "organelle"),
    ("nucleus", "control of cell activities and heredity", "the nucleus", "organelle"),
]

# (gland, hormone, primary effect) — canonical endocrine chains. Only glands whose PRINCIPAL hormone is
# unambiguous are used (anterior pituitary is multi-hormone → deliberately excluded, per examiner note).
GLAND_HORMONE_EFFECT: List[Tuple[str, str, str]] = [
    ("pancreas (islets of Langerhans)", "insulin", "lowering of blood glucose level"),
    ("thyroid gland", "thyroxine", "regulation of the basal metabolic rate"),
    ("adrenal medulla", "adrenaline", "the fight-or-flight response"),
    ("parathyroid gland", "parathormone", "raising of blood calcium level"),
]

# (deficient nutrient, resulting disease) — canonical deficiency cause–effect
DEFICIENCY_DISEASE: List[Tuple[str, str]] = [
    ("vitamin C", "scurvy"), ("vitamin D", "rickets"), ("iodine", "goitre"),
    ("iron", "anaemia"), ("vitamin A", "night blindness"), ("vitamin B1", "beri-beri"),
]

# (process name, ordered steps) — canonical pathways/sequences
PROCESSES: List[Tuple[str, List[str]]] = [
    ("the passage of food through the human alimentary canal",
     ["mouth", "oesophagus", "stomach", "small intestine", "large intestine"]),
    ("the stages of mitosis (in order)",
     ["prophase", "metaphase", "anaphase", "telophase"]),
    ("urine formation in a nephron",
     ["glomerular filtration", "tubular reabsorption", "tubular secretion"]),
    ("the human reflex arc",
     ["receptor", "sensory neuron", "interneuron in the spinal cord", "motor neuron", "effector muscle"]),
    ("the flow of oxygenated blood in double circulation",
     ["lungs", "pulmonary vein", "left atrium", "left ventricle", "aorta", "body tissues"]),
]

# derived lookup maps (deterministic; built once)
FUNC_TO_STRUCT: Dict[str, str] = {fn: st for st, fn, sy, cat in STRUCTURE_FUNCTION}
STRUCT_TO_FUNC: Dict[str, str] = {st: fn for st, fn, sy, cat in STRUCTURE_FUNCTION}
STRUCT_TO_SYSTEM: Dict[str, str] = {st: sy for st, fn, sy, cat in STRUCTURE_FUNCTION}
GLAND_TO_HORMONE: Dict[str, str] = {g: h for g, h, e in GLAND_HORMONE_EFFECT}
HORMONE_TO_EFFECT: Dict[str, str] = {h: e for g, h, e in GLAND_HORMONE_EFFECT}

# same-category subset for the structure→system template (distractors stay within one kind → no giveaway)
HUMAN_SF: List[Tuple[str, str, str]] = [(st, fn, sy) for st, fn, sy, cat in STRUCTURE_FUNCTION
                                        if cat == "human_system"]
HUMAN_SYSTEMS: List[str] = [sy for st, fn, sy in HUMAN_SF]


def assert_consistent() -> None:
    """Each relation must be functional (one canonical answer) so generated questions are unambiguous."""
    assert len(FUNC_TO_STRUCT) == len(STRUCTURE_FUNCTION), "duplicate function → ambiguous structure"
    assert len(HUMAN_SYSTEMS) == len(set(HUMAN_SYSTEMS)), "duplicate human system → giveaway/ambiguity"
    assert len(GLAND_TO_HORMONE) == len(GLAND_HORMONE_EFFECT), "duplicate gland"
    assert len({h for g, h, e in GLAND_HORMONE_EFFECT}) == len(GLAND_HORMONE_EFFECT), "duplicate hormone"
    for name, steps in PROCESSES:
        assert len(steps) == len(set(steps)), f"repeated step in {name}"


assert_consistent()
