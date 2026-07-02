import '../../../features/library/library_models.dart';
import '../../../features/library/library_requests.dart';
import '../paginated_result.dart';
import '../repository_query.dart';

/// Contract for library data access (mock or API).
abstract class LibraryRepository {
  Future<LibraryDashboardData> getDashboard({required RepositoryQuery query});
  Future<PaginatedResult<LibraryBook>> getCatalog({required RepositoryQuery query});
  Future<PaginatedResult<LibraryIssueRecord>> getIssues({required RepositoryQuery query});
  Future<PaginatedResult<LibraryReturnRecord>> getReturns({required RepositoryQuery query});
  Future<PaginatedResult<LibraryMember>> getMembers({required RepositoryQuery query});
  Future<LibraryFinesData> getFines({required RepositoryQuery query});
  Future<LibraryDigitalResourcesData> getDigitalResources({required RepositoryQuery query});
  Future<LibraryReportsData> getReports({required RepositoryQuery query});
  Future<LibraryIssueRecord> issueLibraryBook({
    required RepositoryQuery query,
    required IssueLibraryBookRequest request,
  });
  Future<LibraryReturnRecord> returnLibraryBook({
    required RepositoryQuery query,
    required ReturnLibraryBookRequest request,
  });
  Future<LibraryBook> addLibraryBook({
    required RepositoryQuery query,
    required AddLibraryBookRequest request,
  });
  Future<LibraryDigitalResource> addDigitalResource({
    required RepositoryQuery query,
    required AddLibraryResourceRequest request,
  });
  Future<LibraryMember> enrollMember({
    required RepositoryQuery query,
    required EnrollLibraryMemberRequest request,
  });
  Future<LibraryFine> waiveFine({
    required RepositoryQuery query,
    required WaiveLibraryFineRequest request,
  });

  // ── LIB-1 … LIB-D1 extensions ──────────────────────────────────────────────

  /// LIB-2 — edit an existing catalogue book.
  Future<LibraryBook> updateLibraryBook({
    required RepositoryQuery query,
    required String id,
    required UpdateLibraryBookRequest request,
  });

  /// LIB-2 — delete a book (rejected while a copy is on an active loan).
  Future<void> deleteLibraryBook({
    required RepositoryQuery query,
    required String id,
  });

  /// LIB-2 — bulk-import books; returns per-row import outcome.
  Future<ImportResult> bulkImportBooks({
    required RepositoryQuery query,
    required BulkImportBooksRequest request,
  });

  /// LIB-4 — renew an active loan (+14d, capped by settings.maxRenewals).
  Future<LibraryIssueRecord> renewLibraryLoan({
    required RepositoryQuery query,
    required String issueId,
  });

  /// LIB-1 — the open overdue loans with per-row accrued fine.
  Future<List<OverdueLoan>> getOverdueLoans({required RepositoryQuery query});

  /// LIB-5 — enqueue in-app overdue reminders; returns the recipient count.
  Future<int> sendOverdueReminder({required RepositoryQuery query});

  /// LIB-D1 — the circulation guardrail settings.
  Future<LibrarySettings> getLibrarySettings({required RepositoryQuery query});

  /// LIB-D1 — update the circulation guardrail settings.
  Future<LibrarySettings> updateLibrarySettings({
    required RepositoryQuery query,
    required LibrarySettings settings,
  });
}
