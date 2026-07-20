// PRC-A client — Certificate Request Desk models. Mirrors the server
// envelope (supabase/functions/_shared/certificate_desk/certificate_desk_handlers.ts
// `certificateRequestToApi`). Approve/reject is NOT modeled here — it happens
// through the existing F2 approvals queue (type `certificateRequest`); this
// module only raises, lists, and cancels requests.

const certificateRequestTypes = <String>['bonafide', 'study', 'conduct', 'transfer', 'fee'];

const certificateRequestStatuses = <String>[
  'pending',
  'approved',
  'rejected',
  'issued',
  'blocked_dues',
  'cancelled',
];

String certificateTypeLabel(String type) => switch (type) {
      'bonafide' => 'Bonafide',
      'study' => 'Study',
      'conduct' => 'Conduct',
      'transfer' => 'Transfer',
      'fee' => 'Fee',
      _ => type,
    };

String certificateStatusLabel(String status) => switch (status) {
      'pending' => 'Pending',
      'approved' => 'Approved',
      'rejected' => 'Rejected',
      'issued' => 'Issued',
      'blocked_dues' => 'Blocked — dues pending',
      'cancelled' => 'Cancelled',
      _ => status,
    };

class CertificateRequest {
  const CertificateRequest({
    required this.id,
    required this.studentId,
    required this.certificateType,
    required this.purpose,
    required this.status,
    required this.requestedBy,
    required this.requestedByRole,
    this.approvalRequestId,
    this.issuedCertificateId,
    this.issueNote = '',
    this.decidedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String studentId;

  /// bonafide | study | conduct | transfer | fee
  final String certificateType;
  final String purpose;

  /// pending | approved | rejected | issued | blocked_dues | cancelled
  final String status;
  final String requestedBy;
  final String requestedByRole;
  final String? approvalRequestId;
  final String? issuedCertificateId;

  /// Populated when [status] is `blocked_dues` (why the certificate was NOT
  /// issued — a real outstanding-dues reason, never a catch-all) or when the
  /// approval was rejected with a comment.
  final String issueNote;
  final String? decidedAt;
  final String? createdAt;
  final String? updatedAt;

  bool get isPending => status == 'pending';
  bool get isBlockedDues => status == 'blocked_dues';
  bool get isIssued => status == 'issued';

  /// Only a pending request can be withdrawn.
  bool get isCancellable => status == 'pending';

  factory CertificateRequest.fromJson(Map<String, dynamic> json) => CertificateRequest(
        id: (json['id'] ?? '').toString(),
        studentId: (json['studentId'] ?? '').toString(),
        certificateType: (json['certificateType'] ?? '').toString(),
        purpose: (json['purpose'] ?? '').toString(),
        status: (json['status'] ?? '').toString(),
        requestedBy: (json['requestedBy'] ?? '').toString(),
        requestedByRole: (json['requestedByRole'] ?? '').toString(),
        approvalRequestId: json['approvalRequestId']?.toString(),
        issuedCertificateId: json['issuedCertificateId']?.toString(),
        issueNote: (json['issueNote'] ?? '').toString(),
        decidedAt: json['decidedAt']?.toString(),
        createdAt: json['createdAt']?.toString(),
        updatedAt: json['updatedAt']?.toString(),
      );
}
