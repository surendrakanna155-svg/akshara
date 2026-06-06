enum ExamSection { upcoming, results }

extension ExamSectionLabel on ExamSection {
  String get label {
    return switch (this) {
      ExamSection.upcoming => 'Upcoming',
      ExamSection.results => 'Results',
    };
  }
}

/// Parent-facing upcoming exam schedule card model.
class ExamScheduleItem {
  const ExamScheduleItem({
    required this.id,
    required this.title,
    required this.subject,
    required this.dateLabel,
    required this.timeLabel,
    required this.venueLabel,
    required this.syllabusLabel,
    this.isToday = false,
  });

  final String id;
  final String title;
  final String subject;
  final String dateLabel;
  final String timeLabel;
  final String venueLabel;
  final String syllabusLabel;
  final bool isToday;
}

/// Parent-facing past exam result row model.
class ExamResultItem {
  const ExamResultItem({
    required this.id,
    required this.title,
    required this.termLabel,
    required this.dateLabel,
    required this.scoreObtained,
    required this.maxScore,
    required this.grade,
    this.remarks,
  });

  final String id;
  final String title;
  final String termLabel;
  final String dateLabel;
  final int scoreObtained;
  final int maxScore;
  final String grade;
  final String? remarks;

  int get percent => ((scoreObtained / maxScore) * 100).round();
}

/// Exams payload for [ParentExamsScreen].
class ParentExamsData {
  const ParentExamsData({
    required this.childName,
    required this.childClass,
    required this.unreadNotifications,
    required this.upcomingExams,
    required this.examResults,
  });

  final String childName;
  final String childClass;
  final int unreadNotifications;
  final List<ExamScheduleItem> upcomingExams;
  final List<ExamResultItem> examResults;

  int get upcomingCount => upcomingExams.length;
  int get resultsCount => examResults.length;

  int get averageScorePercent {
    if (examResults.isEmpty) {
      return 0;
    }
    final totalScored = examResults.fold<int>(
      0,
      (sum, item) => sum + item.scoreObtained,
    );
    final totalMax = examResults.fold<int>(
      0,
      (sum, item) => sum + item.maxScore,
    );
    if (totalMax == 0) {
      return 0;
    }
    return ((totalScored / totalMax) * 100).round();
  }

  ParentExamsData copyWith({
    String? childName,
    String? childClass,
    int? unreadNotifications,
    List<ExamScheduleItem>? upcomingExams,
    List<ExamResultItem>? examResults,
  }) {
    return ParentExamsData(
      childName: childName ?? this.childName,
      childClass: childClass ?? this.childClass,
      unreadNotifications: unreadNotifications ?? this.unreadNotifications,
      upcomingExams: upcomingExams ?? this.upcomingExams,
      examResults: examResults ?? this.examResults,
    );
  }

  factory ParentExamsData.mock() {
    return const ParentExamsData(
      childName: 'Ravi Kumar',
      childClass: '8-A',
      unreadNotifications: 2,
      upcomingExams: [
        ExamScheduleItem(
          id: 'up_1',
          title: 'Unit Test - Mathematics',
          subject: 'Mathematics',
          dateLabel: '12 Jun 2026',
          timeLabel: '9:00 AM - 10:30 AM',
          venueLabel: 'Room 8A',
          syllabusLabel: 'Algebra, Linear Equations',
          isToday: true,
        ),
        ExamScheduleItem(
          id: 'up_2',
          title: 'Unit Test - Science',
          subject: 'Science',
          dateLabel: '14 Jun 2026',
          timeLabel: '11:00 AM - 12:30 PM',
          venueLabel: 'Science Lab 2',
          syllabusLabel: 'Cell Structure, Nutrition',
        ),
        ExamScheduleItem(
          id: 'up_3',
          title: 'Language Assessment - English',
          subject: 'English',
          dateLabel: '17 Jun 2026',
          timeLabel: '10:00 AM - 11:00 AM',
          venueLabel: 'Room 8A',
          syllabusLabel: 'Grammar and Comprehension',
        ),
      ],
      examResults: [
        ExamResultItem(
          id: 'res_1',
          title: 'Mathematics',
          termLabel: 'Term 1',
          dateLabel: '18 Apr 2026',
          scoreObtained: 86,
          maxScore: 100,
          grade: 'A',
          remarks: 'Strong problem solving.',
        ),
        ExamResultItem(
          id: 'res_2',
          title: 'Science',
          termLabel: 'Term 1',
          dateLabel: '20 Apr 2026',
          scoreObtained: 79,
          maxScore: 100,
          grade: 'B+',
          remarks: 'Good concepts; revise diagrams.',
        ),
        ExamResultItem(
          id: 'res_3',
          title: 'English',
          termLabel: 'Term 1',
          dateLabel: '21 Apr 2026',
          scoreObtained: 91,
          maxScore: 100,
          grade: 'A+',
        ),
        ExamResultItem(
          id: 'res_4',
          title: 'Social Studies',
          termLabel: 'Term 1',
          dateLabel: '23 Apr 2026',
          scoreObtained: 74,
          maxScore: 100,
          grade: 'B',
        ),
      ],
    );
  }
}
