import 'library_models.dart';

class IssueLibraryBookRequest {
  const IssueLibraryBookRequest({
    required this.isbn,
    required this.memberId,
  });

  final String isbn;
  final String memberId;
}

class ReturnLibraryBookRequest {
  const ReturnLibraryBookRequest({
    required this.issueId,
    required this.condition,
  });

  final String issueId;
  final LibraryReturnCondition condition;
}

class AddLibraryBookRequest {
  const AddLibraryBookRequest({
    required this.isbn,
    required this.title,
    required this.author,
    required this.category,
    required this.totalCopies,
    required this.shelf,
  });

  final String isbn;
  final String title;
  final String author;
  final String category;
  final int totalCopies;
  final String shelf;
}

class AddLibraryResourceRequest {
  const AddLibraryResourceRequest({
    required this.title,
    required this.type,
    required this.classAccess,
    required this.resourceUrl,
    required this.studentAppVisible,
    required this.teacherAppVisible,
  });

  final String title;
  final LibraryResourceType type;
  final String classAccess;

  /// Real, openable http(s) content pointer (LIBRA-4) — not metadata-only.
  final String resourceUrl;
  final bool studentAppVisible;
  final bool teacherAppVisible;
}

class EnrollLibraryMemberRequest {
  const EnrollLibraryMemberRequest({
    required this.name,
    required this.memberType,
    required this.identifier,
    required this.classOrDepartment,
    this.sisStudentId,
  });

  final String name;
  final LibraryMemberType memberType;
  final String identifier;
  final String classOrDepartment;
  final String? sisStudentId;
}

class WaiveLibraryFineRequest {
  const WaiveLibraryFineRequest({required this.fineId});

  final String fineId;
}

/// LIB-2 — edit an existing catalogue book (`PUT /library/catalog/:id`). ISBN is
/// included; the server keeps it unique (self-exempt).
class UpdateLibraryBookRequest {
  const UpdateLibraryBookRequest({
    required this.isbn,
    required this.title,
    required this.author,
    required this.category,
    required this.totalCopies,
    required this.shelf,
  });

  final String isbn;
  final String title;
  final String author;
  final String category;
  final int totalCopies;
  final String shelf;
}

/// LIB-2 — a single book row for the bulk importer.
class ImportBookRow {
  const ImportBookRow({
    required this.title,
    required this.author,
    required this.isbn,
    this.category,
    this.totalCopies,
    this.shelf,
  });

  final String title;
  final String author;
  final String isbn;
  final String? category;
  final int? totalCopies;
  final String? shelf;

  Map<String, dynamic> toJson() => {
        'title': title,
        'author': author,
        'isbn': isbn,
        if (category != null && category!.isNotEmpty) 'category': category,
        if (totalCopies != null) 'totalCopies': totalCopies,
        if (shelf != null && shelf!.isNotEmpty) 'shelf': shelf,
      };
}

/// LIB-2 — bulk-import books (`POST /library/catalog/import`).
class BulkImportBooksRequest {
  const BulkImportBooksRequest({required this.rows});

  final List<ImportBookRow> rows;
}
