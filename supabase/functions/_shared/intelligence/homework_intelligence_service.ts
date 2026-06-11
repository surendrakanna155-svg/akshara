import type { TenantQueryClient } from "../tenant_db.ts";
import { createHomeworkAssignment } from "../education/education_repository.ts";
import { generateStubHomeworkContent } from "../education/education_generator.ts";
import { listRiskSnapshots } from "./student_risk_repository.ts";

export interface HomeworkIntelligenceInput {
  className: string;
  sectionName?: string;
  subjectName: string;
  examType: string;
  academicYearLabel?: string;
}

export interface HomeworkIntelligencePlan {
  className: string;
  subjectName: string;
  examType: string;
  weakTopics: Array<{ topic: string; chapter: string; avgMarksPercent: number }>;
  riskStudents: Array<{
    studentId: string;
    studentName: string;
    riskLevel: string;
    riskScore: number;
    topReason: string;
  }>;
  revisionSuggestions: string[];
  worksheetSuggestions: Array<{ topic: string; assignmentType: string; reason: string }>;
  recommendedHomework: Array<{ topic: string; title: string; assignmentType: string }>;
  recommendedQuestionPapers: Array<{ examType: string; chapters: string[]; reason: string }>;
  classRecommendations: string[];
  studentRecommendations: Array<{ studentId: string; actions: string[] }>;
  revisionPlans: Array<{ studentId: string; plan: string }>;
  interventionPlans: Array<{ studentId: string; intervention: string; owner: string }>;
}

export async function buildHomeworkIntelligencePlan(
  client: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  input: HomeworkIntelligenceInput,
): Promise<HomeworkIntelligencePlan> {
  const classFilter = input.className.trim();
  const subjectFilter = input.subjectName.trim();

  const topicRows = await client.queryObject<{
    chapter: string;
    topic: string;
    avg_marks: number;
  }>(
    `SELECT
       coalesce(em.class_label, 'General') AS chapter,
       coalesce(em.exam_title, 'Exam') AS topic,
       coalesce(avg(
         CASE WHEN em.max_marks > 0
           THEN (em.marks_obtained::float / em.max_marks) * 100
           ELSE 70 END
       ), 70)::int AS avg_marks
     FROM exam_mark_entries em
     JOIN students s ON s.id = em.student_id
     LEFT JOIN sis_student_enrollments e
       ON e.student_id = s.id AND e.is_current = true
     WHERE em.organization_id = $1
       AND em.school_id = $2
       AND (e.class_name ILIKE $3 OR em.class_label ILIKE $3)
     GROUP BY em.class_label, em.exam_title
     ORDER BY avg_marks ASC
     LIMIT 8`,
    [organizationId, schoolId, `%${classFilter}%`],
  );

  const bankTopics = await client.queryObject<{ chapter: string; topic: string }>(
    `SELECT chapter, topic
     FROM edu_question_bank_items
     WHERE organization_id = $1 AND school_id = $2
       AND subject_name ILIKE $3 AND status = 'active'
     ORDER BY chapter, topic
     LIMIT 10`,
    [organizationId, schoolId, `%${subjectFilter}%`],
  );

  const weakTopics = topicRows
    .filter((r) => r.avg_marks < 65)
    .map((r) => ({
      chapter: r.chapter,
      topic: r.topic,
      avgMarksPercent: r.avg_marks,
    }));

  if (weakTopics.length === 0 && bankTopics.length > 0) {
    for (const row of bankTopics.slice(0, 3)) {
      weakTopics.push({
        chapter: row.chapter,
        topic: row.topic,
        avgMarksPercent: 55,
      });
    }
  }

  const snapshots = await listRiskSnapshots(client, { className: classFilter });
  const riskStudents = snapshots
    .filter((s) => s.risk_level !== "low")
    .map((s) => {
      const inputs = s.inputs as { student_name?: string } | null;
      const reasons = s.reasons as Array<{ label?: string }> | null;
      return {
        studentId: s.student_id,
        studentName: inputs?.student_name ?? s.student_id,
        riskLevel: s.risk_level,
        riskScore: s.risk_score,
        topReason: reasons?.[0]?.label ?? "Risk signal detected",
      };
    });

  const revisionSuggestions = weakTopics.map(
    (t) => `Revision focus: ${t.topic} (${t.chapter}) — class average ${t.avgMarksPercent}%`,
  );

  const worksheetSuggestions = weakTopics.slice(0, 5).map((t) => ({
    topic: t.topic,
    assignmentType: "revision_worksheet",
    reason: `Weak performance in ${t.topic}`,
  }));

  const recommendedHomework = weakTopics.slice(0, 3).map((t) => ({
    topic: t.topic,
    title: `${subjectFilter} homework — ${t.topic}`,
    assignmentType: "homework",
  }));

  const recommendedQuestionPapers = [{
    examType: input.examType,
    chapters: weakTopics.map((t) => t.chapter).filter((c, i, a) => a.indexOf(c) === i).slice(0, 4),
    reason: `Target weak chapters for ${input.examType.replaceAll("_", " ")}`,
  }];

  const classRecommendations = [
    `${weakTopics.length} weak topic(s) identified for ${classFilter} ${subjectFilter}.`,
    `${riskStudents.length} student(s) flagged above low risk.`,
    "Assign revision worksheets before next assessment.",
  ];

  const studentRecommendations = riskStudents.map((s) => ({
    studentId: s.studentId,
    actions: [
      `Assign targeted homework for ${s.topReason}`,
      "Schedule short intervention check-in",
    ],
  }));

  const revisionPlans = riskStudents.map((s) => ({
    studentId: s.studentId,
    plan: `Daily 30-minute revision on ${weakTopics[0]?.topic ?? subjectFilter} for 2 weeks`,
  }));

  const interventionPlans = riskStudents.map((s) => ({
    studentId: s.studentId,
    intervention: s.riskLevel === "critical" || s.riskLevel === "high"
      ? "Principal-led intervention within 48 hours"
      : "Teacher check-in and parent communication",
    owner: s.riskLevel === "critical" ? "principal" : "teacher",
  }));

  return {
    className: classFilter,
    subjectName: subjectFilter,
    examType: input.examType,
    weakTopics,
    riskStudents,
    revisionSuggestions,
    worksheetSuggestions,
    recommendedHomework,
    recommendedQuestionPapers,
    classRecommendations,
    studentRecommendations,
    revisionPlans,
    interventionPlans,
  };
}

export async function storeHomeworkIntelligenceRun(
  client: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  input: HomeworkIntelligenceInput,
  plan: HomeworkIntelligencePlan,
  createdBy: string | null,
): Promise<string> {
  const rows = await client.queryObject<{ id: string }>(
    `INSERT INTO homework_intelligence_runs (
       organization_id, school_id, academic_year_label,
       class_name, section_name, subject_name, exam_type, plan, created_by
     ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8::jsonb, $9)
     RETURNING id`,
    [
      organizationId,
      schoolId,
      input.academicYearLabel ?? "2025-26",
      input.className,
      input.sectionName ?? null,
      input.subjectName,
      input.examType,
      JSON.stringify(plan),
      createdBy,
    ],
  );
  return rows[0]!.id;
}

export async function applyHomeworkRecommendations(
  client: TenantQueryClient,
  organizationId: string,
  schoolId: string,
  runId: string,
  createdBy: string | null,
  studentIds?: string[],
): Promise<{ homeworkIds: string[]; targetCount: number }> {
  const runs = await client.queryObject<{ plan: HomeworkIntelligencePlan }>(
    `SELECT plan FROM homework_intelligence_runs WHERE id = $1`,
    [runId],
  );
  const plan = runs[0]?.plan;
  if (!plan) throw new Error("Homework intelligence run not found");

  const homeworkIds: string[] = [];
  let targetCount = 0;

  for (const hw of plan.recommendedHomework.slice(0, 2)) {
    const content = generateStubHomeworkContent(
      plan.subjectName,
      hw.topic,
      "medium",
      hw.assignmentType as "homework",
    );
    const created = await createHomeworkAssignment(client, organizationId, schoolId, {
      academicYearLabel: "2025-26",
      className: plan.className,
      sectionName: undefined,
      subjectName: plan.subjectName,
      topic: hw.topic,
      difficulty: "medium",
      assignmentType: hw.assignmentType as "homework",
      title: hw.title,
      content,
      dueDate: undefined,
      createdBy: createdBy ?? "system",
    });
    homeworkIds.push(created.id);

    const targets = studentIds?.length
      ? plan.riskStudents.filter((s) => studentIds.includes(s.studentId))
      : plan.riskStudents;

    for (const student of targets) {
      await client.queryObject(
        `INSERT INTO edu_homework_student_targets (
           organization_id, school_id, homework_assignment_id,
           student_id, intelligence_run_id, assignment_reason
         ) VALUES ($1, $2, $3, $4, $5, $6)
         ON CONFLICT (homework_assignment_id, student_id) DO NOTHING`,
        [
          organizationId,
          schoolId,
          created.id,
          student.studentId,
          runId,
          student.topReason,
        ],
      );
      targetCount += 1;
    }
  }

  return { homeworkIds, targetCount };
}
