import '../i18n/supported_languages.dart';
import 'teacher_parent_templates.dart';

/// Delivery channels for teacher → parent communication.
enum ParentCommunicationChannel {
  inApp,
  push,
  whatsApp,
}

extension ParentCommunicationChannelLabel on ParentCommunicationChannel {
  String get label => switch (this) {
        ParentCommunicationChannel.inApp => 'In-App',
        ParentCommunicationChannel.push => 'Push',
        ParentCommunicationChannel.whatsApp => 'WhatsApp',
      };
}

enum ParentCommunicationDeliveryStatus {
  pending,
  delivered,
  read,
  acknowledged,
}

/// A message in the student communication timeline.
class ParentCommunicationRecord {
  const ParentCommunicationRecord({
    required this.id,
    required this.sisStudentId,
    required this.studentName,
    required this.senderName,
    required this.reason,
    required this.tone,
    required this.originalMessage,
    required this.translatedMessage,
    required this.targetLanguage,
    required this.channels,
    required this.sentAt,
    required this.deliveryStatus,
    this.readAt,
    this.acknowledgedAt,
    this.parentPhone,
    this.usedAi = false,
    this.sourceConcernId,
  });

  final String id;
  final String sisStudentId;
  final String studentName;
  final String senderName;
  final ParentCommunicationReason reason;
  final ParentCommunicationTone tone;
  final String originalMessage;
  final String translatedMessage;
  final AksharaLanguage targetLanguage;
  final List<ParentCommunicationChannel> channels;
  final DateTime sentAt;
  final ParentCommunicationDeliveryStatus deliveryStatus;
  final DateTime? readAt;
  final DateTime? acknowledgedAt;
  final String? parentPhone;
  final bool usedAi;
  final String? sourceConcernId;

  String get parentFacingBody => translatedMessage;

  bool get includesWhatsApp =>
      channels.contains(ParentCommunicationChannel.whatsApp);

  bool get includesInApp =>
      channels.contains(ParentCommunicationChannel.inApp);

  bool get isAcknowledged =>
      deliveryStatus == ParentCommunicationDeliveryStatus.acknowledged;

  String get deliveryStatusLabel => switch (deliveryStatus) {
        ParentCommunicationDeliveryStatus.pending => 'Pending',
        ParentCommunicationDeliveryStatus.delivered => 'Delivered',
        ParentCommunicationDeliveryStatus.read => 'Read',
        ParentCommunicationDeliveryStatus.acknowledged => 'Acknowledged',
      };

  String get channelsLabel =>
      channels.map((channel) => channel.label).join(', ');

  ParentCommunicationRecord copyWith({
    ParentCommunicationDeliveryStatus? deliveryStatus,
    DateTime? readAt,
    DateTime? acknowledgedAt,
  }) {
    return ParentCommunicationRecord(
      id: id,
      sisStudentId: sisStudentId,
      studentName: studentName,
      senderName: senderName,
      reason: reason,
      tone: tone,
      originalMessage: originalMessage,
      translatedMessage: translatedMessage,
      targetLanguage: targetLanguage,
      channels: channels,
      sentAt: sentAt,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      readAt: readAt ?? this.readAt,
      acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
      parentPhone: parentPhone,
      usedAi: usedAi,
      sourceConcernId: sourceConcernId,
    );
  }
}

/// Parent inbox row derived from [ParentCommunicationRecord].
class ParentCommunicationInboxItem {
  const ParentCommunicationInboxItem({
    required this.id,
    required this.sisStudentId,
    required this.studentName,
    required this.senderName,
    required this.reasonLabel,
    required this.originalMessage,
    required this.translatedMessage,
    required this.targetLanguage,
    required this.channels,
    required this.sentAt,
    required this.sentAtLabel,
    required this.deliveryStatus,
    required this.isUnread,
    this.readAt,
    this.acknowledgedAt,
  });

  final String id;
  final String sisStudentId;
  final String studentName;
  final String senderName;
  final String reasonLabel;
  final String originalMessage;
  final String translatedMessage;
  final AksharaLanguage targetLanguage;
  final List<ParentCommunicationChannel> channels;
  final DateTime sentAt;
  final String sentAtLabel;
  final ParentCommunicationDeliveryStatus deliveryStatus;
  final bool isUnread;
  final DateTime? readAt;
  final DateTime? acknowledgedAt;

  String get displayBody => translatedMessage;

  String get deliveryStatusLabel => switch (deliveryStatus) {
        ParentCommunicationDeliveryStatus.pending => 'Pending',
        ParentCommunicationDeliveryStatus.delivered => 'Delivered',
        ParentCommunicationDeliveryStatus.read => 'Read',
        ParentCommunicationDeliveryStatus.acknowledged => 'Acknowledged',
      };

  String get channelsLabel =>
      channels.map((channel) => channel.label).join(', ');
}

class ParentCommunicationSendRequest {
  const ParentCommunicationSendRequest({
    required this.sisStudentId,
    required this.reason,
    required this.tone,
    required this.channels,
    this.customMessage,
    this.useAi = false,
    this.sourceConcernId,
  });

  final String sisStudentId;
  final ParentCommunicationReason reason;
  final ParentCommunicationTone tone;
  final Set<ParentCommunicationChannel> channels;
  final String? customMessage;
  final bool useAi;
  final String? sourceConcernId;
}

class ParentCommunicationSendResult {
  const ParentCommunicationSendResult({
    required this.record,
    this.whatsAppLaunchUri,
  });

  final ParentCommunicationRecord record;
  final String? whatsAppLaunchUri;
}

/// Subject-specific concern categories for escalation to class teacher.
enum SubjectConcernCategory {
  lowMarks,
  homeworkNotSubmitted,
  participationIssue,
  labPerformance,
  assignmentIssue,
  disciplineObservation,
  other,
}

extension SubjectConcernCategoryLabel on SubjectConcernCategory {
  String get label => switch (this) {
        SubjectConcernCategory.lowMarks => 'Low marks',
        SubjectConcernCategory.homeworkNotSubmitted => 'Homework not submitted',
        SubjectConcernCategory.participationIssue => 'Participation issue',
        SubjectConcernCategory.labPerformance => 'Lab performance',
        SubjectConcernCategory.assignmentIssue => 'Assignment issue',
        SubjectConcernCategory.disciplineObservation => 'Behaviour observation',
        SubjectConcernCategory.other => 'Other observation',
      };

  ParentCommunicationReason get suggestedReason => switch (this) {
        SubjectConcernCategory.lowMarks => ParentCommunicationReason.marksLow,
        SubjectConcernCategory.homeworkNotSubmitted ||
        SubjectConcernCategory.assignmentIssue =>
          ParentCommunicationReason.homeworkMissing,
        SubjectConcernCategory.disciplineObservation =>
          ParentCommunicationReason.disciplineIssue,
        _ => ParentCommunicationReason.generalProgress,
      };
}

enum SubjectConcernStatus {
  pendingClassTeacherReview,
  sentToParent,
  dismissed,
}

/// Subject teacher flags concern — class teacher must review before parent contact.
class SubjectTeacherConcern {
  const SubjectTeacherConcern({
    required this.id,
    required this.sisStudentId,
    required this.studentName,
    required this.classLabel,
    required this.flaggedByTeacherId,
    required this.flaggedByTeacherName,
    required this.subject,
    required this.category,
    required this.observation,
    required this.status,
    required this.flaggedAt,
    this.reviewedAt,
    this.resolvedCommunicationId,
    this.auditTrail = const [],
  });

  final String id;
  final String sisStudentId;
  final String studentName;
  final String classLabel;
  final String flaggedByTeacherId;
  final String flaggedByTeacherName;
  final String subject;
  final SubjectConcernCategory category;
  final String observation;
  final SubjectConcernStatus status;
  final DateTime flaggedAt;
  final DateTime? reviewedAt;
  final String? resolvedCommunicationId;
  final List<String> auditTrail;

  bool get isPending =>
      status == SubjectConcernStatus.pendingClassTeacherReview;

  SubjectTeacherConcern copyWith({
    SubjectConcernStatus? status,
    DateTime? reviewedAt,
    String? resolvedCommunicationId,
    List<String>? auditTrail,
  }) {
    return SubjectTeacherConcern(
      id: id,
      sisStudentId: sisStudentId,
      studentName: studentName,
      classLabel: classLabel,
      flaggedByTeacherId: flaggedByTeacherId,
      flaggedByTeacherName: flaggedByTeacherName,
      subject: subject,
      category: category,
      observation: observation,
      status: status ?? this.status,
      flaggedAt: flaggedAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      resolvedCommunicationId:
          resolvedCommunicationId ?? this.resolvedCommunicationId,
      auditTrail: auditTrail ?? this.auditTrail,
    );
  }
}

class SubjectTeacherConcernFlagRequest {
  const SubjectTeacherConcernFlagRequest({
    required this.sisStudentId,
    required this.category,
    required this.observation,
    required this.flaggedByTeacherId,
    required this.flaggedByTeacherName,
    required this.subject,
  });

  final String sisStudentId;
  final SubjectConcernCategory category;
  final String observation;
  final String flaggedByTeacherId;
  final String flaggedByTeacherName;
  final String subject;
}

class SubjectTeacherConcernFlagResult {
  const SubjectTeacherConcernFlagResult({required this.concern});

  final SubjectTeacherConcern concern;
}

