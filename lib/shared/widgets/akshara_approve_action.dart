import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/security/permissions.dart';
import '../../router/route_guards.dart';

/// Wraps approve actions with [ApprovePermissionGuard].
class AksharaApproveAction extends ConsumerWidget {
  const AksharaApproveAction({
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
    return ApprovePermissionGuard(
      permission: permission,
      auditRoute: auditRoute,
      fallback: const SizedBox.shrink(),
      child: child,
    );
  }
}
