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
    required this.studentAppVisible,
    required this.teacherAppVisible,
  });

  final String title;
  final LibraryResourceType type;
  final String classAccess;
  final bool studentAppVisible;
  final bool teacherAppVisible;
}
