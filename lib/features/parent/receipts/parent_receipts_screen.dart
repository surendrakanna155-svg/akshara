import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import 'parent_receipts_provider.dart';
import 'receipt_models.dart';
import 'widgets/receipt_filter_bar.dart';
import 'widgets/receipt_list_row.dart';

/// Parent fee receipts list — PA-11.
class ParentReceiptsScreen extends ConsumerWidget {
  const ParentReceiptsScreen({
    super.key,
    this.onNotificationsTap,
    this.onReceiptTap,
  });

  final VoidCallback? onNotificationsTap;
  final void Function(FeeReceipt receipt)? onReceiptTap;

  static const double _tabletBreakpoint = 768;
  static const double _tabletMaxContentWidth = 480;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(parentReceiptsDataProvider);
    final filter = ref.watch(parentReceiptFilterProvider);
    final search = ref.watch(parentReceiptSearchProvider);
    final isLoading = ref.watch(parentReceiptsLoadingProvider);
    final hasError = ref.watch(parentReceiptsErrorProvider);

    return Scaffold(
      backgroundColor: context.colors.surfaceContainerLow,
      appBar: AksharaAppBar(
        titleText: 'Receipts',
        subtitle: '${data.childName} · ${data.childClass}',
        unreadNotifications: data.unreadNotifications,
        trailingPadding: true,
        onNotificationsTap: onNotificationsTap,
      ),
      body: isLoading
          ? const AksharaLoadingState(semanticLabel: 'Loading receipts')
          : hasError
              ? AksharaErrorState(
                  message: 'Unable to load receipts right now.',
                  onRetry: () => ref
                      .read(parentReceiptsErrorProvider.notifier)
                      .state = false,
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final isTablet =
                        constraints.maxWidth >= _tabletBreakpoint;
                    final horizontalPadding = isTablet
                        ? AksharaSpacing.tabletMargin
                        : AksharaSpacing.mobileMargin;

                    return Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: isTablet
                              ? _tabletMaxContentWidth
                              : double.infinity,
                        ),
                        child: Column(
                          children: [
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                horizontalPadding,
                                AksharaSpacing.s4,
                                horizontalPadding,
                                AksharaSpacing.s2,
                              ),
                              child: Semantics(
                                label: 'Search receipts',
                                child: SearchBar(
                                  hintText: 'Search by title or receipt no.',
                                  leading: const Icon(Icons.search),
                                  onChanged: (value) => ref
                                      .read(
                                        parentReceiptSearchProvider.notifier,
                                      )
                                      .state = value,
                                  padding: const WidgetStatePropertyAll(
                                    EdgeInsets.symmetric(
                                      horizontal: AksharaSpacing.s3,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: horizontalPadding,
                              ),
                              child: ReceiptFilterBar(
                                selectedFilter: filter,
                                onFilterChanged: (value) => ref
                                    .read(parentReceiptFilterProvider.notifier)
                                    .state = value,
                              ),
                            ),
                            const SizedBox(height: AksharaSpacing.s3),
                            Expanded(
                              child: data.receipts.isEmpty
                                  ? AksharaEmptyState(
                                      message: search.isEmpty
                                          ? 'No receipts available yet.'
                                          : 'No receipts match your search.',
                                      icon: Icons.receipt_long_outlined,
                                      compact: true,
                                    )
                                  : Material(
                                      color: context.colors.surface,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          AksharaSpacing.s2,
                                        ),
                                        side: BorderSide(
                                          color:
                                              context.colors.outlineVariant,
                                        ),
                                      ),
                                      child: ListView.builder(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: horizontalPadding,
                                        ),
                                        itemCount: data.receipts.length,
                                        itemBuilder: (context, index) {
                                          final receipt =
                                              data.receipts[index];
                                          return ReceiptListRow(
                                            receipt: receipt,
                                            showDivider:
                                                index < data.receipts.length - 1,
                                            onTap: onReceiptTap == null
                                                ? null
                                                : () => onReceiptTap!(receipt),
                                          );
                                        },
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
