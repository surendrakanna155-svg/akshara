# Visual Intelligence Specification

**Date:** 2026-07-11 · **Status:** SPEC (proposal — not implemented)
**Goal:** Treat diagrams, graphs, figures and tables as first-class assessment assets — understood on
ingestion, and **generated deterministically** for original production questions.
**Aligns with:** Assessment-Intelligence-Platform diagram-intelligence vision (wave CI-C11, currently
unscheduled) and D8 original-content-first. Today, diagram-dependent questions are "not detected or
flagged" and the engine explicitly synthesizes no diagrams (`templates.py:177`).

---

## 1. Two jobs, kept separate

1. **Understand** source visuals (L2 analysis) — so we know which source questions are diagram-dependent
   and what they test.
2. **Generate** original visuals (L3 production) — deterministic, semantic, copyright-clean — so Akshara
   can *own* diagram-based questions instead of avoiding them.

These are different pipelines and must not be conflated. Source visuals are never republished.

---

## 2. Visual Asset Intelligence (understanding — L2)

For every ingested image/graph/figure/table (from `MULTIMODAL_INGESTION_ARCHITECTURE.md` §6/§9), determine
and store:
```
VisualAsset {
  asset_id, resource_id, page, bbox, kind: raster|vector, digest,
  asset_type,               // geometry | circuit | ray_diagram | force_diagram | graph
                            //   | coordinate_plot | biology_schema | chemistry_structure | table | photo
  educational_role,         // decorative | data_source | referent | answer_locus
  linked_question_id,
  concept,                  // resolved concept_code
  labels[],                 // detected labels/annotations
  measurable_values[],      // quantities the figure encodes
  visual_dependencies,      // what must be read to answer
  answerable_without_visual,// TRUE ⇒ decorative; FALSE ⇒ diagram-locked (question needs the figure)
  extraction_quality
}
```
`answerable_without_visual=false` is the critical flag: it marks a question that cannot be regenerated as
text-only. Such a source question can become a production item **only** if we can synthesize an equivalent
semantic visual (§3); otherwise it is flagged diagram-locked and excluded — **never silently converted**.

Detection is tiered: deterministic for asset_type from vector primitives / table structure; a Tier-2 model
for role and answerable-without-visual judgments on ambiguous figures. Source assets stay in the
analytical corpus only.

---

## 3. Semantic Visual Specification (generation — L3)

The heart of visual quality: **do not ask an image model to draw precision educational diagrams.** Use a
deterministic semantic spec → deterministic vector (SVG) renderer. The question references the semantic
object; the answer validator independently reads the same object.

Per-type specs (each is a small typed schema → SVG):
```
geometry_spec        { shapes[], points, lengths, angles, labels, right_angle_marks }
circuit_spec         { components[] (R,C,L,cell,switch,meter), topology (series/parallel graph), values, labels }
ray_diagram_spec     { optical_element (lens/mirror), focal_length, object {pos,height}, principal_axis, rays[] }
force_diagram_spec   { body, forces[] {magnitude,direction,label}, angles, surface }
graph_spec           { axes {label,unit,range}, series[] {points|function}, gridlines, markers }
coordinate_plot_spec { axes, plotted_points, lines/curves, shaded_regions }
biology_schema_spec  { structure, labelled_parts[], leader_lines }     // stylized, original — not a copied figure
chemistry_structure_spec { atoms[], bonds[], charges, lone_pairs }     // from SMILES-like input
table_spec           { columns[], rows[], units, highlighted_cells }
```
Rules:
- **Deterministic rendering.** Given a spec + seed, the SVG is reproducible. No generative-image model in
  the certified path.
- **The spec is the source of truth.** The stem is authored to reference spec quantities; the
  `answer_function` reads the spec, not the pixels. This lets the answer validator (GATE 11) independently
  confirm the visual and the question agree.
- **Originality by construction.** A generated circuit/graph/geometry figure is a fresh parameterization,
  never a traced source image — copyright-clean.
- **Chemistry/biology** structures are rendered from structured input (SMILES-like / part lists) into an
  original house style, not copied textbook art.

The `visual_generator` field on an Item Model (`ITEM_MODEL_SPECIFICATION.md` §2) holds the semantic spec
template; parameters flow from the same constraint solver that sets the numeric variables, so the figure
and the numbers are guaranteed consistent.

---

## 4. Consistency validation (GATE 11)

For any item with a visual, an independent check confirms:
- every quantity the stem references exists in the spec and is uniquely readable;
- the `answer_function`'s reading of the spec reproduces the stated answer;
- the figure contains no information that contradicts the stem (e.g. a labelled 30° that the stem calls
  45°);
- labels are unambiguous and legible at print size.
Fail ⇒ REJECT (a visual required but missing/inconsistent is a hard reject, per the mission).

---

## 5. Archetypes unlocked

Semantic visuals enable the Tier-C archetypes the engine cannot express today:
graph_interpretation (read a slope/intercept/area), table_interpretation (compute from a readings table),
diagram_interpretation (circuit/ray/force), experiment_inference (infer from an apparatus + readings).
Each ships only after passing the gold benchmark for that archetype.

---

## 6. Storage & mirror

- New `visual_assets` table (L2 understanding) + `visual_specs` on Item Models (L3 generation), local per
  the storage decision.
- Postgres `edu_diagrams` is explicitly out of the current dormant migration (CI-C11 wave) — this spec is
  what CI-C11 would implement; we note the alignment so the two do not diverge.

---

## 7. Acceptance criteria

- Every ingested figure has a `VisualAsset` row with `answerable_without_visual` decided.
- Diagram-locked source questions are flagged and excluded from text-only regeneration — measured, not
  assumed.
- Every generated visual comes from a semantic spec rendered deterministically to SVG; zero
  generative-image-model calls in the certified path.
- GATE 11 independently confirms visual/question/answer agreement; inconsistent items are rejected.
- Generated figures are original parameterizations (no traced source art) — copyright review passes.
