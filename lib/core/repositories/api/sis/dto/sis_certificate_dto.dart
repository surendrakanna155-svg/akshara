import '../../admissions/dto/api_envelope_dto.dart';
import '../../../../../features/sis/sis_models.dart';
import '../../../../../features/sis/sis_requests.dart';

/// SIS-1 — request body for POST /sis/students/{id}/certificates.
class IssueCertificateRequestDto {
  const IssueCertificateRequestDto({required this.raw});

  factory IssueCertificateRequestDto.fromDomain(IssueCertificateRequest request) {
    final reason = request.reason?.trim();
    return IssueCertificateRequestDto(
      raw: {
        'type': request.type.apiValue,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      },
    );
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}

/// SIS-D1 — request body for POST /sis/students/{id}/transfer-certificate.
class IssueTransferCertificateRequestDto {
  const IssueTransferCertificateRequestDto({required this.raw});

  factory IssueTransferCertificateRequestDto.fromDomain(
    IssueTransferCertificateRequest request,
  ) {
    final reason = request.reason?.trim();
    return IssueTransferCertificateRequestDto(
      raw: {
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      },
    );
  }

  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}

/// Wraps the certificate DATA envelope returned by an issuance.
class SisCertificateDataDto {
  const SisCertificateDataDto({required this.raw});

  factory SisCertificateDataDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return SisCertificateDataDto(raw: envelope.requireData());
  }

  final Map<String, dynamic> raw;
}

/// Wraps the certificate issuance register list envelope.
class SisCertificateRegisterDto {
  const SisCertificateRegisterDto({required this.items});

  factory SisCertificateRegisterDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return SisCertificateRegisterDto(items: envelope.requireListItems());
  }

  final List<Map<String, dynamic>> items;
}
