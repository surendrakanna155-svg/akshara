import 'package:flutter/foundation.dart';

enum TeacherExamSection { upcoming, marksEntry, results }

extension TeacherExamSectionX on TeacherExamSection {
  String get label => switch (this) {
        TeacherExamSection.upcoming => 'Upcoming',
        TeacherExamSection.marksEntry => 'Marks entry',
        TeacherExamSection.results => 'Results',
      };
}

@immutable
class TeacherUpcomingExam {
  const TeacherUpcomingExam({
    required this.id,
    required this.title,
    required this.classLabel,
    required this.dateLabel,
    required this.maxMarks,
  });

  final String id;
  final String title;
  final String classLabel;
  final String dateLabel;
  final int maxMarks;
}

@immutable
class ExamMarkEntry {
  const ExamMarkEntry({
    required this.id,
    required this.studentName,
    required this.rollNo,
    required this.marksObtained,
    required this.maxMarks,
  });

  final String id;
  final String studentName;
  final String rollNo;
  final int? marksObtained;
  final int maxMarks;

  ExamMarkEntry copyWith({int? marksObtained}) {
    return ExamMarkEntry(
      id: id,
      studentName: studentName,
      rollNo: rollNo,
      marksObtained: marksObtained ?? this.marksObtained,
      maxMarks: maxMarks,
    );
  }

  int? get percent {
    if (marksObtained == null || maxMarks == 0) return null;
    return ((marksObtained! / maxMarks) * 100).round();
  }
}

@immutable
class TeacherExamsData {
  const TeacherExamsData({
    required this.upcomingExams,
    required this.markEntries,
    required this.classAveragePercent,
    required this.unreadNotifications,
  });

  final List<TeacherUpcomingExam> upcomingExams;
  final List<ExamMarkEntry> markEntries;
  final int classAveragePercent;
  final int unreadNotifications;
}
