import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/security/permissions.dart';
import '../../router/route_guards.dart';

/// Wraps mutation actions (buttons, FABs) with [ManagePermissionGuard].
class AksharaManageAction extends ConsumerWidget {
  const AksharaManageAction({
    super.key,
    required this.permission,
    required this.child,
    this.auditRoute,
  });

  final Permission permission;
  final Widget child;
  final String? auditRoute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ManagePermissionGuard(
      permission: permission,
      auditRoute: auditRoute,
      fallback: const SizedBox.shrink(),
      child: child,
    );
  }
}
