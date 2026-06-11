# Design — AI Question Paper System

**Status:** Future education module · not in v1.0

## Goals

Teachers generate syllabus-aligned papers (unit → annual) with review before print/PDF.

## Architecture

| Component | Role |
|-----------|------|
| Syllabus catalog | Class → subject → chapter → topic (links academic catalog) |
| Question bank | Tagged items: type, difficulty, marks, Bloom level |
| Generator service | LLM + retrieval from bank; constraint solver for total marks |
| Review workflow | Draft → teacher edit → approve → PDF export |
| Audit | Prompt hash, model version, approver |

Build on v7.4 Copilot session pattern — **write** actions require new permissions.

## Permissions

| Permission | Action |
|------------|--------|
| `manageQuestionBank` | CRUD bank items |
| `generateQuestionPaper` | Run generator |
| `approveQuestionPaper` | Publish to class |

## Data model (conceptual)

- `edu_syllabus_nodes`  
- `edu_question_bank_items`  
- `edu_question_papers` (draft/published)  
- `edu_question_paper_sections`  

No v1.0 migrations.

## APIs (conceptual)

- `POST /education/question-papers/generate`  
- `GET /education/question-papers/:id`  
- `POST /education/question-papers/:id/approve`  
- `GET /education/question-bank`  

## Rollout plan

1. Question bank CRUD (no AI)  
2. Template-based paper assembly  
3. LLM generation with human review  
4. PDF + print layout  

## Risks

| Risk | Mitigation |
|------|------------|
| Incorrect syllabus alignment | RAG from verified bank only |
| Copyright / leakage | No external publish without review |
| Student PII in prompts | Anonymize; class-level context only |
