// SCE-1 slice 4 — client models for the Student Clearance / No-Dues report and
// the dues-waiver maker-checker flow. Mirrors the server envelopes
// (supabase/functions/_shared/clearance/*).

/// One module's contribution to a student's clearance.
class ClearanceContribution {
  const ClearanceContribution({
    required this.module,
    required this.status,
    required this.policy,
    required this.amount,
    this.items = const [],
  });

  final String module; // 'finance' | 'inventory' | 'library' | 'hostel'
  final String status; // 'cleared' | 'pending' | 'not_tracked'
  final String policy; // 'blocking' | 'advisory'
  final double amount;
  final List<ClearanceItem> items;

  bool get isPending => status == 'pending';
  bool get isNotTracked => status == 'not_tracked';

  factory ClearanceContribution.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return ClearanceContribution(
      module: (json['module'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      policy: (json['policy'] ?? 'advisory').toString(),
      amount: _asDouble(json['amount']),
      items: [
        if (rawItems is List)
          for (final i in rawItems)
            if (i is Map) ClearanceItem.fromJson(i.cast<String, dynamic>()),
      ],
    );
  }
}

class ClearanceItem {
  const ClearanceItem({required this.description, required this.amount});
  final String description;
  final double amount;

  factory ClearanceItem.fromJson(Map<String, dynamic> json) => ClearanceItem(
        description: (json['description'] ?? '').toString(),
        amount: _asDouble(json['amount']),
      );
}

/// The consolidated no-dues report for a student + lifecycle.
class ClearanceReport {
  const ClearanceReport({
    required this.studentId,
    required this.lifecycle,
    required this.blocked,
    required this.blockingAmount,
    required this.totalOutstanding,
    required this.contributions,
    required this.notTracked,
  });

  final String studentId;
  final String lifecycle;
  final bool blocked;
  final double blockingAmount;
  final double totalOutstanding;
  final List<ClearanceContribution> contributions;
  final List<String> notTracked;

  factory ClearanceReport.fromJson(Map<String, dynamic> json) {
    final rawContribs = json['contributions'];
    final rawNot = json['notTracked'];
    return ClearanceReport(
      studentId: (json['studentId'] ?? '').toString(),
      lifecycle: (json['lifecycle'] ?? '').toString(),
      blocked: json['blocked'] == true,
      blockingAmount: _asDouble(json['blockingAmount']),
      totalOutstanding: _asDouble(json['totalOutstanding']),
      contributions: [
        if (rawContribs is List)
          for (final c in rawContribs)
            if (c is Map) ClearanceContribution.fromJson(c.cast<String, dynamic>()),
      ],
      notTracked: [
        if (rawNot is List)
          for (final m in rawNot) m.toString(),
      ],
    );
  }
}

/// A dues-waiver (maker-checker).
class ClearanceWaiver {
  const ClearanceWaiver({
    required this.id,
    required this.studentId,
    required this.lifecycle,
    required this.reason,
    required this.amount,
    required this.status,
    required this.makerId,
    this.checkerId,
    this.createdAt,
  });

  final String id;
  final String studentId;
  final String lifecycle;
  final String reason;
  final double amount;
  final String status; // pending | approved | rejected | consumed
  final String makerId;
  final String? checkerId;
  final String? createdAt;

  factory ClearanceWaiver.fromJson(Map<String, dynamic> json) => ClearanceWaiver(
        id: (json['id'] ?? '').toString(),
        studentId: (json['studentId'] ?? '').toString(),
        lifecycle: (json['lifecycle'] ?? '').toString(),
        reason: (json['reason'] ?? '').toString(),
        amount: _asDouble(json['amount']),
        status: (json['status'] ?? '').toString(),
        makerId: (json['makerId'] ?? '').toString(),
        checkerId: (json['checkerId'])?.toString(),
        createdAt: (json['createdAt'])?.toString(),
      );
}

double _asDouble(dynamic v) => v == null ? 0 : (v as num).toDouble();
