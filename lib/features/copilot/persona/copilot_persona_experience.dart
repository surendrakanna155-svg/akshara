import '../copilot_role_intelligence.dart';

/// Read-only persona experience metadata (INTEL-04 — no prediction engine).
class CopilotPersonaExperience {
  const CopilotPersonaExperience({
    required this.persona,
    required this.title,
    required this.subtitle,
    required this.focusAreas,
    required this.starterPrompts,
  });

  final CopilotPersonaRole persona;
  final String title;
  final String subtitle;
  final List<String> focusAreas;
  final List<String> starterPrompts;

  static CopilotPersonaExperience forPersona(CopilotPersonaRole persona) =>
      _experiences[persona]!;

  static const _experiences = {
    CopilotPersonaRole.platformOwner: CopilotPersonaExperience(
      persona: CopilotPersonaRole.platformOwner,
      title: 'Platform Intelligence',
      subtitle: 'Multi-school analytics, revenue, growth, and expansion signals.',
      focusAreas: [
        'Multi-school analytics',
        'Revenue trends',
        'Growth opportunities',
        'Expansion recommendations',
        'Risk detection',
      ],
      starterPrompts: [
        'Compare schools by revenue this quarter',
        'Which campuses show enrollment risk?',
        'Summarize portfolio health',
      ],
    ),
    CopilotPersonaRole.organizationOwner: CopilotPersonaExperience(
      persona: CopilotPersonaRole.organizationOwner,
      title: 'Trust Intelligence',
      subtitle: 'Organization-wide governance and school portfolio oversight.',
      focusAreas: [
        'Multi-school portfolio',
        'Trust governance',
        'Revenue trends',
        'Expansion recommendations',
      ],
      starterPrompts: [
        'Summarize trust-wide fee collection',
        'Which schools need board attention?',
      ],
    ),
    CopilotPersonaRole.directorCorrespondent: CopilotPersonaExperience(
      persona: CopilotPersonaRole.directorCorrespondent,
      title: 'Director Intelligence',
      subtitle: 'School health, admissions pipeline, and fee operations.',
      focusAreas: [
        'School health score',
        'Admissions funnel',
        'Fee collection',
        'Staff performance',
      ],
      starterPrompts: [
        'How is admissions conversion this month?',
        'Summarize fee defaulters by class',
      ],
    ),
    CopilotPersonaRole.principal: CopilotPersonaExperience(
      persona: CopilotPersonaRole.principal,
      title: 'Principal Intelligence',
      subtitle: 'Attendance, academics, teacher effectiveness, and at-risk students.',
      focusAreas: [
        'Attendance trends',
        'Academic performance',
        'Teacher effectiveness',
        'At-risk students',
      ],
      starterPrompts: [
        'Which classes have attendance dips?',
        'Summarize at-risk students this week',
      ],
    ),
    CopilotPersonaRole.academicCoordinator: CopilotPersonaExperience(
      persona: CopilotPersonaRole.academicCoordinator,
      title: 'Academic Operations',
      subtitle: 'Class performance, timetable, and teacher assignments.',
      focusAreas: [
        'Class performance',
        'Timetable conflicts',
        'Teacher assignments',
        'At-risk students',
      ],
      starterPrompts: [
        'Which sections lack teacher coverage?',
        'Summarize weak chapters before exams',
      ],
    ),
    CopilotPersonaRole.teacher: CopilotPersonaExperience(
      persona: CopilotPersonaRole.teacher,
      title: 'Teacher Assistant',
      subtitle: 'Class insights, homework completion, and attendance alerts.',
      focusAreas: [
        'Weak students',
        'Homework completion',
        'Attendance patterns',
        'Class insights',
      ],
      starterPrompts: [
        'Which students missed homework this week?',
        'Summarize attendance alerts for my class',
      ],
    ),
    CopilotPersonaRole.parent: CopilotPersonaExperience(
      persona: CopilotPersonaRole.parent,
      title: 'Parent Guidance',
      subtitle: 'Your child\'s performance, attendance, homework, and exams.',
      focusAreas: [
        'Child performance',
        'Attendance alerts',
        'Homework reminders',
        'Upcoming exams',
      ],
      starterPrompts: [
        'How is my child\'s attendance this month?',
        'What homework is due this week?',
      ],
    ),
    CopilotPersonaRole.student: CopilotPersonaExperience(
      persona: CopilotPersonaRole.student,
      title: 'Study Assistant',
      subtitle: 'Study guidance, exam preparation, and performance insights.',
      focusAreas: [
        'Study recommendations',
        'Exam preparation',
        'Performance insights',
      ],
      starterPrompts: [
        'What should I revise before the next exam?',
        'Summarize my weak subjects',
      ],
    ),
  };
}
