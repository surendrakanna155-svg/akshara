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
