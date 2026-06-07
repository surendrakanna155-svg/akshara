import 'package:flutter/material.dart';

import '../../core/repositories/paginated_result.dart';
import '../../theme/spacing.dart';

/// Simple prev/next pagination controls for paginated repository lists.
class AksharaPaginationBar<T> extends StatelessWidget {
  const AksharaPaginationBar({
    super.key,
    required this.result,
    required this.onPageChanged,
  });

  final PaginatedResult<T> result;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    if (result.total == 0) {
      return const SizedBox.shrink();
    }

    final start = ((result.page - 1) * result.pageSize) + 1;
    final end = start + result.items.length - 1;
    final canGoBack = result.page > 1;
    final canGoForward = result.hasMore;

    return Padding(
      padding: const EdgeInsets.only(top: AksharaSpacing.s3),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AksharaSpacing.s2,
        runSpacing: AksharaSpacing.s2,
        children: [
          Text('Showing $start–$end of ${result.total}'),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Previous page',
                onPressed:
                    canGoBack ? () => onPageChanged(result.page - 1) : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Text('Page ${result.page}'),
              IconButton(
                tooltip: 'Next page',
                onPressed:
                    canGoForward ? () => onPageChanged(result.page + 1) : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
