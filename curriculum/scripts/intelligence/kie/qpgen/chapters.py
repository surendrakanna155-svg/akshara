"""Chapter taxonomy — a curated, deterministic map of the standard JEE/NEET syllabus chapters.

The certified KIE has no clean chapter attribute (concepts came from bundled textbook archives,
so the evidencing document is not a chapter). Rather than infer chapters from noisy extraction,
we map each concept to a canonical syllabus chapter by keyword matching on its title. This is
deterministic, grounded in the real syllabus, and independent of extraction quality. Concepts
that match no chapter fall into a "General <Subject>" bucket (surfaced, never hidden).

This is reference data (like presets); it can be refined without touching engine logic.
"""
from __future__ import annotations

from typing import Optional

# subject → ordered list of (chapter_name, keyword patterns). First match wins.
SUBJECT_CHAPTERS = {
    "Physics": [
        ("Mechanics", ("kinematic", "motion", "velocity", "acceleration", "force", "newton",
                       "momentum", "impulse", "work", "energy", "power", "gravit", "rotation",
                       "friction", "projectile", "circular", "collision", "elasticit", "fluid",
                       "pressure", "density", "buoyan", "thrust", "torque", "centre of mass",
                       "bernoulli", "archimedes", "viscosit", "stoke", "simple machine", "pascal")),
        ("Thermodynamics", ("thermodynam", "heat", "temperature", "kinetic theory", "calorimetr",
                            "thermal", "entropy", "gas law", "carnot", "convection", "conduction",
                            "radiation", "boyle", "charles's law", "gaseous state", "liquid state",
                            "specific heat", "latent heat")),
        ("Oscillations & Waves", ("oscillat", "wave", "sound", "harmonic", "shm", "doppler",
                                  "resonance", "pendulum", "tuning fork", "vibration", "frequency")),
        ("Optics", ("optic", "light", "reflection", "refraction", "refractive index", "lens",
                    "mirror", "interference", "diffraction", "polaris", "polariz", "prism",
                    "vision", "eye", "snell", "brewster", "huygen")),
        ("Electromagnetism", ("electric", "magnet", "current", "circuit", "induction", "inductance",
                              "capacitor", "resistance", "resistor", "voltage", "charge",
                              "electromagnet", "emf", "ohm", "battery", "coulomb", "ampere",
                              "solenoid", "dipole", "electrostatic", "gauss", "potential",
                              "right-hand thumb")),
        ("Modern Physics", ("atom", "nucle", "photoelectric", "radioactiv", "semiconductor",
                            "quantum", "photon", "electron", "bohr", "de broglie", "dual",
                            "fission", "fusion", "x-ray", "uncertainty principle")),
    ],
    "Chemistry": [
        ("Physical Chemistry", ("mole", "stoichiometr", "thermodynam", "equilibrium", "kinetic",
                                "electrochem", "solution", "concentration", "acid", "base", "redox",
                                "oxidation", "gas law", "colligative", "atomic structure", "raoult",
                                "henry's law", "corrosion", "tyndall", "colloid", "electricity",
                                "scientific notation", "exponential notation")),
        ("Organic Chemistry", ("organic", "hydrocarbon", "alcohol", "aldehyde", "ketone", "carboxyl",
                               "amine", "ester", "alkane", "alkene", "alkyne", "benzene", "aromatic",
                               "polymer", "biomolecule", "isomer", "saytzeff", "zaitsev",
                               "substitution reaction", "addition reaction", "homologous series",
                               "functional group", "combustion")),
        ("Inorganic Chemistry", ("periodic", "bonding", "bond length", "coordination", "metal",
                                 "block", "hydrogen", "halogen", "noble gas", "oxide", "salt",
                                 "valenc", "electroneg", "hund", "huckel", "compound")),
    ],
    "Biology": [
        ("Cell Biology", ("cell", "mitochond", "nucleus", "membrane", "organelle", "cytoplasm",
                          "ribosome", "plastid", "microbodies", "prophase", "metaphase", "anaphase",
                          "telophase", "cytokinesis", "mitosis", "meiosis", "cell cycle")),
        ("Genetics & Evolution", ("gene", "dna", "rna", "inherit", "hered", "evolution", "replication",
                                  "transcription", "translation", "mutation", "allele", "mendel",
                                  "natural selection", "chromosom", "sex determination")),
        ("Human Physiology", ("digest", "respiration", "breathing", "circulat", "excret", "nervous",
                              "hormone", "muscle", "blood", "plasma", "heart", "kidney", "neuron",
                              "endocrine", "stomach", "intestine", "immunity", "menstrual",
                              "transport of oxygen", "balanced diet", "nutrition")),
        ("Plant Physiology", ("photosynth", "transpir", "plant", "stomata", "xylem", "phloem",
                              "germination", "auxin", "chlorophyll", "pollination")),
        ("Ecology", ("ecosystem", "ecolog", "environment", "population", "biodiversity", "food chain",
                     "pollution", "habitat", "sewage", "decomposition", "productivity", "biosphere",
                     "wildlife", "water cycle", "nitrogen fixation", "sludge", "forest")),
        ("Biotechnology", ("biotech", "recombinant", "pcr", "cloning", "gene therap", "plasmid",
                           "transgenic", "fermentation", "vaccine", "microorganism", "microbe")),
        ("Biological Classification", ("classif", "taxonom", "kingdom", "morpholog", "anatomy",
                                       "species", "phylum", "bacteria", "virus", "fungi", "algae",
                                       "basidiomycetes")),
        ("Biomolecules & Metabolism", ("protein", "carbohydrate", "polysaccharide", "lipid",
                                       "nucleic acid", "enzyme", "amino acid", "tricarboxylic",
                                       "activation energy", "metaboli")),
        ("Reproduction & Development", ("reproduc", "fertilis", "fertiliz", "development",
                                        "regeneration", "fragmentation", "cancer", "totipotency")),
    ],
    "Mathematics": [
        ("Algebra", ("equation", "polynomial", "matrix", "matrices", "determinant", "complex number",
                     "sequence", "series", "binomial", "logarithm", "quadratic", "inequalit",
                     "exponent", "integer", "real number", "rational number", "prime", "factoris",
                     "factorization", "algebraic expression", "arithmetic expression", "number system",
                     "square root", "square number", "surd")),
        ("Calculus", ("limit", "derivative", "differential", "integral", "integration", "continuity",
                      "maxima", "minima", "linear programming")),
        ("Coordinate Geometry", ("coordinate", "straight line", "parabola", "ellipse",
                                 "hyperbola", "conic")),
        ("Trigonometry", ("trigonometr", "angle", "sine", "cosine", "tangent")),
        ("Geometry & Mensuration", ("triangle", "circle", "perimeter", "area", "volume", "surface",
                                    "parallelogram", "rhombus", "quadrilateral", "trapezium",
                                    "polygon", "pythagoras", "symmetry", "reflection", "line segment",
                                    "bisector", "congru", "similar", "mensuration", "geometric")),
        ("Vectors & 3D Geometry", ("vector", "plane", "three dimension", "dot product", "cross product")),
        ("Probability & Statistics", ("probabilit", "statistic", "mean", "median", "mode",
                                      "permutation", "combination", "variance", "distribution",
                                      "bar graph", "histogram", "proportion")),
    ],
}


def resolve_chapter(subject: Optional[str], title: str) -> str:
    """Map a concept to its canonical syllabus chapter (deterministic; unmatched → General)."""
    t = (title or "").lower()
    for chapter, keys in SUBJECT_CHAPTERS.get(subject, ()):
        if any(k in t for k in keys):
            return chapter
    return f"General {subject}" if subject else "General"


def chapters_for(subject: str) -> list:
    return [c for c, _ in SUBJECT_CHAPTERS.get(subject, ())]
