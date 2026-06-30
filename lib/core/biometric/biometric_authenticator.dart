import 'package:local_auth/local_auth.dart';

/// Outcome of a device-biometric prompt for staff check-in.
///
/// HARD-BLOCK policy (owner decision 2026-06-30): a staff check-in proceeds ONLY
/// on a real biometric (Face ID / fingerprint / iris). There is NO device-credential
/// (PIN/passcode) fallback — if no biometric is enrolled, the gate is [unavailable]
/// and the check-in is refused. This is the anti-buddy-punching guarantee.
class BiometricResult {
  const BiometricResult._({
    required this.authenticated,
    required this.method,
    this.reasonCode,
    this.message,
  });

  /// A real biometric succeeded; [method] is `face_id` | `fingerprint` | `iris` | `biometric`.
  factory BiometricResult.success(String method) =>
      BiometricResult._(authenticated: true, method: method);

  /// The device has no usable/enrolled biometric — check-in is blocked (no PIN fallback).
  factory BiometricResult.unavailable([String? message]) => BiometricResult._(
        authenticated: false,
        method: 'none',
        reasonCode: 'biometric_unavailable',
        message: message ?? 'No device biometric is enrolled. Enrol Face ID / fingerprint to check in.',
      );

  /// The user cancelled or the biometric did not match.
  factory BiometricResult.failed([String? message]) => BiometricResult._(
        authenticated: false,
        method: 'none',
        reasonCode: 'biometric_failed',
        message: message ?? 'Biometric verification was not completed.',
      );

  final bool authenticated;
  final String method;
  final String? reasonCode;
  final String? message;
}

/// Gates an action behind a device biometric. Injected so it can be faked in
/// tests (no device hardware needed for certification).
abstract interface class BiometricAuthenticator {
  Future<BiometricResult> authenticate({required String reason});
}

/// `local_auth`-backed implementation. Device OS gate only — NO computer-vision
/// face matching (that is Future Vision). `biometricOnly: true` enforces the
/// hard-block: the OS will not offer a PIN/passcode fallback.
class LocalAuthBiometricAuthenticator implements BiometricAuthenticator {
  LocalAuthBiometricAuthenticator({LocalAuthentication? auth})
      : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<BiometricResult> authenticate({required String reason}) async {
    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      if (!supported || !canCheck) {
        return BiometricResult.unavailable('This device cannot perform biometric check-in.');
      }

      final enrolled = await _auth.getAvailableBiometrics();
      if (enrolled.isEmpty) {
        return BiometricResult.unavailable();
      }

      final ok = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true, // hard-block: no device-credential (PIN) fallback
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
      return ok ? BiometricResult.success(_methodLabel(enrolled)) : BiometricResult.failed();
    } catch (e) {
      return BiometricResult.failed(e.toString());
    }
  }

  static String _methodLabel(List<BiometricType> types) {
    if (types.contains(BiometricType.face)) return 'face_id';
    if (types.contains(BiometricType.fingerprint)) return 'fingerprint';
    if (types.contains(BiometricType.iris)) return 'iris';
    return 'biometric';
  }
}
