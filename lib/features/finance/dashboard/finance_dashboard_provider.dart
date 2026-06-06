import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../finance_models.dart';

final financeDashboardLoadingProvider = StateProvider<bool>((ref) => false);
final financeDashboardErrorProvider = StateProvider<bool>((ref) => false);
final financeDashboardEmptyProvider = StateProvider<bool>((ref) => false);
final financeDashboardFilterProvider = StateProvider<int>((ref) => 0);

final financeDashboardProvider = Provider<FinanceDashboardData?>((ref) {
  if (ref.watch(financeDashboardLoadingProvider)) return null;
  if (ref.watch(financeDashboardErrorProvider)) return null;
  if (ref.watch(financeDashboardEmptyProvider)) return null;
  return _mockDashboard();
});

FinanceDashboardData _mockDashboard() {
  return const FinanceDashboardData(
    outstandingAmount: '₹18.6L',
    defaultersCount: 47,
    kpis: [
      FinanceKpi(
        id: 'collected_mtd',
        value: '₹42.0L',
        label: 'Fee Collected (MTD)',
        icon: Icons.payments_outlined,
        accentName: 'success',
        detail: '+12% vs last month',
      ),
      FinanceKpi(
        id: 'outstanding',
        value: '₹18.6L',
        label: 'Outstanding',
        icon: Icons.pending_actions_outlined,
        accentName: 'warning',
      ),
      FinanceKpi(
        id: 'defaulters',
        value: '47',
        label: 'Defaulters',
        icon: Icons.warning_amber_outlined,
        accentName: 'error',
        detail: '12 critical',
      ),
      FinanceKpi(
        id: 'collection_rate',
        value: '68%',
        label: 'Collection Rate',
        icon: Icons.trending_up,
        accentName: 'primary',
      ),
      FinanceKpi(
        id: 'today',
        value: '₹2.4L',
        label: 'Collected Today',
        icon: Icons.today_outlined,
        accentName: 'success',
      ),
      FinanceKpi(
        id: 'pending_handoffs',
        value: '2',
        label: 'Admissions Handoffs',
        icon: Icons.swap_horiz_outlined,
        accentName: 'neutral',
      ),
    ],
    collectionTrend: [
      CollectionTrendPoint(label: 'Jan', amountLakhs: 6.2, targetLakhs: 7.0),
      CollectionTrendPoint(label: 'Feb', amountLakhs: 7.8, targetLakhs: 7.0),
      CollectionTrendPoint(label: 'Mar', amountLakhs: 8.4, targetLakhs: 8.0),
      CollectionTrendPoint(label: 'Apr', amountLakhs: 9.1, targetLakhs: 8.5),
      CollectionTrendPoint(label: 'May', amountLakhs: 10.5, targetLakhs: 9.0),
      CollectionTrendPoint(label: 'Jun', amountLakhs: 11.2, targetLakhs: 10.0),
    ],
    recentPayments: [
      RecentPayment(
        id: 'pay_1',
        studentName: 'Arjun Patel',
        admissionNumber: 'ADM-2026-0138',
        amount: '₹62,000',
        mode: 'UPI',
        receiptNumber: 'RCP-2026-8841',
        collectedAt: 'Today, 10:42',
        status: CollectionStatus.completed,
      ),
      RecentPayment(
        id: 'pay_2',
        studentName: 'Priya Sharma',
        admissionNumber: 'ADM-2025-0092',
        amount: '₹45,000',
        mode: 'Cash',
        receiptNumber: 'RCP-2026-8840',
        collectedAt: 'Today, 09:15',
        status: CollectionStatus.completed,
      ),
      RecentPayment(
        id: 'pay_3',
        studentName: 'Rohan Mehta',
        admissionNumber: 'ADM-2025-0114',
        amount: '₹38,500',
        mode: 'Card',
        receiptNumber: 'RCP-2026-8839',
        collectedAt: 'Yesterday',
        status: CollectionStatus.completed,
      ),
      RecentPayment(
        id: 'pay_4',
        studentName: 'Ananya Reddy',
        admissionNumber: 'ADM-2026-0142',
        amount: '₹71,500',
        mode: 'UPI',
        receiptNumber: 'RCP-2026-8838',
        collectedAt: 'Yesterday',
        status: CollectionStatus.pending,
      ),
      RecentPayment(
        id: 'pay_5',
        studentName: 'Emma Thomas',
        admissionNumber: 'ADM-2026-0135',
        amount: '₹85,000',
        mode: 'Bank Transfer',
        receiptNumber: 'RCP-2026-8837',
        collectedAt: '2 days ago',
        status: CollectionStatus.completed,
      ),
    ],
    aiInsight:
        'Collection rate dropped 4% in Class 8 this week. 12 students have overdue installments exceeding 30 days — consider sending reminders before the term-end deadline.',
  );
}
