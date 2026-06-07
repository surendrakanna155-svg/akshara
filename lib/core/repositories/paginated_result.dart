import 'package:flutter/foundation.dart';

import 'api/admissions/dto/pagination_dto.dart';

/// A paginated list response from repository list endpoints.
@immutable
class PaginatedResult<T> {
  const PaginatedResult({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
    required this.hasMore,
  });

  factory PaginatedResult.fromItems(
    List<T> allItems, {
    required int page,
    required int pageSize,
  }) {
    final total = allItems.length;
    if (pageSize <= 0 || total == 0) {
      return PaginatedResult(
        items: const [],
        page: page,
        pageSize: pageSize,
        total: total,
        hasMore: false,
      );
    }

    final start = (page - 1) * pageSize;
    if (start >= total) {
      return PaginatedResult(
        items: const [],
        page: page,
        pageSize: pageSize,
        total: total,
        hasMore: false,
      );
    }

    final end = start + pageSize;
    final slice = allItems.sublist(
      start,
      end > total ? total : end,
    );

    return PaginatedResult(
      items: slice,
      page: page,
      pageSize: pageSize,
      total: total,
      hasMore: end < total,
    );
  }

  factory PaginatedResult.fromDto({
    required List<T> items,
    required PaginationDto? pagination,
    required int fallbackPage,
    required int fallbackPageSize,
  }) {
    if (pagination == null) {
      return PaginatedResult(
        items: items,
        page: fallbackPage,
        pageSize: fallbackPageSize,
        total: items.length,
        hasMore: false,
      );
    }

    return PaginatedResult(
      items: items,
      page: pagination.page,
      pageSize: pagination.pageSize,
      total: pagination.total,
      hasMore: pagination.hasMore,
    );
  }

  final List<T> items;
  final int page;
  final int pageSize;
  final int total;
  final bool hasMore;

  PaginationDto toPaginationDto() => PaginationDto(
        page: page,
        pageSize: pageSize,
        total: total,
        hasMore: hasMore,
      );
}

/// Default page size for ERP list endpoints.
const int kDefaultRepositoryPageSize = 20;
