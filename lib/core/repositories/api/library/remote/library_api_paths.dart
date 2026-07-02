/// REST paths for the Library API module.
abstract final class LibraryApiPaths {
  static const String base = '/library';

  static const String dashboard = '$base/dashboard';
  static const String catalog = '$base/catalog';
  static const String issues = '$base/issues';
  static const String returns = '$base/returns';
  static const String members = '$base/members';
  static const String fines = '$base/fines';
  static const String digitalResources = '$base/digital-resources';
  static const String reports = '$base/reports';

  // LIB-1 / LIB-D1 — computed overdue list + circulation settings.
  static const String overdue = '$base/overdue';
  static const String settings = '$base/settings';

  // LIB-2 — bulk catalogue import.
  static const String catalogImport = '$catalog/import';

  // LIB-5 — enqueue overdue reminders.
  static const String overdueReminders = '$base/reminders/overdue';

  static String waiveFine(String fineId) => '$fines/$fineId/waive';

  /// LIB-2 — update / delete a single catalogue book.
  static String catalogBook(String bookId) => '$catalog/$bookId';

  /// LIB-4 — renew an active loan.
  static String renewLoan(String issueId) => '$issues/$issueId/renew';
}
