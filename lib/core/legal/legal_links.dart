import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Centralised legal / compliance links surfaced in the app (e.g. the Privacy
/// Policy entry in the profile screen).
///
/// OWNER ACTION REQUIRED: host `docs/legal/PRIVACY_POLICY.md` at a public HTTPS
/// URL and replace [privacyPolicyUrl] below with that URL. The same URL must be
/// entered in the Play Console "Privacy Policy" field. Until it is set to a real
/// hosted page, [hasPrivacyPolicyUrl] is false and the in-app link is hidden so
/// users never hit a dead placeholder.
abstract final class LegalLinks {
  /// Public HTTPS base where the hosted legal documents live (served by the VPS
  /// nginx vhost; see docs/legal/PLACEHOLDERS.md → `[POLICY HOST BASE URL]`).
  /// Individual policies are reached at this base + their catalog `path`
  /// (e.g. `/privacy`, `/terms/user`).
  ///
  /// OWNER ACTION: keep this in sync with the Play Console "Privacy Policy" URL
  /// and host the documents under this base.
  static const String policyHostBaseUrl = 'https://nikshaos.in';

  /// Placeholder base; used to detect an unconfigured host.
  static const String _placeholderHostBaseUrl = 'https://example.com/akshara';

  /// Hosted Privacy Policy. The same URL must be entered in the Play Console
  /// "Privacy Policy" field.
  static const String privacyPolicyUrl = '$policyHostBaseUrl/privacy';

  /// True once the owner has replaced the placeholder with a real host.
  static bool get hasPrivacyPolicyUrl =>
      policyHostBaseUrl.isNotEmpty &&
      policyHostBaseUrl != _placeholderHostBaseUrl;

  /// Builds the full URL for a policy catalog [path] (e.g. `/privacy`). Returns
  /// null when the host is unconfigured.
  static String? urlForPath(String path) {
    if (!hasPrivacyPolicyUrl || path.isEmpty) return null;
    final normalised = path.startsWith('/') ? path : '/$path';
    return '$policyHostBaseUrl$normalised';
  }

  /// Opens a hosted policy by its catalog [path]. Returns false if the host is
  /// unconfigured or the URL could not be launched, so callers can show an error.
  static Future<bool> openPolicyPath(String path) {
    final url = urlForPath(path);
    if (url == null) return Future.value(false);
    return _open(url);
  }

  /// Opens the hosted Privacy Policy in the device browser. Returns false if the
  /// URL is unconfigured or could not be launched, so callers can show an error.
  static Future<bool> openPrivacyPolicy() => openPolicyPath('/privacy');

  static Future<bool> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    if (kIsWeb) {
      return launchUrl(uri, webOnlyWindowName: '_blank');
    }
    if (!await canLaunchUrl(uri)) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
