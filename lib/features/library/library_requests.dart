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
