import 'package:flutter/material.dart';

import '../approval/principal_approval_center_screen.dart';

/// MG-07 — Tasks & Approvals (delegates to unified Principal Approval Center).
class ManagementTasksScreen extends StatelessWidget {
  const ManagementTasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PrincipalApprovalCenterScreen();
  }
}
