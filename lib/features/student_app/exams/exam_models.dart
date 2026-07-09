import 'package:flutter/foundation.dart';

enum StudentExamSection { upcoming, results }

extension StudentExamSectionX on StudentExamSection {
  String get label => switch (this) {
        StudentExamSection.upcoming => 'Upcoming',
        StudentExamSection.results => 'Results',
      };
}

@immutable
class StudentUpcomingExam {
  const StudentUpcomingExam({
    required this.id,
    required this.title,
    required this.subject,
    required this.dateLabel,
    required this.timeLabel,
    required this.venueLabel,
  });

  final String id;
  final String title;
  final String subject;
  final String dateLabel;
  final String timeLabel;
  final String venueLabel;
}

@immutable
class StudentExamResult {
  const StudentExamResult({
    required this.id,
    required this.title,
    required this.termLabel,
    required this.dateLabel,
    required this.scoreObtained,
    required this.maxScore,
    required this.grade,
  });

  final String id;
  final String title;
  final String termLabel;
  final String dateLabel;
  final int scoreObtained;
  final int maxScore;
  final String grade;

  int get percent => ((scoreObtained / maxScore) * 100).round();
}

@immutable
class SubjectScore {
  const SubjectScore({
    required this.subject,
    required this.scorePercent,
    required this.grade,
  });

  final String subject;
  final int scorePercent;
  final String grade;
}

@immutable
class StudentExamsData {
  const StudentExamsData({
    required this.studentName,
    required this.classLabel,
    required this.upcomingExams,
    required this.examResults,
    required this.subjectScores,
    required this.averagePercent,
    this.unreadNotifications = 0,
    this.schoolName = '',
  });

  final String studentName;
  final String classLabel;
  final List<StudentUpcomingExam> upcomingExams;
  final List<StudentExamResult> examResults;
  final List<SubjectScore> subjectScores;
  final int averagePercent;
  final int unreadNotifications;

  /// Real per-tenant school name (from `schools.name`), used to brand the
  /// report-card PDF export. Empty until the backend snapshot resolves.
  final String schoolName;
}
