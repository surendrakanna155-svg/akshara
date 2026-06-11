import type {
  EduDifficulty,
  EduHomeworkType,
  EduQuestionType,
  EduRemarkLanguage,
  EduRemarkType,
} from "./education_types.ts";

export interface GeneratedQuestion {
  questionType: EduQuestionType;
  marks: number;
  questionText: string;
  answerText: string;
  options: string[];
}

export interface RemarkInputs {
  attendancePercent?: number;
  averageMarks?: number;
  strengths?: string[];
  weaknesses?: string[];
  activities?: string[];
  subjectName?: string;
}

const QUESTION_TEMPLATES: Record<EduQuestionType, (topic: string, marks: number) => GeneratedQuestion> = {
  mcq: (topic, marks) => ({
    questionType: "mcq",
    marks,
    questionText: `Multiple choice (${marks} marks): ${topic} — select the correct option.`,
    answerText: "Option B",
    options: ["Option A", "Option B", "Option C", "Option D"],
  }),
  fill_blank: (topic, marks) => ({
    questionType: "fill_blank",
    marks,
    questionText: `Fill in the blank (${marks} marks): The key concept in ${topic} is _______.`,
    answerText: "Sample answer",
    options: [],
  }),
  match: (topic, marks) => ({
    questionType: "match",
    marks,
    questionText: `Match the following (${marks} marks) for ${topic}:\nColumn A | Column B\n1. Term | Definition`,
    answerText: "1-a, 2-b",
    options: [],
  }),
  short_answer: (topic, marks) => ({
    questionType: "short_answer",
    marks,
    questionText: `Short answer (${marks} marks): Explain ${topic} in 3–4 sentences.`,
    answerText: `A concise explanation of ${topic}.`,
    options: [],
  }),
  long_answer: (topic, marks) => ({
    questionType: "long_answer",
    marks,
    questionText: `Long answer (${marks} marks): Discuss ${topic} with examples.`,
    answerText: `Detailed discussion of ${topic} with examples.`,
    options: [],
  }),
  diagram: (topic, marks) => ({
    questionType: "diagram",
    marks,
    questionText: `Diagram (${marks} marks): Draw and label a diagram related to ${topic}.`,
    answerText: `Labeled diagram for ${topic}.`,
    options: [],
  }),
};

export function generateStubQuestion(
  subject: string,
  chapter: string,
  difficulty: EduDifficulty,
  questionType: EduQuestionType,
  marks: number,
): GeneratedQuestion {
  const topic = `${subject} — ${chapter} (${difficulty})`;
  return QUESTION_TEMPLATES[questionType](topic, marks);
}

export function defaultQuestionTypeMix(): EduQuestionType[] {
  return ["mcq", "fill_blank", "short_answer", "long_answer"];
}

/** Balanced difficulty spread for mixed papers: easy 30%, medium 50%, hard 20%. */
export function balanceDifficultyMix(
  count: number,
): EduDifficulty[] {
  const easy = Math.max(1, Math.round(count * 0.3));
  const hard = Math.max(1, Math.round(count * 0.2));
  const medium = Math.max(0, count - easy - hard);
  return [
    ...Array.from({ length: easy }, () => "easy" as EduDifficulty),
    ...Array.from({ length: medium }, () => "medium" as EduDifficulty),
    ...Array.from({ length: hard }, () => "hard" as EduDifficulty),
  ];
}

export function buildPaperBlueprint(
  totalMarks: number,
  items: Array<{ marks: number; questionType: string; source: string }>,
  chapters: string[],
): Record<string, unknown> {
  const typeDistribution: Record<string, number> = {};
  const marksByType: Record<string, number> = {};
  for (const item of items) {
    typeDistribution[item.questionType] = (typeDistribution[item.questionType] ?? 0) + 1;
    marksByType[item.questionType] = (marksByType[item.questionType] ?? 0) + item.marks;
  }
  return {
    totalMarks,
    questionCount: items.length,
    typeDistribution,
    marksByType,
    chapterCoverage: chapters,
    marksDistribution: items.map((item, i) => ({
      questionNumber: i + 1,
      marks: item.marks,
      type: item.questionType,
      source: item.source,
    })),
  };
}

export function generateStubHomeworkContent(
  subject: string,
  topic: string,
  difficulty: string,
  assignmentType: EduHomeworkType,
  count = 5,
): Array<{ prompt: string; answerHint: string }> {
  const label = assignmentType.replaceAll("_", " ");
  return Array.from({ length: count }, (_, i) => ({
    prompt: `${label} Q${i + 1}: ${subject} — ${topic} (${difficulty})`,
    answerHint: `Sample solution for question ${i + 1}.`,
  }));
}

const REMARK_TEMPLATES: Record<EduRemarkLanguage, Record<EduRemarkType, (inputs: RemarkInputs) => string>> = {
  english: {
    principal: (i) =>
      `The student has shown ${i.strengths?.join(", ") ?? "consistent effort"} this term. ` +
      `Attendance is ${i.attendancePercent ?? 0}%. ` +
      `${i.weaknesses?.length ? `Areas to improve: ${i.weaknesses.join(", ")}.` : ""} ` +
      `We encourage continued participation in ${i.activities?.join(", ") ?? "school activities"}.`,
    class_teacher: (i) =>
      `As class teacher, I note attendance at ${i.attendancePercent ?? 0}% with average marks ` +
      `${i.averageMarks ?? 0}. Strengths include ${i.strengths?.join(", ") ?? "diligence"}. ` +
      `Focus areas: ${i.weaknesses?.join(", ") ?? "regular revision"}.`,
    subject_teacher: (i) =>
      `In ${i.subjectName ?? "this subject"}, the student scored around ${i.averageMarks ?? 0} marks. ` +
      `Demonstrated strength in ${i.strengths?.join(", ") ?? "class participation"}. ` +
      `Needs support with ${i.weaknesses?.join(", ") ?? "practice questions"}.`,
  },
  telugu: {
    principal: (i) =>
      `విద్యార్థి ఈ సంవత్సరం ${i.strengths?.join(", ") ?? "శ్రద్ధ"} చూపించారు. ` +
      `హాజరు ${i.attendancePercent ?? 0}%. ` +
      `${i.activities?.length ? `కార్యక్రమాల్లో పాల్గొన్నారు: ${i.activities.join(", ")}.` : ""}`,
    class_teacher: (i) =>
      `తరగతి టీచర్ గా, హాజరు ${i.attendancePercent ?? 0}% మరియు సగటు మార్కులు ${i.averageMarks ?? 0}. ` +
      `బలాలు: ${i.strengths?.join(", ") ?? "శ్రద్ధ"}.`,
    subject_teacher: (i) =>
      `${i.subjectName ?? "విషయం"} లో సగటు ${i.averageMarks ?? 0} మార్కులు. ` +
      `బలాలు: ${i.strengths?.join(", ") ?? "పాల్గొనడం"}.`,
  },
  hindi: {
    principal: (i) =>
      `छात्र ने इस वर्ष ${i.strengths?.join(", ") ?? "लगन"} दिखाई है। उपस्थिति ${i.attendancePercent ?? 0}% है।`,
    class_teacher: (i) =>
      `कक्षा अध्यापक के रूप में, उपस्थिति ${i.attendancePercent ?? 0}% और औसत अंक ${i.averageMarks ?? 0} हैं।`,
    subject_teacher: (i) =>
      `${i.subjectName ?? "विषय"} में औसत ${i.averageMarks ?? 0} अंक। ` +
      `ताकत: ${i.strengths?.join(", ") ?? "भागीदारी"}।`,
  },
};

export function generateStubRemark(
  remarkType: EduRemarkType,
  language: EduRemarkLanguage,
  inputs: RemarkInputs,
): string {
  return REMARK_TEMPLATES[language][remarkType](inputs);
}
