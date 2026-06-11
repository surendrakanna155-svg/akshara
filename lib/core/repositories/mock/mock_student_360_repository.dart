import '../../../features/student_360/student_360_models.dart';
import '../interfaces/student_360_repository.dart';
import '../repository_query.dart';

class MockStudent360Repository implements Student360Repository {
  @override
  Future<Student360Profile> getProfile({
    required RepositoryQuery query,
    required String studentId,
  }) async {
    return Student360Profile(
      identity: {
        'studentId': studentId,
        'studentCode': 'STU-001',
        'displayName': 'Arjun Reddy',
        'status': 'active',
        'className': 'Grade 8',
        'sectionName': 'A',
      },
      admissions: {'admissionNumber': 'ADM-2024-001'},
      attendance: {'present': 42, 'absent': 8, 'total': 50, 'percent': 84},
      marks: {
        'exams': [
          {'exam': 'Unit Test 2', 'averagePercent': 54},
        ],
      },
      homework: {'submitted': 8, 'total': 10, 'completionRate': 80},
      communication: {'pendingNotices': 1},
      fees: {'pendingAmount': 5000, 'openInvoices': 1},
      inventory: {
        'items': [
          {'name': 'Mathematics Textbook', 'category': 'books', 'status': 'distributed'},
        ],
      },
      activities: {'clubs': [], 'events': []},
      achievements: {'badges': [], 'milestones': []},
      risk: {'riskScore': 78, 'riskLevel': 'high', 'reasons': []},
      parentInformation: {
        'guardians': [
          {'name': 'Parent Reddy', 'relationship': 'father', 'isPrimary': true},
        ],
      },
    );
  }

  @override
  Future<List<StudentTimelineEvent>> getTimeline({
    required RepositoryQuery query,
    required String studentId,
  }) async {
    return const [
      StudentTimelineEvent(
        id: 'tl_1',
        eventType: 'attendance',
        eventAt: '2026-06-01T09:00:00Z',
        title: 'Attendance marked absent',
        sourceModule: 'attendance',
        payload: {'mark': 'absent'},
      ),
      StudentTimelineEvent(
        id: 'tl_2',
        eventType: 'risk_change',
        eventAt: '2026-06-02T10:00:00Z',
        title: 'Risk level high',
        summary: 'Score 78',
        sourceModule: 'intelligence',
        payload: {'riskLevel': 'high'},
      ),
    ];
  }
}
