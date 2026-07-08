import 'package:akshara_erp/core/approvals/approval_models.dart';
import 'package:akshara_erp/core/approvals/approval_request_type.dart';
import 'package:akshara_erp/core/approvals/approval_status.dart';
import 'package:akshara_erp/core/testing/qa_test_keys.dart';
import 'package:akshara_erp/features/management/approval/approval_center_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'approval_center_test_helpers.dart';

/// P2-UX-2 §2.3 — Approval Center polish: the maker-checker badge + disabled
/// Approve are driven purely by the SERVER `sodBlocked` flag (no client SoD
/// derivation); the summary is an on-card fact; the queue groups by type.
ApprovalRequest _req({
  required String id,
  required ApprovalRequestType type,
  required String title,
  required String summary,
  bool sodBlocked = false,
}) {
  return ApprovalRequest(
    id: id,
    type: type,
    status: ApprovalStatus.pending,
    title: title,
    summary: summary,
    requesterId: 'user_maker',
    requesterName: 'Ravi Maker',
    entityType: 'entity',
    entityId: 'e_$id',
    createdAt: DateTime.utc(2026, 6, 12),
    sodBlocked: sodBlocked,
  );
}

void main() {
  final items = [
    _req(
      id: 'appr_po',
      type: ApprovalRequestType.inventoryPo,
      title: 'Purchase order — whiteboards',
      summary: '5 whiteboards — ₹12,000',
      sodBlocked: true,
    ),
    _req(
      id: 'appr_leave',
      type: ApprovalRequestType.studentLeave,
      title: 'Student leave — Aarav',
      summary: 'Medical leave · 2 days',
    ),
  ];

  testWidgets('server sodBlocked → badge shows + Approve is disabled',
      (tester) async {
    await pumpApprovalCenter(
      tester,
      extraOverrides: [
        approvalCenterListProvider.overrideWithValue(items),
      ],
    );

    // The maker-checker badge renders for the self-raised money request only.
    expect(
      find.byKey(QaTestKeys.approvalMakerCheckerBadge('appr_po')),
      findsOneWidget,
    );
    expect(
      find.byKey(QaTestKeys.approvalMakerCheckerBadge('appr_leave')),
      findsNothing,
    );

    // The on-card decision fact (summary) is present.
    expect(find.textContaining('5 whiteboards'), findsWidgets);

    // Approve is disabled for the SoD-blocked request; the other stays enabled.
    final blockedApprove = tester.widget<FilledButton>(
      find.byKey(QaTestKeys.approvalApproveButton('appr_po')),
    );
    expect(blockedApprove.onPressed, isNull);
    final okApprove = tester.widget<FilledButton>(
      find.byKey(QaTestKeys.approvalApproveButton('appr_leave')),
    );
    expect(okApprove.onPressed, isNotNull);
  });

  testWidgets('the mobile queue groups requests by type', (tester) async {
    await pumpApprovalCenter(
      tester,
      viewport: const Size(390, 844),
      extraOverrides: [
        approvalCenterListProvider.overrideWithValue(items),
      ],
    );

    // A per-type section header for each represented type.
    expect(
      find.byKey(QaTestKeys.approvalGroupHeader('inventoryPo')),
      findsOneWidget,
    );
    expect(
      find.byKey(QaTestKeys.approvalGroupHeader('studentLeave')),
      findsOneWidget,
    );
  });
}
