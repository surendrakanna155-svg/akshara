import 'package:flutter/material.dart';

import '../../../../../features/library/library_models.dart';

/// Parses Library API enum strings and presentation helpers.
abstract final class LibraryEnumCodec {
  static LibraryBookStatus parseBookStatus(String? value) {
    return LibraryBookStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => LibraryBookStatus.available,
    );
  }

  static String bookStatusToApi(LibraryBookStatus status) => status.name;

  static LibraryMemberType parseMemberType(String? value) {
    return LibraryMemberType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => LibraryMemberType.student,
    );
  }

  static String memberTypeToApi(LibraryMemberType type) => type.name;

  static LibraryMemberStatus parseMemberStatus(String? value) {
    return LibraryMemberStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => LibraryMemberStatus.active,
    );
  }

  static String memberStatusToApi(LibraryMemberStatus status) => status.name;

  static LibraryLoanStatus parseLoanStatus(String? value) {
    return LibraryLoanStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => LibraryLoanStatus.active,
    );
  }

  static String loanStatusToApi(LibraryLoanStatus status) => status.name;

  static LibraryFineStatus parseFineStatus(String? value) {
    return LibraryFineStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => LibraryFineStatus.pending,
    );
  }

  static String fineStatusToApi(LibraryFineStatus status) => status.name;

  static LibraryResourceType parseResourceType(String? value) {
    return LibraryResourceType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => LibraryResourceType.pdf,
    );
  }

  static String resourceTypeToApi(LibraryResourceType type) => type.name;

  static LibraryReturnCondition parseReturnCondition(String? value) {
    return LibraryReturnCondition.values.firstWhere(
      (condition) => condition.name == value,
      orElse: () => LibraryReturnCondition.good,
    );
  }

  static String returnConditionToApi(LibraryReturnCondition condition) =>
      condition.name;

  static IconData iconForKpi(String? iconName, String? accentName, String? id) {
    if (iconName != null && iconName.isNotEmpty) {
      return switch (iconName) {
        'menu_book_outlined' => Icons.menu_book_outlined,
        'swap_horiz_outlined' => Icons.swap_horiz_outlined,
        'schedule_outlined' => Icons.schedule_outlined,
        'payments_outlined' => Icons.payments_outlined,
        'trending_up_outlined' => Icons.trending_up_outlined,
        'cloud_download_outlined' => Icons.cloud_download_outlined,
        _ => Icons.insights_outlined,
      };
    }
    return switch (id) {
      'total_books' => Icons.menu_book_outlined,
      'issued_today' => Icons.swap_horiz_outlined,
      'overdue' => Icons.schedule_outlined,
      'fines_mtd' => Icons.payments_outlined,
      'popular' => Icons.trending_up_outlined,
      'digital' => Icons.cloud_download_outlined,
      _ => switch (accentName) {
          'primary' => Icons.menu_book_outlined,
          'success' => Icons.swap_horiz_outlined,
          'warning' => Icons.schedule_outlined,
          'error' => Icons.payments_outlined,
          _ => Icons.insights_outlined,
        },
    };
  }
}
