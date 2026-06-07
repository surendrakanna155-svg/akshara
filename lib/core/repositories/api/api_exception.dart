/// Thrown when an API repository is wired but remote calls are not implemented.
class ApiNotConnectedException implements Exception {
  ApiNotConnectedException(this.repository, [this.method]);

  final String repository;
  final String? method;

  @override
  String toString() {
    final target = method == null ? repository : '$repository.$method';
    return 'ApiNotConnectedException: $target — remote API not connected';
  }
}
