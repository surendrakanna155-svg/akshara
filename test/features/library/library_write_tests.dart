import 'package:akshara_erp/core/repositories/mock/mock_library_repository.dart';
import 'package:akshara_erp/core/repositories/repository_query.dart';
import 'package:akshara_erp/core/security/erp_role.dart';
import 'package:akshara_erp/core/security/rbac_service.dart';
import 'package:akshara_erp/core/security/user_permissions.dart';
import 'package:akshara_erp/features/library/library_models.dart';
import 'package:akshara_erp/features/library/library_mutations_provider.dart';
import 'package:akshara_erp/features/library/library_requests.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/provider_test_overrides.dart';

void main() {
  setUpAll(() async {
    await initProviderTestPrefs();
  });

  group('Library mock writes', () {
    const query = RepositoryQuery.demo;

    test('issueLibraryBook creates active loan', () async {
      final repo = MockLibraryRepository();
      final before = await repo.getIssues(query: query);

      final issue = await repo.issueLibraryBook(
        query: query,
        request: const IssueLibraryBookRequest(
          isbn: '978-0-07-802563-1',
          memberId: 'mem_5',
        ),
      );

      final after = await repo.getIssues(query: query);
      expect(after.total, greaterThan(before.total));
      expect(issue.status, LibraryLoanStatus.active);
      expect(issue.memberName, 'Ravi Shankar');
    });

    test('returnLibraryBook closes loan and adds return record', () async {
      final repo = MockLibraryRepository();
      final beforeIssues = await repo.getIssues(query: query);
      final beforeReturns = await repo.getReturns(query: query);

      final record = await repo.returnLibraryBook(
        query: query,
        request: const ReturnLibraryBookRequest(
          issueId: 'iss_2',
          condition: LibraryReturnCondition.good,
        ),
      );

      final afterIssues = await repo.getIssues(query: query);
      final afterReturns = await repo.getReturns(query: query);

      expect(afterIssues.total, lessThan(beforeIssues.total));
      expect(afterReturns.total, greaterThan(beforeReturns.total));
      expect(record.bookTitle, 'The Great Gatsby');
      expect(record.fineAmount, '₹0');
    });
  });

  group('Library RBAC mutations', () {
    test('issueLibraryBook fails without manageLibrary', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.admissionsCounselor),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(issueLibraryBookProvider.notifier).execute(
            const IssueLibraryBookRequest(
              isbn: '978-0-07-802563-1',
              memberId: 'mem_5',
            ),
          );

      expect(container.read(issueLibraryBookProvider).hasError, isTrue);
    });

    test('returnLibraryBook succeeds for superAdmin', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.superAdmin),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(returnLibraryBookProvider.notifier).execute(
            const ReturnLibraryBookRequest(
              issueId: 'iss_3',
              condition: LibraryReturnCondition.fair,
            ),
          );

      expect(container.read(returnLibraryBookProvider).hasValue, isTrue);
      expect(
        container.read(returnLibraryBookProvider).value?.bookTitle,
        'Effective Java',
      );
    });
  });
}
