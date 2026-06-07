import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/paginated_result.dart';

import '../../../shared/widgets/widgets.dart';
import '../../../theme/spacing.dart';
import '../../../theme/theme_extensions.dart';
import '../control_center_models.dart';
import '../control_center_providers.dart';
import '../widgets/control_center_module_scaffold.dart';

/// ACC-08 — White Label Manager.
class ControlCenterWhiteLabelScreen extends ConsumerWidget {
  const ControlCenterWhiteLabelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(controlCenterWhiteLabelLoadingProvider);
    final isError = ref.watch(controlCenterWhiteLabelErrorProvider);
    final configs = ref.watch(controlCenterWhiteLabelProvider);
    final pageResult = ref.watch(controlCenterWhiteLabelPageResultProvider);

    return ControlCenterModuleScaffold(
      screen: ControlCenterScreen.whiteLabel,
      showFilterBar: false,
      body: _buildBody(
        context,
        isLoading: isLoading,
        isError: isError,
        configs: configs,
        pageResult: pageResult,
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required bool isLoading,
    required bool isError,
    required List<WhiteLabelConfig>? configs,
    required PaginatedResult<WhiteLabelConfig>? pageResult,
  }) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AksharaSpacing.s12),
        child: AksharaLoadingState(
          semanticLabel: 'Loading white label configs',
        ),
      );
    }

    if (isError) {
      return const AksharaErrorState(
        message: 'Unable to load white label configurations.',
      );
    }

    if (configs == null || configs.isEmpty) {
      return const AksharaErrorState(
        message: 'No white label configurations found.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AksharaSectionHeader(title: 'White label configurations'),
        const SizedBox(height: AksharaSpacing.s3),
        for (final config in configs) ...[
          _WhiteLabelCard(config: config),
          const SizedBox(height: AksharaSpacing.s4),
        ],
        AksharaPaginatedListFooter<WhiteLabelConfig>(
          result: pageResult,
          pageProvider: controlCenterWhiteLabelPageProvider,
        ),
      ],
    );
  }
}

class _WhiteLabelCard extends StatelessWidget {
  const _WhiteLabelCard({required this.config});

  final WhiteLabelConfig config;

  @override
  Widget build(BuildContext context) {
    final text = context.aksharaText;
    final colors = context.colors;

    return Semantics(
      container: true,
      label: 'White label for ${config.schoolName}',
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(AksharaSpacing.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(config.schoolName, style: text.titleMedium),
                  ),
                  AksharaStatusChip(
                    label: config.isPublished ? 'Published' : 'Draft',
                    tone: config.isPublished
                        ? KpiAccent.success
                        : KpiAccent.warning,
                    semanticLabel: config.isPublished
                        ? 'Published'
                        : 'Draft',
                  ),
                ],
              ),
              const SizedBox(height: AksharaSpacing.s3),
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Color(
                        int.parse(
                          config.primaryColorHex.replaceFirst('#', '0xFF'),
                        ),
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: AksharaSpacing.s3),
                  Expanded(
                    child: Text(
                      'Primary ${config.primaryColorHex} · ${config.customDomain}',
                      style: text.bodyMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AksharaSpacing.s2),
              Text(
                'Logo: ${config.logoUrl} · Login BG: ${config.loginBackgroundUrl}',
                style: text.bodySmall.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
