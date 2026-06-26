import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_failure_mapper.dart';
import '../../../core/testing/qa_test_keys.dart';
import '../../../shared/widgets/widgets.dart';
import 'white_label_mutations_provider.dart';
import 'white_label_providers.dart';

class LogoManagementScreen extends ConsumerWidget {
  const LogoManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logos = ref.watch(logoAssetsProvider);
    return Scaffold(
      key: QaTestKeys.whiteLabelLogoScreen,
      appBar: AppBar(title: const Text('Logo Management')),
      body: logos.when(
        data: (list) => ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, index) {
            final logo = list[index];
            return ListTile(
              key: QaTestKeys.whiteLabelLogoTile(logo.id),
              title: Text(logo.label),
              subtitle: Text(logo.variant),
            );
          },
        ),
        loading: () => const AksharaLoadingState(),
        error: (e, _) => AksharaErrorState.fromFailure(
          apiFailureMapper.fromException(e),
          onRetry: () => ref.invalidate(logoAssetsProvider),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        key: QaTestKeys.whiteLabelUploadLogoButton,
        onPressed: () {
          ref.read(uploadLogoProvider.notifier).execute(
                label: 'Uploaded Logo',
                variant: 'primary',
              );
        },
        child: const Icon(Icons.upload),
      ),
    );
  }
}
