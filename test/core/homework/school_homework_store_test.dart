import 'package:flutter_test/flutter_test.dart';

import 'package:akshara_erp/core/homework/school_homework_store.dart';
import 'package:akshara_erp/core/i18n/content_localization.dart';
import 'package:akshara_erp/core/i18n/supported_languages.dart';
import 'package:akshara_erp/core/repositories/mock/mock_canonical_student_registry.dart';
import 'package:akshara_erp/core/repositories/mock/mock_parent_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_student_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/communication/parent_communication_store.dart';

void main() {
  setUp(() {
    SchoolHomeworkStore.instance.reset();
    ParentCommunicationStore.instance.setPreferredLanguage(
      sisStudentId: MockCanonicalStudentRegistry.primaryMobileStudentId,
      language: AksharaLanguage.telugu,
    );
  });

  group('SchoolHomeworkStore', () {
    test('teacher create is visible to parent and student with translation', () async {
      final student = MockCanonicalStudentRegistry.primaryMobileStudent;
      SchoolHomeworkStore.instance.create(
        grade: '8',
        section: 'A',
        subject: 'Mathematics',
        title: 'Mathematics Practice',
        dueLabel: 'Due next Monday',
        teacherName: 'Priya Sharma',
        targetSisStudentIds: [student.sisStudentId],
      );

      final parentRepo = MockParentRepository();
      final parentHw =
          await parentRepo.getHomework(query: RepositoryQuery.demo);
      expect(
        parentHw.items.any((item) => item.title.contains('గణితం')),
        isTrue,
      );

      final studentRepo = MockStudentRepository();
      final studentHw = await studentRepo.getHomeworkItems(
        query: RepositoryQuery.demo,
      );
      expect(studentHw.any((item) => item.id.startsWith('hw_store_')), isTrue);
      expect(
        studentHw.first.title,
        ContentLocalization.localize('Mathematics Practice', AksharaLanguage.telugu),
      );
    });

    test('class-wide homework applies to all students in class', () {
      SchoolHomeworkStore.instance.create(
        grade: '8',
        section: 'A',
        subject: 'Science',
        title: 'Photosynthesis lab report',
        dueLabel: 'Due Friday',
        teacherName: 'Mr. Patel',
      );

      final class8a = MockCanonicalStudentRegistry.class8A();
      expect(class8a.length, greaterThan(1));
      for (final student in class8a) {
        expect(
          SchoolHomeworkStore.instance.forStudent(student.sisStudentId),
          isNotEmpty,
        );
      }
    });
  });
}
