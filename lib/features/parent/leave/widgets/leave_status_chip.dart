import 'package:flutter/material.dart';

import '../../../../shared/widgets/akshara_status_chip.dart';
import '../../../../theme/theme_extensions.dart';
import '../leave_models.dart';

/// Maps [LeaveStatus] to shared [AksharaStatusChip] tones.
class LeaveStatusChip extends StatelessWidget {
  const LeaveStatusChip({
    super.key,
    required this.status,
  });

  final LeaveStatus status;

  @override
  Widget build(BuildContext context) {
    final tone = switch (status) {
      LeaveStatus.pending => KpiAccent.warning,
      LeaveStatus.approved => KpiAccent.success,
      LeaveStatus.rejected => KpiAccent.error,
      LeaveStatus.cancelled => KpiAccent.primary,
    };

    return AksharaStatusChip(
      label: status.label,
      tone: tone,
      size: AksharaStatusChipSize.compact,
    );
  }
}
