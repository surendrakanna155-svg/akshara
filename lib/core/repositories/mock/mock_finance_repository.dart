import 'package:flutter/material.dart';

import '../../../features/finance/finance_models.dart';
import '../../../router/route_names.dart';
import '../interfaces/finance_repository.dart';

/// In-memory finance data for MVP and Phase 2 screens.
class MockFinanceRepository implements FinanceRepository {
  @override
  FinanceDashboardData getDashboard() {
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

  @override
  List<CollectionPayment> getCollections() => _payments;

  @override
  DailyCollectionSummary getDailySummary() {
    return const DailyCollectionSummary(
      dateLabel: 'Today, 5 Jun 2026',
      totalCollected: '₹2,41,500',
      transactionCount: 18,
      cashAmount: '₹45,000',
      upiAmount: '₹1,96,500',
      pendingReconciliation: 2,
    );
  }

  @override
  List<FinanceFeeStructure> getFeeStructures(String year) {
    return [
      FinanceFeeStructure(
        id: 'fee_std',
        name: 'Standard CBSE',
        academicYear: year,
        totalAnnual: '₹1,85,000',
        classRange: 'Nursery – 12',
        status: FeeStructureStatus.active,
        installmentOptions: const [3, 4],
        categories: const [
          FeeCategoryLine(
            category: FeeStructureCategory.tuition,
            label: 'Tuition',
            amount: '₹1,45,000',
          ),
          FeeCategoryLine(
            category: FeeStructureCategory.activity,
            label: 'Activity & Labs',
            amount: '₹40,000',
          ),
        ],
      ),
      FinanceFeeStructure(
        id: 'fee_premium',
        name: 'Premium + Transport',
        academicYear: year,
        totalAnnual: '₹2,15,000',
        classRange: '1 – 12',
        status: FeeStructureStatus.active,
        installmentOptions: const [3, 4],
        categories: const [
          FeeCategoryLine(
            category: FeeStructureCategory.tuition,
            label: 'Tuition',
            amount: '₹1,55,000',
          ),
          FeeCategoryLine(
            category: FeeStructureCategory.transport,
            label: 'Transport',
            amount: '₹30,000',
          ),
          FeeCategoryLine(
            category: FeeStructureCategory.activity,
            label: 'Activity',
            amount: '₹30,000',
          ),
        ],
      ),
      FinanceFeeStructure(
        id: 'fee_hostel',
        name: 'Boarding Package',
        academicYear: year,
        totalAnnual: '₹3,40,000',
        classRange: '5 – 12',
        status: FeeStructureStatus.active,
        installmentOptions: const [4, 6],
        categories: const [
          FeeCategoryLine(
            category: FeeStructureCategory.tuition,
            label: 'Tuition',
            amount: '₹1,80,000',
          ),
          FeeCategoryLine(
            category: FeeStructureCategory.hostel,
            label: 'Hostel',
            amount: '₹1,20,000',
          ),
          FeeCategoryLine(
            category: FeeStructureCategory.transport,
            label: 'Transport',
            amount: '₹25,000',
          ),
          FeeCategoryLine(
            category: FeeStructureCategory.activity,
            label: 'Activity',
            amount: '₹15,000',
          ),
        ],
      ),
      const FinanceFeeStructure(
        id: 'fee_legacy',
        name: 'Legacy 2024 Plan',
        academicYear: '2024-25',
        totalAnnual: '₹1,65,000',
        classRange: 'Nursery – 12',
        status: FeeStructureStatus.inactive,
        installmentOptions: [3],
        categories: [
          FeeCategoryLine(
            category: FeeStructureCategory.tuition,
            label: 'Tuition',
            amount: '₹1,65,000',
          ),
        ],
      ),
    ]
        .where(
          (s) =>
              s.academicYear == year || s.status == FeeStructureStatus.inactive,
        )
        .toList();
  }

  @override
  List<String> getAcademicYears() => const ['2026-27', '2025-26', '2024-25'];

  @override
  List<StudentFeeAccount> getStudentAccounts() => const [
        StudentFeeAccount(
          id: 'acct_1',
          studentName: 'Arjun Patel',
          admissionNumber: 'ADM-2026-0138',
          classLabel: '10',
          feeStructureName: 'Standard CBSE',
          totalDue: '₹1,85,000',
          totalPaid: '₹62,000',
          balance: '₹1,23,000',
          status: FeeAccountStatus.active,
          lastPaymentDate: 'Today',
          installmentPlan: '3-term quarterly',
        ),
        StudentFeeAccount(
          id: 'acct_2',
          studentName: 'Ananya Reddy',
          admissionNumber: 'ADM-2026-0142',
          classLabel: '5',
          feeStructureName: 'Premium + Transport',
          totalDue: '₹2,15,000',
          totalPaid: '₹0',
          balance: '₹2,15,000',
          status: FeeAccountStatus.pending,
          lastPaymentDate: '—',
          installmentPlan: '3-term quarterly',
        ),
        StudentFeeAccount(
          id: 'acct_3',
          studentName: 'Emma Thomas',
          admissionNumber: 'ADM-2026-0135',
          classLabel: '7',
          feeStructureName: 'Boarding Package',
          totalDue: '₹3,40,000',
          totalPaid: '₹85,000',
          balance: '₹2,55,000',
          status: FeeAccountStatus.active,
          lastPaymentDate: '2 days ago',
          installmentPlan: '4-term termly',
        ),
        StudentFeeAccount(
          id: 'acct_4',
          studentName: 'Priya Sharma',
          admissionNumber: 'ADM-2025-0092',
          classLabel: '8',
          feeStructureName: 'Standard CBSE',
          totalDue: '₹1,85,000',
          totalPaid: '₹1,20,000',
          balance: '₹65,000',
          status: FeeAccountStatus.overdue,
          lastPaymentDate: '45 days ago',
          installmentPlan: '3-term quarterly',
        ),
      ];

  @override
  List<InstallmentPlan> getInstallmentPlans() => const [
        InstallmentPlan(
          id: 'plan_quarterly',
          label: '3-term quarterly',
          installmentCount: 3,
          type: InstallmentPlanType.quarterly,
        ),
        InstallmentPlan(
          id: 'plan_termly',
          label: '4-term termly',
          installmentCount: 4,
          type: InstallmentPlanType.termly,
        ),
        InstallmentPlan(
          id: 'plan_monthly',
          label: '10-month monthly',
          installmentCount: 10,
          type: InstallmentPlanType.monthly,
        ),
        InstallmentPlan(
          id: 'plan_annual',
          label: 'Annual single payment',
          installmentCount: 1,
          type: InstallmentPlanType.annual,
        ),
      ];

  @override
  CollectionDetail? getCollectionDetail(String collectionId) {
    for (final payment in _payments) {
      if (payment.id == collectionId) {
        return CollectionDetail(
          payment: payment,
          feeAccountId: _accountIdForAdmission(payment.admissionNumber),
          summaryKpis: [
            FinanceKpi(
              id: 'amount',
              value: payment.amount,
              label: 'Payment amount',
              icon: Icons.payments_outlined,
              accentName: 'success',
            ),
            FinanceKpi(
              id: 'balance',
              value: _balanceForAdmission(payment.admissionNumber),
              label: 'Remaining balance',
              icon: Icons.account_balance_wallet_outlined,
              accentName: 'warning',
            ),
            const FinanceKpi(
              id: 'installments',
              value: '3 of 4 paid',
              label: 'Installments',
              icon: Icons.calendar_month_outlined,
              accentName: 'primary',
            ),
            FinanceKpi(
              id: 'mode',
              value: payment.mode,
              label: 'Payment mode',
              icon: Icons.credit_card_outlined,
              accentName: 'neutral',
            ),
          ],
          paymentTimeline: [
            PaymentTimelineEntry(
              id: 'tl_1',
              label: payment.receiptNumber,
              amount: payment.amount,
              timestamp: payment.collectedAt,
              status: payment.status,
              mode: payment.mode,
            ),
            const PaymentTimelineEntry(
              id: 'tl_2',
              label: 'Term 2 installment',
              amount: '₹45,000',
              timestamp: '15 May 2026',
              status: CollectionStatus.completed,
              mode: 'UPI',
            ),
            const PaymentTimelineEntry(
              id: 'tl_3',
              label: 'Term 1 installment',
              amount: '₹45,000',
              timestamp: '10 Apr 2026',
              status: CollectionStatus.completed,
              mode: 'Cash',
            ),
          ],
          installmentHistory: [
            const InstallmentHistoryEntry(
              id: 'inst_1',
              termLabel: 'Term 1',
              dueDate: '10 Apr 2026',
              amount: '₹61,667',
              paidAmount: '₹61,667',
              status: CollectionStatus.completed,
            ),
            const InstallmentHistoryEntry(
              id: 'inst_2',
              termLabel: 'Term 2',
              dueDate: '15 May 2026',
              amount: '₹61,667',
              paidAmount: '₹61,667',
              status: CollectionStatus.completed,
            ),
            InstallmentHistoryEntry(
              id: 'inst_3',
              termLabel: 'Term 3',
              dueDate: '15 Jun 2026',
              amount: '₹61,666',
              paidAmount: payment.amount,
              status: CollectionStatus.pending,
            ),
          ],
          receiptLinks: [
            ReceiptLink(
              receiptNumber: payment.receiptNumber,
              amount: payment.amount,
              dateLabel: payment.collectedAt,
              parentReceiptRoute: RouteNames.parentReceiptDetail(
                payment.receiptNumber,
              ),
            ),
            const ReceiptLink(
              receiptNumber: 'RCP-2026-8801',
              amount: '₹45,000',
              dateLabel: '15 May 2026',
              parentReceiptRoute: '/parent/receipts/RCP-2026-8801',
            ),
          ],
          aiInsight:
              'Payment aligns with quarterly plan. Next installment due in 10 days — auto-reminder scheduled via Parent App (PA-03).',
        );
      }
    }
    return null;
  }

  @override
  DefaultersDashboardData getDefaultersDashboard() {
    return const DefaultersDashboardData(
      kpis: [
        FinanceKpi(
          id: 'total_overdue',
          value: '₹18.6L',
          label: 'Total overdue',
          icon: Icons.warning_amber_outlined,
          accentName: 'error',
        ),
        FinanceKpi(
          id: 'defaulter_count',
          value: '47',
          label: 'Defaulters',
          icon: Icons.people_outline,
          accentName: 'warning',
        ),
        FinanceKpi(
          id: 'critical',
          value: '12',
          label: 'Critical (>60d)',
          icon: Icons.priority_high,
          accentName: 'error',
        ),
        FinanceKpi(
          id: 'followups',
          value: '8',
          label: 'Follow-ups today',
          icon: Icons.phone_in_talk_outlined,
          accentName: 'primary',
        ),
      ],
      agingBuckets: [
        AgingBucketSummary(
          bucket: DefaulterAgingBucket.current,
          label: 'Current',
          studentCount: 12,
          totalAmount: '₹2.1L',
        ),
        AgingBucketSummary(
          bucket: DefaulterAgingBucket.days1to30,
          label: '1–30 days',
          studentCount: 18,
          totalAmount: '₹4.8L',
        ),
        AgingBucketSummary(
          bucket: DefaulterAgingBucket.days31to60,
          label: '31–60 days',
          studentCount: 9,
          totalAmount: '₹5.2L',
        ),
        AgingBucketSummary(
          bucket: DefaulterAgingBucket.days61to90,
          label: '61–90 days',
          studentCount: 5,
          totalAmount: '₹3.5L',
        ),
        AgingBucketSummary(
          bucket: DefaulterAgingBucket.over90,
          label: '90+ days',
          studentCount: 3,
          totalAmount: '₹3.0L',
        ),
      ],
      defaulters: [
        DefaulterRecord(
          id: 'def_1',
          studentName: 'Priya Sharma',
          admissionNumber: 'ADM-2025-0092',
          classLabel: '8',
          overdueAmount: '₹65,000',
          daysOverdue: 45,
          bucket: DefaulterAgingBucket.days31to60,
          lastContact: '12 May · WhatsApp',
          collectionProbability: 62,
          feeAccountId: 'acct_4',
          contactHistory: [
            ContactHistoryEntry(
              id: 'ch_1',
              timestamp: '12 May · 4:30 PM',
              channel: 'WhatsApp',
              outcome: 'No response',
              notes: 'Sent payment reminder with UPI link (PA-10).',
            ),
            ContactHistoryEntry(
              id: 'ch_2',
              timestamp: '28 Apr · 11:00 AM',
              channel: 'Phone',
              outcome: 'Promised by 5 May',
              notes: 'Parent requested extension for medical expenses.',
            ),
          ],
        ),
        DefaulterRecord(
          id: 'def_2',
          studentName: 'Ananya Reddy',
          admissionNumber: 'ADM-2026-0142',
          classLabel: '5',
          overdueAmount: '₹71,667',
          daysOverdue: 15,
          bucket: DefaulterAgingBucket.days1to30,
          lastContact: '3 Jun · Email',
          collectionProbability: 78,
          feeAccountId: 'acct_2',
          contactHistory: [
            ContactHistoryEntry(
              id: 'ch_3',
              timestamp: '3 Jun · 9:00 AM',
              channel: 'Email',
              outcome: 'Opened',
              notes: 'New admission — first installment pending after AD-08 handoff.',
            ),
          ],
        ),
        DefaulterRecord(
          id: 'def_3',
          studentName: 'Kavya Iyer',
          admissionNumber: 'ADM-2025-0101',
          classLabel: '6',
          overdueAmount: '₹52,000',
          daysOverdue: 92,
          bucket: DefaulterAgingBucket.over90,
          lastContact: '20 May · Phone',
          collectionProbability: 34,
          feeAccountId: 'acct_5',
          contactHistory: [
            ContactHistoryEntry(
              id: 'ch_4',
              timestamp: '20 May · 2:00 PM',
              channel: 'Phone',
              outcome: 'Unreachable',
              notes: 'Escalated to management review.',
            ),
          ],
        ),
      ],
      aiInsight:
          'Class 8 defaulters rose 22% this month. Prioritize WhatsApp reminders for 31–60 day bucket — 78% open rate vs 41% for email.',
      aiActionLabel: 'Send bulk reminders',
    );
  }

  @override
  List<RefundRequest> getRefundRequests() => const [
        RefundRequest(
          id: 'ref_1',
          studentName: 'Kavya Iyer',
          admissionNumber: 'ADM-2025-0101',
          classLabel: '6',
          amount: '₹52,000',
          reason: 'Withdrawal — family relocation',
          requestedAt: '4 Jun 2026',
          status: RefundStatus.pending,
          approver: 'Finance Manager',
          feeAccountId: 'acct_5',
          originalReceipt: 'RCP-2026-8836',
        ),
        RefundRequest(
          id: 'ref_2',
          studentName: 'Rohan Mehta',
          admissionNumber: 'ADM-2025-0114',
          classLabel: '9',
          amount: '₹12,500',
          reason: 'Transport fee overcharge',
          requestedAt: '2 Jun 2026',
          status: RefundStatus.approved,
          approver: 'Principal Sharma',
          feeAccountId: 'acct_6',
          originalReceipt: 'RCP-2026-8820',
        ),
        RefundRequest(
          id: 'ref_3',
          studentName: 'Divya Iyer',
          admissionNumber: 'ADM-2025-0088',
          classLabel: '4',
          amount: '₹8,000',
          reason: 'Activity fee duplicate payment',
          requestedAt: '28 May 2026',
          status: RefundStatus.processed,
          approver: 'Finance Manager',
          feeAccountId: 'acct_7',
          originalReceipt: 'RCP-2026-8795',
        ),
      ];

  @override
  DiscountsDashboardData getDiscountsDashboard() {
    return const DiscountsDashboardData(
      kpis: [
        FinanceKpi(
          id: 'active_scholarships',
          value: '8',
          label: 'Active scholarships',
          icon: Icons.school_outlined,
          accentName: 'primary',
        ),
        FinanceKpi(
          id: 'assigned',
          value: '24',
          label: 'Student assignments',
          icon: Icons.people_outline,
          accentName: 'success',
        ),
        FinanceKpi(
          id: 'pending_approval',
          value: '3',
          label: 'Pending approval',
          icon: Icons.pending_actions_outlined,
          accentName: 'warning',
        ),
        FinanceKpi(
          id: 'impact',
          value: '₹4.2L',
          label: 'Discount impact (YTD)',
          icon: Icons.savings_outlined,
          accentName: 'neutral',
        ),
      ],
      scholarships: [
        ScholarshipCatalogItem(
          id: 'sch_1',
          name: 'Merit Scholarship',
          type: ScholarshipType.merit,
          maxDiscount: '25%',
          eligibility: 'Top 10% academic performance',
          activeAssignments: 8,
        ),
        ScholarshipCatalogItem(
          id: 'sch_2',
          name: 'Sibling Discount',
          type: ScholarshipType.sibling,
          maxDiscount: '10%',
          eligibility: 'Second child enrolled',
          activeAssignments: 12,
        ),
        ScholarshipCatalogItem(
          id: 'sch_3',
          name: 'Sports Excellence',
          type: ScholarshipType.sports,
          maxDiscount: '15%',
          eligibility: 'State-level sports achievement',
          activeAssignments: 4,
        ),
      ],
      rules: [
        DiscountRule(
          id: 'rule_1',
          name: 'Early bird payment',
          discountPercent: '5%',
          appliesTo: 'Annual fee — paid before 30 Apr',
          status: DiscountApprovalStatus.active,
        ),
        DiscountRule(
          id: 'rule_2',
          name: 'Staff child waiver',
          discountPercent: '50%',
          appliesTo: 'Tuition component only',
          status: DiscountApprovalStatus.active,
        ),
        DiscountRule(
          id: 'rule_3',
          name: 'Need-based aid',
          discountPercent: 'Up to 40%',
          appliesTo: 'Management approval required',
          status: DiscountApprovalStatus.pending,
        ),
      ],
      assignments: [
        StudentDiscountAssignment(
          id: 'asgn_1',
          studentName: 'Arjun Patel',
          admissionNumber: 'ADM-2026-0138',
          scholarshipName: 'Merit Scholarship',
          discountAmount: '₹46,250',
          status: DiscountApprovalStatus.active,
          impactOnFees: '25% off tuition',
        ),
        StudentDiscountAssignment(
          id: 'asgn_2',
          studentName: 'Emma Thomas',
          admissionNumber: 'ADM-2026-0135',
          scholarshipName: 'Sports Excellence',
          discountAmount: '₹27,000',
          status: DiscountApprovalStatus.approved,
          impactOnFees: '15% off annual fee',
        ),
        StudentDiscountAssignment(
          id: 'asgn_3',
          studentName: 'Ananya Reddy',
          admissionNumber: 'ADM-2026-0142',
          scholarshipName: 'Sibling Discount',
          discountAmount: '₹21,500',
          status: DiscountApprovalStatus.pending,
          impactOnFees: '10% off — pending docs',
        ),
      ],
      impactSummary:
          'Discounts reduced gross collections by ₹4.2L YTD. Merit scholarships account for 48% of total impact.',
    );
  }

  @override
  FinanceReportsData getReportsData() {
    return const FinanceReportsData(
      selectedReportId: 'rpt_collection',
      catalog: [
        FinanceReportCatalogItem(
          id: 'rpt_collection',
          title: 'Collection Report',
          description: 'Daily and monthly fee collection summary',
          type: FinanceReportType.collection,
          lastGenerated: '5 Jun 2026',
        ),
        FinanceReportCatalogItem(
          id: 'rpt_outstanding',
          title: 'Outstanding Report',
          description: 'Class-wise outstanding and aging analysis',
          type: FinanceReportType.outstanding,
          lastGenerated: '4 Jun 2026',
        ),
        FinanceReportCatalogItem(
          id: 'rpt_discount',
          title: 'Discount Report',
          description: 'Scholarship and discount impact analysis',
          type: FinanceReportType.discount,
          lastGenerated: '1 Jun 2026',
        ),
        FinanceReportCatalogItem(
          id: 'rpt_refund',
          title: 'Refund Report',
          description: 'Refund requests and processing status',
          type: FinanceReportType.refund,
          lastGenerated: '3 Jun 2026',
        ),
      ],
      collectionTrend: [
        FinanceReportTrendPoint(label: 'Jan', value: 6.2, target: 7.0),
        FinanceReportTrendPoint(label: 'Feb', value: 7.8, target: 7.0),
        FinanceReportTrendPoint(label: 'Mar', value: 8.4, target: 8.0),
        FinanceReportTrendPoint(label: 'Apr', value: 9.1, target: 8.5),
        FinanceReportTrendPoint(label: 'May', value: 10.5, target: 9.0),
        FinanceReportTrendPoint(label: 'Jun', value: 11.2, target: 10.0),
      ],
      outstandingTrend: [
        FinanceReportTrendPoint(label: 'Jan', value: 22.0, target: 20.0),
        FinanceReportTrendPoint(label: 'Feb', value: 21.2, target: 19.0),
        FinanceReportTrendPoint(label: 'Mar', value: 20.5, target: 18.0),
        FinanceReportTrendPoint(label: 'Apr', value: 19.8, target: 17.0),
        FinanceReportTrendPoint(label: 'May', value: 18.9, target: 16.0),
        FinanceReportTrendPoint(label: 'Jun', value: 18.6, target: 15.0),
      ],
    );
  }

  @override
  FinanceSettingsData getSettings() {
    return const FinanceSettingsData(
      academicYear: '2026-27',
      sections: [
        FinanceSettingsSection(
          id: 'academic',
          title: 'Academic year setup',
          items: [
            FinanceSettingItem(
              id: 'year',
              label: 'Active academic year',
              value: '2026-27',
              description: 'Fee structures and assignments use this year',
              editable: true,
            ),
            FinanceSettingItem(
              id: 'term_dates',
              label: 'Term dates',
              value: 'Apr – Mar (3 terms)',
              description: 'Installment due dates derived from term calendar',
              editable: true,
            ),
          ],
        ),
        FinanceSettingsSection(
          id: 'receipts',
          title: 'Receipt numbering',
          items: [
            FinanceSettingItem(
              id: 'prefix',
              label: 'Receipt prefix',
              value: 'RCP-2026-',
              description: 'Auto-incremented per transaction (PA-11)',
              editable: true,
            ),
            FinanceSettingItem(
              id: 'next_number',
              label: 'Next receipt number',
              value: '8842',
              description: 'Last issued: RCP-2026-8841',
              editable: false,
            ),
          ],
        ),
        FinanceSettingsSection(
          id: 'gateway',
          title: 'Payment gateway',
          items: [
            FinanceSettingItem(
              id: 'upi',
              label: 'UPI gateway',
              value: 'Razorpay (sandbox)',
              description: 'Parent App payment flow (PA-10)',
              editable: true,
            ),
            FinanceSettingItem(
              id: 'card',
              label: 'Card payments',
              value: 'Disabled',
              description: 'Enable for online card collection',
              editable: true,
            ),
          ],
        ),
        FinanceSettingsSection(
          id: 'workflow',
          title: 'Finance workflow',
          items: [
            FinanceSettingItem(
              id: 'handoff',
              label: 'Admissions handoff',
              value: 'Auto-queue on approval',
              description: 'AD-08 → FN-04 fee assignment',
              editable: true,
            ),
            FinanceSettingItem(
              id: 'refund_approval',
              label: 'Refund approval',
              value: 'Principal + Finance',
              description: 'Dual approval for refunds > ₹25,000',
              editable: true,
            ),
          ],
        ),
        FinanceSettingsSection(
          id: 'reminders',
          title: 'Reminder settings',
          items: [
            FinanceSettingItem(
              id: 'due_reminder',
              label: 'Due date reminder',
              value: '3 days before',
              description: 'Push + WhatsApp via Parent App',
              editable: true,
            ),
            FinanceSettingItem(
              id: 'overdue',
              label: 'Overdue escalation',
              value: '7 / 15 / 30 days',
              description: 'Escalation ladder for defaulters (FN-07)',
              editable: true,
            ),
          ],
        ),
        FinanceSettingsSection(
          id: 'policy',
          title: 'Collection policy',
          items: [
            FinanceSettingItem(
              id: 'late_fee',
              label: 'Late fee',
              value: '₹500 / month',
              description: 'Applied after 15-day grace period',
              editable: true,
            ),
            FinanceSettingItem(
              id: 'min_payment',
              label: 'Minimum partial payment',
              value: '25% of installment',
              description: 'Allowed for hardship cases',
              editable: true,
            ),
          ],
        ),
      ],
    );
  }

  String _accountIdForAdmission(String admissionNumber) => switch (admissionNumber) {
        'ADM-2026-0138' => 'acct_1',
        'ADM-2026-0142' => 'acct_2',
        'ADM-2026-0135' => 'acct_3',
        'ADM-2025-0092' => 'acct_4',
        _ => 'acct_unknown',
      };

  String _balanceForAdmission(String admissionNumber) => switch (admissionNumber) {
        'ADM-2026-0138' => '₹1,23,000',
        'ADM-2026-0142' => '₹2,15,000',
        'ADM-2026-0135' => '₹2,55,000',
        'ADM-2025-0092' => '₹65,000',
        _ => '—',
      };

  static const List<CollectionPayment> _payments = [
    CollectionPayment(
      id: 'col_1',
      receiptNumber: 'RCP-2026-8841',
      studentName: 'Arjun Patel',
      admissionNumber: 'ADM-2026-0138',
      amount: '₹62,000',
      mode: 'UPI',
      collectedAt: 'Today, 10:42',
      collectedBy: 'R. Kumar',
      status: CollectionStatus.completed,
      classLabel: '10',
    ),
    CollectionPayment(
      id: 'col_2',
      receiptNumber: 'RCP-2026-8840',
      studentName: 'Priya Sharma',
      admissionNumber: 'ADM-2025-0092',
      amount: '₹45,000',
      mode: 'Cash',
      collectedAt: 'Today, 09:15',
      collectedBy: 'S. Nair',
      status: CollectionStatus.completed,
      classLabel: '8',
    ),
    CollectionPayment(
      id: 'col_3',
      receiptNumber: 'RCP-2026-8839',
      studentName: 'Rohan Mehta',
      admissionNumber: 'ADM-2025-0114',
      amount: '₹38,500',
      mode: 'Card',
      collectedAt: 'Today, 08:30',
      collectedBy: 'R. Kumar',
      status: CollectionStatus.completed,
      classLabel: '9',
    ),
    CollectionPayment(
      id: 'col_4',
      receiptNumber: 'RCP-2026-8838',
      studentName: 'Ananya Reddy',
      admissionNumber: 'ADM-2026-0142',
      amount: '₹71,500',
      mode: 'UPI',
      collectedAt: 'Yesterday',
      collectedBy: 'R. Kumar',
      status: CollectionStatus.pending,
      classLabel: '5',
    ),
    CollectionPayment(
      id: 'col_5',
      receiptNumber: 'RCP-2026-8837',
      studentName: 'Emma Thomas',
      admissionNumber: 'ADM-2026-0135',
      amount: '₹85,000',
      mode: 'Bank Transfer',
      collectedAt: 'Yesterday',
      collectedBy: 'S. Nair',
      status: CollectionStatus.completed,
      classLabel: '7',
    ),
    CollectionPayment(
      id: 'col_6',
      receiptNumber: 'RCP-2026-8836',
      studentName: 'Kavya Iyer',
      admissionNumber: 'ADM-2025-0101',
      amount: '₹52,000',
      mode: 'UPI',
      collectedAt: '2 days ago',
      collectedBy: 'R. Kumar',
      status: CollectionStatus.refunded,
      classLabel: '6',
    ),
  ];
}
