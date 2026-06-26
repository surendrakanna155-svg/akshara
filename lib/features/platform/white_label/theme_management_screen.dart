import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure_mapper.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../theme/theme_extensions.dart';
import 'white_label_mutations_provider.dart';
import 'white_label_providers.dart';

class ThemeManagementScreen extends ConsumerWidget {
  const ThemeManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themes = ref.watch(themeConfigsProvider);
    return Scaffold(
      key: QaTestKeys.whiteLabelThemeScreen,
      appBar: AppBar(title: const Text('Theme Management')),
      body: themes.when(
        data: (list) => ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, index) {
            final theme = list[index];
            return ListTile(
              key: QaTestKeys.whiteLabelThemeTile(theme.id),
              title: Text(theme.name),
              subtitle: Text(theme.mode),
              trailing: theme.isActive
                  ? Icon(Icons.check_circle, color: context.akshara.success)
                  : TextButton(
                      key: QaTestKeys.whiteLabelApplyThemeButton(theme.id),
                      onPressed: () {
                        ref.read(applyThemeProvider.notifier).execute(
                              themeId: theme.id,
                            );
                      },
                      child: const Text('Apply'),
                    ),
            );
          },
        ),
        loading: () => const AksharaLoadingState(),
        error: (e, _) => AksharaErrorState.fromFailure(
          apiFailureMapper.fromException(e),
          onRetry: () => ref.invalidate(themeConfigsProvider),
        ),
      ),
    );
  }
}
