import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/repositories/paginated_result.dart';
import 'akshara_pagination_bar.dart';

/// Standard footer for paginated ERP list screens.
class AksharaPaginatedListFooter<T> extends ConsumerWidget {
  const AksharaPaginatedListFooter({
    super.key,
    required this.result,
    required this.pageProvider,
  });

  final PaginatedResult<T>? result;
  final StateProvider<int> pageProvider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (result == null) return const SizedBox.shrink();
    return AksharaPaginationBar<T>(
      result: result!,
      onPageChanged: (page) => ref.read(pageProvider.notifier).state = page,
    );
  }
}
