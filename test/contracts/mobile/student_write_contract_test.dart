import 'package:akshara_erp/core/repositories/api/student/dto/student_homework_submit_request_dto.dart';
import 'package:akshara_erp/core/repositories/interfaces/student_repository.dart';
import 'package:akshara_erp/core/repositories/mock/mock_student_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/student_app/homework/homework_models.dart';
import 'package:akshara_erp/features/student_app/student_requests.dart';
import 'package:flutter_test/flutter_test.dart';

const kQuery = RepositoryQuery.demo;

void main() {
  group('Student write DTO serialization', () {
    test('homework submit request uses snake_case keys', () {
      final json = StudentHomeworkSubmitRequestDto.fromDomain(
        const StudentHomeworkSubmitRequest(
          homeworkId: 'hw-1',
          attachmentLabel: 'worksheet.pdf',
          notes: 'Completed all questions.',
        ),
      ).toJson();
      expect(json['homework_id'], 'hw-1');
      expect(json['attachment_label'], 'worksheet.pdf');
    });

    test('PRA-P1-30 homework submit serializes attachment_storage_path when set',
        () {
      final json = StudentHomeworkSubmitRequestDto.fromDomain(
        const StudentHomeworkSubmitRequest(
          homeworkId: 'hw-1',
          attachmentLabel: 'worksheet.pdf',
          attachmentStoragePath: 'org/school/stu-1/hw-1/uuid_worksheet.pdf',
          notes: 'Completed all questions.',
        ),
      ).toJson();
      expect(json['attachment_storage_path'],
          'org/school/stu-1/hw-1/uuid_worksheet.pdf');
    });

    test('PRA-P1-30 homework submit omits attachment_storage_path when absent',
        () {
      final json = StudentHomeworkSubmitRequestDto.fromDomain(
        const StudentHomeworkSubmitRequest(homeworkId: 'hw-1'),
      ).toJson();
      expect(json.containsKey('attachment_storage_path'), isFalse);
    });
  });

  group('Mock student write repository', () {
    late MockStudentRepository repo;

    setUp(() {
      repo = MockStudentRepository();
    });

    test('implements all write methods on StudentRepository', () {
      expect(repo, isA<StudentRepository>());
    });

    test('submitHomework returns submitted item in getHomeworkItems', () async {
      final submitted = await repo.submitHomework(
        query: kQuery,
        request: const StudentHomeworkSubmitRequest(
          homeworkId: 'hw-1',
          attachmentLabel: 'worksheet.pdf',
        ),
      );
      final items = await repo.getHomeworkItems(query: kQuery);
      expect(submitted.status, StudentHomeworkStatus.submitted);
      expect(items.firstWhere((item) => item.id == 'hw-1').status,
          StudentHomeworkStatus.submitted);
    });
  });
}
