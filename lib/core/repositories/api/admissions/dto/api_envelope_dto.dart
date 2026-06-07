import 'api_error_dto.dart';
import 'pagination_dto.dart';

/// Parses common `{ data, pagination, error }` API envelopes.
class ApiEnvelopeDto {
  const ApiEnvelopeDto({
    this.data,
    this.listItems,
    this.pagination,
    this.error,
  });

  factory ApiEnvelopeDto.fromJson(Map<String, dynamic> json) {
    ApiErrorDto? error;
    if (json['error'] is Map<String, dynamic>) {
      error = ApiErrorDto.fromJson(json['error'] as Map<String, dynamic>);
    }

    PaginationDto? pagination;
    if (json['pagination'] is Map<String, dynamic>) {
      pagination =
          PaginationDto.fromJson(json['pagination'] as Map<String, dynamic>);
    }

    final dataField = json['data'];
    Map<String, dynamic>? data;
    List<Map<String, dynamic>>? listItems;

    if (dataField is Map<String, dynamic>) {
      data = dataField;
      if (dataField['items'] is List) {
        listItems = _mapList(dataField['items'] as List);
      }
      if (dataField['pagination'] is Map<String, dynamic>) {
        pagination = PaginationDto.fromJson(
          dataField['pagination'] as Map<String, dynamic>,
        );
      }
    } else if (dataField is List) {
      listItems = _mapList(dataField);
    } else if (json['items'] is List) {
      listItems = _mapList(json['items'] as List);
    } else {
      data = json;
    }

    return ApiEnvelopeDto(
      data: data,
      listItems: listItems,
      pagination: pagination,
      error: error,
    );
  }

  final Map<String, dynamic>? data;
  final List<Map<String, dynamic>>? listItems;
  final PaginationDto? pagination;
  final ApiErrorDto? error;

  static List<Map<String, dynamic>> _mapList(List list) {
    return [
      for (final item in list)
        if (item is Map<String, dynamic>) item,
    ];
  }

  Map<String, dynamic> requireData() {
    if (error != null) {
      throw StateError('API error: ${error!.code} — ${error!.message}');
    }
    return data ?? const {};
  }

  List<Map<String, dynamic>> requireListItems() {
    if (error != null) {
      throw StateError('API error: ${error!.code} — ${error!.message}');
    }
    return listItems ?? const [];
  }
}
