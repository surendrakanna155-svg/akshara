// Program D · M0.1 — ERP-side loader for the deterministic synthetic certified corpus (TEST-ONLY).
//
// This is the ERP end of the fixture strategy: the QIE-native certified rows that
// `kie.qie.export.fixtures.make_certified_fixture(12, 0)` produces, committed as a golden JSON so the
// Deno promotion/import/retrieval tests have deterministic certified content BEFORE the real bank fills.
//
// The shape here is QIE-NATIVE (question_type='MCQ', difficulty='moderate', KC_ concept codes). The
// M1.2 exporter maps it to the ERP platform-bank shape ('mcq', 'medium', concept UUID); tests that need
// the mapped shape consume the M1.2 export artifact, not this raw corpus.
//
// TEST-ONLY: never imported by any production/edge code path. Regeneration: see ./README.md.

import corpus from "./certified_corpus.json" with { type: "json" };

/** One QIE-native certified row (the pre-export shape). Program-D-relevant fields are typed. */
export interface CertifiedFixtureRow {
  candidate_id: string;
  run_id: string;
  spec_id: string;
  lane: string;
  board: string;
  exam_profile: string;
  class_level: number;
  subject: string;
  concept_code: string; // KC_<sha14>
  concept_title: string;
  concept_codes_all: string; // JSON-encoded string[]
  composition: string;
  archetype: string;
  question_type: string; // QIE-native 'MCQ'
  intended_depth: number;
  intended_difficulty: string; // QIE-native easy|moderate|hard
  visual_required: number;
  stem: string;
  options: Record<string, string>;
  answer_label: string;
  answer_value: string;
  claimed: Record<string, unknown>;
  structure: Record<string, unknown>;
  solution: Record<string, unknown>;
  distractor_rationale: Record<string, string>;
  visual_spec: unknown;
  item_hash: string;
  stem_norm_hash: string;
  evidence_class: string;
  certification_class: string;
  earned_depth: number;
  computed_archetype: string;
  bloom: string; // ERP cognitive_level axis
  marks: number;
  generator_model: string;
  generator_family: string;
  provenance: Record<string, string>;
}

/** The committed golden corpus: 12 deterministic certified rows (seed 0). */
export const certifiedCorpus: CertifiedFixtureRow[] = corpus as CertifiedFixtureRow[];
