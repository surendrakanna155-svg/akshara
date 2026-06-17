import 'package:flutter_riverpod/flutter_riverpod.dart';

/// When true (default), procurement orders require principal approval.
/// Rollback: `--dart-define=INVENTORY_PO_AUTO_APPROVE=true`
final inventoryPoApprovalRequiredProvider = Provider<bool>(
  (ref) => !const bool.fromEnvironment(
    'INVENTORY_PO_AUTO_APPROVE',
    defaultValue: false,
  ),
);
