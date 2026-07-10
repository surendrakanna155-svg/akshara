"""Knowledge Layer — richer chapter taxonomy (knowledge-layer only; engine stays frozen).

The certified engine resolves chapters with its OWN frozen `qpgen.chapters` (narrow, so most
concepts fall into a "General <Subject>" bucket). The engine keeps using it — this module is
NOT wired into the engine. It enriches `concept_board_mappings.chapter` in the knowledge layer
(used for Postgres promotion + coverage reporting, never read by the engine).

Superset guarantee (by construction): resolve_chapter tries the ENGINE'S resolver FIRST and
returns its result whenever it is a real chapter. Only a concept the engine leaves in "General"
is passed to the richer keyword set. So every engine mapping is preserved EXACTLY and engine
behaviour is untouched; we only rescue General-bucket concepts into standard chapters.

Deterministic, keyword-first, first-match-wins. Reference data — refine freely.
"""
from __future__ import annotations

from typing import Optional

from kie.qpgen import chapters as _engine

# Richer keywords applied ONLY when the engine's resolver returns "General <Subject>".
# Named laws + common topics that today land in General. Ordered; first match wins.
# Deliberately excludes "characteristic(s)" (kept General by design) and any bare <=2-char key.
_EXTRA = {
    "Physics": [
        ("Mechanics", ("bernoulli", "stoke", "hooke", "torricelli", "pascal", "archimedes",
                       "centre of mass", "centripetal", "inertia", "impulse", "tension",
                       "malleab", "ductil", "elastic", "viscos", "surface tension",
                       "terminal velocity", "simple machine", "lever", "pulley")),
        ("Thermodynamics", ("boyle", "charles", "gay-lussac", "convection", "conduction of heat",
                            "combustion", "latent heat", "specific heat", "stefan", "boltzmann",
                            "thermal expansion", "internal energy", "calorimet")),
        ("Oscillations & Waves", ("tuning fork", "sonority", "sonorous", "echo", "vibration",
                                  "beats", "wavelength", "amplitude", "standing wave")),
        ("Optics", ("huygen", "snell", "brewster", "malus", "pinhole", "periscope", "kaleidoscope",
                    "eclipse", "shadow", "rainbow", "dispersion", "magnification", "telescope",
                    "microscope", "spectrum", "total internal reflection")),
        ("Electromagnetism", ("electric cell", "voltaic cell", "dry cell", "faraday", "lenz",
                              "biot", "ampere", "coulomb", "kirchhoff", "transformer", "solenoid",
                              "galvanometer", "magnetic flux")),
        ("Modern Physics", ("x-ray", "laser", "isotope", "half life", "fission", "fusion",
                            "binding energy", "mass defect", "uncertainty principle")),
        ("Units & Measurement", ("unit of measure", "units of measure", "measurement", "si unit",
                                 "dimensional", "significant figure", "least count", "vernier")),
    ],
    "Chemistry": [
        ("Physical Chemistry", ("raoult", "henry", "hess", "le chatelier", "chatelier", "arrhenius",
                                "nernst", "buffer", "solubility", "enthalpy", "entropy", "gibbs",
                                "rate law", "order of reaction", "molarity", "normality", "molality",
                                "colligative", "electrolysis", "half life")),
        ("Organic Chemistry", ("markovnikov", "saytzeff", "zaitsev", "friedel", "aldol",
                               "cannizzaro", "grignard", "electrophil", "nucleophil", "carbocation",
                               "hybridis", "functional group", "substitution reaction",
                               "elimination reaction", "addition reaction", "iupac")),
        ("Inorganic Chemistry", ("s-block", "p-block", "d-block", "f-block", "transition element",
                                 "lanthanide", "actinide", "alkali metal", "alkaline earth",
                                 "ionization enthalpy", "atomic radius", "electron affinity",
                                 "allotrop", "amphoteric")),
    ],
    "Biology": [
        ("Cell Biology", ("chloroplast", "lysosome", "golgi", "endoplasmic", "vacuole",
                          "cell wall", "cell division", "mitosis", "meiosis", "cytokinesis")),
        ("Genetics & Evolution", ("genome", "genotype", "phenotype", "codon", "genetic code",
                                  "linkage", "crossing over", "natural selection", "speciation",
                                  "hardy", "darwin", "lamarck")),
        ("Human Physiology", ("digest", "nephron", "alveoli", "neuron", "synapse", "reflex",
                              "immunity", "antibody", "antigen", "enzyme", "vitamin", "hemoglobin",
                              "insulin", "peristalsis", "nutrition", "hygiene")),
        ("Plant Physiology", ("transport of water", "transport of food", "translocation",
                              "guard cell", "respiration in plant", "photolysis", "grafting",
                              "layering", "pollination")),
        ("Ecology", ("food chain", "food web", "trophic", "nitrogen cycle", "carbon cycle",
                     "conservation", "endangered", "succession", "niche")),
    ],
    "Mathematics": [
        ("Algebra", ("rational number", "real number", "integer", "factoris", "factorization",
                     "identit", "proportion", "arithmetic progression", "geometric progression",
                     "hcf", "lcm", "surd", "cube root", "square root")),
        ("Calculus", ("differentiation", "antiderivative", "rate of change", "tangent to a curve",
                      "area under")),
        ("Coordinate Geometry", ("slope", "distance formula", "section formula", "locus",
                                 "perpendicular line", "transversal", "collinear")),
        ("Trigonometry", ("height and distance", "radian", "secant", "cosecant", "cotangent")),
        ("Probability & Statistics", ("frequency distribution", "histogram", "ogive", "quartile",
                                      "standard deviation", "correlation")),
        ("Geometry & Mensuration", ("quadrilateral", "polygon", "surface area", "volume of",
                                    "perimeter", "pythagoras", "similarity", "congruen",
                                    "parallelogram", "mensuration", "solid shape")),
    ],
}


def resolve_chapter(subject: Optional[str], title: str) -> str:
    """Richer knowledge-layer chapter for a concept (deterministic; unmatched → General).

    Superset of qpgen.chapters.resolve_chapter: the engine's mapping is returned unchanged
    whenever it is a real chapter; only General-bucket concepts consult the richer keywords."""
    base = _engine.resolve_chapter(subject, title)
    if not base.startswith("General"):
        return base                                   # engine mapping preserved EXACTLY
    t = (title or "").lower()
    for chapter, keys in _EXTRA.get(subject, ()):
        if any(k in t for k in keys):
            return chapter
    return base                                        # still General
