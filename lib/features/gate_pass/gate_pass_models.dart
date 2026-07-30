// PRC-A client — Gate Pass / early pickup models. Mirrors the server
// envelope (supabase/functions/_shared/gate_pass/gate_pass_handlers.ts
// `gatePassToApi`). The API never returns the OTP/QR credential itself — only
// a `hasCredential` boolean — so this model has no field for it either.

const gatePassTypes = <String>['early_pickup', 'late_arrival', 'authorized_exit'];

const gatePassStatuses = <String>[
  'pending',
  'approved',
  'rejected',
  'used',
  'expired',
  'cancelled',
];

String gatePassTypeLabel(String type) => switch (type) {
      'early_pickup' => 'Early pickup',
      'late_arrival' => 'Late arrival',
      'authorized_exit' => 'Authorized exit',
      _ => type,
    };

String gatePassStatusLabel(String status) => switch (status) {
      'pending' => 'Pending',
      'approved' => 'Approved',
      'rejected' => 'Rejected',
      'used' => 'Used',
      'expired' => 'Expired',
      'cancelled' => 'Cancelled',
      _ => status,
    };

class GatePass {
  const GatePass({
    required this.id,
    required this.studentId,
    required this.passType,
    required this.reason,
    required this.requestedBy,
    required this.pickupPersonName,
    required this.pickupPersonRelation,
    required this.pickupPersonPhone,
    required this.scheduledAt,
    required this.status,
    required this.rawStatus,
    this.approvalRequestId,
    this.hasCredential = false,
    this.credentialExpiresAt,
    this.verifiedBy,
    this.verifiedAt,
    this.verificationNote,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String studentId;

  /// early_pickup | late_arrival | authorized_exit
  final String passType;
  final String reason;
  final String requestedBy;
  final String pickupPersonName;
  final String pickupPersonRelation;
  final String pickupPersonPhone;
  final String scheduledAt;

  /// The EFFECTIVE status: an `approved` pass whose credential has expired is
  /// already reported as `expired` here (lazy expiry — see the repository).
  final String status;

  /// The raw DB status before the lazy-expiry projection (server diagnostics
  /// only; prefer [status] for display).
  final String rawStatus;
  final String? approvalRequestId;

  /// True once approved and a credential was minted — never the credential
  /// itself, which the API never returns.
  final bool hasCredential;
  final String? credentialExpiresAt;
  final String? verifiedBy;
  final String? verifiedAt;
  final String? verificationNote;
  final String? createdAt;
  final String? updatedAt;

  bool get isPending => status == 'pending';

  /// Approved + not yet expired — the only state a credential may be verified in.
  bool get isVerifiable => status == 'approved';
  bool get isExpired => status == 'expired';
  bool get isUsed => status == 'used';

  /// A pending or approved pass may still be withdrawn.
  bool get isCancellable => status == 'pending' || status == 'approved';

  factory GatePass.fromJson(Map<String, dynamic> json) => GatePass(
        id: (json['id'] ?? '').toString(),
        studentId: (json['studentId'] ?? '').toString(),
        passType: (json['passType'] ?? '').toString(),
        reason: (json['reason'] ?? '').toString(),
        requestedBy: (json['requestedBy'] ?? '').toString(),
        pickupPersonName: (json['pickupPersonName'] ?? '').toString(),
        pickupPersonRelation: (json['pickupPersonRelation'] ?? '').toString(),
        pickupPersonPhone: (json['pickupPersonPhone'] ?? '').toString(),
        scheduledAt: (json['scheduledAt'] ?? '').toString(),
        status: (json['status'] ?? '').toString(),
        rawStatus: (json['rawStatus'] ?? json['status'] ?? '').toString(),
        approvalRequestId: json['approvalRequestId']?.toString(),
        hasCredential: json['hasCredential'] == true,
        credentialExpiresAt: json['credentialExpiresAt']?.toString(),
        verifiedBy: json['verifiedBy']?.toString(),
        verifiedAt: json['verifiedAt']?.toString(),
        verificationNote: json['verificationNote']?.toString(),
        createdAt: json['createdAt']?.toString(),
        updatedAt: json['updatedAt']?.toString(),
      );
}
