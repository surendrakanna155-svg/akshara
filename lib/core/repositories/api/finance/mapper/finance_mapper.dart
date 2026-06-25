import 'package:flutter/material.dart';

import '../dto/create_collection_request_dto.dart';
import '../dto/finance_collections_dto.dart';
import '../dto/finance_dashboard_dto.dart';
import '../dto/finance_defaulters_dto.dart';
import '../dto/finance_discounts_dto.dart';
import '../dto/finance_enum_codec.dart';
import '../dto/finance_fee_structures_dto.dart';
import '../dto/finance_invoices_dto.dart';
import '../dto/offline_payment_dto.dart';
import '../dto/finance_receipt_dto.dart';
import '../dto/finance_refunds_dto.dart';
import '../dto/finance_reports_dto.dart';
import '../dto/finance_settings_dto.dart';
import '../dto/finance_student_accounts_dto.dart';
import '../dto/qr_payment_session_dto.dart';
import '../dto/scholarship_dto.dart';
import '../../../../../features/finance/finance_models.dart';

/// Maps Finance API DTOs to domain models.
class FinanceMapper {
  const FinanceMapper();

  FinanceDashboardData toDashboard(FinanceDashboardDto dto) {
    final raw = dto.raw;
    if (raw.containsKey('totalCollected') || raw.containsKey('totalStudents')) {
      return _toDashboardFromApi(raw);
    }
    return FinanceDashboardData(
      outstandingAmount: raw['outstandingAmount'] as String? ?? '',
      defaultersCount: raw['defaultersCount'] as int? ?? 0,
      aiInsight: raw['aiInsight'] as String? ?? '',
      kpis: _mapKpis(raw['kpis'] as List<dynamic>? ?? const []),
      collectionTrend: _mapCollectionTrend(
        raw['collectionTrend'] as List<dynamic>? ?? const [],
      ),
      recentPayments: _mapRecentPayments(
        raw['recentPayments'] as List<dynamic>? ?? const [],
      ),
    );
  }

  FinanceDashboardData _toDashboardFromApi(Map<String, dynamic> raw) {
    final totalOutstanding = _readAmount(raw['totalOutstanding']);
    final totalCollected = _readAmount(raw['totalCollected']);
    final totalInvoiced = _readAmount(raw['totalInvoiced']);
    final todayCollections = _readAmount(raw['todayCollections']);
    final collectionRate = (raw['collectionRate'] as num?)?.toDouble() ?? 0;
    final pendingRefunds = raw['pendingRefunds'] as int? ?? 0;

    return FinanceDashboardData(
      outstandingAmount: _formatDashboardAmount(totalOutstanding),
      defaultersCount: 0,
      aiInsight: pendingRefunds > 0
          ? '$pendingRefunds refund requests awaiting review.'
          : '',
      kpis: [
        FinanceKpi(
          id: 'collected_total',
          value: _formatDashboardAmount(totalCollected),
          label: 'Total Collected',
          icon: Icons.payments_outlined,
          accentName: 'success',
        ),
        FinanceKpi(
          id: 'outstanding',
          value: _formatDashboardAmount(totalOutstanding),
          label: 'Outstanding',
          icon: Icons.pending_actions_outlined,
          accentName: 'warning',
        ),
        FinanceKpi(
          id: 'collection_rate',
          value:
              '${collectionRate.toStringAsFixed(collectionRate % 1 == 0 ? 0 : 1)}%',
          label: 'Collection Rate',
          icon: Icons.trending_up,
          accentName: 'primary',
          detail: totalInvoiced > 0
              ? 'of ${_formatDashboardAmount(totalInvoiced)} invoiced'
              : null,
        ),
        FinanceKpi(
          id: 'today',
          value: _formatDashboardAmount(todayCollections),
          label: 'Collected Today',
          icon: Icons.today_outlined,
          accentName: 'success',
          detail: '${raw['todayCollectionCount'] ?? 0} transactions',
        ),
        FinanceKpi(
          id: 'active_students',
          value: '${raw['totalStudents'] ?? 0}',
          label: 'Open Fee Accounts',
          icon: Icons.groups_outlined,
          accentName: 'neutral',
        ),
        FinanceKpi(
          id: 'active_assignments',
          value: '${raw['activeFeeAssignments'] ?? 0}',
          label: 'Active Assignments',
          icon: Icons.assignment_outlined,
          accentName: 'neutral',
        ),
      ],
      collectionTrend: const [],
      recentPayments: _mapRecentCollections(
        raw['recentCollections'] as List<dynamic>? ?? const [],
      ),
    );
  }

  double _readAmount(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  String _formatDashboardAmount(double amount) {
    if (amount >= 100000) {
      final lakhs = amount / 100000;
      final formatted =
          lakhs % 1 == 0 ? lakhs.toStringAsFixed(0) : lakhs.toStringAsFixed(1);
      return '₹${formatted}L';
    }
    if (amount >= 1000) {
      final thousands = amount / 1000;
      final formatted = thousands % 1 == 0
          ? thousands.toStringAsFixed(0)
          : thousands.toStringAsFixed(1);
      return '₹${formatted}K';
    }
    return '₹${amount.toStringAsFixed(amount % 1 == 0 ? 0 : 0)}';
  }

  List<RecentPayment> _mapRecentCollections(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          RecentPayment(
            id: item['id'] as String? ?? '',
            studentName: item['studentName'] as String? ?? '',
            admissionNumber: '',
            amount: _formatDashboardAmount(_readAmount(item['amount'])),
            mode: _formatPaymentMethod(item['paymentMethod'] as String?),
            receiptNumber: item['receiptNumber'] as String? ?? '',
            collectedAt: item['collectionDate'] as String? ?? '',
            status: CollectionStatus.completed,
          ),
    ];
  }

  String _formatPaymentMethod(String? method) {
    if (method == null || method.isEmpty) return '';
    return method[0].toUpperCase() + method.substring(1).toLowerCase();
  }

  List<CollectionPayment> toCollections(FinanceCollectionsResponseDto dto) {
    return [for (final item in dto.items) toCollectionPayment(item)];
  }

  CollectionPayment toCollectionPayment(CollectionPaymentDto dto) {
    final raw = dto.raw;
    return CollectionPayment(
      id: raw['id'] as String? ?? '',
      receiptNumber: raw['receiptNumber'] as String? ?? '',
      studentName: raw['studentName'] as String? ?? '',
      admissionNumber: raw['admissionNumber'] as String? ?? '',
      amount: raw['amount'] as String? ?? '',
      mode: raw['mode'] as String? ?? '',
      collectedAt: raw['collectedAt'] as String? ?? '',
      collectedBy: raw['collectedBy'] as String? ?? '',
      status: FinanceEnumCodec.parseCollectionStatus(raw['status'] as String?),
      classLabel: raw['classLabel'] as String? ?? '',
    );
  }

  DailyCollectionSummary toDailySummary(DailyCollectionSummaryDto dto) {
    final raw = dto.raw;
    return DailyCollectionSummary(
      dateLabel: raw['dateLabel'] as String? ?? '',
      totalCollected: raw['totalCollected'] as String? ?? '',
      transactionCount: raw['transactionCount'] as int? ?? 0,
      cashAmount: raw['cashAmount'] as String? ?? '',
      upiAmount: raw['upiAmount'] as String? ?? '',
      pendingReconciliation: raw['pendingReconciliation'] as int? ?? 0,
    );
  }

  CollectionDetail? toCollectionDetail(CollectionDetailDto dto) {
    final raw = dto.raw;
    if (raw.isEmpty) return null;
    final paymentRaw = raw['payment'] as Map<String, dynamic>?;
    if (paymentRaw == null) return null;
    return CollectionDetail(
      payment: toCollectionPayment(CollectionPaymentDto.fromJson(paymentRaw)),
      feeAccountId: raw['feeAccountId'] as String? ?? '',
      aiInsight: raw['aiInsight'] as String? ?? '',
      summaryKpis: _mapKpis(raw['summaryKpis'] as List<dynamic>? ?? const []),
      paymentTimeline: _mapPaymentTimeline(
        raw['paymentTimeline'] as List<dynamic>? ?? const [],
      ),
      installmentHistory: _mapInstallmentHistory(
        raw['installmentHistory'] as List<dynamic>? ?? const [],
      ),
      receiptLinks: _mapReceiptLinks(
        raw['receiptLinks'] as List<dynamic>? ?? const [],
      ),
    );
  }

  FinanceCollectionResult toCollectionResult(FinanceCollectionResultDto dto) {
    final raw = dto.raw;
    final collectionRaw =
        raw['collection'] as Map<String, dynamic>? ?? const {};
    final receiptRaw = raw['receipt'] as Map<String, dynamic>? ?? const {};
    final invoiceRaw = raw['invoice'] as Map<String, dynamic>? ?? const {};
    return FinanceCollectionResult(
      collectionId: collectionRaw['id'] as String? ?? '',
      invoiceId: collectionRaw['invoiceId'] as String? ?? '',
      studentAccountId: collectionRaw['studentAccountId'] as String? ?? '',
      receiptNumber: collectionRaw['receiptNumber'] as String? ?? '',
      amountCollected: collectionRaw['amountCollected'] as String? ?? '',
      paymentMethod: collectionRaw['paymentMethod'] as String? ?? '',
      collectionDate: collectionRaw['collectionDate'] as String? ?? '',
      receipt: FinanceReceiptDetail(
        id: receiptRaw['id'] as String? ?? '',
        receiptNumber: receiptRaw['receiptNumber'] as String? ?? '',
        amount: receiptRaw['amount'] as String? ?? '',
        receiptDate: receiptRaw['receiptDate'] as String? ?? '',
        collectionId: receiptRaw['collectionId'] as String? ??
            collectionRaw['id'] as String? ??
            '',
        invoiceId: collectionRaw['invoiceId'] as String? ?? '',
        studentAccountId: collectionRaw['studentAccountId'] as String? ?? '',
      ),
      invoice: toFinanceInvoice(FinanceInvoiceDto.fromJson(invoiceRaw)),
    );
  }

  List<OfflinePaymentRecord> toOfflinePayments(OfflinePaymentsResponseDto dto) {
    return [for (final item in dto.items) toOfflinePayment(item)];
  }

  OfflinePaymentRecord toOfflinePayment(OfflinePaymentDto dto) {
    final raw = dto.raw;
    final amount =
        raw['amount_display'] as String? ?? raw['amount']?.toString() ?? '';
    return OfflinePaymentRecord(
      id: raw['id'] as String? ?? '',
      invoiceId:
          raw['invoiceId'] as String? ?? raw['invoice_id'] as String? ?? '',
      studentName:
          raw['studentName'] as String? ?? raw['student_name'] as String? ?? '',
      amount: amount,
      method: FinanceEnumCodec.parseOfflinePaymentMethod(
        raw['method'] as String? ?? raw['payment_method'] as String?,
      ),
      referenceNumber: raw['referenceNumber'] as String? ??
          raw['reference_number'] as String? ??
          '',
      recordedAt:
          raw['recordedAt'] as String? ?? raw['recorded_at'] as String? ?? '',
      status: FinanceEnumCodec.parseOfflinePaymentStatus(
        raw['status'] as String?,
      ),
      collectionId:
          raw['collectionId'] as String? ?? raw['collection_id'] as String?,
    );
  }

  QrPaymentSession toQrPaymentSession(QrPaymentSessionDto dto) {
    final raw = dto.raw;
    final expiresAtRaw =
        raw['expiresAt'] as String? ?? raw['expires_at'] as String? ?? '';
    final statusRaw = raw['status'] as String? ?? 'pending';
    return QrPaymentSession(
      id: raw['id'] as String? ?? '',
      invoiceId:
          raw['invoiceId'] as String? ?? raw['invoice_id'] as String? ?? '',
      amount: raw['amount'] as String? ?? '',
      upiPayload:
          raw['upiPayload'] as String? ?? raw['upi_payload'] as String? ?? '',
      status: switch (statusRaw.toLowerCase()) {
        'confirmed' => QrPaymentSessionStatus.confirmed,
        'expired' => QrPaymentSessionStatus.expired,
        _ => QrPaymentSessionStatus.pending,
      },
      expiresAt: DateTime.tryParse(expiresAtRaw) ?? DateTime.now(),
      receiptNumber:
          raw['receiptNumber'] as String? ?? raw['receipt_number'] as String?,
    );
  }

  List<FinanceFeeStructure> toFeeStructures(
    FinanceFeeStructuresResponseDto dto,
  ) {
    return [for (final item in dto.items) toFeeStructure(item)];
  }

  FinanceFeeStructure toFeeStructure(FinanceFeeStructureDto dto) {
    final raw = dto.raw;
    return FinanceFeeStructure(
      id: raw['id'] as String? ?? '',
      name: raw['name'] as String? ?? '',
      academicYear: raw['academicYear'] as String? ?? '',
      academicYearId: raw['academicYearId'] as String? ??
          raw['academic_year_id'] as String?,
      totalAnnual: raw['totalAnnual'] as String? ?? '',
      classRange: raw['classRange'] as String? ?? '',
      status: FinanceEnumCodec.parseFeeStructureStatus(
        raw['status'] as String?,
      ),
      installmentOptions: [
        for (final option
            in raw['installmentOptions'] as List<dynamic>? ?? const [])
          if (option is int) option else (option as num?)?.toInt() ?? 0,
      ],
      categories: _mapFeeCategories(
        raw['categories'] as List<dynamic>? ?? const [],
      ),
    );
  }

  List<String> toAcademicYears(FinanceAcademicYearsResponseDto dto) {
    return dto.items;
  }

  List<StudentFeeAccount> toStudentAccounts(
    StudentFeeAccountsResponseDto dto,
  ) {
    return [for (final item in dto.items) toStudentAccount(item)];
  }

  StudentFeeAccount toStudentAccount(StudentFeeAccountDto dto) {
    final raw = dto.raw;
    return StudentFeeAccount(
      id: raw['id'] as String? ?? '',
      studentName: raw['studentName'] as String? ?? '',
      admissionNumber: raw['admissionNumber'] as String? ?? '',
      classLabel: raw['classLabel'] as String? ?? '',
      feeStructureName: raw['feeStructureName'] as String? ?? '',
      totalDue: raw['totalDue'] as String? ?? '',
      totalPaid: raw['totalPaid'] as String? ?? '',
      balance: raw['balance'] as String? ?? '',
      status: FinanceEnumCodec.parseFeeAccountStatus(raw['status'] as String?),
      lastPaymentDate: raw['lastPaymentDate'] as String? ?? '',
      installmentPlan: raw['installmentPlan'] as String? ?? '',
    );
  }

  List<InstallmentPlan> toInstallmentPlans(
    FinanceFeeAssignmentResponseDto dto,
  ) {
    return [for (final item in dto.items) toInstallmentPlan(item)];
  }

  InstallmentPlan toInstallmentPlan(FeeAssignmentPlanDto dto) {
    final raw = dto.raw;
    return InstallmentPlan(
      id: raw['id'] as String? ?? '',
      label: raw['label'] as String? ?? '',
      installmentCount: raw['installmentCount'] as int? ?? 0,
      type: FinanceEnumCodec.parseInstallmentPlanType(raw['type'] as String?),
    );
  }

  DefaultersDashboardData toDefaultersDashboard(DefaultersDashboardDto dto) {
    final raw = dto.raw;
    return DefaultersDashboardData(
      kpis: _mapKpis(raw['kpis'] as List<dynamic>? ?? const []),
      agingBuckets: _mapAgingBuckets(
        raw['agingBuckets'] as List<dynamic>? ?? const [],
      ),
      defaulters:
          _mapDefaulters(raw['defaulters'] as List<dynamic>? ?? const []),
      aiInsight: raw['aiInsight'] as String? ?? '',
      aiActionLabel: raw['aiActionLabel'] as String? ?? '',
    );
  }

  List<RefundRequest> toRefundRequests(RefundRequestsResponseDto dto) {
    return [for (final item in dto.items) toRefundRequest(item)];
  }

  RefundRequest toRefundRequest(RefundRequestDto dto) {
    final raw = dto.raw;
    return RefundRequest(
      id: raw['id'] as String? ?? '',
      studentName: raw['studentName'] as String? ?? '',
      admissionNumber: raw['admissionNumber'] as String? ?? '',
      classLabel: raw['classLabel'] as String? ?? '',
      amount: raw['amount'] as String? ?? '',
      reason: raw['reason'] as String? ?? '',
      requestedAt: raw['requestedAt'] as String? ?? '',
      status: FinanceEnumCodec.parseRefundStatus(raw['status'] as String?),
      approver: raw['approver'] as String? ?? '',
      feeAccountId: raw['feeAccountId'] as String? ?? '',
      originalReceipt: raw['originalReceipt'] as String? ?? '',
      collectionId: raw['collectionId'] as String? ?? '',
      invoiceId: raw['invoiceId'] as String? ?? '',
    );
  }

  FinanceReceiptDetail? toReceiptDetail(FinanceReceiptResponseDto dto) {
    final raw = dto.raw;
    final receiptRaw = raw['receipt'] as Map<String, dynamic>? ?? raw;
    final receiptNumber = receiptRaw['receiptNumber'] as String? ?? '';
    if (receiptNumber.isEmpty && (receiptRaw['id'] as String? ?? '').isEmpty) {
      return null;
    }
    return FinanceReceiptDetail(
      id: receiptRaw['id'] as String? ?? '',
      receiptNumber: receiptNumber,
      amount: receiptRaw['amount'] as String? ?? '',
      receiptDate: receiptRaw['receiptDate'] as String? ?? '',
      collectionId: raw['collectionId'] as String? ??
          receiptRaw['collectionId'] as String? ??
          '',
      invoiceId: raw['invoiceId'] as String? ?? '',
      studentAccountId: raw['studentAccountId'] as String? ?? '',
    );
  }

  List<FinanceInvoice> toInvoices(FinanceInvoicesResponseDto dto) {
    return [for (final item in dto.items) toFinanceInvoice(item)];
  }

  FinanceInvoice toFinanceInvoice(FinanceInvoiceDto dto) {
    final raw = dto.raw;
    return FinanceInvoice(
      id: raw['id'] as String? ?? '',
      studentId: raw['studentId'] as String? ?? '',
      feeAssignmentId: raw['feeAssignmentId'] as String? ?? '',
      academicYear: raw['academicYear'] as String? ?? '',
      invoiceNumber: raw['invoiceNumber'] as String? ?? '',
      invoiceDate: raw['invoiceDate'] as String? ?? '',
      dueDate: raw['dueDate'] as String? ?? '',
      subtotalAmount: raw['subtotalAmount'] as String? ?? '0',
      discountAmount: raw['discountAmount'] as String? ?? '0',
      totalAmount: raw['totalAmount'] as String? ?? '0',
      outstandingAmount: raw['outstandingAmount'] as String? ?? '0',
      paidAmount: raw['paidAmount'] as String? ?? '0',
      invoiceStatus: FinanceEnumCodec.parseInvoiceStatus(
        raw['invoiceStatus'] as String?,
      ),
      termLabel: raw['termLabel'] as String? ?? 'Annual',
      createdBy: raw['createdBy'] as String? ?? '',
      createdAt: raw['createdAt'] as String? ?? '',
      updatedAt: raw['updatedAt'] as String? ?? '',
    );
  }

  InstallmentHistoryEntry toInstallmentHistory(FinanceInvoice invoice) {
    return InstallmentHistoryEntry(
      id: invoice.id,
      termLabel: invoice.termLabel,
      dueDate: invoice.dueDate,
      amount: invoice.totalAmount,
      paidAmount: invoice.paidAmount,
      status: FinanceEnumCodec.invoiceStatusToCollectionStatus(
        invoice.invoiceStatus,
      ),
    );
  }

  DiscountsDashboardData toDiscountsDashboard(DiscountsDashboardDto dto) {
    final raw = dto.raw;
    return DiscountsDashboardData(
      kpis: _mapKpis(raw['kpis'] as List<dynamic>? ?? const []),
      scholarships: _mapScholarships(
        raw['scholarships'] as List<dynamic>? ?? const [],
      ),
      rules: _mapDiscountRules(raw['rules'] as List<dynamic>? ?? const []),
      assignments: _mapDiscountAssignments(
        raw['assignments'] as List<dynamic>? ?? const [],
      ),
      impactSummary: raw['impactSummary'] as String? ?? '',
    );
  }

  FinanceReportsData toReports(FinanceReportsDto dto) {
    final raw = dto.raw;
    return FinanceReportsData(
      selectedReportId: raw['selectedReportId'] as String? ?? '',
      catalog: _mapReportCatalog(raw['catalog'] as List<dynamic>? ?? const []),
      collectionTrend: _mapReportTrend(
        raw['collectionTrend'] as List<dynamic>? ?? const [],
      ),
      outstandingTrend: _mapReportTrend(
        raw['outstandingTrend'] as List<dynamic>? ?? const [],
      ),
    );
  }

  FinanceSettingsData toSettings(FinanceSettingsDto dto) {
    final raw = dto.raw;
    return FinanceSettingsData(
      academicYear: raw['academicYear'] as String? ?? '',
      sections: _mapSettingsSections(
        raw['sections'] as List<dynamic>? ?? const [],
      ),
    );
  }

  List<FinanceKpi> _mapKpis(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          FinanceKpi(
            id: item['id'] as String? ?? '',
            value: item['value'] as String? ?? '',
            label: item['label'] as String? ?? '',
            icon: _kpiIcon(item['id'] as String? ?? ''),
            accentName: item['accentName'] as String? ?? 'neutral',
            detail: item['detail'] as String?,
          ),
    ];
  }

  List<CollectionTrendPoint> _mapCollectionTrend(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          CollectionTrendPoint(
            label: item['label'] as String? ?? '',
            amountLakhs: (item['amountLakhs'] as num?)?.toDouble() ?? 0,
            targetLakhs: (item['targetLakhs'] as num?)?.toDouble() ?? 0,
          ),
    ];
  }

  List<RecentPayment> _mapRecentPayments(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          RecentPayment(
            id: item['id'] as String? ?? '',
            studentName: item['studentName'] as String? ?? '',
            admissionNumber: item['admissionNumber'] as String? ?? '',
            amount: item['amount'] as String? ?? '',
            mode: item['mode'] as String? ?? '',
            receiptNumber: item['receiptNumber'] as String? ?? '',
            collectedAt: item['collectedAt'] as String? ?? '',
            status: FinanceEnumCodec.parseCollectionStatus(
              item['status'] as String?,
            ),
          ),
    ];
  }

  List<FeeCategoryLine> _mapFeeCategories(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          FeeCategoryLine(
            category: FinanceEnumCodec.parseFeeStructureCategory(
              item['category'] as String?,
            ),
            label: item['label'] as String? ?? '',
            amount: item['amount'] as String? ?? '',
          ),
    ];
  }

  List<PaymentTimelineEntry> _mapPaymentTimeline(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          PaymentTimelineEntry(
            id: item['id'] as String? ?? '',
            label: item['label'] as String? ?? '',
            amount: item['amount'] as String? ?? '',
            timestamp: item['timestamp'] as String? ?? '',
            status: FinanceEnumCodec.parseCollectionStatus(
              item['status'] as String?,
            ),
            mode: item['mode'] as String? ?? '',
          ),
    ];
  }

  List<InstallmentHistoryEntry> _mapInstallmentHistory(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          InstallmentHistoryEntry(
            id: item['id'] as String? ?? '',
            termLabel: item['termLabel'] as String? ?? '',
            dueDate: item['dueDate'] as String? ?? '',
            amount: item['amount'] as String? ?? '',
            paidAmount: item['paidAmount'] as String? ?? '',
            status: FinanceEnumCodec.parseCollectionStatus(
              item['status'] as String?,
            ),
          ),
    ];
  }

  List<ReceiptLink> _mapReceiptLinks(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          ReceiptLink(
            receiptNumber: item['receiptNumber'] as String? ?? '',
            amount: item['amount'] as String? ?? '',
            dateLabel: item['dateLabel'] as String? ?? '',
            parentReceiptRoute: item['parentReceiptRoute'] as String? ?? '',
          ),
    ];
  }

  List<AgingBucketSummary> _mapAgingBuckets(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          AgingBucketSummary(
            bucket: FinanceEnumCodec.parseDefaulterAgingBucket(
              item['bucket'] as String?,
            ),
            label: item['label'] as String? ?? '',
            studentCount: item['studentCount'] as int? ?? 0,
            totalAmount: item['totalAmount'] as String? ?? '',
          ),
    ];
  }

  List<DefaulterRecord> _mapDefaulters(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          DefaulterRecord(
            id: item['id'] as String? ?? '',
            studentName: item['studentName'] as String? ?? '',
            admissionNumber: item['admissionNumber'] as String? ?? '',
            classLabel: item['classLabel'] as String? ?? '',
            overdueAmount: item['overdueAmount'] as String? ?? '',
            daysOverdue: item['daysOverdue'] as int? ?? 0,
            bucket: FinanceEnumCodec.parseDefaulterAgingBucket(
              item['bucket'] as String?,
            ),
            lastContact: item['lastContact'] as String? ?? '',
            collectionProbability: item['collectionProbability'] as int? ?? 0,
            feeAccountId: item['feeAccountId'] as String? ?? '',
            guardianPhone: item['guardianPhone'] as String? ??
                item['phone'] as String? ??
                '',
            contactHistory: _mapContactHistory(
              item['contactHistory'] as List<dynamic>? ?? const [],
            ),
          ),
    ];
  }

  List<ContactHistoryEntry> _mapContactHistory(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          ContactHistoryEntry(
            id: item['id'] as String? ?? '',
            timestamp: item['timestamp'] as String? ?? '',
            channel: item['channel'] as String? ?? '',
            outcome: item['outcome'] as String? ?? '',
            notes: item['notes'] as String? ?? '',
          ),
    ];
  }

  ScholarshipCatalogItem toScholarship(ScholarshipDto dto) {
    return _mapScholarship(dto.raw);
  }

  List<ScholarshipCatalogItem> _mapScholarships(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>) _mapScholarship(item),
    ];
  }

  ScholarshipCatalogItem _mapScholarship(Map<String, dynamic> item) {
    return ScholarshipCatalogItem(
      id: item['id'] as String? ?? '',
      name: item['name'] as String? ?? '',
      type: FinanceEnumCodec.parseScholarshipType(item['type'] as String?),
      maxDiscount: item['maxDiscount'] as String? ??
          item['max_discount'] as String? ??
          '',
      eligibility: item['eligibility'] as String? ?? '',
      activeAssignments: item['activeAssignments'] as int? ??
          item['active_assignments'] as int? ??
          0,
    );
  }

  DiscountRule toDiscountRule(DiscountRuleDto dto) => _mapDiscountRule(dto.raw);

  List<DiscountRule> _mapDiscountRules(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>) _mapDiscountRule(item),
    ];
  }

  DiscountRule _mapDiscountRule(Map<String, dynamic> item) {
    return DiscountRule(
      id: item['id'] as String? ?? '',
      name: item['name'] as String? ?? '',
      discountPercent: item['discountPercent'] as String? ??
          item['discount_percent']?.toString() ??
          '',
      appliesTo: item['appliesTo'] as String? ??
          item['applies_to'] as String? ??
          '',
      status: FinanceEnumCodec.parseDiscountApprovalStatus(
        item['status'] as String?,
      ),
    );
  }

  List<StudentDiscountAssignment> _mapDiscountAssignments(
    List<dynamic> items,
  ) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          StudentDiscountAssignment(
            id: item['id'] as String? ?? '',
            studentName: item['studentName'] as String? ?? '',
            admissionNumber: item['admissionNumber'] as String? ?? '',
            scholarshipName: item['scholarshipName'] as String? ?? '',
            discountAmount: item['discountAmount'] as String? ?? '',
            status: FinanceEnumCodec.parseDiscountApprovalStatus(
              item['status'] as String?,
            ),
            impactOnFees: item['impactOnFees'] as String? ?? '',
          ),
    ];
  }

  List<FinanceReportCatalogItem> _mapReportCatalog(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          FinanceReportCatalogItem(
            id: item['id'] as String? ?? '',
            title: item['title'] as String? ?? '',
            description: item['description'] as String? ?? '',
            type: FinanceEnumCodec.parseFinanceReportType(
              item['type'] as String?,
            ),
            lastGenerated: item['lastGenerated'] as String? ?? '',
          ),
    ];
  }

  List<FinanceReportTrendPoint> _mapReportTrend(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          FinanceReportTrendPoint(
            label: item['label'] as String? ?? '',
            value: (item['value'] as num?)?.toDouble() ?? 0,
            target: (item['target'] as num?)?.toDouble() ?? 0,
          ),
    ];
  }

  List<FinanceSettingsSection> _mapSettingsSections(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          FinanceSettingsSection(
            id: item['id'] as String? ?? '',
            title: item['title'] as String? ?? '',
            items:
                _mapSettingItems(item['items'] as List<dynamic>? ?? const []),
          ),
    ];
  }

  List<FinanceSettingItem> _mapSettingItems(List<dynamic> items) {
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          FinanceSettingItem(
            id: item['id'] as String? ?? '',
            label: item['label'] as String? ?? '',
            value: item['value'] as String? ?? '',
            description: item['description'] as String? ?? '',
            editable: item['editable'] as bool? ?? false,
          ),
    ];
  }

  IconData _kpiIcon(String id) => switch (id) {
        'collected_mtd' => Icons.payments_outlined,
        'outstanding' => Icons.pending_actions_outlined,
        'defaulters' || 'defaulter_count' => Icons.warning_amber_outlined,
        'collection_rate' => Icons.trending_up,
        'today' || 'daily_total' => Icons.today_outlined,
        'pending_handoffs' => Icons.swap_horiz_outlined,
        'total_overdue' => Icons.warning_amber_outlined,
        'critical' => Icons.priority_high,
        'followups' => Icons.phone_in_talk_outlined,
        'active_scholarships' => Icons.school_outlined,
        'assigned' => Icons.people_outline,
        'pending_approval' => Icons.pending_actions_outlined,
        'impact' => Icons.savings_outlined,
        'amount' => Icons.payments_outlined,
        'balance' => Icons.account_balance_wallet_outlined,
        'installments' => Icons.calendar_month_outlined,
        'mode' => Icons.credit_card_outlined,
        _ => Icons.insights_outlined,
      };
}
