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
  /// Hosted Privacy Policy (served by the VPS nginx vhost; see
  /// docs/legal/PRIVACY_POLICY.md). The same URL must be entered in the Play
  /// Console "Privacy Policy" field.
  static const String privacyPolicyUrl =
      'https://akshara.veloraunisexsalon.com/privacy';

  /// The placeholder value above; used to detect an unconfigured URL.
  static const String _placeholderPrivacyPolicyUrl =
      'https://example.com/akshara/privacy';

  /// True once the owner has replaced the placeholder with a real URL.
  static bool get hasPrivacyPolicyUrl =>
      privacyPolicyUrl.isNotEmpty &&
      privacyPolicyUrl != _placeholderPrivacyPolicyUrl;

  /// Opens the hosted Privacy Policy in the device browser. Returns false if the
  /// URL is unconfigured or could not be launched, so callers can show an error.
  static Future<bool> openPrivacyPolicy() async {
    if (!hasPrivacyPolicyUrl) return false;
    final uri = Uri.tryParse(privacyPolicyUrl);
    if (uri == null) return false;
    if (kIsWeb) {
      return launchUrl(uri, webOnlyWindowName: '_blank');
    }
    if (!await canLaunchUrl(uri)) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
