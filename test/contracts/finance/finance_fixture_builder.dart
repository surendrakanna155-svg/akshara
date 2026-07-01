import 'package:akshara_erp/core/repositories/api/finance/dto/finance_enum_codec.dart';
import 'package:akshara_erp/features/finance/finance_models.dart';

/// Builds API-shaped JSON envelopes from domain models for contract tests.
class FinanceFixtureBuilder {
  const FinanceFixtureBuilder();

  Map<String, dynamic> envelope(Map<String, dynamic> data) => {'data': data};

  Map<String, dynamic> listEnvelope(List<Map<String, dynamic>> items) => {
        'data': {'items': items},
      };

  Map<String, dynamic> apiDashboardEnvelope({
    int totalStudents = 2,
    int activeFeeAssignments = 2,
    double totalInvoiced = 150000,
    double totalCollected = 60000,
    double totalOutstanding = 30000,
    double collectionRate = 40,
    int pendingInvoices = 1,
    int partiallyPaidInvoices = 0,
    int paidInvoices = 1,
    int pendingRefunds = 1,
    int processedRefunds = 1,
    double todayCollections = 40000,
    int todayCollectionCount = 1,
  }) {
    return envelope({
      'totalStudents': totalStudents,
      'activeFeeAssignments': activeFeeAssignments,
      'totalInvoiced': totalInvoiced,
      'totalCollected': totalCollected,
      'totalOutstanding': totalOutstanding,
      'collectionRate': collectionRate,
      'pendingInvoices': pendingInvoices,
      'partiallyPaidInvoices': partiallyPaidInvoices,
      'paidInvoices': paidInvoices,
      'pendingRefunds': pendingRefunds,
      'processedRefunds': processedRefunds,
      'todayCollections': todayCollections,
      'todayCollectionCount': todayCollectionCount,
      'recentCollections': [
        {
          'id': 'col-1',
          'receiptNumber': 'RCP-001',
          'studentName': 'Probe Student',
          'amount': 40000,
          'paymentMethod': 'cash',
          'collectionDate': '2026-06-09',
        },
      ],
      'recentRefunds': [
        {
          'id': 'ref-1',
          'studentName': 'Probe Student',
          'amount': 1000,
          'status': 'pending',
          'requestedAt': '2026-06-09T09:00:00.000Z',
        },
      ],
    });
  }

  Map<String, dynamic> dashboardEnvelope(FinanceDashboardData data) {
    return envelope({
      'outstandingAmount': data.outstandingAmount,
      'defaultersCount': data.defaultersCount,
      'aiInsight': data.aiInsight,
      'kpis': [
        for (final kpi in data.kpis)
          {
            'id': kpi.id,
            'value': kpi.value,
            'label': kpi.label,
            'accentName': kpi.accentName,
            if (kpi.detail != null) 'detail': kpi.detail,
          },
      ],
      'collectionTrend': [
        for (final point in data.collectionTrend)
          {
            'label': point.label,
            'amountLakhs': point.amountLakhs,
            'targetLakhs': point.targetLakhs,
          },
      ],
      'recentPayments': [
        for (final payment in data.recentPayments)
          {
            'id': payment.id,
            'studentName': payment.studentName,
            'admissionNumber': payment.admissionNumber,
            'amount': payment.amount,
            'mode': payment.mode,
            'receiptNumber': payment.receiptNumber,
            'collectedAt': payment.collectedAt,
            'status': payment.status.name,
          },
      ],
    });
  }

  Map<String, dynamic> collectionItem(CollectionPayment payment) => {
        'id': payment.id,
        'receiptNumber': payment.receiptNumber,
        'studentName': payment.studentName,
        'admissionNumber': payment.admissionNumber,
        'amount': payment.amount,
        'mode': payment.mode,
        'collectedAt': payment.collectedAt,
        'collectedBy': payment.collectedBy,
        'status': payment.status.name,
        'classLabel': payment.classLabel,
      };

  Map<String, dynamic> offlinePaymentItem(OfflinePaymentRecord payment) => {
        'id': payment.id,
        'invoiceId': payment.invoiceId,
        'studentName': payment.studentName,
        'amount': payment.amount,
        'method': FinanceEnumCodec.offlinePaymentMethodToApi(payment.method),
        'referenceNumber': payment.referenceNumber,
        'recordedAt': payment.recordedAt,
        'status': FinanceEnumCodec.offlinePaymentStatusToApi(payment.status),
        if (payment.collectionId != null) 'collectionId': payment.collectionId,
      };

  Map<String, dynamic> qrPaymentSessionItem(QrPaymentSession session) => {
        'id': session.id,
        'invoiceId': session.invoiceId,
        'amount': session.amount,
        'upiPayload': session.upiPayload,
        'status': session.status.name,
        'expiresAt': session.expiresAt.toIso8601String(),
        if (session.receiptNumber != null)
          'receiptNumber': session.receiptNumber,
      };

  Map<String, dynamic> dailySummaryEnvelope(DailyCollectionSummary summary) {
    return envelope({
      'dateLabel': summary.dateLabel,
      'totalCollected': summary.totalCollected,
      'transactionCount': summary.transactionCount,
      'cashAmount': summary.cashAmount,
      'upiAmount': summary.upiAmount,
      'pendingReconciliation': summary.pendingReconciliation,
    });
  }

  Map<String, dynamic> feeStructureItem(FinanceFeeStructure structure) => {
        'id': structure.id,
        'name': structure.name,
        'academicYear': structure.academicYear,
        'totalAnnual': structure.totalAnnual,
        'classRange': structure.classRange,
        'status': structure.status.name,
        'installmentOptions': structure.installmentOptions,
        'categories': [
          for (final line in structure.categories)
            {
              'category': FinanceEnumCodec.feeStructureCategoryToApi(
                line.category,
              ),
              'label': line.label,
              'amount': line.amount,
            },
        ],
      };

  Map<String, dynamic> academicYearsEnvelope(List<String> years) => envelope({
        'years': years,
      });

  Map<String, dynamic> studentAccountItem(StudentFeeAccount account) => {
        'id': account.id,
        'studentName': account.studentName,
        'admissionNumber': account.admissionNumber,
        'classLabel': account.classLabel,
        'feeStructureName': account.feeStructureName,
        'totalDue': account.totalDue,
        'totalPaid': account.totalPaid,
        'balance': account.balance,
        'status': account.status.name,
        'lastPaymentDate': account.lastPaymentDate,
        'installmentPlan': account.installmentPlan,
      };

  Map<String, dynamic> installmentPlanItem(InstallmentPlan plan) => {
        'id': plan.id,
        'label': plan.label,
        'installmentCount': plan.installmentCount,
        'type': plan.type.name,
      };

  Map<String, dynamic> invoiceItem(FinanceInvoice invoice) => {
        'id': invoice.id,
        'studentId': invoice.studentId,
        'feeAssignmentId': invoice.feeAssignmentId,
        'academicYear': invoice.academicYear,
        'invoiceNumber': invoice.invoiceNumber,
        'invoiceDate': invoice.invoiceDate,
        'dueDate': invoice.dueDate,
        'subtotalAmount': invoice.subtotalAmount,
        'discountAmount': invoice.discountAmount,
        'totalAmount': invoice.totalAmount,
        'outstandingAmount': invoice.outstandingAmount,
        'paidAmount': invoice.paidAmount,
        'invoiceStatus':
            FinanceEnumCodec.invoiceStatusToApi(invoice.invoiceStatus),
        'termLabel': invoice.termLabel,
        'createdBy': invoice.createdBy,
        'createdAt': invoice.createdAt,
        'updatedAt': invoice.updatedAt,
      };

  Map<String, dynamic> collectionResultEnvelope(
          FinanceCollectionResult result) =>
      envelope({
        'collection': {
          'id': result.collectionId,
          'invoiceId': result.invoiceId,
          'studentAccountId': result.studentAccountId,
          'receiptNumber': result.receiptNumber,
          'amountCollected': result.amountCollected,
          'paymentMethod': result.paymentMethod,
          'collectionStatus': 'completed',
          'collectionDate': result.collectionDate,
        },
        'receipt': {
          'id': result.receipt.id,
          'collectionId': result.receipt.collectionId,
          'receiptNumber': result.receipt.receiptNumber,
          'receiptDate': result.receipt.receiptDate,
          'amount': result.receipt.amount,
          'generatedBy': 'staff',
          'createdAt': '2026-06-10T00:00:00.000Z',
        },
        'invoice': invoiceItem(result.invoice),
      });

  Map<String, dynamic> collectionDetailEnvelope(CollectionDetail detail) {
    return envelope({
      'feeAccountId': detail.feeAccountId,
      'invoiceId': detail.invoiceId,
      'aiInsight': detail.aiInsight,
      'payment': collectionItem(detail.payment),
      'summaryKpis': [
        for (final kpi in detail.summaryKpis)
          {
            'id': kpi.id,
            'value': kpi.value,
            'label': kpi.label,
            'accentName': kpi.accentName,
          },
      ],
      'paymentTimeline': [
        for (final entry in detail.paymentTimeline)
          {
            'id': entry.id,
            'label': entry.label,
            'amount': entry.amount,
            'timestamp': entry.timestamp,
            'status': entry.status.name,
            'mode': entry.mode,
          },
      ],
      'installmentHistory': [
        for (final entry in detail.installmentHistory)
          {
            'id': entry.id,
            'termLabel': entry.termLabel,
            'dueDate': entry.dueDate,
            'amount': entry.amount,
            'paidAmount': entry.paidAmount,
            'status': entry.status.name,
          },
      ],
      'receiptLinks': [
        for (final link in detail.receiptLinks)
          {
            'receiptNumber': link.receiptNumber,
            'amount': link.amount,
            'dateLabel': link.dateLabel,
            'parentReceiptRoute': link.parentReceiptRoute,
          },
      ],
    });
  }

  // FIN-6 — installment schedule list envelope.
  Map<String, dynamic> installmentScheduleEnvelope(
    List<InstallmentScheduleEntry> terms,
  ) {
    return listEnvelope([
      for (final t in terms)
        {
          'id': t.id,
          'termNo': t.termNo,
          'termLabel': t.termLabel,
          'dueDate': t.dueDate,
          'amount': t.amount,
          'status': t.status,
        },
    ]);
  }

  // FIN-9 — head-wise dues list envelope.
  Map<String, dynamic> headWiseDuesEnvelope(List<HeadWiseDue> dues) {
    return listEnvelope([
      for (final d in dues)
        {
          'feeHead': d.feeHead,
          'category': d.category,
          'label': d.label,
          'dues': d.dues,
        },
    ]);
  }

  Map<String, dynamic> defaultersEnvelope(DefaultersDashboardData data) {
    return envelope({
      'aiInsight': data.aiInsight,
      'aiActionLabel': data.aiActionLabel,
      'kpis': [
        for (final kpi in data.kpis)
          {
            'id': kpi.id,
            'value': kpi.value,
            'label': kpi.label,
            'accentName': kpi.accentName,
          },
      ],
      'agingBuckets': [
        for (final bucket in data.agingBuckets)
          {
            'bucket': bucket.bucket.name,
            'label': bucket.label,
            'studentCount': bucket.studentCount,
            'totalAmount': bucket.totalAmount,
          },
      ],
      'defaulters': [
        for (final record in data.defaulters)
          {
            'id': record.id,
            'studentName': record.studentName,
            'admissionNumber': record.admissionNumber,
            'classLabel': record.classLabel,
            'overdueAmount': record.overdueAmount,
            'daysOverdue': record.daysOverdue,
            'bucket': record.bucket.name,
            'lastContact': record.lastContact,
            'collectionProbability': record.collectionProbability,
            'feeAccountId': record.feeAccountId,
            'contactHistory': [
              for (final contact in record.contactHistory)
                {
                  'id': contact.id,
                  'timestamp': contact.timestamp,
                  'channel': contact.channel,
                  'outcome': contact.outcome,
                  'notes': contact.notes,
                },
            ],
          },
      ],
    });
  }

  Map<String, dynamic> scholarshipItem(ScholarshipCatalogItem scholarship) => {
        'id': scholarship.id,
        'name': scholarship.name,
        'type': scholarship.type.name,
        'maxDiscount': scholarship.maxDiscount,
        'eligibility': scholarship.eligibility,
        'activeAssignments': scholarship.activeAssignments,
      };

  Map<String, dynamic> refundItem(RefundRequest refund) => {
        'id': refund.id,
        'studentName': refund.studentName,
        'admissionNumber': refund.admissionNumber,
        'classLabel': refund.classLabel,
        'amount': refund.amount,
        'reason': refund.reason,
        'requestedAt': refund.requestedAt,
        'status': refund.status.name,
        'approver': refund.approver,
        'feeAccountId': refund.feeAccountId,
        'originalReceipt': refund.originalReceipt,
        'collectionId': refund.collectionId,
        'invoiceId': refund.invoiceId,
      };

  Map<String, dynamic> discountsEnvelope(DiscountsDashboardData data) {
    return envelope({
      'impactSummary': data.impactSummary,
      'kpis': [
        for (final kpi in data.kpis)
          {
            'id': kpi.id,
            'value': kpi.value,
            'label': kpi.label,
            'accentName': kpi.accentName,
          },
      ],
      'scholarships': [
        for (final scholarship in data.scholarships)
          {
            'id': scholarship.id,
            'name': scholarship.name,
            'type': scholarship.type.name,
            'maxDiscount': scholarship.maxDiscount,
            'eligibility': scholarship.eligibility,
            'activeAssignments': scholarship.activeAssignments,
          },
      ],
      'rules': [
        for (final rule in data.rules)
          {
            'id': rule.id,
            'name': rule.name,
            'discountPercent': rule.discountPercent,
            'appliesTo': rule.appliesTo,
            'status': rule.status.name,
          },
      ],
      'assignments': [
        for (final assignment in data.assignments)
          {
            'id': assignment.id,
            'studentName': assignment.studentName,
            'admissionNumber': assignment.admissionNumber,
            'scholarshipName': assignment.scholarshipName,
            'discountAmount': assignment.discountAmount,
            'status': assignment.status.name,
            'impactOnFees': assignment.impactOnFees,
          },
      ],
    });
  }

  Map<String, dynamic> reportsEnvelope(FinanceReportsData data) {
    return envelope({
      'selectedReportId': data.selectedReportId,
      'catalog': [
        for (final item in data.catalog)
          {
            'id': item.id,
            'title': item.title,
            'description': item.description,
            'type': item.type.name,
            'lastGenerated': item.lastGenerated,
          },
      ],
      'collectionTrend': _trendPoints(data.collectionTrend),
      'outstandingTrend': _trendPoints(data.outstandingTrend),
    });
  }

  Map<String, dynamic> settingsEnvelope(FinanceSettingsData data) {
    return envelope({
      'academicYear': data.academicYear,
      'sections': [
        for (final section in data.sections)
          {
            'id': section.id,
            'title': section.title,
            'items': [
              for (final item in section.items)
                {
                  'id': item.id,
                  'label': item.label,
                  'value': item.value,
                  'description': item.description,
                  'editable': item.editable,
                },
            ],
          },
      ],
    });
  }

  List<Map<String, dynamic>> _trendPoints(
      List<FinanceReportTrendPoint> points) {
    return [
      for (final point in points)
        {
          'label': point.label,
          'value': point.value,
          'target': point.target,
        },
    ];
  }
}
