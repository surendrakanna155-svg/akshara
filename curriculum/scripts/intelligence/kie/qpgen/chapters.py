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
                       "momentum", "work", "energy", "power", "gravit", "rotation", "friction",
                       "projectile", "circular", "collision", "elasticit", "fluid", "pressure")),
        ("Thermodynamics", ("thermodynam", "heat", "temperature", "kinetic theory", "calorimetr",
                            "thermal", "entropy", "gas law", "carnot")),
        ("Oscillations & Waves", ("oscillat", "wave", "sound", "harmonic", "shm", "doppler",
                                  "resonance", "pendulum")),
        ("Optics", ("optic", "light", "reflection", "refraction", "lens", "mirror", "interference",
                    "diffraction", "polariz", "prism")),
        ("Electromagnetism", ("electric", "magnet", "current", "circuit", "induction", "capacitor",
                              "resistance", "voltage", "charge", "electromagnet", "emf", "ohm")),
        ("Modern Physics", ("atom", "nucle", "photoelectric", "radioactiv", "semiconductor",
                            "quantum", "photon", "electron", "bohr", "de broglie", "dual")),
    ],
    "Chemistry": [
        ("Physical Chemistry", ("mole", "stoichiometr", "thermodynam", "equilibrium", "kinetic",
                                "electrochem", "solution", "concentration", "acid", "base", "redox",
                                "oxidation", "gas law", "colligative", "atomic structure")),
        ("Organic Chemistry", ("organic", "hydrocarbon", "alcohol", "aldehyde", "ketone", "carboxyl",
                               "amine", "ester", "alkane", "alkene", "alkyne", "benzene", "aromatic",
                               "polymer", "biomolecule", "isomer")),
        ("Inorganic Chemistry", ("periodic", "bonding", "coordination", "metal", "block", "hydrogen",
                                 "halogen", "noble gas", "oxide", "salt", "valenc", "electroneg")),
    ],
    "Biology": [
        ("Cell Biology", ("cell", "mitochond", "nucleus", "membrane", "organelle", "cytoplasm",
                          "ribosome")),
        ("Genetics & Evolution", ("gene", "dna", "rna", "inherit", "evolution", "replication",
                                  "transcription", "translation", "mutation", "allele", "mendel",
                                  "natural selection", "chromosom")),
        ("Human Physiology", ("digest", "respiration", "circulat", "excret", "nervous", "hormone",
                              "reproduc", "muscle", "blood", "heart", "kidney", "neuron", "endocrine")),
        ("Plant Physiology", ("photosynth", "transpir", "plant", "stomata", "xylem", "phloem",
                              "germination", "auxin", "chlorophyll")),
        ("Ecology", ("ecosystem", "ecolog", "environment", "population", "biodiversity", "food chain",
                     "pollution", "habitat")),
        ("Biotechnology", ("biotech", "recombinant", "pcr", "cloning", "gene therap", "plasmid",
                           "transgenic", "fermentation")),
        ("Biological Classification", ("classif", "taxonom", "kingdom", "morpholog", "anatomy",
                                       "species", "phylum", "bacteria", "virus", "fungi", "algae")),
    ],
    "Mathematics": [
        ("Algebra", ("equation", "polynomial", "matrix", "determinant", "complex number", "sequence",
                     "series", "binomial", "logarithm", "quadratic", "inequalit", "exponent")),
        ("Calculus", ("limit", "derivative", "differential", "integral", "integration", "continuity",
                      "maxima", "minima")),
        ("Coordinate Geometry", ("coordinate", "straight line", "circle", "parabola", "ellipse",
                                 "hyperbola", "conic")),
        ("Trigonometry", ("trigonometr", "angle", "sine", "cosine", "tangent", "triangle")),
        ("Vectors & 3D Geometry", ("vector", "plane", "three dimension", "dot product", "cross product")),
        ("Probability & Statistics", ("probabilit", "statistic", "mean", "median", "mode",
                                      "permutation", "combination", "variance", "distribution")),
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
