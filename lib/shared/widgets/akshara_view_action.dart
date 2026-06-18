import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/security/permissions.dart';
import '../../router/route_guards.dart';

/// Wraps read-only actions with [PermissionGuard] (view permissions).
class AksharaViewAction extends ConsumerWidget {
  const AksharaViewAction({
    super.key,
    required this.permission,
    required this.child,
  });

  final Permission permission;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PermissionGuard(
      permission: permission,
      fallback: const SizedBox.shrink(),
      child: child,
    );
  }
}
