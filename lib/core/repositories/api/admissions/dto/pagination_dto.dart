/// Cursor/page pagination metadata from list endpoints.
class PaginationDto {
  const PaginationDto({
    required this.page,
    required this.pageSize,
    required this.total,
    required this.hasMore,
  });

  factory PaginationDto.fromJson(Map<String, dynamic> json) {
    return PaginationDto(
      page: json['page'] as int? ?? 1,
      pageSize: json['pageSize'] as int? ?? json['page_size'] as int? ?? 20,
      total: json['total'] as int? ?? 0,
      hasMore: json['hasMore'] as bool? ?? json['has_more'] as bool? ?? false,
    );
  }

  final int page;
  final int pageSize;
  final int total;
  final bool hasMore;

  Map<String, dynamic> toJson() => {
        'page': page,
        'pageSize': pageSize,
        'total': total,
        'hasMore': hasMore,
      };
}
