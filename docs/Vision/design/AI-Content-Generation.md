# Design — AI Content Generation

**Status:** Future · broader than question papers (homework, worksheets, lesson plans, remarks)

## Goals

Reduce teacher admin time via AI drafts grounded in school curriculum and student context (aggregated, non-PII where possible).

## Architecture

| Module | Input | Output |
|--------|-------|--------|
| Homework generator | Chapter, difficulty, count | Assignment list |
| Worksheet generator | Topic, grade | Printable worksheet |
| Lesson planner | Syllabus week, periods | Day-wise plan |
| Report remarks | Grade band, traits | Narrative remark drafts |
| Parent meeting summary | Attendance + grades summary | Talking points |

Shared **content generation service** with vertical-specific prompt packs.

## Permissions

Same family as question papers: `generate*` + `approve*` per content type. Principals may approve school-wide templates.

## Data model

- `edu_content_generations` — job status, inputs, outputs, reviewer  
- Link to `edu_syllabus_nodes` and academic year  

## APIs

- `POST /education/content/generate` — type enum + params  
- `GET /education/content/jobs/:id`  

## Rollout plan

1. Read-only suggestions in Copilot (v7.4 extension)  
2. Homework + worksheet MVP  
3. Lesson planner + remarks  
4. Parent meeting summary  

## Risks

| Risk | Mitigation |
|------|------------|
| Off-curriculum content | Syllabus RAG gate |
| Bias in remarks | Teacher must edit before save |
| Cost at scale | Per-school token budgets |
