import '../../../../../features/education/education_models.dart';

class EducationMapper {
  static EduDifficulty difficultyFromApi(String value) => switch (value) {
        'easy' => EduDifficulty.easy,
        'hard' => EduDifficulty.hard,
        'mixed' => EduDifficulty.mixed,
        _ => EduDifficulty.medium,
      };

  static String difficultyToApi(EduDifficulty value) => value.name;

  static EduQuestionType questionTypeFromApi(String value) => switch (value) {
        'fill_blank' => EduQuestionType.fillBlank,
        'match' => EduQuestionType.match,
        'short_answer' => EduQuestionType.shortAnswer,
        'long_answer' => EduQuestionType.longAnswer,
        'diagram' => EduQuestionType.diagram,
        _ => EduQuestionType.mcq,
      };

  static String questionTypeToApi(EduQuestionType value) => switch (value) {
        EduQuestionType.fillBlank => 'fill_blank',
        EduQuestionType.match => 'match',
        EduQuestionType.shortAnswer => 'short_answer',
        EduQuestionType.longAnswer => 'long_answer',
        EduQuestionType.diagram => 'diagram',
        EduQuestionType.mcq => 'mcq',
      };

  static EduExamType examTypeFromApi(String value) => switch (value) {
        'weekly_test' => EduExamType.weeklyTest,
        'monthly_test' => EduExamType.monthlyTest,
        'quarterly' => EduExamType.quarterly,
        'half_yearly' => EduExamType.halfYearly,
        'annual' => EduExamType.annual,
        _ => EduExamType.unitTest,
      };

  static String examTypeToApi(EduExamType value) => switch (value) {
        EduExamType.weeklyTest => 'weekly_test',
        EduExamType.monthlyTest => 'monthly_test',
        EduExamType.quarterly => 'quarterly',
        EduExamType.halfYearly => 'half_yearly',
        EduExamType.annual => 'annual',
        EduExamType.unitTest => 'unit_test',
      };

  static EduHomeworkType homeworkTypeFromApi(String value) => switch (value) {
        'practice_worksheet' => EduHomeworkType.practiceWorksheet,
        'revision_worksheet' => EduHomeworkType.revisionWorksheet,
        'holiday_homework' => EduHomeworkType.holidayHomework,
        _ => EduHomeworkType.homework,
      };

  static String homeworkTypeToApi(EduHomeworkType value) => switch (value) {
        EduHomeworkType.practiceWorksheet => 'practice_worksheet',
        EduHomeworkType.revisionWorksheet => 'revision_worksheet',
        EduHomeworkType.holidayHomework => 'holiday_homework',
        EduHomeworkType.homework => 'homework',
      };

  static EduRemarkType remarkTypeFromApi(String value) => switch (value) {
        'class_teacher' => EduRemarkType.classTeacher,
        'subject_teacher' => EduRemarkType.subjectTeacher,
        _ => EduRemarkType.principal,
      };

  static String remarkTypeToApi(EduRemarkType value) => switch (value) {
        EduRemarkType.classTeacher => 'class_teacher',
        EduRemarkType.subjectTeacher => 'subject_teacher',
        EduRemarkType.principal => 'principal',
      };

  static EduRemarkLanguage remarkLanguageFromApi(String value) => switch (value) {
        'telugu' => EduRemarkLanguage.telugu,
        'hindi' => EduRemarkLanguage.hindi,
        _ => EduRemarkLanguage.english,
      };

  static String remarkLanguageToApi(EduRemarkLanguage value) => value.name;

  static EduProgramTrack programTrackFromApi(String value) => switch (value) {
        'jee_foundation' => EduProgramTrack.jeeFoundation,
        'neet_foundation' => EduProgramTrack.neetFoundation,
        'ntse' => EduProgramTrack.ntse,
        'olympiad' => EduProgramTrack.olympiad,
        _ => EduProgramTrack.board,
      };

  static String programTrackToApi(EduProgramTrack value) => switch (value) {
        EduProgramTrack.jeeFoundation => 'jee_foundation',
        EduProgramTrack.neetFoundation => 'neet_foundation',
        EduProgramTrack.ntse => 'ntse',
        EduProgramTrack.olympiad => 'olympiad',
        EduProgramTrack.board => 'board',
      };

  static EduCognitiveLevel? cognitiveLevelFromApi(String? value) => switch (value) {
        'remember' => EduCognitiveLevel.remember,
        'understand' => EduCognitiveLevel.understand,
        'apply' => EduCognitiveLevel.apply,
        'analyze' => EduCognitiveLevel.analyze,
        'hots' => EduCognitiveLevel.hots,
        _ => null,
      };

  static String cognitiveLevelToApi(EduCognitiveLevel value) => value.name;

  static EduPaperReviewStatus paperReviewStatusFromApi(String value) => switch (value) {
        'submitted' => EduPaperReviewStatus.submitted,
        'changes_requested' => EduPaperReviewStatus.changesRequested,
        'approved' => EduPaperReviewStatus.approved,
        'published' => EduPaperReviewStatus.published,
        'archived' => EduPaperReviewStatus.archived,
        _ => EduPaperReviewStatus.draft,
      };

  static QuestionBankItem questionBankFromApi(Map<String, dynamic> json) {
    return QuestionBankItem(
      id: json['id'] as String,
      subjectName: json['subjectName'] as String,
      chapter: json['chapter'] as String? ?? '',
      topic: json['topic'] as String? ?? '',
      difficulty: difficultyFromApi(json['difficulty'] as String? ?? 'medium'),
      questionType: questionTypeFromApi(json['questionType'] as String? ?? 'mcq'),
      marks: (json['marks'] as num).toInt(),
      questionText: json['questionText'] as String,
      answerText: json['answerText'] as String?,
      options: (json['options'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      status: json['status'] as String? ?? 'active',
      programTrack: programTrackFromApi(json['programTrack'] as String? ?? 'board'),
      cognitiveLevel: cognitiveLevelFromApi(json['cognitiveLevel'] as String?),
      syllabusChapterId: json['syllabusChapterId'] as String?,
      sourceReference: json['sourceReference'] as String?,
      reviewStatus: json['reviewStatus'] as String? ?? 'approved',
    );
  }

  static QuestionPaperSummary paperSummaryFromApi(Map<String, dynamic> json) {
    // AI-5: the composition counts are persisted inside `blueprint` (and the
    // AI count is stored there as `aiCandidateCount`); only the generate
    // response echoes them at the top level. Prefer the top-level value, then
    // fall back to the blueprint, so list/detail chips no longer read 0.
    final blueprint =
        json['blueprint'] is Map ? json['blueprint'] as Map : const {};
    return QuestionPaperSummary(
      id: json['id'] as String,
      title: json['title'] as String,
      className: json['className'] as String,
      sectionName: json['sectionName'] as String?,
      subjectName: json['subjectName'] as String,
      examType: examTypeFromApi(json['examType'] as String? ?? 'unit_test'),
      totalMarks: (json['totalMarks'] as num).toInt(),
      difficulty: difficultyFromApi(json['difficulty'] as String? ?? 'mixed'),
      status: json['status'] as String? ?? 'draft',
      reviewStatus: paperReviewStatusFromApi(json['reviewStatus'] as String? ?? 'draft'),
      programTrack: programTrackFromApi(json['programTrack'] as String? ?? 'board'),
      bankReuseCount:
          _intOrNull(json['bankReuseCount'] ?? blueprint['bankReuseCount']),
      aiGeneratedCount: _intOrNull(json['aiGeneratedCount'] ??
          blueprint['aiCandidateCount'] ??
          blueprint['aiGeneratedCount']),
    );
  }

  /// Coerce a JSON number (int or double) to int, tolerating nulls.
  static int? _intOrNull(Object? value) =>
      value is num ? value.toInt() : null;

  static QuestionPaperItem paperItemFromApi(Map<String, dynamic> json) {
    return QuestionPaperItem(
      id: json['id'] as String?,
      questionNumber: (json['questionNumber'] as num).toInt(),
      questionType: questionTypeFromApi(json['questionType'] as String? ?? 'mcq'),
      marks: (json['marks'] as num).toInt(),
      questionText: json['questionText'] as String,
      answerText: json['answerText'] as String?,
      options: (json['options'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      source: json['source'] as String? ?? 'bank',
      reviewStatus: json['reviewStatus'] as String? ?? 'approved',
    );
  }

  static PaperGap paperGapFromApi(Map<String, dynamic> json) {
    return PaperGap(
      questionType: questionTypeFromApi(json['questionType'] as String? ?? 'mcq'),
      difficulty: json['difficulty'] as String? ?? 'medium',
      marks: (json['marks'] as num?)?.toInt() ?? 0,
      chapter: json['chapter'] as String? ?? '',
    );
  }

  static PaperReview paperReviewFromApi(Map<String, dynamic> json) {
    return PaperReview(
      id: json['id'] as String,
      roundNumber: (json['roundNumber'] as num?)?.toInt() ?? 1,
      status: json['status'] as String? ?? 'submitted',
      comments: json['comments'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
    );
  }

  static HomeworkAssignment homeworkFromApi(Map<String, dynamic> json) {
    return HomeworkAssignment(
      id: json['id'] as String,
      title: json['title'] as String,
      className: json['className'] as String,
      sectionName: json['sectionName'] as String?,
      subjectName: json['subjectName'] as String,
      topic: json['topic'] as String? ?? '',
      difficulty: difficultyFromApi(json['difficulty'] as String? ?? 'medium'),
      assignmentType:
          homeworkTypeFromApi(json['assignmentType'] as String? ?? 'homework'),
      content: (json['content'] as List<dynamic>? ?? const [])
          .map((e) => Map<String, String>.from(
                (e as Map).map((k, v) => MapEntry(k.toString(), v.toString())),
              ))
          .toList(),
      status: json['status'] as String? ?? 'draft',
      dueDate: json['dueDate'] != null
          ? DateTime.tryParse(json['dueDate'] as String)
          : null,
    );
  }

  static ReportCardRemark remarkFromApi(Map<String, dynamic> json) {
    return ReportCardRemark(
      id: json['id'] as String,
      studentId: json['studentId'] as String,
      academicYearLabel: json['academicYearLabel'] as String,
      remarkType: remarkTypeFromApi(json['remarkType'] as String? ?? 'principal'),
      language: remarkLanguageFromApi(json['language'] as String? ?? 'english'),
      displayRemark: json['displayRemark'] as String? ??
          json['generatedRemark'] as String? ??
          '',
      generatedRemark: json['generatedRemark'] as String?,
      editedRemark: json['editedRemark'] as String?,
      status: json['status'] as String? ?? 'draft',
    );
  }
}
