import '../../admissions/dto/api_envelope_dto.dart';
import '../../admissions/dto/pagination_dto.dart';

class FinanceInvoiceDto {
  const FinanceInvoiceDto({required this.raw});

  factory FinanceInvoiceDto.fromJson(Map<String, dynamic> json) {
    return FinanceInvoiceDto(raw: json);
  }

  final Map<String, dynamic> raw;
}

class FinanceInvoicesResponseDto {
  const FinanceInvoicesResponseDto({
    required this.items,
    this.pagination,
  });

  factory FinanceInvoicesResponseDto.fromJson(Map<String, dynamic> json) {
    final envelope = ApiEnvelopeDto.fromJson(json);
    return FinanceInvoicesResponseDto(
      items: [
        for (final item in envelope.requireListItems())
          FinanceInvoiceDto.fromJson(item),
      ],
      pagination: envelope.pagination,
    );
  }

  final List<FinanceInvoiceDto> items;
  final PaginationDto? pagination;
}
