import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/async/erp_async_state.dart';
import '../../shared/widgets/widgets.dart';
import '../../theme/spacing.dart';
import '../copilot/copilot_context_provider.dart';
import 'director_models.dart';
import 'director_navigation.dart';
import 'director_providers.dart';
import 'widgets/director_module_scaffold.dart';
import 'widgets/director_shared_widgets.dart';

class DirectorMarketingScreen extends ConsumerWidget {
  const DirectorMarketingScreen({super.key});

  static const _filters = ['All Channels', 'Quarter', 'Top / Bottom Schools'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(directorMarketingProvider);
    return CopilotContextScope(
      module: 'director',
      screen: 'Director Marketing Performance',
      child: DirectorModuleScaffold(
        screen: DirectorScreen.marketing,
        filters: _filters,
        filterTrailing: const DirectorAiAssistantLink(
          screenLabel: 'Director Marketing Performance',
        ),
        body: ErpAsyncBody<DirectorMarketingSnapshot>(
          state: resolveErpAsync(state, isDataEmpty: (_) => false),
          loadingLabel: 'Loading',
          emptyMessage: 'No marketing data available.',
          onRetry: () => ref.invalidate(directorMarketingProvider),
          builder: (marketing) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: AksharaSpacing.s3,
                runSpacing: AksharaSpacing.s3,
                children: [
                  DirectorMetricTile(
                    label: 'Total Spend',
                    value: '${marketing.totalSpendLakhs.toStringAsFixed(1)} L',
                  ),
                  DirectorMetricTile(
                    label: 'Leads',
                    value: '${marketing.totalLeads}',
                  ),
                  DirectorMetricTile(
                    label: 'CPL',
                    value: 'Rs ${marketing.cplInr}',
                  ),
                  DirectorMetricTile(
                    label: 'ROI',
                    value: '${marketing.roiPercent}%',
                  ),
                ],
              ),
              const SizedBox(height: AksharaSpacing.s4),
              const AksharaSectionHeader(title: 'Channel performance'),
              const SizedBox(height: AksharaSpacing.s2),
              for (final channel in marketing.channelPerformance.entries)
                ListTile(
                  dense: true,
                  title: Text(channel.key),
                  trailing: Text('${channel.value.toStringAsFixed(0)}%'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
