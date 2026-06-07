import 'package:akshara_erp/core/repositories/api/admissions/dto/pagination_dto.dart';
import 'package:akshara_erp/core/repositories/paginated_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PaginatedResult.fromItems', () {
    const items = ['a', 'b', 'c', 'd', 'e'];

    test('returns first page slice with hasMore', () {
      final result = PaginatedResult.fromItems(
        items,
        page: 1,
        pageSize: 2,
      );

      expect(result.items, ['a', 'b']);
      expect(result.page, 1);
      expect(result.pageSize, 2);
      expect(result.total, 5);
      expect(result.hasMore, isTrue);
    });

    test('returns middle page slice', () {
      final result = PaginatedResult.fromItems(
        items,
        page: 2,
        pageSize: 2,
      );

      expect(result.items, ['c', 'd']);
      expect(result.hasMore, isTrue);
    });

    test('returns final page without hasMore', () {
      final result = PaginatedResult.fromItems(
        items,
        page: 3,
        pageSize: 2,
      );

      expect(result.items, ['e']);
      expect(result.hasMore, isFalse);
    });

    test('returns empty items when page is beyond total', () {
      final result = PaginatedResult.fromItems(
        items,
        page: 4,
        pageSize: 2,
      );

      expect(result.items, isEmpty);
      expect(result.total, 5);
      expect(result.hasMore, isFalse);
    });

    test('returns empty result for empty source list', () {
      final result = PaginatedResult.fromItems(
        const <String>[],
        page: 1,
        pageSize: 20,
      );

      expect(result.items, isEmpty);
      expect(result.total, 0);
      expect(result.hasMore, isFalse);
    });

    test('returns empty items when pageSize is zero', () {
      final result = PaginatedResult.fromItems(
        items,
        page: 1,
        pageSize: 0,
      );

      expect(result.items, isEmpty);
      expect(result.total, 5);
      expect(result.hasMore, isFalse);
    });
  });

  group('PaginatedResult.fromDto', () {
    test('uses pagination metadata when present', () {
      final result = PaginatedResult<String>.fromDto(
        items: const ['a', 'b'],
        pagination: const PaginationDto(
          page: 2,
          pageSize: 2,
          total: 7,
          hasMore: true,
        ),
        fallbackPage: 1,
        fallbackPageSize: 20,
      );

      expect(result.page, 2);
      expect(result.pageSize, 2);
      expect(result.total, 7);
      expect(result.hasMore, isTrue);
    });
  });
}
