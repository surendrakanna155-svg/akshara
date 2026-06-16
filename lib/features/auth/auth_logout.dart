import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/environment_provider.dart';
import '../../router/route_names.dart';
import '../../core/testing/qa_test_keys.dart';
import 'auth_provider.dart';

/// Shows a confirmation dialog, clears the session, and returns to login.
Future<void> confirmAndLogout(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Log out?'),
      content: const Text(
        'You will need to sign in again to access your account.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: QaTestKeys.logoutConfirmButton,
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Log out'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) {
    return;
  }

  await ref.read(authProvider.notifier).logout();
  if (!context.mounted) {
    return;
  }

  final qaLoginEnabled = ref.read(isQaLoginEnabledProvider);
  context.go(qaLoginEnabled ? RouteNames.qaLogin : RouteNames.login);
}
