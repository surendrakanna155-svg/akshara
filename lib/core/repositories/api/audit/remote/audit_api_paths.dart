/// REST paths for the Audit ingestion API module.
abstract final class AuditApiPaths {
  static const String base = '/audit';

  static const String events = '$base/events';
  static const String batch = '$base/events/batch';
}
