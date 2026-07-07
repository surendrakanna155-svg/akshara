# ASSESSMENT_INTELLIGENCE_MASTER_SPECIFICATION

**Status:** Canonical Master Specification

**Version:** 1.0

**Owner:** Project Owner

**Implementation Status:** Planning Complete

**Authority:** Canonical Assessment Intelligence Specification

**Supersedes:** Any conflicting planning notes

**Read Before:** Any implementation of Curriculum Intelligence, Knowledge Base, Question Generation, Diagram Intelligence, Validation, Question Bank or Assessment Engine.

**Related Documents:**
- MASTER_CURRICULUM_INTELLIGENCE_PIPELINE.md
- OPUS_IMPLEMENTATION_HANDOFF.md
- DOWNLOAD_VERIFICATION_AND_RECOVERY_ENGINE.md

**Implementation Rule:**
This document extends the existing approved architecture. It must not be interpreted as a replacement architecture.

PART 1 — CORE ARCHITECTURE & INTEGRATION RULES

PURPOSE

This is NOT a new project.

This is NOT a replacement for the existing Curriculum Intelligence Platform.

This is NOT a replacement for the certified Assessment Intelligence Platform.

This document defines architectural enhancements that must be intelligently merged into the existing approved planning.

The Program Baseline v1.0 remains the canonical foundation.

All improvements described here must extend the existing architecture.

Never create competing implementations.

Never duplicate existing functionality.

Always preserve backward compatibility.

Always preserve EOS compliance.

⸻

PRIMARY OBJECTIVE

Transform the existing Question Paper Generation System into a complete Assessment Intelligence Platform while preserving the current architecture.

The implementation must remain modular, scalable, deterministic and production-ready.

⸻

ARCHITECTURAL PRINCIPLES

Always follow these principles.

Principle 1

Extend.

Never rebuild.

If an existing module already solves part of the problem, enhance it instead of creating another implementation.

⸻

Principle 2

Knowledge should be generated once.

Reuse forever.

AI should continuously enrich the platform but should not repeatedly regenerate identical knowledge.

⸻

Principle 3

Questions are long-term educational assets.

They must continuously improve through validation and usage.

They are not temporary AI outputs.

⸻

Principle 4

Question Papers are temporary.

Question Banks are permanent.

The system’s primary objective is to build the highest quality Certified Question Bank.

Question Papers are assembled from that asset.

⸻

Principle 5

AI is an Author.

AI is a Validator.

AI is an Assistant.

AI is NOT the primary runtime paper generation engine.

Runtime generation should primarily use deterministic selection from the Certified Question Bank.

⸻

HIGH LEVEL PIPELINE

The complete platform should operate as follows.

Official Curriculum Resources

↓

Repository Acquisition

↓

Download Verification

↓

Knowledge Extraction

↓

Concept Extraction

↓

Concept Graph

↓

Knowledge Base

↓

Question Generation

↓

Question Validation

↓

Teacher Validation

↓

Certified Question Bank

↓

Question Paper Engine

↓

Teacher Review

↓

Student Usage

↓

Quality Feedback

↓

Continuous Improvement

This pipeline should become the conceptual architecture of the Assessment Intelligence Platform.

⸻

AI RESPONSIBILITIES

Artificial Intelligence should be responsible for:

• Curriculum understanding

• Chapter extraction

• Topic extraction

• Concept extraction

• Learning Outcome extraction

• Competency extraction

• Knowledge extraction

• Blueprint understanding

• Difficulty estimation

• Bloom Level estimation

• Question generation

• Answer generation

• Explanation generation

• Distractor generation

• Metadata generation

• Quality validation

• Suggesting improvements

AI should NOT become the primary runtime Question Paper Generator.

⸻

RUNTIME RESPONSIBILITIES

The runtime engine should perform:

Question selection

Blueprint validation

Marks balancing

Difficulty balancing

Bloom balancing

Competency balancing

Chapter coverage

Duplicate prevention

Paper assembly

Export

The runtime engine should complete these operations primarily using the Certified Question Bank rather than regenerating questions.

⸻

EXISTING ARCHITECTURE

The following existing systems must remain authoritative.

• Curriculum Intelligence Platform

• Certified Assessment Intelligence Platform

• Download Verification & Recovery Engine

• Repository Certification

• Knowledge Base

• Blueprint Engine

• Question Paper Engine

• EOS Constitution

These systems should only be extended.

Never replaced.

⸻

NO PARALLEL ARCHITECTURES

Before introducing any new module always ask:

Can this be added as metadata?

Can this extend an existing module?

Can this become a validation rule?

Can this become configuration?

Can this become part of an existing pipeline?

Only create a completely new module if none of the above are appropriate.

⸻

IMPLEMENTATION POLICY

This document must update the existing planning.

It must not restart planning.

It must not create competing specifications.

It must not replace approved architecture.

It must intelligently merge every improvement into the existing Program Baseline.

Continue to preserve all roadmap decisions, implementation sequencing, governance rules and EOS gates.


PART 2 — KNOWLEDGE INTELLIGENCE, CONCEPT GRAPH & QUESTION GENERATION ARCHITECTURE

OBJECTIVE

The objective of this section is to transform raw curriculum resources into structured educational intelligence.

The platform should never think in terms of PDFs or textbooks.

It should think in terms of educational concepts.

Every future operation should work on Concepts rather than Documents.

⸻

KNOWLEDGE ACQUISITION PIPELINE

Official Resources

↓

Download Verification Engine

↓

Repository Certification

↓

Knowledge Extraction

↓

Concept Extraction

↓

Concept Graph

↓

Knowledge Base

↓

Question Intelligence

↓

Certified Question Bank

↓

Question Paper Engine

Every stage should preserve complete traceability back to the original verified curriculum source.

⸻

KNOWLEDGE EXTRACTION

The AI should extract structured educational knowledge from verified resources.

Extract:

Board

Class

Subject

Chapter

Topic

Subtopic

Learning Outcomes

Competencies

Academic Standards

Blueprint Mapping

Marks Distribution

Bloom Levels

Difficulty Levels

Prerequisites

Cross-topic Relationships

Examples

Important Definitions

Formulae

Theorems

Scientific Laws

Activities

Experiments

Diagrams

Tables

Key Facts

Frequently Confused Concepts

This information becomes the permanent Knowledge Base.

⸻

CONCEPT GRAPH

The platform should construct a Concept Graph rather than a simple hierarchical syllabus.

Each Concept must become an independent entity.

Every Concept should know:

Parent Concept

Child Concepts

Prerequisite Concepts

Dependent Concepts

Related Concepts

Alternative Concepts

Higher-grade Continuation

Lower-grade Foundation

Learning Outcomes

Competencies

Bloom Levels

Difficulty Range

Allowed Question Types

Allowed Diagram Types

Allowed Practical Activities

Allowed Assessment Types

Common Student Mistakes

Frequently Confused Concepts

Recommended Teaching Sequence

Recommended Revision Sequence

Every Question, Diagram, Activity and Assessment must reference one or more Concept IDs.

⸻

CONCEPT IDENTIFIERS

Every educational concept must receive a permanent Concept ID.

Example:

SCI_G06_PHY_FORCE_001

The Concept ID becomes the primary educational identifier throughout the platform.

Questions should reference Concept IDs instead of only Chapters.

⸻

CURRICULUM BOUNDARY ENGINE

Introduce a mandatory Curriculum Boundary Engine.

No generated content may exceed the approved curriculum.

Before generating any Question, Answer or Diagram validate:

Board

Medium

Class

Subject

Chapter

Topic

Subtopic

Learning Outcome

Competency

Prerequisites

Allowed Cognitive Depth

Allowed Bloom Level

Allowed Difficulty

If any generated content exceeds the approved curriculum boundary:

Reject immediately.

Never store boundary violations.

⸻

FOUNDATION PROGRAM RULE

Foundation Programs should NEVER expand curriculum scope.

Instead they should increase:

Reasoning

Problem Solving

Critical Thinking

Application

Analytical Thinking

Multi-step Thinking

Higher Bloom Levels

Numerical Complexity

Logical Complexity

Real-world Application

Foundation programs must remain concept-safe.

Depth increases.

Scope does not.

Unless explicitly configured by the curriculum authority.

⸻

AUTOMATIC ITEM GENERATION

The platform should adopt Automatic Item Generation principles.

Generate reusable educational Item Models rather than isolated questions.

Each Item Model should support controlled parameter variation.

Examples:

Mathematics

Variable substitution

Numerical variation

Context variation

Difficulty variation

Science

Scenario variation

Experimental variation

Observation variation

Reasoning variation

Language

Reading passage variation

Grammar variation

Vocabulary variation

Comprehension variation

Social Studies

Case variation

Map variation

Timeline variation

Situation variation

One Item Model should be capable of generating many curriculum-compliant questions while preserving originality.

⸻

QUESTION FAMILIES

Questions should belong to Question Families.

One educational concept may produce:

MCQ

Very Short Answer

Short Answer

Long Answer

Essay

Fill in the Blanks

Match the Following

True / False

Assertion–Reason

Case Study

Numerical

Diagram Based

Experimental

Application Based

Competency Based

HOTS

Project Work

Activity Based

Viva Questions

All family members remain connected through the same Concept ID.

⸻

QUESTION GENERATION

Question generation should primarily occur as an offline batch process.

The runtime engine should not repeatedly invoke AI for every paper.

Offline Flow:

Concept

↓

AI Question Generation

↓

AI Validation

↓

Teacher Validation

↓

Certified Question Bank

Runtime Flow:

Teacher selects:

Board

↓

Class

↓

Subject

↓

Exam Type

↓

Chapters

↓

Blueprint

↓

Difficulty

↓

Marks

↓

Question Paper Engine

↓

Certified Question Bank

↓

Paper Assembly

This architecture minimizes AI cost while maximizing quality and consistency.

⸻

ANSWER GENERATION

Every Question should contain:

Correct Answer

Step-by-step Solution

Explanation

Expected Keywords

Marking Scheme

Alternative Correct Answers

Common Mistakes

Evaluation Notes

Teacher Notes

This enables automated evaluation and future AI-assisted assessment.

⸻

KNOWLEDGE EVOLUTION

The Knowledge Base should continuously improve.

Whenever:

New curriculum releases

Official updates

Teacher corrections

Curriculum revisions

Academic reforms

New competencies

New learning outcomes

are detected,

only the affected Concepts should be updated.

Never rebuild the complete Knowledge Base unnecessarily.

Incremental updates should always be preferred.

⸻

IMPLEMENTATION GUIDELINE

Do not create a separate Concept Engine.

Integrate these capabilities into the existing Curriculum Intelligence Platform.

Treat the Concept Graph, Curriculum Boundary Engine and Automatic Item Generation as extensions of the approved architecture.

Do not duplicate functionality already present in the existing planning documents.

Always merge intelligently into the approved Program Baseline.

PART 3 — CERTIFIED QUESTION INTELLIGENCE, QUALITY ENGINE & DIAGRAM INTELLIGENCE

OBJECTIVE

The objective of this phase is to transform generated educational content into trusted educational assets.

The platform should not simply generate questions.

It should continuously build, validate, improve and maintain the highest quality Certified Question Bank.

The Certified Question Bank becomes one of the most valuable long-term assets of the platform.

⸻

CERTIFIED QUESTION BANK

The Certified Question Bank becomes the primary production source.

Question Papers should primarily be assembled from this repository.

Questions should never remain static.

Every question must evolve over time.

Every modification should increase educational quality.

Every approved improvement becomes part of the permanent knowledge asset.

⸻

QUESTION TRUST LIFECYCLE

Every question must pass the following lifecycle.

RAW

↓

GENERATED

↓

AI_VALIDATED

↓

TEACHER_VALIDATED

↓

CERTIFIED

↓

ACTIVE

↓

CONTINUOUS_REVIEW

↓

RETIRED (if necessary)

Production Question Papers should only use ACTIVE Certified Questions by default.

⸻

QUESTION QUALITY INTELLIGENCE

Every question should maintain a continuously evolving Quality Score.

Quality should be calculated using multiple factors.

Examples:

Teacher Approvals

Teacher Edits

Teacher Rejections

Usage Count

Student Accuracy

Student Failure Rate

Average Solving Time

Difficulty Validation

Duplicate Detection

Curriculum Updates

Revision History

Review Frequency

Confidence Score

Quality Score should improve automatically over time.

⸻

TEACHER FEEDBACK INTELLIGENCE

Teachers should become continuous contributors to the Question Bank.

Track:

Accepted Questions

Rejected Questions

Modified Questions

Frequently Edited Questions

Suggested Improvements

Teacher Ratings

Teacher Notes

Approval History

Subject Expert Reviews

Future AI improvements should learn from validated teacher decisions.

Teacher intelligence is a permanent educational asset.

⸻

QUESTION VERSIONING

Every question must support version control.

Maintain:

Question Version

Revision History

Previous Versions

Reason for Change

Modified By

Approval Timestamp

Review History

Rollback Support

Questions should never be permanently overwritten.

⸻

DISTRACTOR INTELLIGENCE

Wrong MCQ options must never be discarded.

Every distractor should become educational intelligence.

Track:

Distractor Quality

Confusion Frequency

Concept Similarity

Student Selection Rate

Teacher Rating

Difficulty Contribution

Misconception Category

Concept Relationship

Store distractors inside a dedicated Distractor Library linked to the same Concept ID.

Future MCQ generation should intelligently reuse high-quality distractors.

⸻

QUESTION METADATA

Every question entering the Certified Question Bank must contain complete metadata.

Mandatory fields include:

Question ID

Concept ID

Board

Medium

Class

Subject

Chapter

Topic

Subtopic

Learning Outcome

Competency

Blueprint Mapping

Difficulty

Bloom Level

Question Type

Question Family

Marks

Estimated Time

Answer

Explanation

Alternative Answers

Keywords

Teacher Notes

AI Confidence

Teacher Confidence

Quality Score

Trust Status

Version

License Status

Validation Status

Repository Source

Question Origin

Generation Method

Curriculum Boundary Status

No question may enter production with incomplete metadata.

⸻

ANSWER VALIDATION

Every generated answer must be validated.

Verify:

Correctness

Curriculum Alignment

Concept Alignment

Calculation Accuracy

Scientific Accuracy

Terminology

Grammar

Expected Keywords

Mark Allocation

Alternative Valid Answers

Teacher Review

Only validated answers should be stored.

⸻

DUPLICATE INTELLIGENCE

Detect duplicate questions using:

Semantic Similarity

Concept Similarity

Answer Similarity

Difficulty Similarity

Blueprint Similarity

Question Structure

Numerical Variation

Language Variation

Merge duplicates intelligently.

Maintain references.

Do not create unnecessary copies.

⸻

COPYRIGHT-SAFE GENERATION

Never copy textbook questions.

Never reproduce previous board papers.

Never copy copyrighted diagrams.

Use previous papers only for:

Blueprint Analysis

Difficulty Analysis

Pattern Analysis

Question Style Analysis

Competency Analysis

Trend Analysis

Generate original educational content using:

Curriculum

Concept Graph

Knowledge Base

Item Models

Teacher Intelligence

AI Reasoning

Every production question must be original.

⸻

DIAGRAM INTELLIGENCE

Diagrams are first-class educational assets.

Do not copy diagrams from textbooks or previous papers.

Instead:

Extract educational meaning.

Generate completely new diagrams.

Support:

Science

Physics

Chemistry

Biology

Mathematics

Geometry

Geography

Environmental Science

Computer Science

Laboratory Activities

Flowcharts

Educational Illustrations

Circuit Diagrams

Experimental Setups

⸻

DIAGRAM GENERATION ENGINE

Whenever a question requires a diagram:

Question

↓

Diagram Requirement Detection

↓

Diagram Specification

↓

Diagram Generation

↓

AI Validation

↓

Teacher Validation

↓

Certified Diagram Library

↓

Question Paper

The runtime engine should reuse certified diagrams whenever possible.

⸻

DIAGRAM LIBRARY

Maintain a permanent Diagram Library.

Each diagram should include:

Diagram ID

Concept ID

Board

Class

Subject

Chapter

Diagram Type

SVG Source

Vector Source

Generation Method

Teacher Approval

Version

License Status

Quality Score

Related Questions

Multiple questions should reuse the same certified diagram.

⸻

DIAGRAM TECHNOLOGY

Prefer programmatically generated diagrams.

Use open, editable formats.

Examples:

SVG

Vector Graphics

Geometry Engines

Circuit Rendering Libraries

Mathematical Plotting

Scientific Drawing Libraries

Flow Diagram Engines

Avoid raster images whenever possible.

Generated diagrams should remain editable, scalable and copyright-safe.

⸻

CONTINUOUS LEARNING

The platform should continuously improve using:

Teacher Feedback

Curriculum Updates

Student Performance

Assessment Analytics

Question Usage

Diagram Usage

Validation Results

Never regenerate the complete Question Bank unnecessarily.

Prefer intelligent incremental improvement.

⸻

IMPLEMENTATION GUIDELINE

Do not introduce separate Question Intelligence or Diagram Intelligence systems.

Integrate these capabilities into the existing Assessment Intelligence Platform.

Extend existing metadata, validation pipelines and repositories.

Avoid duplicate implementations.

Maintain backward compatibility.

Preserve the approved Program Baseline and roadmap.

PART 4 — RUNTIME ARCHITECTURE, IMPLEMENTATION STRATEGY & FINAL INTEGRATION

OBJECTIVE

This section defines how the complete Assessment Intelligence Platform operates in production.

The objective is to ensure that AI performs the heavy educational work only once, while the runtime system remains deterministic, fast, scalable, cost-efficient and production-ready.

The implementation must seamlessly integrate into the existing Curriculum Intelligence Platform, Assessment Intelligence Platform, roadmap and approved Program Baseline.

⸻

END-TO-END ASSESSMENT INTELLIGENCE PIPELINE

The complete platform should operate as follows.

Official Curriculum Resources

↓

Download Engine

↓

Download Verification & Recovery Engine

↓

Repository Certification

↓

Knowledge Extraction

↓

Concept Extraction

↓

Concept Graph

↓

Knowledge Base

↓

Question Generation (Offline AI)

↓

Answer Generation

↓

Diagram Generation

↓

Metadata Generation

↓

AI Validation

↓

Teacher Validation

↓

Certified Question Bank

↓

Certified Diagram Library

↓

Assessment Intelligence Repository

↓

Question Paper Engine

↓

Teacher Review

↓

Student Assessment

↓

Learning Analytics

↓

Continuous Improvement

Every stage must preserve traceability, validation and educational quality.

⸻

OFFLINE VS RUNTIME AI

Separate AI responsibilities into two distinct modes.

Offline AI (Batch Processing)

Runs only when required.

Responsibilities:

Curriculum analysis

Knowledge extraction

Concept extraction

Question generation

Answer generation

Diagram generation

Metadata generation

Distractor generation

Quality analysis

Validation assistance

Knowledge updates

This process builds long-term educational assets.

⸻

Runtime Engine

Runs during normal system usage.

Responsibilities:

Blueprint interpretation

Question selection

Question balancing

Difficulty balancing

Bloom balancing

Competency balancing

Marks balancing

Diagram selection

Paper assembly

Export

Runtime should primarily reuse Certified Questions and Certified Diagrams.

Do not regenerate questions unnecessarily.

Only invoke AI when new educational content is genuinely required.

⸻

EXAM PROFILE ENGINE

The platform must support configurable examination profiles.

Examples:

Regular School Exams

Unit Test

Monthly Test

Quarterly

Half-Yearly

Annual Examination

Practice Papers

School Custom Exams

Foundation Programs

JEE Foundation

NEET Foundation

Olympiad

NTSE

Scholarship

Talent Search

Higher Order Thinking

Future Examination Profiles

Each profile should define:

Difficulty Distribution

Bloom Distribution

Question Family Distribution

Time Allocation

Marks Distribution

Competency Weightage

Reasoning Depth

Diagram Requirements

Numerical Requirements

Question Mix

Profiles must remain configuration-driven.

Never hard-code examination behaviour.

⸻

SUBSCRIPTION ARCHITECTURE

The Assessment Intelligence Platform must remain subscription independent.

Never hard-code plan names.

Use feature capabilities.

Examples:

Question Generation

Blueprint Designer

Foundation Profiles

Advanced Analytics

Custom Templates

Diagram Intelligence

Bulk Paper Generation

Teacher Collaboration

Future capabilities should be enabled through configuration.

⸻

PERFORMANCE STRATEGY

The platform should minimise AI cost.

Preferred workflow:

AI generates educational assets once.

↓

Teacher validates.

↓

Assets become Certified.

↓

Runtime reuses Certified Assets.

↓

Only missing concepts invoke AI again.

Never regenerate identical educational content repeatedly.

⸻

CONTINUOUS IMPROVEMENT ENGINE

The platform should continuously improve through:

Teacher Feedback

Teacher Corrections

Student Performance

Assessment Analytics

Question Usage

Diagram Usage

Curriculum Updates

Official Resource Updates

Rejected Questions

Retired Questions

Quality Reviews

Every improvement should strengthen the Certified Question Bank.

⸻

SAFEGUARDS

Every production Question must satisfy all safeguards.

Repository Certified

Curriculum Boundary Verified

Concept Verified

Metadata Complete

Answer Verified

Diagram Verified (if applicable)

AI Validated

Teacher Approved

Trust Level Certified

Copyright Safe

Quality Score Above Threshold

If any safeguard fails:

Reject the Question.

Do not allow it into production.

⸻

COPYRIGHT COMPLIANCE

Maintain strict copyright compliance.

Official resources may be downloaded only from legally accessible sources.

Previous Question Papers must only support:

Pattern Analysis

Difficulty Analysis

Blueprint Analysis

Trend Analysis

Question Style Analysis

Educational Intelligence

Never reproduce copyrighted questions verbatim.

Never reproduce copyrighted diagrams.

Always generate original educational content.

All generated questions and diagrams must remain curriculum-aligned while being independently created.

⸻

IMPLEMENTATION STRATEGY

This initiative must integrate into the existing approved roadmap.

Do not create a parallel roadmap.

Do not replace approved architecture.

Merge improvements into existing planning.

Update only the affected:

Planning Documents

Architecture Documents

Implementation Documents

Validation Rules

Metadata Schemas

Acceptance Tests

Roadmap Dependencies

Do not regenerate unrelated documentation.

⸻

IMPLEMENTATION PRINCIPLES

Always prefer:

Extension

Configuration

Metadata

Validation

Composition

Reuse

Avoid:

Duplicate logic

Parallel implementations

Conflicting standards

Redundant repositories

Architecture drift

⸻

ACCEPTANCE CRITERIA

This enhancement is complete only when:

Existing planning has been updated.

No duplicate architecture exists.

No roadmap conflicts exist.

No EOS conflicts exist.

All new safeguards are integrated.

All metadata extensions are documented.

Question Intelligence integrates with the existing Assessment Intelligence Platform.

Diagram Intelligence integrates with the existing Assessment Intelligence Platform.

Concept Graph integrates with the existing Curriculum Intelligence Platform.

No approved implementation is broken.

Backward compatibility is preserved.

Program Baseline remains authoritative.

⸻

FINAL DELIVERABLE

Analyse the existing repository, planning documents and implementation strategy.

Determine the best integration points for every enhancement described in Parts 1–4.

Merge these improvements into the existing approved Program Baseline.

Extend existing documents wherever possible.

Only create new files when absolutely necessary.

Provide a final summary including:

• Documents Updated

• Sections Extended

• Metadata Added

• Validation Rules Added

• New Safeguards Added

• New Intelligence Layers Added

• Diagram Intelligence Integration

• Question Intelligence Enhancements

• Runtime Optimisations

• Roadmap Impact

• Remaining Owner Decisions (if any)

After updating the planning package:

Freeze the updated baseline.

Do not begin production implementation.

Wait for the next implementation phase, which will be executed using Claude Opus 4.8.

Maintain complete compatibility with EOS, the approved roadmap and the certified Assessment Intelligence Platform.

The final architecture should represent a single, unified, extensible and production-ready Assessment Intelligence Platform without introducing duplicate systems or conflicting standards.


MASTER INSTRUCTION FOR PARTS 5–11

Before continuing with Parts 5–11, carefully review the entire approved Program Baseline, all Curriculum Intelligence documents, Assessment Intelligence documents, implementation plans, roadmap, audits, EOS Constitution and the certified Assessment Intelligence Platform.

This is NOT a new project.

Do NOT restart planning.

Do NOT regenerate existing documents.

Do NOT redesign the architecture.

Do NOT create parallel systems.

Your responsibility is to intelligently extend the existing architecture.

Everything developed in Parts 1–4 remains authoritative.

Parts 5–11 are architectural refinements that strengthen the existing platform.

Before adding any new rule, module or document, always determine whether it should:

* Extend an existing document.
* Extend existing metadata.
* Extend an existing validation pipeline.
* Extend an existing repository.
* Extend an existing service.
* Extend an existing implementation plan.

Only create a new document or module when absolutely necessary.

Avoid duplicate functionality.

Avoid architectural drift.

Maintain backward compatibility.

Maintain EOS compliance.

Maintain compatibility with the certified Assessment Intelligence Platform.

The final result should remain a single unified Assessment Intelligence Platform rather than multiple disconnected systems.

The objective of Parts 5–11 is to make the platform enterprise-grade, future-proof, maintainable, copyright-safe, AI-efficient, teacher-centric and production-ready.

Generate every remaining part with implementation quality suitable for long-term development.

Every recommendation should be practical, scalable and integrate naturally into the approved roadmap.

Do not introduce ideas that conflict with the existing implementation strategy.

Always prefer extending the current Program Baseline over creating new architectures.

After completing Parts 5–11, produce a final integrated architecture that remains clean, deterministic, modular and ready for implementation by Claude Opus 4.8.


PART 5 — ASSESSMENT INTELLIGENCE GOLDEN RULES (CONSTITUTION)

PURPOSE

This document defines the non-negotiable architectural principles of the Assessment Intelligence Platform.

These rules override implementation preferences.

Whenever implementation decisions conflict with these rules, these rules take precedence unless explicitly changed by the Project Owner.

These rules must remain valid regardless of programming language, AI model, framework, database or deployment architecture.

⸻

RULE 1 — CURRICULUM FIRST

Everything begins with the approved curriculum.

The curriculum is the highest educational authority.

No Question, Diagram, Answer or Assessment may violate the approved curriculum.

⸻

RULE 2 — CONCEPT BEFORE QUESTION

Questions are temporary.

Concepts are permanent.

Every Question must originate from one or more verified Concepts.

Never generate isolated questions without Concept mapping.

⸻

RULE 3 — AI CREATES, ENGINE ASSEMBLES

Artificial Intelligence creates educational assets.

The Assessment Engine assembles Question Papers.

AI should not be repeatedly used during runtime unless new educational content is genuinely required.

⸻

RULE 4 — CERTIFIED CONTENT ONLY

Production Question Papers must use Certified educational assets by default.

Questions

Answers

Diagrams

Blueprints

Templates

must all be Certified before entering production.

⸻

RULE 5 — REPOSITORY CERTIFICATION IS MANDATORY

No educational resource enters the Knowledge Base until Repository Certification succeeds.

Downloaded does not mean Verified.

Verified does not mean Certified.

Repository Certification is mandatory.

⸻

RULE 6 — CURRICULUM BOUNDARIES ARE ABSOLUTE

The system must never exceed curriculum boundaries.

Foundation programs may increase reasoning depth.

They must not expand curriculum scope unless explicitly configured.

⸻

RULE 7 — COPYRIGHT SAFETY

Never copy educational content.

Never reproduce copyrighted questions.

Never reproduce copyrighted diagrams.

Use official resources only for curriculum understanding, educational intelligence, blueprint analysis and pattern analysis.

Generate original educational content.

⸻

RULE 8 — COMPLETE METADATA

No Question, Diagram or Educational Asset may enter production without complete metadata.

Incomplete educational assets must be rejected automatically.

⸻

RULE 9 — TEACHER AUTHORITY

Teachers remain the final educational authority.

AI assists.

Teachers certify.

Teacher decisions always override AI recommendations.

⸻

RULE 10 — CONTINUOUS IMPROVEMENT

The platform must continuously improve.

Teacher feedback

Curriculum updates

Student performance

Assessment analytics

Quality reviews

must continuously strengthen the platform.

⸻

RULE 11 — KNOWLEDGE IS PERMANENT

Educational knowledge is a long-term asset.

Never rebuild educational knowledge unnecessarily.

Prefer incremental improvement.

⸻

RULE 12 — NO DUPLICATE ARCHITECTURE

Always extend existing modules.

Never create competing implementations.

Avoid duplicate repositories.

Avoid duplicate pipelines.

Avoid conflicting standards.

⸻

RULE 13 — EVERY QUESTION MUST BE TRACEABLE

Every Question must be traceable to:

Repository Source

Curriculum

Concept

Learning Outcome

Competency

Blueprint

Teacher Approval

Version

Trust Status

Nothing should become anonymous.

⸻

RULE 14 — EVERY DIAGRAM MUST BE ORIGINAL

Never store textbook images directly.

Extract educational meaning.

Generate original diagrams.

Store reusable vector-based educational diagrams.

⸻

RULE 15 — EVERY QUESTION BELONGS TO A FAMILY

Questions should not exist in isolation.

Each Question belongs to a Question Family.

Each family belongs to one or more Concepts.

⸻

RULE 16 — DYNAMIC QUALITY

Quality is never fixed.

Every educational asset should continuously improve through:

Teacher review

Student analytics

Usage

Validation

Retirement

Revision

⸻

RULE 17 — EXPLAINABILITY

Every AI-generated decision must remain explainable.

The system should always be able to explain:

Why this question was generated.

Why this difficulty was selected.

Why this answer is correct.

Why this diagram was chosen.

⸻

RULE 18 — CONFIGURATION OVER HARD-CODING

Blueprints

Exam Profiles

Subscription Features

Difficulty Rules

Foundation Rules

Validation Rules

should remain configuration-driven.

Avoid hard-coded educational logic.

⸻

RULE 19 — MODULAR INTELLIGENCE

Knowledge Intelligence

Question Intelligence

Diagram Intelligence

Validation Intelligence

Analytics Intelligence

should work together as one platform.

Never become disconnected products.

⸻

RULE 20 — AI IS A PARTNER, NOT THE OWNER

Artificial Intelligence accelerates educational work.

The Assessment Intelligence Platform owns the educational assets.

The Certified Question Bank remains the primary production asset.

AI continuously enriches the platform but never replaces educational governance.

⸻

FINAL CONSTITUTION

Whenever implementation decisions become unclear:

Protect educational quality.

Protect curriculum integrity.

Protect originality.

Protect teacher authority.

Protect student learning.

Protect maintainability.

Protect long-term knowledge.

These principles define the permanent foundation of the Assessment Intelligence Platform.

PART 6 — ASSESSMENT INTELLIGENCE DATA MODEL & ENTITY ARCHITECTURE

PURPOSE

This document defines the canonical educational data model of the Assessment Intelligence Platform.

The objective is to create a single, extensible, normalized educational knowledge model that supports every present and future feature without requiring architectural redesign.

The data model must remain independent of programming language, framework and database technology.

The implementation may use PostgreSQL, Supabase, SQLite, NoSQL or any future storage engine, but the logical model must remain unchanged.

⸻

CORE PHILOSOPHY

The platform should never think in terms of PDF files.

The platform should think in terms of educational entities and their relationships.

Everything becomes structured educational knowledge.

Educational assets are connected through relationships rather than isolated documents.

⸻

PRIMARY ENTITY HIERARCHY

Educational Authority

↓

Board

↓

Curriculum

↓

Medium

↓

Academic Year

↓

Class

↓

Subject

↓

Chapter

↓

Topic

↓

Subtopic

↓

Concept

↓

Learning Outcome

↓

Competency

↓

Question Family

↓

Question

↓

Answer

↓

Diagram

↓

Assessment Blueprint

↓

Question Paper

Every entity should have its own permanent identifier.

⸻

BOARD ENTITY

Stores educational board information.

Examples:

CBSE

Andhra Pradesh SCERT

Telangana SCERT

CISCE / ICSE

Future Boards

Attributes:

Board ID

Board Name

Academic Authority

Version

Status

Language Support

Medium Support

Curriculum Version

Effective Date

Revision History

⸻

CURRICULUM ENTITY

Represents one complete curriculum.

Attributes:

Curriculum ID

Board ID

Medium

Academic Year

Version

Status

Official Source

Certification Status

Repository Status

Knowledge Extraction Status

⸻

SUBJECT ENTITY

Attributes:

Subject ID

Board

Class

Subject Name

Code

Category

Language

Difficulty Profile

Assessment Rules

Diagram Support

Practical Support

⸻

CHAPTER ENTITY

Attributes:

Chapter ID

Subject ID

Sequence

Chapter Name

Weightage

Teaching Hours

Revision History

⸻

TOPIC ENTITY

Attributes:

Topic ID

Chapter ID

Topic Name

Description

Sequence

Dependencies

Learning Outcomes

⸻

SUBTOPIC ENTITY

Attributes:

Subtopic ID

Topic ID

Name

Description

Sequence

Difficulty

⸻

CONCEPT ENTITY

The Concept becomes the most important educational entity.

Every Question belongs to one or more Concepts.

Attributes:

Concept ID

Topic ID

Concept Name

Definition

Description

Learning Outcomes

Competencies

Bloom Levels

Difficulty Range

Curriculum Boundary

Foundation Boundary

Prerequisites

Related Concepts

Parent Concepts

Child Concepts

Formula References

Scientific Laws

Theorems

Definitions

Diagram References

Common Misconceptions

Teaching Notes

Revision Notes

Status

Version

⸻

LEARNING OUTCOME ENTITY

Attributes:

Outcome ID

Concept ID

Description

Assessment Level

Expected Skills

Evaluation Method

Bloom Mapping

⸻

COMPETENCY ENTITY

Attributes:

Competency ID

Learning Outcome

Competency Type

Skill Category

Expected Mastery

Assessment Strategy

Evidence Requirements

⸻

QUESTION TEMPLATE ENTITY

Represents reusable Item Models.

Attributes:

Template ID

Concept ID

Question Family

Difficulty Range

Variables

Constraints

Generation Rules

Validation Rules

Supported Exam Profiles

⸻

QUESTION FAMILY ENTITY

Groups all educational variations.

Examples:

MCQ

Very Short

Short

Long

Essay

Case Study

Assertion Reason

Numerical

Diagram

Practical

Application

Project

Activity

Every family belongs to one Concept.

⸻

QUESTION ENTITY

Every Question becomes an educational asset.

Attributes:

Question ID

Question Family

Concept ID

Board

Medium

Class

Subject

Chapter

Topic

Subtopic

Difficulty

Bloom Level

Competency

Learning Outcome

Question Text

Language

Marks

Estimated Time

Question Status

Trust Status

Version

Quality Score

Usage Count

Teacher Rating

License Status

Repository Source

Generation Method

Creation Date

Approval Date

Retirement Date

⸻

ANSWER ENTITY

Attributes:

Answer ID

Question ID

Correct Answer

Alternative Answers

Step-by-Step Solution

Explanation

Keywords

Marking Scheme

Teacher Notes

AI Confidence

Teacher Confidence

Validation Status

⸻

DISTRACTOR ENTITY

Applicable to MCQs.

Attributes:

Distractor ID

Question ID

Concept ID

Distractor Text

Misconception Type

Difficulty

Selection Frequency

Confusion Score

Teacher Rating

Reuse Score

Quality Score

⸻

DIAGRAM ENTITY

Every Diagram is an educational asset.

Attributes:

Diagram ID

Concept ID

Board

Subject

Chapter

Diagram Type

SVG Source

Generation Method

Teacher Approval

Quality Score

License Status

Version

Reusable Status

Related Questions

⸻

BLUEPRINT ENTITY

Attributes:

Blueprint ID

Exam Profile

Marks

Difficulty Distribution

Bloom Distribution

Competency Distribution

Question Mix

Chapter Coverage

Diagram Rules

Validation Rules

⸻

EXAM PROFILE ENTITY

Represents assessment strategies.

Examples:

Regular School Exam

Unit Test

Quarterly

Half-Yearly

Annual

Practice

Foundation

JEE Foundation

NEET Foundation

Olympiad

NTSE

Scholarship

Attributes:

Profile ID

Difficulty Rules

Bloom Rules

Competency Rules

Question Mix

Diagram Policy

Time Rules

Scoring Rules

⸻

QUESTION PAPER ENTITY

Represents one assembled paper.

Attributes:

Paper ID

Blueprint

Exam Profile

Questions

Diagrams

Answers

Difficulty Summary

Bloom Summary

Competency Summary

Generation Date

Teacher Approval

Export Formats

⸻

ANALYTICS ENTITY

Stores educational intelligence.

Track:

Usage

Teacher Reviews

Student Performance

Average Time

Correct Rate

Wrong Rate

Difficulty Validation

Question Retirement

Diagram Usage

Trend Analysis

Quality Evolution

⸻

RELATIONSHIP MODEL

Every entity should remain connected.

Board

↓

Curriculum

↓

Class

↓

Subject

↓

Chapter

↓

Topic

↓

Subtopic

↓

Concept

↓

Question Family

↓

Question

↓

Answer

↓

Diagram

↓

Assessment

↓

Analytics

No educational asset should become isolated.

⸻

DATA MODEL PRINCIPLES

Every entity must support:

Unique ID

Versioning

Audit Trail

Metadata

Validation Status

License Status

Quality Score

Trust Status

Repository Traceability

Teacher Traceability

AI Traceability

⸻

IMPLEMENTATION GUIDELINES

Do not redesign the existing database unless necessary.

Map these entities onto the existing architecture.

Reuse existing tables wherever possible.

Only introduce new entities when the current schema cannot represent the required educational intelligence.

Maintain normalization.

Maintain scalability.

Maintain backward compatibility.

Avoid duplicate educational data.

The Assessment Intelligence Data Model should become the canonical educational data architecture for the entire Akshara ERP platform.



PART 7 — ASSESSMENT INTELLIGENCE PIPELINES

PURPOSE

This document defines the canonical operational pipelines of the Assessment Intelligence Platform.

Every educational asset should move through deterministic, traceable and auditable pipelines.

Pipelines should be modular, reusable and independently testable.

The objective is to ensure educational consistency while avoiding duplicated business logic.

⸻

PIPELINE PHILOSOPHY

Every pipeline must satisfy:

Deterministic

Traceable

Auditable

Incremental

Recoverable

Versioned

Configurable

Extensible

EOS Compliant

Every stage must produce structured outputs.

No stage should bypass validation.

⸻

PIPELINE 1 — CURRICULUM ACQUISITION

Official Sources

↓

Download Queue

↓

Download Engine

↓

Download Verification Engine

↓

Repository Certification

↓

Repository Storage

↓

Repository Metadata

↓

Master Index Update

↓

Repository Ready

Only certified educational resources may continue.

⸻

PIPELINE 2 — KNOWLEDGE EXTRACTION

Certified Repository

↓

Document Parsing

↓

Curriculum Extraction

↓

Chapter Extraction

↓

Topic Extraction

↓

Subtopic Extraction

↓

Concept Extraction

↓

Learning Outcome Extraction

↓

Competency Extraction

↓

Relationship Discovery

↓

Knowledge Validation

↓

Knowledge Base

Knowledge should always remain traceable to its original certified source.

⸻

PIPELINE 3 — CONCEPT GRAPH

Knowledge Base

↓

Concept Discovery

↓

Relationship Mapping

↓

Prerequisite Detection

↓

Dependency Graph

↓

Misconception Mapping

↓

Bloom Mapping

↓

Difficulty Mapping

↓

Foundation Boundary Mapping

↓

Concept Graph

The Concept Graph becomes the educational foundation of the platform.

⸻

PIPELINE 4 — QUESTION GENERATION

Concept Graph

↓

Question Template Selection

↓

Item Model Selection

↓

AI Question Generation

↓

Answer Generation

↓

Distractor Generation

↓

Metadata Generation

↓

Question Validation

↓

Teacher Validation Queue

↓

Certified Question Bank

Question generation should primarily occur offline.

⸻

PIPELINE 5 — DIAGRAM GENERATION

Concept

↓

Diagram Requirement Detection

↓

Diagram Specification

↓

Diagram Generator

↓

SVG / Vector Generation

↓

AI Validation

↓

Teacher Validation

↓

Diagram Metadata

↓

Certified Diagram Library

↓

Question Association

Generated diagrams must remain editable, reusable and copyright-safe.

⸻

PIPELINE 6 — QUALITY & CERTIFICATION

Generated Question

↓

Duplicate Detection

↓

Curriculum Boundary Validation

↓

Concept Validation

↓

Answer Validation

↓

Diagram Validation

↓

Metadata Validation

↓

AI Validation

↓

Teacher Validation

↓

Certification

↓

Production Approval

No Question should bypass certification.

⸻

PIPELINE 7 — PAPER ASSEMBLY (RUNTIME)

Teacher Configuration

↓

Board

↓

Class

↓

Subject

↓

Exam Profile

↓

Blueprint

↓

Chapter Selection

↓

Difficulty

↓

Question Family Rules

↓

Question Selection

↓

Diagram Selection

↓

Balance Validation

↓

Question Paper Assembly

↓

Teacher Review

↓

Export

Runtime should primarily use Certified educational assets.

⸻

PIPELINE 8 — TEACHER FEEDBACK

Teacher Usage

↓

Question Review

↓

Corrections

↓

Approvals

↓

Rejections

↓

Difficulty Feedback

↓

Diagram Feedback

↓

Metadata Updates

↓

Quality Score Update

↓

Certified Question Bank Update

Teacher intelligence continuously improves the platform.

⸻

PIPELINE 9 — STUDENT ANALYTICS

Student Assessment

↓

Response Collection

↓

Accuracy Analysis

↓

Time Analysis

↓

Difficulty Validation

↓

Misconception Detection

↓

Weak Concept Detection

↓

Question Performance

↓

Diagram Performance

↓

Learning Analytics

↓

Quality Improvement

Educational intelligence grows continuously.

⸻

PIPELINE 10 — CONTINUOUS KNOWLEDGE EVOLUTION

Official Curriculum Updates

↓

Repository Update

↓

Knowledge Delta Detection

↓

Affected Concept Detection

↓

Question Impact Analysis

↓

Diagram Impact Analysis

↓

Regeneration Queue

↓

Validation

↓

Certification

↓

Repository Update

Never rebuild the entire Knowledge Base unnecessarily.

Always prefer incremental evolution.

⸻

PIPELINE 11 — FOUNDATION PROFILE GENERATION

Certified Concepts

↓

Foundation Rules

↓

Reasoning Expansion

↓

Application Expansion

↓

Critical Thinking

↓

Problem Solving

↓

Higher Bloom Mapping

↓

Difficulty Adjustment

↓

Validation

↓

Foundation Question Bank

Foundation Profiles must increase depth while respecting curriculum boundaries.

⸻

PIPELINE 12 — COPYRIGHT COMPLIANCE

Official Resources

↓

Legal Source Verification

↓

Repository Verification

↓

Educational Meaning Extraction

↓

Pattern Analysis

↓

Blueprint Analysis

↓

Knowledge Extraction

↓

Original Content Generation

↓

Validation

↓

Certification

↓

Production Assets

Never reproduce copyrighted educational material.

⸻

PIPELINE STANDARDS

Every pipeline must support:

Versioning

Checkpoint Recovery

Logging

Metrics

Audit Trail

Retry Mechanisms

Error Recovery

Validation Gates

Quality Reports

Pipeline Status

Health Monitoring

⸻

CROSS-PIPELINE RULES

Pipelines should communicate only through certified educational assets.

No pipeline should directly modify another pipeline’s internal state.

Each pipeline should remain independently testable.

Each pipeline should expose deterministic inputs and outputs.

Avoid tightly coupled workflows.

⸻

IMPLEMENTATION GUIDELINES

Integrate these pipelines into the existing Curriculum Intelligence Platform and Assessment Intelligence Platform.

Reuse existing services wherever possible.

Avoid duplicate workflow implementations.

Preserve the approved roadmap.

Maintain EOS compliance.

These pipelines become the canonical operational model for all future Assessment Intelligence development.


PART 8 — ASSESSMENT INTELLIGENCE SERVICE ARCHITECTURE

PURPOSE

This document defines the logical service architecture of the Assessment Intelligence Platform.

The objective is to create a modular, scalable, maintainable and extensible service-oriented architecture that integrates seamlessly with the existing Akshara ERP ecosystem.

This is a logical architecture, not a microservices mandate.

The implementation may remain a modular monolith initially and evolve into distributed services in the future without changing business logic.

⸻

ARCHITECTURAL PRINCIPLES

Every service should have:

Single Responsibility

Clear Ownership

Deterministic Behaviour

Configuration-driven Logic

Independent Testing

Independent Versioning

Well-defined Inputs and Outputs

No Circular Dependencies

Every service must extend the existing architecture.

Never duplicate existing functionality.

⸻

HIGH LEVEL SERVICE MAP

Assessment Intelligence Platform

↓

Curriculum Services

Knowledge Services

Concept Services

Question Services

Diagram Services

Blueprint Services

Validation Services

Assessment Services

Analytics Services

Repository Services

Teacher Intelligence Services

AI Intelligence Services

Configuration Services

All services work together through certified educational assets.

⸻

CURRICULUM SERVICE

Responsibilities:

Curriculum Management

Board Management

Class Management

Subject Management

Chapter Management

Topic Management

Subtopic Management

Curriculum Versioning

Curriculum Boundary Rules

Official Resource Mapping

Curriculum Updates

The Curriculum Service remains the educational authority.

⸻

REPOSITORY SERVICE

Responsibilities:

Repository Storage

Download Queue

Verification Status

Certification Status

Metadata

Checksums

Indexes

Repository Health

License Tracking

Resource Discovery

Repository Audit

Repository Recovery

This service owns all downloaded educational resources.

⸻

KNOWLEDGE SERVICE

Responsibilities:

Knowledge Extraction

Knowledge Storage

Knowledge Updates

Knowledge Search

Knowledge Relationships

Knowledge Versioning

Knowledge Validation

Knowledge Synchronization

Knowledge Deltas

Knowledge Health

⸻

CONCEPT SERVICE

Responsibilities:

Concept Management

Concept Graph

Relationships

Prerequisites

Learning Outcomes

Competencies

Bloom Mapping

Difficulty Mapping

Foundation Rules

Concept Search

Concept Versioning

Concept Evolution

The Concept Service becomes the educational core of the platform.

⸻

QUESTION SERVICE

Responsibilities:

Question Templates

Item Models

Question Generation

Question Families

Question Versioning

Question Metadata

Question Search

Question Selection

Question Certification

Question Retirement

Question Reuse

Question Export

⸻

ANSWER SERVICE

Responsibilities:

Answer Generation

Alternative Answers

Solution Steps

Marking Schemes

Keywords

Evaluation Rules

Answer Validation

Explanation Management

⸻

DIAGRAM SERVICE

Responsibilities:

Diagram Specifications

Diagram Generation

SVG Generation

Geometry Rendering

Circuit Rendering

Scientific Illustrations

Educational Graphics

Diagram Metadata

Diagram Validation

Diagram Library

Diagram Versioning

Diagram Reuse

Original educational diagrams only.

⸻

BLUEPRINT SERVICE

Responsibilities:

Blueprint Management

Marks Distribution

Difficulty Distribution

Bloom Distribution

Competency Distribution

Question Mix

Diagram Policies

Assessment Profiles

Blueprint Validation

Blueprint Versioning

⸻

VALIDATION SERVICE

Responsibilities:

Curriculum Validation

Concept Validation

Answer Validation

Metadata Validation

Duplicate Detection

Copyright Validation

Boundary Validation

Diagram Validation

Blueprint Validation

Certification Rules

Validation Reports

Nothing enters production without Validation Service approval.

⸻

ASSESSMENT SERVICE

Responsibilities:

Exam Profiles

Paper Assembly

Question Selection

Diagram Selection

Marks Balancing

Difficulty Balancing

Bloom Balancing

Competency Balancing

Coverage Validation

Export

Teacher Review

Assessment History

Runtime paper generation belongs here.

⸻

ANALYTICS SERVICE

Responsibilities:

Student Analytics

Teacher Analytics

Question Analytics

Diagram Analytics

Difficulty Analytics

Competency Analytics

Usage Statistics

Quality Trends

Weak Topic Detection

Assessment Intelligence

Recommendations

Predictive Insights

⸻

TEACHER INTELLIGENCE SERVICE

Responsibilities:

Teacher Reviews

Teacher Corrections

Teacher Approvals

Teacher Suggestions

Question Ratings

Diagram Ratings

Quality Feedback

Approval History

Teacher Trust

Teacher Contributions

Teachers remain the final educational authority.

⸻

AI INTELLIGENCE SERVICE

Responsibilities:

Knowledge Extraction

Question Authoring

Answer Authoring

Diagram Specification

Metadata Generation

Difficulty Estimation

Bloom Classification

Competency Mapping

Improvement Suggestions

AI Validation Assistance

AI should assist every service.

AI should not own runtime paper generation.

⸻

CONFIGURATION SERVICE

Responsibilities:

Exam Profiles

Foundation Rules

Difficulty Rules

Bloom Rules

Subscription Capabilities

Feature Flags

Validation Thresholds

Quality Thresholds

AI Configuration

Diagram Policies

Repository Policies

Avoid hard-coded educational behaviour.

Everything configurable.

⸻

EVENT FLOW

Repository Updated

↓

Knowledge Updated

↓

Concept Updated

↓

Question Impact Analysis

↓

Diagram Impact Analysis

↓

Validation Queue

↓

Certification Queue

↓

Question Bank Updated

↓

Assessment Engine Ready

All changes should flow through deterministic events.

⸻

INTER-SERVICE COMMUNICATION

Services communicate through certified educational entities.

Never bypass validation.

Never directly modify another service’s internal state.

Use contracts, events or service interfaces.

Maintain loose coupling.

⸻

SCALABILITY

The architecture must support:

Single School

Multi School

District

State

National Deployments

Multiple Boards

Multiple Languages

Multiple Mediums

Future International Boards

Without architectural redesign.

⸻

IMPLEMENTATION GUIDELINES

Do not create these services immediately.

First map every responsibility to the existing codebase.

Reuse existing services wherever possible.

Only introduce new services when the current architecture cannot naturally absorb the responsibility.

Preserve backward compatibility.

Preserve EOS compliance.

Preserve the approved roadmap.

This Service Architecture becomes the canonical logical architecture for future implementation.


PART 9 — ACCEPTANCE CRITERIA, QUALITY ASSURANCE, TESTING & PRODUCTION READINESS

PURPOSE

This document defines the mandatory quality standards, testing strategy, acceptance criteria and production readiness requirements for the Assessment Intelligence Platform.

No implementation should be considered complete until it satisfies every requirement defined in this document.

The objective is to ensure educational correctness, technical reliability, legal compliance and long-term maintainability.

⸻

QUALITY PHILOSOPHY

Educational quality is more important than implementation speed.

The platform must prefer:

Correctness

Consistency

Traceability

Explainability

Maintainability

Deterministic Behaviour

Teacher Trust

Student Benefit

No feature should bypass quality assurance.

⸻

PRODUCTION READINESS DEFINITION

A feature is Production Ready only when:

Business Logic Complete

Architecture Approved

Implementation Complete

Unit Tests Pass

Integration Tests Pass

Golden Tests Pass

Repository Validation Passes

Knowledge Validation Passes

Question Validation Passes

Diagram Validation Passes

Teacher Validation Passes

Performance Targets Met

Security Review Passed

EOS Gate Passed

Documentation Complete

Monitoring Ready

Rollback Ready

If any requirement fails:

The feature remains NOT PRODUCTION READY.

⸻

ACCEPTANCE CRITERIA

Every educational feature must satisfy:

Curriculum Accuracy

Educational Accuracy

Concept Accuracy

Answer Accuracy

Metadata Completeness

Question Traceability

Diagram Traceability

Repository Traceability

Versioning

Teacher Review

Certification

Performance

Auditability

No partial acceptance.

⸻

CURRICULUM QA

Verify:

Correct Board

Correct Class

Correct Subject

Correct Chapter

Correct Topic

Correct Subtopic

Correct Learning Outcome

Correct Competency

Correct Curriculum Boundary

Correct Foundation Boundary

No educational asset should violate curriculum constraints.

⸻

KNOWLEDGE BASE QA

Verify:

Every Concept exists.

Every Concept has relationships.

Every Concept has Learning Outcomes.

Every Concept has Competencies.

No orphan Concepts.

No duplicate Concepts.

No missing hierarchy.

No broken references.

⸻

QUESTION QA

Every Question must pass:

Curriculum Validation

Concept Validation

Difficulty Validation

Bloom Validation

Competency Validation

Answer Validation

Metadata Validation

Duplicate Detection

Trust Validation

Teacher Validation

Certification

Questions failing any validation must never enter production.

⸻

ANSWER QA

Verify:

Correct Answer

Alternative Answers

Explanation

Step-by-Step Solution

Keywords

Marking Scheme

Scientific Accuracy

Mathematical Accuracy

Language Accuracy

Teacher Approval

⸻

DIAGRAM QA

Verify:

Diagram belongs to Concept.

Diagram belongs to Question.

Diagram matches curriculum.

Diagram is original.

Diagram is editable.

Diagram renders correctly.

SVG valid.

Geometry valid.

Circuit valid.

Labels correct.

Teacher approved.

Never use copyrighted diagrams.

⸻

BLUEPRINT QA

Verify:

Marks Distribution

Difficulty Distribution

Bloom Distribution

Competency Distribution

Question Family Distribution

Chapter Coverage

Time Allocation

Diagram Requirements

Blueprint Completeness

⸻

CERTIFIED QUESTION BANK QA

Verify:

No Duplicate Questions

No Missing Metadata

No Broken References

Version History Exists

Trust Status Exists

Quality Score Exists

Teacher Approval Exists

Concept Mapping Exists

Diagram Mapping Exists (where applicable)

Repository Traceability Exists

⸻

REPOSITORY QA

Verify:

Repository Certified

Downloads Verified

Checksums Valid

Metadata Exists

Indexes Updated

No Missing Files

No Corrupted Files

No Invalid PDFs

Repository Audit Passed

Knowledge Generation Allowed

⸻

COPYRIGHT QA

Verify:

Official Sources Used

No Illegal Downloads

No Paywall Bypass

No Copyrighted Question Reproduction

No Copyrighted Diagram Reproduction

Generated Questions Original

Generated Diagrams Original

License Metadata Present

⸻

PERFORMANCE QA

Target:

Fast Repository Search

Fast Knowledge Search

Fast Question Search

Fast Paper Generation

Fast Diagram Loading

Fast Blueprint Validation

Fast Metadata Lookup

Scalable Architecture

Minimal Runtime AI Calls

Maximum Certified Asset Reuse

⸻

SECURITY QA

Verify:

Repository Integrity

Metadata Integrity

Teacher Authorization

Approval Workflow

Audit Logging

Version History

Access Control

Change Tracking

No unauthorized educational modifications.

⸻

TESTING STRATEGY

Testing should occur in multiple layers.

Unit Testing

↓

Integration Testing

↓

Pipeline Testing

↓

Repository Testing

↓

Knowledge Testing

↓

Question Testing

↓

Diagram Testing

↓

Blueprint Testing

↓

Assessment Testing

↓

Teacher Acceptance Testing

↓

Golden Testing

↓

Regression Testing

↓

Production Certification

Every layer must pass.

⸻

GOLDEN TESTS

Maintain permanent Golden Test Suites.

Examples:

Curriculum Parsing

Knowledge Extraction

Concept Graph

Question Generation

Answer Generation

Diagram Generation

Blueprint Solver

Paper Assembly

Metadata Generation

Repository Certification

Future changes must never break Golden Tests.

⸻

REGRESSION TESTING

Every implementation must verify:

Existing Questions remain valid.

Existing Papers remain valid.

Existing Diagrams remain valid.

Existing Metadata remains valid.

Existing APIs remain compatible.

Existing Blueprint behaviour remains unchanged.

Backward compatibility is mandatory.

⸻

RED TEAM INTEGRATION

Integrate with the existing Red Team framework.

Validate:

Educational correctness

Security

Prompt Injection Resistance

AI Safety

Repository Safety

Question Integrity

Diagram Integrity

Teacher Workflow

Data Isolation

Copyright Compliance

Do not create a second Red Team process.

Extend the existing framework.

⸻

RELEASE GATES

No release should proceed until:

Repository Gate PASS

Knowledge Gate PASS

Concept Gate PASS

Question Gate PASS

Diagram Gate PASS

Validation Gate PASS

Teacher Gate PASS

Golden Tests PASS

Regression PASS

Performance PASS

EOS PASS

Architecture PASS

Only then:

Production Release Approved.

⸻

METRICS

Continuously monitor:

Repository Health

Knowledge Coverage

Concept Coverage

Question Coverage

Diagram Coverage

Teacher Approval Rate

Question Quality

Diagram Quality

Curriculum Coverage

Duplicate Rate

Validation Failure Rate

Runtime Performance

Student Outcomes

These metrics should become permanent operational dashboards.

⸻

IMPLEMENTATION GUIDELINES

Do not introduce a separate QA architecture.

Integrate these standards into the existing testing framework, EOS gates, roadmap and implementation plan.

Reuse existing quality infrastructure.

Extend existing acceptance criteria.

Maintain backward compatibility.

Preserve the approved Program Baseline.

This document becomes the canonical Quality Assurance and Production Readiness standard for the entire Assessment Intelligence Platform.


PART 10 — FUTURE VISION, PLATFORM EVOLUTION & LONG-TERM ROADMAP

PURPOSE

This document defines the long-term evolution strategy of the Assessment Intelligence Platform.

It is not an implementation roadmap.

It is a strategic architectural vision.

The objective is to ensure that every implementation decision made today remains compatible with future educational capabilities without requiring major architectural redesign.

All future features should naturally extend the current platform.

⸻

LONG-TERM PHILOSOPHY

The Assessment Intelligence Platform should evolve from a Question Paper Generator into a complete Educational Intelligence Platform.

The long-term objective is to build an adaptive educational ecosystem capable of understanding curriculum, learning, assessment and student progress.

Educational intelligence should continuously improve while preserving backward compatibility.

⸻

EVOLUTION STAGES

Stage 1

Curriculum Intelligence

↓

Stage 2

Knowledge Intelligence

↓

Stage 3

Assessment Intelligence

↓

Stage 4

Adaptive Assessment Intelligence

↓

Stage 5

Personalized Learning Intelligence

↓

Stage 6

Institutional Intelligence

↓

Stage 7

National Scale Educational Intelligence

Every future stage must extend previous stages.

Never replace existing architecture.

⸻

ADAPTIVE ASSESSMENT

Future versions should support adaptive assessments.

Examples:

Student-specific papers

Weak-topic focused assessments

Difficulty adaptation

Personalized revision papers

Automatic practice generation

Adaptive challenge questions

Adaptive remedial assessments

This functionality should reuse the existing Certified Question Bank.

⸻

PERSONALIZED LEARNING

The platform should eventually understand:

Student strengths

Student weaknesses

Learning speed

Concept mastery

Revision history

Assessment history

Learning gaps

Confidence levels

Future recommendations should be based on verified educational intelligence.

⸻

CONTINUOUS LEARNING

Educational assets should continuously evolve using:

Curriculum revisions

Teacher feedback

Student analytics

Assessment outcomes

Question performance

Diagram performance

Competency improvements

Knowledge Base updates

Learning should never stop after initial implementation.

⸻

MULTI-LANGUAGE SUPPORT

The architecture should support future expansion to:

English

Telugu

Hindi

Tamil

Kannada

Malayalam

Marathi

Other Indian languages

International languages

The educational meaning must remain identical across translations.

⸻

FUTURE CURRICULUM SUPPORT

Future boards should be supported without architectural redesign.

Examples:

State Boards

National Boards

International Boards

Vocational Curricula

Skill Development Programs

Professional Certifications

Competitive Examinations

The platform should remain curriculum-independent.

⸻

ADVANCED ASSESSMENT TYPES

Future support may include:

Project Evaluation

Practical Assessments

Laboratory Assessments

Coding Assessments

Essay Evaluation

Portfolio Assessment

Oral Examination

Interview Assessment

Presentation Evaluation

Activity-based Assessment

These should integrate with the existing Assessment Intelligence Platform.

⸻

ADVANCED QUESTION TYPES

Future support:

Interactive Questions

Simulation Questions

Image-based Questions

Audio Questions

Video Questions

AR/VR Assessments

Coding Challenges

Case Simulations

Real-world Scenarios

These should extend the existing Question Family model.

⸻

ADVANCED DIAGRAM INTELLIGENCE

Future Diagram Intelligence should support:

Interactive SVG

Animated Diagrams

3D Models

Scientific Simulations

Dynamic Circuit Builders

Mathematical Visualization

Virtual Laboratory Diagrams

Teacher-customized diagrams

Student practice diagrams

All future diagrams should remain editable and reusable.

⸻

AI EVOLUTION

Future AI capabilities may include:

Automatic curriculum comparison

Automatic syllabus migration

Automatic blueprint generation

Automatic competency mapping

Automatic misconception detection

Automatic learning path generation

Automatic remedial recommendation

Automatic teacher assistance

Automatic educational insights

AI remains an assistant.

Educational governance remains under teacher authority.

⸻

ANALYTICS EVOLUTION

Future analytics may include:

School Performance

Teacher Performance

Class Performance

District Comparison

State Comparison

Curriculum Effectiveness

Question Quality Trends

Learning Trend Analysis

Competency Progress

Educational Health Scores

These should extend the existing Analytics Service.

⸻

ADAPTIVE AI

Future Adaptive AI should personalize educational recommendations using:

Curriculum

Student Progress

Teacher Feedback

Assessment Results

Learning Behaviour

Concept Mastery

Without modifying the certified educational assets.

Adaptive AI should recommend.

It should not silently modify certified content.

⸻

FUTURE ARCHITECTURE PRINCIPLES

Future development should always prefer:

Extension

Composition

Configuration

Metadata

Reusable Educational Assets

Deterministic Behaviour

Incremental Improvement

Avoid:

Large rewrites

Architecture replacement

Duplicate systems

Breaking compatibility

Hard-coded educational logic

⸻

IMPLEMENTATION GUIDELINES

This document is strategic guidance only.

It must not introduce immediate implementation work.

It must not modify the approved roadmap.

It must simply ensure that today’s implementation remains compatible with tomorrow’s educational requirements.

Every future enhancement should naturally integrate into the existing Assessment Intelligence Platform.

This document becomes the long-term architectural vision for the Akshara Assessment Intelligence Platform.


PART 11 — ASSESSMENT INTELLIGENCE DESIGN PATTERNS & IMPLEMENTATION PRINCIPLES

PURPOSE

This document defines the canonical design patterns, implementation principles and architectural standards for the Assessment Intelligence Platform.

Its purpose is to ensure that every future implementation follows a consistent engineering approach while preserving the approved architecture, roadmap and EOS Constitution.

This document is implementation guidance.

It is NOT an implementation task.

⸻

DESIGN PHILOSOPHY

Every implementation should follow these principles:

Simple before Complex

Extend before Replace

Reuse before Rewrite

Configuration before Hard-coding

Composition before Inheritance

Validation before Persistence

Certification before Production

Metadata before Intelligence

Knowledge before Questions

Concept before Content

Quality before Quantity

Educational correctness always takes precedence over implementation convenience.

⸻

PATTERN 1 — REPOSITORY PATTERN

Every educational asset should enter through a controlled repository.

Official Source

↓

Repository Download

↓

Verification

↓

Certification

↓

Knowledge Base

↓

Production Assets

Never allow direct ingestion into production repositories.

⸻

PATTERN 2 — KNOWLEDGE PATTERN

Documents are temporary.

Knowledge is permanent.

Every document should be converted into structured educational knowledge.

Never build business logic directly around PDF documents.

⸻

PATTERN 3 — CONCEPT-FIRST PATTERN

Every educational operation begins with Concepts.

Questions

Answers

Diagrams

Blueprints

Competencies

Analytics

must all reference Concept IDs.

Never generate isolated educational content.

⸻

PATTERN 4 — GENERATE → VALIDATE → CERTIFY

Every AI-generated asset follows the same lifecycle.

Generate

↓

Validate

↓

Teacher Review

↓

Certification

↓

Production

No shortcut is allowed.

⸻

PATTERN 5 — OFFLINE AI PATTERN

AI performs expensive educational work offline.

Examples:

Knowledge Extraction

Question Generation

Answer Generation

Diagram Generation

Metadata Generation

Distractor Generation

Curriculum Analysis

Competency Mapping

Runtime should reuse Certified Assets.

⸻

PATTERN 6 — RUNTIME ASSEMBLY PATTERN

Runtime should never regenerate educational content unless absolutely necessary.

Teacher Configuration

↓

Blueprint

↓

Certified Question Bank

↓

Certified Diagram Library

↓

Assembly

↓

Export

Fast.

Deterministic.

Predictable.

⸻

PATTERN 7 — METADATA-FIRST PATTERN

Every educational asset should be metadata-driven.

Business logic should use metadata rather than hard-coded educational rules.

Examples:

Difficulty

Bloom

Competencies

Concept IDs

Learning Outcomes

Exam Profiles

Quality Scores

Trust Levels

Version

⸻

PATTERN 8 — QUALITY EVOLUTION PATTERN

Quality should evolve continuously.

Teacher Review

↓

Student Analytics

↓

Question Performance

↓

Quality Score

↓

Future Improvement

The system should continuously improve educational assets.

⸻

PATTERN 9 — VERSIONING PATTERN

Every educational asset supports versioning.

Questions

Diagrams

Concepts

Blueprints

Templates

Knowledge

Metadata

Nothing should be permanently overwritten.

Support rollback.

Maintain complete history.

⸻

PATTERN 10 — COPYRIGHT-SAFE PATTERN

Downloaded educational resources are reference material.

Production educational assets must be original.

Workflow:

Reference

↓

Knowledge Extraction

↓

Concept Understanding

↓

Original Generation

↓

Validation

↓

Certification

Never publish copied educational content.

⸻

PATTERN 11 — DIAGRAM PATTERN

Diagram generation should follow:

Concept

↓

Diagram Specification

↓

Vector Generation

↓

Validation

↓

Teacher Approval

↓

Certified Diagram Library

↓

Production

Prefer SVG and editable vector formats.

Avoid raster images.

⸻

PATTERN 12 — FOUNDATION PATTERN

Foundation Programs increase:

Depth

Reasoning

Application

Critical Thinking

Problem Solving

Do not increase curriculum scope unless explicitly configured.

⸻

PATTERN 13 — EVENT-DRIVEN EVOLUTION

Educational assets should evolve through events.

Examples:

Curriculum Updated

↓

Knowledge Updated

↓

Concept Updated

↓

Question Impact Analysis

↓

Diagram Impact Analysis

↓

Regeneration Queue

↓

Certification

↓

Production Update

Avoid rebuilding the complete platform.

⸻

PATTERN 14 — SERVICE ISOLATION

Every service owns its own responsibility.

Services communicate only through validated educational entities.

Avoid tight coupling.

Avoid circular dependencies.

Maintain deterministic interfaces.

⸻

PATTERN 15 — CONFIGURATION PATTERN

Never hard-code:

Exam Profiles

Difficulty Rules

Bloom Rules

Validation Rules

Subscription Capabilities

Question Mix

Foundation Rules

Diagram Policies

Everything should remain configurable.

⸻

PATTERN 16 — OBSERVABILITY PATTERN

Every pipeline should expose:

Structured Logs

Metrics

Audit Trails

Health Status

Performance Statistics

Error Reports

Recovery Status

Quality Reports

Every educational decision should be traceable.

⸻

PATTERN 17 — TEST-FIRST PATTERN

Every major educational feature should have:

Unit Tests

Integration Tests

Golden Tests

Regression Tests

Acceptance Tests

Repository Tests

Validation Tests

Teacher Acceptance Tests

Implementation without verification is incomplete.

⸻

PATTERN 18 — EVOLUTION PATTERN

Prefer:

Incremental Improvement

Modular Extension

Backward Compatibility

Continuous Refinement

Avoid:

Large Refactoring

Architecture Replacement

Parallel Systems

Duplicate Logic

Breaking Existing Behaviour

⸻

IMPLEMENTATION STANDARDS

Every implementation must preserve:

EOS Constitution

Approved Roadmap

Assessment Intelligence Platform

Curriculum Intelligence Platform

Repository Certification

Download Verification

Question Trust Lifecycle

Teacher Authority

Copyright Compliance

Production Stability

⸻

FINAL IMPLEMENTATION PRINCIPLE

The Assessment Intelligence Platform should evolve through disciplined engineering rather than continuous redesign.

Every implementation decision should answer these questions:

Does this improve educational quality?

Does this preserve architecture?PART 12 — ANTI-PATTERNS, NON-NEGOTIABLE SAFEGUARDS & ENGINEERING MISTAKES

PURPOSE

This document defines what must NEVER be implemented within the Assessment Intelligence Platform.

These anti-patterns protect educational quality, architectural integrity, copyright compliance, runtime performance and long-term maintainability.

Whenever implementation decisions conflict with these rules, these safeguards take precedence unless explicitly overridden by the Project Owner.

⸻

PHILOSOPHY

The fastest implementation is not always the best implementation.

Protecting educational quality is more important than shipping features quickly.

Every implementation should prioritize correctness, traceability, maintainability and long-term sustainability.

⸻

EDUCATIONAL ANTI-PATTERNS

Never generate questions without Concept Mapping.

Never generate questions directly from PDF content.

Never allow questions outside curriculum boundaries.

Never generate questions without validated answers.

Never generate questions without complete metadata.

Never publish AI-generated questions without validation.

Never bypass Teacher Approval for certification.

Never allow uncertified questions into production papers.

Never create isolated questions without Question Families.

Never create educational assets that cannot be traced back to verified curriculum sources.

⸻

COPYRIGHT ANTI-PATTERNS

Never reproduce textbook questions verbatim.

Never reproduce previous board examination questions verbatim.

Never reproduce copyrighted diagrams.

Never scrape or use illegally shared educational material.

Never bypass licensing restrictions.

Never use previous papers as production content.

Use previous papers only for:

Pattern Analysis

Blueprint Analysis

Difficulty Analysis

Competency Analysis

Question Style Analysis

Educational Intelligence

Always generate original educational assets.

⸻

AI ANTI-PATTERNS

Never invoke AI for every runtime paper generation.

Never depend on AI availability for normal paper assembly.

Never allow AI to silently modify certified educational assets.

Never allow AI to bypass validation pipelines.

Never allow AI to override teacher decisions.

Never treat AI confidence as educational truth.

AI assists.

Teachers certify.

⸻

KNOWLEDGE BASE ANTI-PATTERNS

Never rebuild the complete Knowledge Base unnecessarily.

Never duplicate Concepts.

Never duplicate Learning Outcomes.

Never duplicate Competencies.

Never create disconnected educational entities.

Prefer incremental evolution.

⸻

QUESTION BANK ANTI-PATTERNS

Never store duplicate questions.

Never delete historical versions.

Never overwrite certified questions.

Never lose audit history.

Never lose teacher review history.

Never lose repository traceability.

⸻

DIAGRAM ANTI-PATTERNS

Never embed screenshots from textbooks.

Never store raster images when editable vector diagrams are possible.

Never publish diagrams without validation.

Never create diagrams disconnected from Concept IDs.

Never use copyrighted educational illustrations.

Generate original reusable diagrams.

⸻

SERVICE ARCHITECTURE ANTI-PATTERNS

Never duplicate services.

Never introduce circular dependencies.

Never tightly couple educational services.

Never bypass service responsibilities.

Never place business rules in user interface code.

Never mix runtime logic with AI authoring logic.

⸻

DATABASE ANTI-PATTERNS

Never duplicate educational data.

Never create multiple sources of truth.

Never store derived values unnecessarily.

Never break referential integrity.

Never bypass version control.

Every educational asset must remain traceable.

⸻

VALIDATION ANTI-PATTERNS

Never skip Repository Certification.

Never skip Curriculum Boundary Validation.

Never skip Metadata Validation.

Never skip Answer Validation.

Never skip Diagram Validation.

Never skip Teacher Validation.

Every production asset must pass the complete validation pipeline.

⸻

PERFORMANCE ANTI-PATTERNS

Never regenerate identical educational assets.

Never repeatedly call AI for already certified content.

Never perform unnecessary full repository rebuilds.

Never duplicate heavy processing.

Always reuse certified educational assets.

⸻

CONFIGURATION ANTI-PATTERNS

Never hard-code:

Blueprint Rules

Exam Profiles

Difficulty Levels

Bloom Rules

Foundation Rules

Validation Thresholds

Subscription Features

Diagram Policies

Repository Policies

Everything should remain configuration-driven.

⸻

ROADMAP ANTI-PATTERNS

Never create parallel implementation plans.

Never create competing architectural standards.

Never bypass EOS.

Never replace approved planning.

Always extend existing architecture.

⸻

ENGINEERING PRINCIPLES

Every implementation should reduce:

Complexity

Duplication

Technical Debt

Maintenance Cost

AI Cost

Runtime Cost

Educational Risk

Legal Risk

⸻

FINAL SAFEGUARDS

Before approving any implementation, always verify:

Does it preserve educational quality?

Does it preserve curriculum integrity?

Does it preserve originality?

Does it preserve teacher authority?

Does it preserve repository traceability?

Does it preserve backward compatibility?

Does it preserve architectural consistency?

Does it preserve EOS compliance?

If the answer to any question is NO, the implementation must be redesigned before approval.

⸻

FINAL PRINCIPLE

The Assessment Intelligence Platform is a long-term educational infrastructure, not simply a Question Paper Generator.

Every implementation decision should strengthen:

The Curriculum Intelligence Platform

The Certified Question Bank

The Concept Graph

The Knowledge Base

The Diagram Library

The Assessment Intelligence Platform

The educational experience of teachers and students.

These safeguards are permanent and should remain valid across all future versions of the platform.

Does this reduce duplication?

Does this maintain backward compatibility?

Does this strengthen the Certified Question Bank?

Does this improve long-term maintainability?

If the answer to any of these questions is NO, redesign the implementation before proceeding.

This document becomes the canonical implementation guideline for all future Assessment Intelligence development using Claude Opus 4.8.

