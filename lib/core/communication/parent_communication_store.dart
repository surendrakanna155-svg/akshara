import '../repositories/mock/mock_canonical_student_registry.dart';
import '../i18n/supported_languages.dart';
import '../i18n/translation_service.dart';
import 'parent_communication_models.dart';
import 'teacher_parent_templates.dart';

/// In-memory store for teacher → parent communications and delivery tracking.
final class ParentCommunicationStore {
  ParentCommunicationStore._();

  static final ParentCommunicationStore instance = ParentCommunicationStore._();

  final List<ParentCommunicationRecord> _timeline = [];
  final Map<String, AksharaLanguage> _parentLanguageByStudent = {
    MockCanonicalStudentRegistry.primaryMobileStudentId: AksharaLanguage.telugu,
  };
  int _idSeq = 0;

  void reset() {
    _timeline.clear();
    _idSeq = 0;
  }

  List<ParentCommunicationRecord> timelineForStudent(String sisStudentId) {
    return _timeline
        .where((record) => record.sisStudentId == sisStudentId)
        .toList(growable: false);
  }

  ParentCommunicationRecord? recordById(String communicationId) {
    for (final record in _timeline) {
      if (record.id == communicationId) return record;
    }
    return null;
  }

  List<ParentCommunicationRecord> allRecords() =>
      List.unmodifiable(_timeline);

  AksharaLanguage preferredLanguageForStudent(String sisStudentId) =>
      _parentLanguageByStudent[sisStudentId] ?? AksharaLanguage.english;

  void setPreferredLanguage({
    required String sisStudentId,
    required AksharaLanguage language,
  }) {
    _parentLanguageByStudent[sisStudentId] = language;
  }

  ParentCommunicationSendResult send({
    required ParentCommunicationSendRequest request,
    required String senderName,
    String? parentPhone,
    String? sourceConcernId,
  }) {
    final student = MockCanonicalStudentRegistry.byId(request.sisStudentId);
    if (student == null) {
      throw StateError('Student not found: ${request.sisStudentId}');
    }

    final language = preferredLanguageForStudent(request.sisStudentId);
    final english = request.useAi && request.customMessage != null
        ? request.customMessage!.trim()
        : TeacherParentTemplates.resolve(
            reason: request.reason,
            tone: request.tone,
            studentName: student.studentName,
          );

    final pair = TranslationService.instance.pair(
      englishText: english,
      target: language,
    );

    final id = 'comm_${++_idSeq}';
    final record = ParentCommunicationRecord(
      id: id,
      sisStudentId: student.sisStudentId,
      studentName: student.studentName,
      senderName: senderName,
      reason: request.reason,
      tone: request.tone,
      originalMessage: pair.original,
      translatedMessage: pair.translated,
      targetLanguage: language,
      channels: request.channels.toList(growable: false),
      sentAt: DateTime.now(),
      deliveryStatus: ParentCommunicationDeliveryStatus.delivered,
      parentPhone: parentPhone,
      usedAi: request.useAi,
      sourceConcernId: sourceConcernId ?? request.sourceConcernId,
    );
    _timeline.insert(0, record);

    String? whatsAppUri;
    if (request.channels.contains(ParentCommunicationChannel.whatsApp) &&
        parentPhone != null &&
        parentPhone.isNotEmpty) {
      final digits = parentPhone.replaceAll(RegExp(r'[^\d]'), '');
      final encoded = Uri.encodeComponent(pair.translated);
      whatsAppUri = 'https://wa.me/$digits?text=$encoded';
    }

    return ParentCommunicationSendResult(
      record: record,
      whatsAppLaunchUri: whatsAppUri,
    );
  }

  void markRead(String communicationId) {
    final index = _timeline.indexWhere((r) => r.id == communicationId);
    if (index < 0) return;
    final existing = _timeline[index];
    if (existing.deliveryStatus == ParentCommunicationDeliveryStatus.acknowledged) {
      return;
    }
    _timeline[index] = existing.copyWith(
      deliveryStatus: ParentCommunicationDeliveryStatus.read,
      readAt: DateTime.now(),
    );
  }

  void markAcknowledged(String communicationId) {
    final index = _timeline.indexWhere((r) => r.id == communicationId);
    if (index < 0) return;
    final existing = _timeline[index];
    _timeline[index] = existing.copyWith(
      deliveryStatus: ParentCommunicationDeliveryStatus.acknowledged,
      readAt: existing.readAt ?? DateTime.now(),
      acknowledgedAt: DateTime.now(),
    );
  }

  List<ParentCommunicationInboxItem> inboxForStudent(String sisStudentId) {
    return [
      for (final record in timelineForStudent(sisStudentId))
        _toInboxItem(record),
    ];
  }

  ParentCommunicationInboxItem? inboxItemById(String communicationId) {
    final record = recordById(communicationId);
    if (record == null) return null;
    return _toInboxItem(record);
  }

  ParentCommunicationInboxItem _toInboxItem(ParentCommunicationRecord record) {
    final isUnread = record.deliveryStatus ==
            ParentCommunicationDeliveryStatus.delivered ||
        record.deliveryStatus == ParentCommunicationDeliveryStatus.pending;
    return ParentCommunicationInboxItem(
      id: record.id,
      sisStudentId: record.sisStudentId,
      studentName: record.studentName,
      senderName: record.senderName,
      reasonLabel: record.reason.label,
      originalMessage: record.originalMessage,
      translatedMessage: record.translatedMessage,
      targetLanguage: record.targetLanguage,
      channels: record.channels,
      sentAt: record.sentAt,
      sentAtLabel: _formatSentAt(record.sentAt),
      deliveryStatus: record.deliveryStatus,
      isUnread: isUnread,
      readAt: record.readAt,
      acknowledgedAt: record.acknowledgedAt,
    );
  }

  String _formatSentAt(DateTime sentAt) {
    final diff = DateTime.now().difference(sentAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes} min ago';
    if (diff.inDays < 1) return '${diff.inHours} hr ago';
    if (diff.inDays < 7) return '${diff.inDays} d ago';
    return '${sentAt.day} ${_monthLabel(sentAt.month)}';
  }

  String _monthLabel(int month) => switch (month) {
        1 => 'Jan',
        2 => 'Feb',
        3 => 'Mar',
        4 => 'Apr',
        5 => 'May',
        6 => 'Jun',
        7 => 'Jul',
        8 => 'Aug',
        9 => 'Sep',
        10 => 'Oct',
        11 => 'Nov',
        _ => 'Dec',
      };

  /// Audit metadata for [AuditLogger] integration.
  Map<String, String> auditMetadata(ParentCommunicationRecord record) => {
        'reason': record.reason.name,
        'channels': record.channels.map((c) => c.name).join(','),
        'language': record.targetLanguage.code,
        'usedAi': record.usedAi.toString(),
        'studentId': record.sisStudentId,
      };
}
