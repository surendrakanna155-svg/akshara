import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/industry/industry_context_provider.dart';
import '../../core/industry/industry_type.dart';
import '../../core/testing/qa_test_keys.dart';
import '../../router/route_names.dart';
import 'industry_mutations_provider.dart';
import 'industry_providers.dart';
import '../../theme/spacing.dart';

class IndustryHubScreen extends ConsumerWidget {
  const IndustryHubScreen({super.key, this.showFramework = false});

  final bool showFramework;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(industryDynamicPackSyncProvider);

    if (!ref.watch(industryCanViewProvider)) {
      return const Scaffold(
        body: Center(child: Text('Industry framework permission required.')),
      );
    }

    final activeIndustry = ref.watch(activeIndustryProvider);
    final capability = ref.watch(activeIndustryCapabilityProvider);
    final modules = ref.watch(industryModuleStatusProvider);

    return Scaffold(
      key: QaTestKeys.industryHubScreen,
      appBar: AppBar(
        title: Text(showFramework ? 'Industry Framework' : 'Industry'),
        actions: [
          TextButton(
            key: QaTestKeys.industryFrameworkLink,
            onPressed: () => context.go(RouteNames.industryFramework),
            child: const Text('Framework'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AksharaSpacing.s6),
        children: [
          Text(
            'Active: ${activeIndustry.label}',
            key: QaTestKeys.industryActiveLabel,
          ),
          const SizedBox(height: 8),
          Text('Widget pack: ${capability.widgetPack}'),
          Text('Copilot key: ${capability.copilotContextKey}'),
          const SizedBox(height: 24),
          const Text('Select industry', style: TextStyle(fontWeight: FontWeight.bold)),
          Wrap(
            spacing: 8,
            children: IndustryType.values.map((industry) {
              return ChoiceChip(
                key: QaTestKeys.industryTypeChip(industry.value),
                label: Text(industry.label),
                selected: industry == activeIndustry,
                onSelected: (_) {
                  ref.read(setActiveIndustryProvider.notifier).execute(
                        industry: industry,
                      );
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          const Text('Module activation', style: TextStyle(fontWeight: FontWeight.bold)),
          ...modules.map(
            (module) => SwitchListTile(
              key: QaTestKeys.industryModuleToggle(module.moduleId),
              title: Text(module.label),
              value: module.isActive,
              onChanged: (value) {
                ref.read(activateIndustryModuleProvider.notifier).execute(
                      moduleId: module.moduleId,
                      isActive: value,
                    );
              },
            ),
          ),
          if (showFramework) ...[
            const SizedBox(height: 24),
            const Text('Capability registry', style: TextStyle(fontWeight: FontWeight.bold)),
            ...ref.watch(industryCapabilitiesProvider).map(
                  (cap) => ListTile(
                    key: QaTestKeys.industryCapabilityTile(cap.industry.value),
                    title: Text(cap.industry.label),
                    subtitle: Text(cap.modules.join(', ')),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}
