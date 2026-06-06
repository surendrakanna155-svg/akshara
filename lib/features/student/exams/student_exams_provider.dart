import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'exam_models.dart';

final studentExamSectionProvider = StateProvider<StudentExamSection>(
  (ref) => StudentExamSection.upcoming,
);

final studentExamsLoadingProvider = StateProvider<bool>((ref) => false);
final studentExamsErrorProvider = StateProvider<bool>((ref) => false);
final studentExamsEmptyProvider = StateProvider<bool>((ref) => false);

final studentExamsProvider = Provider<StudentExamsData>((ref) {
  if (ref.watch(studentExamsEmptyProvider)) {
    return const StudentExamsData(
      studentName: 'Ravi Kumar',
      classLabel: '8-A',
      upcomingExams: [],
      examResults: [],
      subjectScores: [],
      averagePercent: 0,
      unreadNotifications: 2,
    );
  }

  return const StudentExamsData(
    studentName: 'Ravi Kumar',
    classLabel: '8-A',
    unreadNotifications: 2,
    averagePercent: 84,
    upcomingExams: [
      StudentUpcomingExam(
        id: 'ex-1',
        title: 'Mid-term Mathematics',
        subject: 'Mathematics',
        dateLabel: '12 Jun 2026',
        timeLabel: '9:00 AM',
        venueLabel: 'Room 203',
      ),
      StudentUpcomingExam(
        id: 'ex-2',
        title: 'Science practical assessment',
        subject: 'Science',
        dateLabel: '18 Jun 2026',
        timeLabel: '10:30 AM',
        venueLabel: 'Lab 2',
      ),
    ],
    examResults: [
      StudentExamResult(
        id: 'res-1',
        title: 'Unit Test — Algebra',
        termLabel: 'Term 2',
        dateLabel: '20 May 2026',
        scoreObtained: 42,
        maxScore: 50,
        grade: 'A',
      ),
      StudentExamResult(
        id: 'res-2',
        title: 'English comprehension',
        termLabel: 'Term 2',
        dateLabel: '8 May 2026',
        scoreObtained: 38,
        maxScore: 50,
        grade: 'B+',
      ),
    ],
    subjectScores: [
      SubjectScore(subject: 'Mathematics', scorePercent: 88, grade: 'A'),
      SubjectScore(subject: 'Science', scorePercent: 82, grade: 'A'),
      SubjectScore(subject: 'English', scorePercent: 76, grade: 'B+'),
      SubjectScore(subject: 'Hindi', scorePercent: 90, grade: 'A+'),
    ],
  );
});
