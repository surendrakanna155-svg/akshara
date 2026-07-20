// PRC-A gap fix — ROUTE contract for the bulk/class-wide fee-structure
// assignment client wiring (POST /finance/fee-assignments/bulk). Proves the
// client posts to the right path with the right body (both snake+camel keys,
// matching the backend's `optionalStr` idiom) and correctly parses the
// assigned/skipped report back into domain models. The server-side contract
// (permission gate, validation, partial-failure semantics) is proven in
// finance_bulk_assignment_route_contract_test.ts /
// finance_assignments_repository_test.ts.

import 'package:akshara_erp/core/repositories/api/finance/dto/finance_student_accounts_dto.dart';
import 'package:akshara_erp/core/repositories/api/finance/mapper/finance_mapper.dart';
import 'package:akshara_erp/core/repositories/api/finance/remote/finance_api_paths.dart';
import 'package:akshara_erp/core/repositories/api/finance/remote/finance_remote_datasource.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/features/finance/finance_requests.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_dio_interceptor.dart';

void main() {
  const query = RepositoryQuery.demo;
  const mapper = FinanceMapper();

  group('PRC-A bulk assign: FinanceRemoteDataSource posts the right path/body', () {
    late String lastPath;
    late String lastMethod;
    late Map<String, dynamic> lastBody;

    FinanceRemoteDataSource buildDataSource(Map<String, dynamic> response) {
      return FinanceRemoteDataSource(
        createFakeDio((options) {
          lastPath = options.path;
          lastMethod = options.method;
          lastBody = Map<String, dynamic>.from(
            options.data as Map<String, dynamic>,
          );
          return response;
        }),
      );
    }

    test('posts to /finance/fee-assignments/bulk with the request body',
        () async {
      final ds = buildDataSource({
        'data': {
          'assigned': <dynamic>[],
          'skipped': <dynamic>[],
          'total': 0,
        },
      });

      await ds.bulkAssignFeeStructure(
        query: query,
        request: const BulkAssignFeePlanRequest(
          feeStructureId: 'struct-1',
          academicYear: '2026-27',
          studentIds: ['stu-1', 'stu-2', 'stu-3'],
        ),
      );

      expect(lastPath, FinanceApiPaths.feeAssignmentsBulk);
      expect(lastPath, '/finance/fee-assignments/bulk');
      expect(lastMethod.toUpperCase(), 'POST');
      // Both snake_case and camelCase carried — mirrors the backend's
      // optionalStr(body, snakeKey, camelKey) idiom that reads either.
      expect(lastBody['fee_structure_id'], 'struct-1');
      expect(lastBody['feeStructureId'], 'struct-1');
      expect(lastBody['academic_year'], '2026-27');
      expect(lastBody['academicYear'], '2026-27');
      expect(lastBody['student_ids'], ['stu-1', 'stu-2', 'stu-3']);
      expect(lastBody['studentIds'], ['stu-1', 'stu-2', 'stu-3']);
    });

    test('parses a report with assigned + skipped students', () async {
      final ds = buildDataSource({
        'data': {
          'assigned': [
            {
              'id': 'acct_1',
              'studentId': 'stu-1',
              'studentName': 'Aisha Rao',
              'admissionNumber': 'ADM-001',
              'classLabel': '8',
              'feeStructureName': 'Standard Tuition',
              'feeStructureId': 'struct-1',
              'feeAssignmentId': 'fa_1',
              'academicYear': '2026-27',
              'totalDue': '50000',
              'totalPaid': '0',
              'balance': '50000',
              'status': 'active',
              'lastPaymentDate': '',
              'installmentPlan': '',
            },
          ],
          'skipped': [
            {'studentId': 'stu-2', 'reason': 'already_assigned'},
          ],
          'total': 2,
        },
      });

      final dto = await ds.bulkAssignFeeStructure(
        query: query,
        request: const BulkAssignFeePlanRequest(
          feeStructureId: 'struct-1',
          academicYear: '2026-27',
          studentIds: ['stu-1', 'stu-2'],
        ),
      );

      final result = mapper.toBulkFeeAssignmentResult(dto);
      expect(result.total, 2);
      expect(result.assigned, hasLength(1));
      expect(result.assigned.single.studentName, 'Aisha Rao');
      expect(result.assigned.single.admissionNumber, 'ADM-001');
      expect(result.skipped, hasLength(1));
      expect(result.skipped.single.studentId, 'stu-2');
      expect(result.skipped.single.reason, 'already_assigned');
    });

    test('FinanceMapper.toBulkFeeAssignmentResult defaults total when absent',
        () {
      final dto = BulkFeeAssignmentResultDto.fromJson(const {
        'assigned': <dynamic>[],
        'skipped': [
          {'studentId': 'stu-9', 'reason': 'already_assigned'},
        ],
      });
      final result = mapper.toBulkFeeAssignmentResult(dto);
      expect(result.total, 1);
      expect(result.assigned, isEmpty);
      expect(result.skipped.single.studentId, 'stu-9');
    });
  });
}
