class Student360Profile {
  const Student360Profile({
    required this.identity,
    required this.admissions,
    required this.attendance,
    required this.marks,
    required this.homework,
    required this.communication,
    required this.fees,
    required this.inventory,
    required this.activities,
    required this.achievements,
    required this.risk,
    required this.parentInformation,
    this.behaviour = const {},
    this.transport = const {},
    this.documents = const {},
  });

  final Map<String, dynamic> identity;
  final Map<String, dynamic> admissions;
  final Map<String, dynamic> attendance;
  final Map<String, dynamic> marks;
  final Map<String, dynamic> homework;
  final Map<String, dynamic> communication;
  final Map<String, dynamic> fees;
  final Map<String, dynamic> inventory;
  final Map<String, dynamic> activities;
  final Map<String, dynamic> achievements;
  final Map<String, dynamic> risk;
  final Map<String, dynamic> parentInformation;
  final Map<String, dynamic> behaviour;
  final Map<String, dynamic> transport;
  final Map<String, dynamic> documents;
}

class StudentTimelineEvent {
  const StudentTimelineEvent({
    required this.id,
    required this.eventType,
    required this.eventAt,
    required this.title,
    this.summary,
    required this.sourceModule,
    required this.payload,
  });

  final String id;
  final String eventType;
  final String eventAt;
  final String title;
  final String? summary;
  final String sourceModule;
  final Map<String, dynamic> payload;
}
