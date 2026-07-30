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
        'name': 'Arjun Reddy',
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
      communication: {'pendingNotices': 1, 'unreadMessages': 2},
      fees: {'pendingAmount': 5000, 'openInvoices': 1, 'paidPercent': 62},
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
          {
            'name': 'Venkat Reddy',
            'relationship': 'father',
            'isPrimary': true,
            'phone': '+91 98490 11234',
          },
          {
            'name': 'Lakshmi Reddy',
            'relationship': 'mother',
            'isPrimary': false,
            'phone': '+91 98490 11235',
          },
        ],
      },
      behaviour: {
        'conductScore': 82,
        'incidents': [
          {'date': '2026-05-12', 'type': 'late_arrival', 'status': 'resolved'},
        ],
        'remarks': 'Generally cooperative in class.',
      },
      transport: {
        'routeName': 'Route 12 — Kukatpally',
        'stopName': 'JNTU Metro',
        'vehicleNumber': 'TS09 AB 4521',
        'pickupTime': '07:45',
        'dropTime': '15:30',
      },
      documents: {
        'items': [
          {'name': 'Birth certificate', 'status': 'verified', 'uploadedAt': '2024-06-01'},
          {'name': 'Transfer certificate', 'status': 'pending', 'uploadedAt': null},
        ],
      },
      // Minimum actionable health flags only — the same shape the backend's
      // student_care_alerts read returns. No clinical detail here by design.
      care: {
        'alerts': [
          {
            'label': 'Severe peanut allergy',
            'actionNote':
                'Epipen kept in the infirmary. Call the infirmary immediately; '
                    'do not move the child.',
            'severity': 'critical',
          },
          {
            'label': 'Wears spectacles — seat in the front row',
            // Deliberately NOT clinical: no prescription, diagnosis or
            // treatment wording belongs on a care alert.
            'actionNote': 'Check the child can read the board from their seat.',
            'severity': 'info',
          },
        ],
      },
      leave: {
        'items': [
          {
            'type': 'sick',
            'fromDate': '2026-07-08',
            'toDate': '2026-07-10',
            'reason': 'Viral fever — doctor advised three days rest.',
            'status': 'approved',
            'requestedAt': '2026-07-07T18:20:00Z',
          },
          {
            'type': 'casual',
            'fromDate': '2026-06-19',
            'toDate': '2026-06-19',
            'reason': 'Family function.',
            'status': 'approved',
            'requestedAt': '2026-06-17T09:05:00Z',
          },
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
      StudentTimelineEvent(
        id: 'tl_3',
        eventType: 'message',
        eventAt: '2026-06-03T08:30:00Z',
        title: 'Fee reminder sent to parent',
        sourceModule: 'communication',
        payload: {'channel': 'sms'},
      ),
    ];
  }
}
