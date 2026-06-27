# Akshara ERP — AI Usage & Disclaimer

**Document version:** 1.0
**Status:** Draft for owner sign-off (see [PLACEHOLDERS.md](PLACEHOLDERS.md))
**Operator:** **[LEGAL ENTITY NAME]** ("Akshara", "we", "us").

> This document explains, in plain language, how Akshara uses artificial
> intelligence (AI), what AI does and does not do with your data, and the limits of
> AI output. It supports the [Privacy Policy](PRIVACY_POLICY.md) and the
> [Acceptable Use Policy](ACCEPTABLE_USE_POLICY.md).

---

## 1. Where AI is used

Akshara offers **optional** AI-assisted features that help staff and parents work
faster. These currently include:

- An **assistant / copilot** that answers questions and drafts text within the app.
- **Parent insights** — plain-language summaries of a child's attendance, results
  and progress for the parent.
- **Question-paper assistance** — suggesting questions to fill gaps in a draft
  paper, drawn from the school's own question bank and syllabus.
- **Admissions assistance** — summarising the school's own enquiry/lead funnel and
  suggesting next actions.
- **Director / executive summaries** — narrative summaries of the school's own
  operational metrics.
- **Predictions** — risk/likelihood scores (e.g. fee-default or admission
  conversion) with a written explanation.
- **Marketing / poster captions** — draft captions and copy for school posts.

Every AI feature is designed with a **safe fallback**: if the AI service is not
available, the feature uses deterministic (non-AI) logic or is hidden, so the app
keeps working.

## 2. Which AI provider we use

- The AI provider is **Anthropic** (the "Claude" family of models). Requests are
  sent to Anthropic's API over an encrypted connection.
- Anthropic processes the text we send **transiently** to produce a response. We do
  **not** authorise the provider to use your data to train its models, and student
  data is not used to train unrelated models.
- The provider's servers may be located **outside India**. We send only the
  **minimum** text needed for the feature, drawn from data the requesting user is
  already authorised to see.
- AI features only run when the operator has enabled them (an API key is
  configured). If they are not enabled, no data is sent to any AI provider.

See the [Sub-processors list](SUBPROCESSORS.md) for the current AI provider and its
role.

## 3. What AI does NOT do

- ❌ It does **not** see data the requesting user isn't already allowed to see —
  AI runs within the same role-based access controls as the rest of the app.
- ❌ It does **not** build advertising or marketing profiles of children or
  families.
- ❌ It does **not** make automated final decisions about a person. AI output is a
  **draft or suggestion** for a human to review and act on.
- ❌ It is **not** used for any tracking, behavioural monitoring or targeted
  advertising directed at children.

## 4. Important disclaimer — AI can be wrong

AI features are **assistive tools, not authoritative sources**. AI-generated text,
summaries, scores, predictions and suggestions:

- **may be inaccurate, incomplete or out of date**, and
- **must be reviewed by a responsible human** before being relied on, shared with
  parents, published, or used to make any decision about a student, parent or
  staff member.

**Do not** treat AI output as a final exam mark, an official record, financial
advice, legal advice, medical advice, or a guaranteed prediction. Final
responsibility for any academic, financial, disciplinary or administrative decision
always rests with the **school and the authorised human user** — never with the AI.

Predictions and risk scores are **statistical estimates** to help prioritise
attention; they are not judgements about a person and must not be used to unfairly
disadvantage any student.

## 5. Human oversight & content governance

- AI suggestions for sensitive workflows (for example, question papers and
  published posters) pass through an **approval/moderation step** before they go
  live, and rejected or pending items are not published or exported.
- Schools remain responsible for what they approve and publish using AI assistance,
  and must comply with the [Acceptable Use Policy](ACCEPTABLE_USE_POLICY.md).

## 6. Your choices

- AI features are optional. A school can choose not to enable them.
- If you have concerns about an AI-generated output, raise them with your school
  and, if needed, contact **[PRIVACY EMAIL]**.

## 7. Changes

As AI features and the law evolve (including any future AI-specific regulation), we
will update this disclaimer. Material changes are recorded in the
[CHANGELOG](CHANGELOG.md).
