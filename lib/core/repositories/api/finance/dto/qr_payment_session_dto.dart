class QrPaymentSessionDto {
  const QrPaymentSessionDto({required this.raw});

  factory QrPaymentSessionDto.fromJson(Map<String, dynamic> json) {
    return QrPaymentSessionDto(raw: json);
  }

  final Map<String, dynamic> raw;
}
