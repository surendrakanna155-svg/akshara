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

    test('addLibraryBook adds an available book to the catalog', () async {
      final repo = MockLibraryRepository();
      final before = await repo.getCatalog(query: query);

      final book = await repo.addLibraryBook(
        query: query,
        request: const AddLibraryBookRequest(
          isbn: '978-1-23-456789-0',
          title: 'Clean Architecture',
          author: 'Robert C. Martin',
          category: 'Computer Science',
          totalCopies: 4,
          shelf: 'CS-21',
        ),
      );

      final after = await repo.getCatalog(query: query);
      expect(after.total, before.total + 1);
      expect(book.status, LibraryBookStatus.available);
      expect(book.availableCopies, 4);
      expect(after.items.any((b) => b.id == book.id), isTrue);
    });

    test('addLibraryBook rejects a duplicate ISBN', () async {
      final repo = MockLibraryRepository();
      final existing = (await repo.getCatalog(query: query)).items.first;

      expect(
        () => repo.addLibraryBook(
          query: query,
          request: AddLibraryBookRequest(
            isbn: existing.isbn,
            title: existing.title,
            author: existing.author,
            category: existing.category,
            totalCopies: existing.totalCopies,
            shelf: existing.shelf,
          ),
        ),
        throwsStateError,
      );
    });

    test('addDigitalResource adds a zero-download resource', () async {
      final repo = MockLibraryRepository();
      final before = await repo.getDigitalResources(query: query);

      final resource = await repo.addDigitalResource(
        query: query,
        request: const AddLibraryResourceRequest(
          title: 'NCERT Maths Class 9 (PDF)',
          type: LibraryResourceType.pdf,
          classAccess: 'Class 9',
          resourceUrl: 'https://ncert.nic.in/jemh1.pdf',
          studentAppVisible: true,
          teacherAppVisible: false,
        ),
      );

      final after = await repo.getDigitalResources(query: query);
      expect(after.resources.length, before.resources.length + 1);
      expect(resource.downloads, 0);
      expect(resource.teacherAppVisible, isFalse);
      expect(resource.resourceUrl, 'https://ncert.nic.in/jemh1.pdf');
      expect(after.resources.any((r) => r.id == resource.id), isTrue);
    });

    test('addDigitalResource rejects an empty URL', () async {
      final repo = MockLibraryRepository();
      expect(
        () => repo.addDigitalResource(
          query: query,
          request: const AddLibraryResourceRequest(
            title: 'No link',
            type: LibraryResourceType.link,
            classAccess: 'All classes',
            resourceUrl: '',
            studentAppVisible: true,
            teacherAppVisible: true,
          ),
        ),
        throwsStateError,
      );
    });

    test('enrollMember adds an active member usable for an issue', () async {
      final repo = MockLibraryRepository();
      final before = await repo.getMembers(query: query);

      final member = await repo.enrollMember(
        query: query,
        request: const EnrollLibraryMemberRequest(
          name: 'Sneha Kulkarni',
          memberType: LibraryMemberType.student,
          identifier: 'ADM-2026-0210',
          classOrDepartment: 'Class 9',
          sisStudentId: 'SIS-STU-20001',
        ),
      );

      final after = await repo.getMembers(query: query);
      expect(after.total, before.total + 1);
      expect(member.status, LibraryMemberStatus.active);
      expect(member.activeLoans, 0);

      // The freshly-enrolled member can borrow a book (no garbage id).
      final issue = await repo.issueLibraryBook(
        query: query,
        request: IssueLibraryBookRequest(
          isbn: '978-0-07-802563-1',
          memberId: member.id,
        ),
      );
      expect(issue.memberName, 'Sneha Kulkarni');
    });

    test('waiveFine flips a pending fine and drops it from the pending total',
        () async {
      final repo = MockLibraryRepository();
      final before = await repo.getFines(query: query);
      final pending = before.fines
          .firstWhere((f) => f.status == LibraryFineStatus.pending);

      final waived = await repo.waiveFine(
        query: query,
        request: WaiveLibraryFineRequest(fineId: pending.id),
      );
      expect(waived.status, LibraryFineStatus.waived);

      final after = await repo.getFines(query: query);
      final updated = after.fines.firstWhere((f) => f.id == pending.id);
      expect(updated.status, LibraryFineStatus.waived);
      expect(after.totalPending, isNot(before.totalPending));
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

    test('addLibraryBook fails without manageLibrary', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.admissionsCounselor),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(addLibraryBookProvider.notifier).execute(
            const AddLibraryBookRequest(
              isbn: '978-1-23-456789-1',
              title: 'Blocked Book',
              author: 'Anon',
              category: 'General',
              totalCopies: 1,
              shelf: 'GEN-1',
            ),
          );

      expect(container.read(addLibraryBookProvider).hasError, isTrue);
    });

    test('addLibraryBook succeeds for superAdmin', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.superAdmin),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(addLibraryBookProvider.notifier).execute(
            const AddLibraryBookRequest(
              isbn: '978-1-23-456789-2',
              title: 'Allowed Book',
              author: 'Anon',
              category: 'General',
              totalCopies: 2,
              shelf: 'GEN-2',
            ),
          );

      expect(container.read(addLibraryBookProvider).hasValue, isTrue);
      expect(
        container.read(addLibraryBookProvider).value?.status,
        LibraryBookStatus.available,
      );
    });

    test('addDigitalResource fails without manageLibrary', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.admissionsCounselor),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(addLibraryResourceProvider.notifier).execute(
            const AddLibraryResourceRequest(
              title: 'Blocked Resource',
              type: LibraryResourceType.link,
              classAccess: 'All classes',
              resourceUrl: 'https://example.org/blocked',
              studentAppVisible: true,
              teacherAppVisible: true,
            ),
          );

      expect(container.read(addLibraryResourceProvider).hasError, isTrue);
    });

    test('addDigitalResource succeeds for superAdmin', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.superAdmin),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(addLibraryResourceProvider.notifier).execute(
            const AddLibraryResourceRequest(
              title: 'Allowed Resource',
              type: LibraryResourceType.video,
              classAccess: 'Class 10',
              resourceUrl: 'https://example.org/allowed.mp4',
              studentAppVisible: true,
              teacherAppVisible: true,
            ),
          );

      expect(container.read(addLibraryResourceProvider).hasValue, isTrue);
      expect(
        container.read(addLibraryResourceProvider).value?.downloads,
        0,
      );
    });

    test('enrollMember fails without manageLibrary', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.admissionsCounselor),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(enrollLibraryMemberProvider.notifier).execute(
            const EnrollLibraryMemberRequest(
              name: 'Blocked Member',
              memberType: LibraryMemberType.student,
              identifier: 'ADM-X',
              classOrDepartment: 'Class 1',
            ),
          );

      expect(container.read(enrollLibraryMemberProvider).hasError, isTrue);
    });

    test('enrollMember succeeds for superAdmin', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.superAdmin),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(enrollLibraryMemberProvider.notifier).execute(
            const EnrollLibraryMemberRequest(
              name: 'Allowed Member',
              memberType: LibraryMemberType.staff,
              identifier: 'EMP-9',
              classOrDepartment: 'Administration',
            ),
          );

      expect(container.read(enrollLibraryMemberProvider).hasValue, isTrue);
      expect(
        container.read(enrollLibraryMemberProvider).value?.status,
        LibraryMemberStatus.active,
      );
    });

    test('waiveFine fails without manageLibrary', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.admissionsCounselor),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(waiveLibraryFineProvider.notifier).execute(
            const WaiveLibraryFineRequest(fineId: 'fine_1'),
          );

      expect(container.read(waiveLibraryFineProvider).hasError, isTrue);
    });

    test('waiveFine succeeds for superAdmin', () async {
      final container = ProviderContainer(
        overrides: [
          ...providerTestOverrides(),
          userPermissionsProvider.overrideWithValue(
            UserPermissions.forRole(ErpRole.superAdmin),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(waiveLibraryFineProvider.notifier).execute(
            const WaiveLibraryFineRequest(fineId: 'fine_1'),
          );

      expect(container.read(waiveLibraryFineProvider).hasValue, isTrue);
      expect(
        container.read(waiveLibraryFineProvider).value?.status,
        LibraryFineStatus.waived,
      );
    });
  });
}
