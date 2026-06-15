import '../../admissions/dto/pagination_dto.dart';

class OfflinePaymentDto {
  const OfflinePaymentDto({required this.raw});

  factory OfflinePaymentDto.fromJson(Map<String, dynamic> json) {
    return OfflinePaymentDto(raw: json);
  }

  final Map<String, dynamic> raw;
}

class OfflinePaymentsResponseDto {
  const OfflinePaymentsResponseDto({
    required this.items,
    this.pagination,
  });

  factory OfflinePaymentsResponseDto.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is List<dynamic>) {
      return OfflinePaymentsResponseDto(
        items: [
          for (final item in data)
            if (item is Map<String, dynamic>) OfflinePaymentDto.fromJson(item),
        ],
      );
    }
    if (data is Map<String, dynamic>) {
      final items = data['items'] as List<dynamic>? ?? const [];
      return OfflinePaymentsResponseDto(
        items: [
          for (final item in items)
            if (item is Map<String, dynamic>) OfflinePaymentDto.fromJson(item),
        ],
        pagination: (data['pagination'] is Map<String, dynamic>)
            ? PaginationDto.fromJson(
                data['pagination'] as Map<String, dynamic>,
              )
            : null,
      );
    }
    return const OfflinePaymentsResponseDto(items: []);
  }

  final List<OfflinePaymentDto> items;
  final PaginationDto? pagination;
}
