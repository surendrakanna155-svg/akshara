import type { TenantQueryClient } from "../tenant_db.ts";

/**
 * PRA-P1-18: thrown when no real curriculum template exists for the requested
 * board+grade+subject. Previously the generator silently inserted a fabricated
 * 2-chapter "Unit 1 / Unit 2" stub — indistinguishable from a real syllabus and
 * counted into the Principal's coverage-% over a meaningless denominator. Now it
 * refuses: no fake curriculum is ever written. The provisioning flows already
 * catch this and record an honest "syllabus auto-generation skipped" warning; the
 * direct generate endpoint returns 422 so the school KNOWS the grade is unseeded.
 */
export class NoSyllabusTemplateError extends Error {
  constructor(
    public readonly board: string,
    public readonly gradeLabel: string,
    public readonly subjectName: string,
  ) {
    super(
      `No curriculum template for ${board} / ${gradeLabel} / ${subjectName}; ` +
        `syllabus cannot be auto-generated (only seeded grades are supported).`,
    );
    this.name = "NoSyllabusTemplateError";
  }
}

export interface SubjectTemplateRow {
  id: string;
  board: string;
  subject_code: string;
  subject_name: string;
  category: string;
  grade_label: string;
  chapters: Array<{ name: string; topics: string[] }>;
}

export interface SyllabusChapterRow {
  id: string;
  organization_id: string;
  school_id: string;
  academic_year_id: string;
  subject_id: string;
  class_name: string;
  chapter_name: string;
  sequence_order: number;
  status: string;
}

export interface SyllabusTopicRow {
  id: string;
  subject_id: string;
  class_name: string;
  chapter_id: string | null;
  topic_name: string;
  sequence_order: number;
  status: string;
}

export async function listSubjectTemplates(
  db: TenantQueryClient,
  board?: string,
  gradeLabel?: string,
): Promise<SubjectTemplateRow[]> {
  const conditions = ["1=1"];
  const params: unknown[] = [];
  if (board) {
    params.push(board);
    conditions.push(`board = $${params.length}`);
  }
  if (gradeLabel) {
    params.push(gradeLabel);
    conditions.push(`grade_label = $${params.length}`);
  }
  const rows = await db.queryObject<SubjectTemplateRow & { chapters: unknown }>(
    `SELECT id, board, subject_code, subject_name, category, grade_label, chapters
     FROM subject_templates WHERE ${conditions.join(" AND ")}
     ORDER BY grade_label, subject_name`,
    params,
  );
  return rows.map((r) => ({
    ...r,
    chapters: parseChapters(r.chapters),
  }));
}

function parseChapters(raw: unknown): Array<{ name: string; topics: string[] }> {
  if (!Array.isArray(raw)) return [];
  return raw.map((c) => {
    const ch = c as Record<string, unknown>;
    return {
      name: String(ch.name ?? ""),
      topics: Array.isArray(ch.topics) ? ch.topics.map(String) : [],
    };
  });
}

export async function generateSyllabusFromTemplates(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  input: {
    academicYearId: string;
    className: string;
    subjectId: string;
    subjectName: string;
    gradeLabel: string;
    board?: string;
    source?: string;
    createdBy: string;
  },
): Promise<{ chaptersCreated: number; topicsCreated: number; generationId: string }> {
  const board = input.board ?? "CBSE";
  const templates = await listSubjectTemplates(db, board, input.gradeLabel);
  const match = templates.find(
    (t) =>
      t.subject_name.toLowerCase() === input.subjectName.toLowerCase() ||
      t.subject_code.toLowerCase() === input.subjectName.slice(0, 3).toLowerCase(),
  );
  // PRA-P1-18: refuse rather than fabricate. A missing template used to seed a
  // fake "Unit 1 / Unit 2" scaffold (with no manual-edit path to fix it) that
  // then polluted syllabus coverage-%. Only real, seeded curriculum is written.
  if (!match || match.chapters.length === 0) {
    throw new NoSyllabusTemplateError(board, input.gradeLabel, input.subjectName);
  }
  const chapters = match.chapters;

  let chaptersCreated = 0;
  let topicsCreated = 0;
  let chapterOrder = 0;

  for (const chapter of chapters) {
    const chapterRows = await db.queryObject<SyllabusChapterRow>(
      `INSERT INTO syllabus_chapters (
         organization_id, school_id, academic_year_id, subject_id, class_name,
         chapter_name, sequence_order
       ) VALUES ($1, $2, $3, $4, $5, $6, $7)
       ON CONFLICT (organization_id, school_id, subject_id, class_name, chapter_name)
       DO UPDATE SET sequence_order = EXCLUDED.sequence_order
       RETURNING *`,
      [
        orgId,
        schoolId,
        input.academicYearId,
        input.subjectId,
        input.className,
        chapter.name,
        chapterOrder++,
      ],
    );
    const chapterRow = chapterRows[0]!;
    chaptersCreated++;

    let topicOrder = 0;
    for (const topicName of chapter.topics) {
      await db.queryObject(
        `INSERT INTO syllabus_topics (
           organization_id, school_id, subject_id, class_name, chapter_id,
           academic_year_id, topic_name, sequence_order
         ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
         ON CONFLICT (organization_id, school_id, subject_id, class_name, topic_name) DO NOTHING`,
        [
          orgId,
          schoolId,
          input.subjectId,
          input.className,
          chapterRow.id,
          input.academicYearId,
          topicName,
          topicOrder++,
        ],
      );
      topicsCreated++;
    }
  }

  const genRows = await db.queryObject<{ id: string }>(
    `INSERT INTO syllabus_generations (
       organization_id, school_id, academic_year_id, source,
       chapters_created, topics_created, created_by
     ) VALUES ($1, $2, $3, $4, $5, $6, $7)
     RETURNING id`,
    [
      orgId,
      schoolId,
      input.academicYearId,
      input.source ?? "template",
      chaptersCreated,
      topicsCreated,
      input.createdBy,
    ],
  );

  return {
    chaptersCreated,
    topicsCreated,
    generationId: genRows[0]!.id,
  };
}

export async function cloneSyllabusForYear(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  fromYearId: string,
  toYearId: string,
  createdBy: string,
): Promise<{ chaptersCreated: number; topicsCreated: number }> {
  const chapters = await db.queryObject<SyllabusChapterRow>(
    `SELECT * FROM syllabus_chapters
     WHERE organization_id = $1 AND school_id = $2 AND academic_year_id = $3`,
    [orgId, schoolId, fromYearId],
  );

  let chaptersCreated = 0;
  let topicsCreated = 0;

  for (const ch of chapters) {
    const newChapter = await db.queryObject<SyllabusChapterRow>(
      `INSERT INTO syllabus_chapters (
         organization_id, school_id, academic_year_id, subject_id, class_name,
         chapter_name, sequence_order, status
       ) VALUES ($1, $2, $3, $4, $5, $6, $7, 'pending')
       ON CONFLICT (organization_id, school_id, subject_id, class_name, chapter_name) DO NOTHING
       RETURNING *`,
      [orgId, schoolId, toYearId, ch.subject_id, ch.class_name, ch.chapter_name, ch.sequence_order],
    );
    if (newChapter.length === 0) continue;
    chaptersCreated++;

    const topics = await db.queryObject<SyllabusTopicRow>(
      `SELECT * FROM syllabus_topics
       WHERE organization_id = $1 AND school_id = $2 AND chapter_id = $3`,
      [orgId, schoolId, ch.id],
    );
    for (const topic of topics) {
      await db.queryObject(
        `INSERT INTO syllabus_topics (
           organization_id, school_id, subject_id, class_name, chapter_id,
           academic_year_id, topic_name, sequence_order, status
         ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'pending')
         ON CONFLICT (organization_id, school_id, subject_id, class_name, topic_name) DO NOTHING`,
        [
          orgId,
          schoolId,
          topic.subject_id,
          topic.class_name,
          newChapter[0]!.id,
          toYearId,
          topic.topic_name,
          topic.sequence_order,
        ],
      );
      topicsCreated++;
    }
  }

  await db.queryObject(
    `INSERT INTO syllabus_generations (
       organization_id, school_id, academic_year_id, source,
       chapters_created, topics_created, created_by
     ) VALUES ($1, $2, $3, 'clone', $4, $5, $6)`,
    [orgId, schoolId, toYearId, chaptersCreated, topicsCreated, createdBy],
  );

  return { chaptersCreated, topicsCreated };
}

export async function listSyllabusChapters(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  academicYearId?: string,
): Promise<SyllabusChapterRow[]> {
  if (academicYearId) {
    return await db.queryObject<SyllabusChapterRow>(
      `SELECT * FROM syllabus_chapters
       WHERE organization_id = $1 AND school_id = $2 AND academic_year_id = $3
       ORDER BY class_name, sequence_order`,
      [orgId, schoolId, academicYearId],
    );
  }
  return await db.queryObject<SyllabusChapterRow>(
    `SELECT * FROM syllabus_chapters
     WHERE organization_id = $1 AND school_id = $2
     ORDER BY class_name, sequence_order`,
    [orgId, schoolId],
  );
}

/**
 * Real syllabus topics for a class/subject (and optionally a single chapter),
 * used by the teacher's daily-capture UI to pick the ACTUAL topic being
 * completed instead of a client-fabricated id (P1 fix — the client previously
 * sent `topic_${lessonLogId}`, which is not a real `syllabus_topics.id` and
 * fails the `syllabus_topic_completions.topic_id` FK).
 */
export async function listSyllabusTopics(
  db: TenantQueryClient,
  orgId: string,
  schoolId: string,
  filters: { className?: string; subjectId?: string; chapterId?: string } = {},
): Promise<SyllabusTopicRow[]> {
  const conditions = ["organization_id = $1", "school_id = $2"];
  const params: unknown[] = [orgId, schoolId];
  if (filters.className) {
    params.push(filters.className);
    conditions.push(`class_name = $${params.length}`);
  }
  if (filters.subjectId) {
    params.push(filters.subjectId);
    conditions.push(`subject_id = $${params.length}`);
  }
  if (filters.chapterId) {
    params.push(filters.chapterId);
    conditions.push(`chapter_id = $${params.length}`);
  }
  return await db.queryObject<SyllabusTopicRow>(
    `SELECT id, subject_id, class_name, chapter_id, topic_name, sequence_order, status
     FROM syllabus_topics WHERE ${conditions.join(" AND ")}
     ORDER BY class_name, sequence_order`,
    params,
  );
}

export function topicToApi(t: SyllabusTopicRow) {
  return {
    id: t.id,
    subjectId: t.subject_id,
    className: t.class_name,
    chapterId: t.chapter_id,
    topicName: t.topic_name,
    sequenceOrder: t.sequence_order,
    status: t.status,
  };
}

export function templateToApi(t: SubjectTemplateRow) {
  return {
    id: t.id,
    board: t.board,
    subjectCode: t.subject_code,
    subjectName: t.subject_name,
    category: t.category,
    gradeLabel: t.grade_label,
    chapters: t.chapters,
  };
}

export function chapterToApi(c: SyllabusChapterRow) {
  return {
    id: c.id,
    academicYearId: c.academic_year_id,
    subjectId: c.subject_id,
    className: c.class_name,
    chapterName: c.chapter_name,
    sequenceOrder: c.sequence_order,
    status: c.status,
  };
}
