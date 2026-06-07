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
}
