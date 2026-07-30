/// Reason categories for teacher → parent communication.
enum ParentCommunicationReason {
  attendanceLow,
  marksLow,
  homeworkMissing,
  disciplineIssue,
  feeReminder,
  appreciation,
  ptmRequest,
  generalProgress,
}

extension ParentCommunicationReasonLabel on ParentCommunicationReason {
  String get label => switch (this) {
        ParentCommunicationReason.attendanceLow => 'Low attendance',
        ParentCommunicationReason.marksLow => 'Low marks',
        ParentCommunicationReason.homeworkMissing => 'Homework missing',
        ParentCommunicationReason.disciplineIssue => 'Discipline issue',
        ParentCommunicationReason.feeReminder => 'Fee reminder',
        ParentCommunicationReason.appreciation => 'Appreciation',
        ParentCommunicationReason.ptmRequest => 'PTM request',
        ParentCommunicationReason.generalProgress => 'Progress update',
      };
}

/// Template tone variants within a reason category.
enum ParentCommunicationTone {
  polite,
  concerned,
  followUp,
  encouragement,
  parentSupport,
  improvementPlan,
  gentleReminder,
  repeatedOccurrence,
  parentIntervention,
  informational,
  discussionRequested,
  meetingRequested,
  goodPerformance,
  improvedAttendance,
  positiveBehavior,
  academicAchievement,
  friendlyReminder,
  dueSoon,
  overdue,
}

/// Predefined template catalog — no AI tokens consumed.
abstract final class TeacherParentTemplates {
  static String resolve({
    required ParentCommunicationReason reason,
    required ParentCommunicationTone tone,
    String studentName = 'your child',
  }) {
    return switch (reason) {
      ParentCommunicationReason.attendanceLow => switch (tone) {
          ParentCommunicationTone.polite =>
            'Your child was absent from school today. Kindly ensure regular attendance and inform the school if there are any concerns.',
          ParentCommunicationTone.concerned =>
            'We noticed your child was absent today. Regular attendance is important for academic progress.',
          _ =>
            'Your child was absent today. Please contact the class teacher if support is needed.',
        },
      ParentCommunicationReason.marksLow => switch (tone) {
          ParentCommunicationTone.encouragement =>
            'Your child\'s recent assessment score needs attention. We encourage additional practice at home.',
          ParentCommunicationTone.parentSupport =>
            'Your child\'s recent marks are below class average. We request your support with revision at home.',
          _ =>
            'We have prepared an improvement plan for $studentName. Please connect with the class teacher this week.',
        },
      ParentCommunicationReason.homeworkMissing => switch (tone) {
          ParentCommunicationTone.gentleReminder =>
            'Homework for today has not been submitted. Kindly ensure completion by tomorrow.',
          ParentCommunicationTone.repeatedOccurrence =>
            'Homework has been missed multiple times this week. Please review pending assignments.',
          _ =>
            'Repeated homework gaps noted. Parent intervention is requested to support timely submission.',
        },
      ParentCommunicationReason.disciplineIssue => switch (tone) {
          ParentCommunicationTone.informational =>
            'We would like to inform you about a minor classroom conduct matter today involving $studentName.',
          ParentCommunicationTone.discussionRequested =>
            'A discipline concern was noted today. Please discuss appropriate classroom behaviour at home.',
          _ =>
            'We request a brief meeting to discuss a conduct matter involving $studentName.',
        },
      ParentCommunicationReason.feeReminder => switch (tone) {
          ParentCommunicationTone.friendlyReminder =>
            'This is a friendly reminder that school fees are due soon. Kindly complete payment at your earliest convenience.',
          ParentCommunicationTone.dueSoon =>
            'School fee payment is due within the next few days. Please use the NIKSHA OS parent app to pay.',
          _ =>
            'School fees are overdue. Please clear the outstanding balance to avoid service interruption.',
        },
      ParentCommunicationReason.appreciation => switch (tone) {
          ParentCommunicationTone.goodPerformance ||
          ParentCommunicationTone.academicAchievement =>
            'We would like to appreciate your child\'s excellent performance in class today.',
          ParentCommunicationTone.improvedAttendance =>
            'We appreciate the improved attendance of $studentName this month. Keep up the great work!',
          _ =>
            'We are pleased to share positive feedback about $studentName\'s behaviour in class today.',
        },
      ParentCommunicationReason.ptmRequest => switch (tone) {
          ParentCommunicationTone.informational =>
            'We would like to schedule a parent-teacher meeting regarding $studentName. Please confirm a convenient time.',
          _ =>
            'A parent-teacher meeting is requested to discuss $studentName\'s progress. Kindly respond at your earliest convenience.',
        },
      ParentCommunicationReason.generalProgress => switch (tone) {
          ParentCommunicationTone.goodPerformance =>
            'We are pleased to share a positive progress update for $studentName this term.',
          _ =>
            'This is a general progress update regarding $studentName. Please review and reach out if you have questions.',
        },
    };
  }
}
