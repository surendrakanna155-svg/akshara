import 'leave/leave_models.dart';
import 'payment/payment_models.dart';

/// Domain request to submit a leave application for a child.
class ParentLeaveSubmitRequest {
  const ParentLeaveSubmitRequest({
    required this.childId,
    required this.fromDateLabel,
    required this.toDateLabel,
    required this.reason,
    this.type = LeaveType.sick,
    this.hasAttachment = false,
    this.attachmentName,
  });

  final String childId;
  final String fromDateLabel;
  final String toDateLabel;
  final String reason;
  final LeaveType type;
  final bool hasAttachment;
  final String? attachmentName;
}

/// Result of cancelling a pending leave (PAR-D1). Mirrors the backend
/// `POST /parent/leave/:id/cancel` envelope `{ id, status }`.
class ParentLeaveCancelResult {
  const ParentLeaveCancelResult({
    required this.id,
    required this.status,
  });

  final String id;
  final LeaveStatus status;
}

/// Result of attaching a medical-cert reference to a pending leave (PAR-3).
/// Mirrors the backend `POST /parent/leave/:id/attachment` envelope
/// `{ id, hasAttachment, attachmentName }`.
class ParentLeaveAttachmentResult {
  const ParentLeaveAttachmentResult({
    required this.id,
    required this.hasAttachment,
    required this.attachmentName,
  });

  final String id;
  final bool hasAttachment;
  final String attachmentName;
}

/// Domain request to initiate an online fee payment.
class ParentPaymentInitiateRequest {
  const ParentPaymentInitiateRequest({
    required this.installmentId,
    required this.paymentMethod,
    required this.amount,
  });

  final String installmentId;
  final PaymentMethod paymentMethod;
  final int amount;
}

/// Domain request to confirm a payment after gateway callback.
class ParentPaymentConfirmRequest {
  const ParentPaymentConfirmRequest({
    required this.paymentIntentId,
    required this.transactionRef,
  });

  final String paymentIntentId;
  final String transactionRef;
}

/// Domain request to send a parent message to a teacher.
class ParentMessageSendRequest {
  const ParentMessageSendRequest({
    required this.recipient,
    required this.subject,
    required this.body,
    this.threadId,
  });

  final String recipient;
  final String subject;
  final String body;
  final String? threadId;
}

/// Parent request to dispute / correct recorded attendance.
class ParentAttendanceCorrectionRequest {
  const ParentAttendanceCorrectionRequest({
    required this.sisStudentId,
    required this.childName,
    required this.classLabel,
    required this.dateLabel,
    required this.fromMark,
    required this.toMark,
    required this.reason,
  });

  final String sisStudentId;
  final String childName;
  final String classLabel;
  final String dateLabel;
  final String fromMark;
  final String toMark;
  final String reason;
}

class ParentAttendanceCorrectionResult {
  const ParentAttendanceCorrectionResult({
    required this.correctionId,
    required this.approvalId,
  });

  final String correctionId;
  final String approvalId;
}
