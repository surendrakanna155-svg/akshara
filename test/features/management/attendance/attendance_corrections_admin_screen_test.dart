import 'package:akshara_erp/core/attendance/attendance_correction_models.dart';
import 'package:akshara_erp/core/attendance/attendance_correction_store.dart';
import 'package:akshara_erp/core/repositories/mock/mock_attendance_correction_repository.dart';
import 'package:akshara_erp/core/repositories/repository_providers.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/tenant/tenant_provider.dart';
import 'package:akshara_erp/features/management/attendance/attendance_corrections_admin_screen.dart';
import 'package:akshara_erp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P0-ATT-001 attendance corrections admin', () {
    setUp(() {
      AttendanceCorrectionStore.instance.reset();
    });

    testWidgets('lists correction requests and submission status', (tester) async {
      AttendanceCorrectionStore.instance.create(
        const CreateAttendanceCorrectionRequest(
          sisStudentId: 'SIS-STU-10430',
          studentName: 'Arjun Reddy',
          classLabel: '8',
          section: 'A',
          dateLabel: '12 Jun 2026',
          fromMark: 'Absent',
          toMark: 'Present',
          reason: 'Biometric error',
          requesterId: 'teacher-1',
          requesterName: 'Priya Sharma',
          requesterRole: 'teacher',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            attendanceCorrectionRepositoryProvider.overrideWithValue(
              MockAttendanceCorrectionRepository(
                store: AttendanceCorrectionStore.instance,
              ),
            ),
            repositoryQueryProvider.overrideWith((ref) => RepositoryQuery.demo),
          ],
          child: MaterialApp(
            theme: AksharaAppTheme.light(),
            home: const AttendanceCorrectionsAdminScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Attendance corrections'), findsOneWidget);
      expect(find.textContaining('Arjun Reddy'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
    });
  });
}
