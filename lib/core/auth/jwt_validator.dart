import 'jwt_decoder.dart';

/// Outcome of JWT claim validation.
class JwtValidationResult {
  const JwtValidationResult.valid() : isValid = true, failureReason = null;

  const JwtValidationResult.invalid(this.failureReason) : isValid = false;

  final bool isValid;
  final String? failureReason;
}

/// Validates JWT structure and required claims before attaching to requests.
class JwtValidator {
  JwtValidator({
    JwtDecoder decoder = jwtDecoder,
    Duration clockSkewTolerance = const Duration(seconds: 60),
  })  : _decoder = decoder,
        _clockSkewTolerance = clockSkewTolerance;

  final JwtDecoder _decoder;
  final Duration _clockSkewTolerance;

  /// Validates [token] claims: format, sub, tenant_id, exp, and iat.
  JwtValidationResult validate(
    String token, {
    String? expectedTenantId,
  }) {
    if (token.isEmpty) {
      return const JwtValidationResult.invalid('empty_token');
    }

    if (!_decoder.isJwtFormat(token)) {
      return const JwtValidationResult.invalid('invalid_format');
    }

    final claims = _decoder.decode(token);
    if (claims == null) {
      return const JwtValidationResult.invalid('decode_failed');
    }

    if (claims.subject == null || claims.subject!.isEmpty) {
      return const JwtValidationResult.invalid('missing_sub');
    }

    if (claims.tenantId == null || claims.tenantId!.isEmpty) {
      return const JwtValidationResult.invalid('missing_tenant_id');
    }

    if (expectedTenantId != null &&
        expectedTenantId.isNotEmpty &&
        claims.tenantId != expectedTenantId) {
      return const JwtValidationResult.invalid('tenant_mismatch');
    }

    if (claims.expiresAt == null) {
      return const JwtValidationResult.invalid('missing_exp');
    }

    final now = DateTime.now();
    if (now.isAfter(claims.expiresAt!.add(_clockSkewTolerance))) {
      return const JwtValidationResult.invalid('expired');
    }

    if (claims.issuedAt == null) {
      return const JwtValidationResult.invalid('missing_iat');
    }

    if (claims.issuedAt!.isAfter(now.add(_clockSkewTolerance))) {
      return const JwtValidationResult.invalid('iat_in_future');
    }

    return const JwtValidationResult.valid();
  }
}

final jwtValidator = JwtValidator();
