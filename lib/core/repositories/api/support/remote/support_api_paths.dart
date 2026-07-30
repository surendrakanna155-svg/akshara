/// REST paths for the ASIP `/support` module (Phase 1 reporter surface).
abstract final class SupportApiPaths {
  static const String base = '/support';

  /// GET lists the reporter's incidents; POST creates one.
  static const String incidents = '$base/incidents';

  static String incident(String id) => '$incidents/$id';
  static String messages(String id) => '${incident(id)}/messages';
  static String presignAttachment(String id) =>
      '${incident(id)}/attachments/presign';
  static String confirmAttachment(String id) =>
      '${incident(id)}/attachments/confirm';
}
