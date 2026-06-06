import 'package:flutter/material.dart';

import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';

/// PA-02 month navigation row (358×48).
class AttendanceMonthSelector extends StatelessWidget {
  const AttendanceMonthSelector({
    super.key,
    required this.monthLabel,
    required this.onPrevious,
    required this.onNext,
    this.canGoPrevious = true,
    this.canGoNext = true,
  });

  final String monthLabel;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final bool canGoPrevious;
  final bool canGoNext;

  static const double height = 48;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    final colors = context.colors;

    return SizedBox(
      height: height,
      child: Row(
        children: [
          IconButton(
            onPressed: canGoPrevious ? onPrevious : null,
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Previous month',
            style: IconButton.styleFrom(
              minimumSize: const Size(
                AksharaSpacing.minTouchTarget,
                AksharaSpacing.minTouchTarget,
              ),
            ),
          ),
          Expanded(
            child: Text(
              monthLabel,
              style: text.titleMedium.copyWith(color: colors.onSurface),
              textAlign: TextAlign.center,
            ),
          ),
          IconButton(
            onPressed: canGoNext ? onNext : null,
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Next month',
            style: IconButton.styleFrom(
              minimumSize: const Size(
                AksharaSpacing.minTouchTarget,
                AksharaSpacing.minTouchTarget,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
