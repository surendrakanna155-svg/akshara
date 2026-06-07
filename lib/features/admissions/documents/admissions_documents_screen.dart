import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/akshara_kpi_card.dart';
import '../../../shared/widgets/akshara_warning_banner.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../../admin/admin_layout.dart';
import '../../../core/repositories/paginated_result.dart';
import '../admissions_async_state.dart';
import '../admissions_models.dart';
import '../admissions_workflow_actions.dart';
import '../admissions_navigation.dart';
import '../widgets/admissions_module_scaffold.dart';
import '../widgets/admissions_responsive_grid.dart';
import 'admissions_documents_provider.dart';
import 'widgets/admissions_document_checklist.dart';
import 'widgets/admissions_documents_table.dart';

/// AD-06 — Document Verification with checklist and approval workflow.
class AdmissionsDocumentsScreen extends ConsumerWidget {
  const AdmissionsDocumentsScreen({super.key});

  static const List<String> filterLabels = [
    'All types',
    'All statuses',
    'All classes',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewState = ref.watch(admissionsDocumentsViewStateProvider);
    final summary = ref.watch(admissionsDocumentSummaryProvider);
    final selectedId = ref.watch(admissionsSelectedDocumentIdProvider);
    final filterIndex = ref.watch(admissionsDocumentsFilterProvider);
    final isMobile = AdminLayout.isMobile(context);

    return AdmissionsModuleScaffold(
      screen: AdmissionsScreen.documents,
      filters: filterLabels,
      selectedFilterIndex: filterIndex,
      onFilterSelected: (index) =>
          ref.read(admissionsDocumentsFilterProvider.notifier).state = index,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (summary.missing > 0)
            AksharaWarningBanner(
              message:
                  '${summary.missing} required document(s) missing across active applications.',
              actionLabel: 'View missing',
              onAction: () {},
              compactMessage: true,
              horizontalPaddingOnly: true,
              semanticLabel: '${summary.missing} documents missing',
            ),
          if (summary.missing > 0) const SizedBox(height: AksharaSpacing.s4),
          AdmissionsAsyncBody<PaginatedResult<StudentDocumentRecord>>(
            state: viewState,
            loadingLabel: 'Loading document verification',
            emptyMessage: 'No documents to verify.',
            emptyIcon: Icons.folder_off_outlined,
            onRetry: () => retryAdmissionsFuture(
              ref,
              admissionsDocumentsFutureProvider,
            ),
            builder: (result) {
              final documents = result.items;
              final selected = documents.cast<StudentDocumentRecord?>().firstWhere(
                    (doc) => doc?.id == selectedId,
                    orElse: () => documents.isEmpty ? null : documents.first,
                  );
              final selectedDocumentId = selected?.id;
              final checklist = ref.watch(
                admissionsDocumentChecklistProvider(selected?.leadId),
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
            AdmissionsResponsiveGrid(
              desktopColumns: 4,
              tabletColumns: 2,
              mobileColumns: 2,
              children: [
                SizedBox(
                  height: 120,
                  child: AksharaKpiCard(
                    value: '${summary.pending}',
                    subtitle: 'Pending',
                    accent: KpiAccent.warning,
                    style: AksharaKpiCardStyle.filled,
                    icon: Icons.hourglass_top_outlined,
                  ),
                ),
                SizedBox(
                  height: 120,
                  child: AksharaKpiCard(
                    value: '${summary.verified}',
                    subtitle: 'Verified',
                    accent: KpiAccent.success,
                    style: AksharaKpiCardStyle.filled,
                    icon: Icons.verified_outlined,
                  ),
                ),
                SizedBox(
                  height: 120,
                  child: AksharaKpiCard(
                    value: '${summary.rejected}',
                    subtitle: 'Rejected',
                    accent: KpiAccent.error,
                    style: AksharaKpiCardStyle.filled,
                    icon: Icons.cancel_outlined,
                  ),
                ),
                SizedBox(
                  height: 120,
                  child: AksharaKpiCard(
                    value: '${summary.missing}',
                    subtitle: 'Missing',
                    accent: KpiAccent.error,
                    style: AksharaKpiCardStyle.filled,
                    icon: Icons.warning_amber_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AksharaSpacing.s6),
            if (isMobile) ...[
              AdmissionsDocumentsTable(
                documents: documents,
                selectedId: selectedId,
                onSelect: (doc) => ref
                    .read(admissionsSelectedDocumentIdProvider.notifier)
                    .state = doc.id,
                onVerify: (_) {},
              ),
              const SizedBox(height: AksharaSpacing.s4),
              if (checklist.isNotEmpty)
                AdmissionsDocumentChecklist(
                  items: checklist,
                  onApprove: selectedDocumentId == null
                      ? null
                      : () => runApproveDocument(
                            context,
                            ref,
                            selectedDocumentId,
                          ),
                  onReject: selectedDocumentId == null
                      ? null
                      : () => runRejectDocument(
                            context,
                            ref,
                            selectedDocumentId,
                          ),
                ),
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: AdmissionsDocumentsTable(
                      documents: documents,
                      selectedId: selectedId,
                      onSelect: (doc) => ref
                          .read(admissionsSelectedDocumentIdProvider.notifier)
                          .state = doc.id,
                      onVerify: (_) {},
                    ),
                  ),
                  const SizedBox(width: AksharaSpacing.s4),
                  Expanded(
                    flex: 2,
                    child: checklist.isEmpty
                        ? const SizedBox.shrink()
                        : AdmissionsDocumentChecklist(
                            items: checklist,
                            onApprove: selectedDocumentId == null
                                ? null
                                : () => runApproveDocument(
                                      context,
                                      ref,
                                      selectedDocumentId,
                                    ),
                            onReject: selectedDocumentId == null
                                ? null
                                : () => runRejectDocument(
                                      context,
                                      ref,
                                      selectedDocumentId,
                                    ),
                          ),
                  ),
                ],
              ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
