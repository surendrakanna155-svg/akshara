/// REST paths for the unified Approval API module (F2).
abstract final class ApprovalApiPaths {
  static const String base = '/approvals';

  static const String pending = '$base/pending';
  static const String entity = '$base/entity';
  static const String audit = '$base/audit';

  static String detail(String id) => '$base/$id';
  static String approve(String id) => '${detail(id)}/approve';
  static String reject(String id) => '${detail(id)}/reject';
  static String cancel(String id) => '${detail(id)}/cancel';
  static String auditTrail(String id) => '${detail(id)}/audit';
}
