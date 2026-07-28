import '../../../features/support/domain/support_delivery_failure.dart';
import '../../../features/support/domain/support_models.dart';
import '../interfaces/support_repository.dart';
import '../paginated_result.dart';
import '../repository_query.dart';

/// In-memory [SupportRepository] for local / demo / test builds.
///
/// READS are seeded and realistic: a spread of incidents across the lifecycle,
/// with timelines, support replies and an attachment, so the UI exercises every
/// state without a backend.
///
/// WRITES all throw [SupportDeliveryFailure.notConfigured]. This is deliberate
/// and is the whole point of the class:
///
///   * A mock may stand in for *reading* data it does not have. It may never
///     stand in for *delivering* something to a human being. The previous
///     version minted `SUP-4200`-style references locally, so a user on the
///     shipping build was shown a real-looking ticket number for a report that
///     was never sent, never stored, and that Akshara Support never saw.
///   * Throwing also keeps the honest-failure UI on the daily developer path —
///     every dev run exercises it, so it cannot rot behind a flag.
///
/// If you are here because a write "stopped working" in a local build: that is
/// the correct behaviour. Point the app at a real backend
/// (`SUPPORT_API_ENABLED=true`) to actually deliver a report.
class MockSupportRepository implements SupportRepository {
  MockSupportRepository() {
    _seed();
  }

  final List<SupportIncident> _incidents = [];
  final Map<String, List<SupportIncidentEvent>> _events = {};
  final Map<String, List<SupportMessage>> _messages = {};
  final Map<String, List<SupportAttachment>> _attachments = {};

  int _seq = 4200;
  final DateTime _base = DateTime.now();

  void _seed() {
    _add(
      title: 'Fee receipt PDF opens blank',
      description:
          'When I tap "Download receipt" after collecting a term fee, the PDF '
          'preview is completely blank. Happens for every payment today.',
      category: 'ui_display',
      status: SupportStatus.inProgress,
      severity: SupportSeverity.sev2,
      moduleKey: 'finance',
      screenRoute: '/finance/collections',
      ageHours: 30,
      supportReplies: const [
        'Thanks for reporting — we can reproduce this on the receipt export and '
            'are shipping a fix. We will update you here.',
      ],
    );
    _add(
      title: 'Cannot mark attendance for Class 6-B',
      description:
          'The Save button stays greyed out even after I select present/absent '
          'for every student in 6-B.',
      category: 'data_incorrect',
      status: SupportStatus.awaitingCustomer,
      severity: SupportSeverity.sev3,
      moduleKey: 'teacher',
      screenRoute: '/teacher/attendance',
      ageHours: 52,
      supportReplies: const [
        'Could you confirm whether every student row shows a status? If one is '
            'left blank the Save stays disabled by design.',
      ],
    );
    _add(
      title: 'OTP not received on parent login',
      description:
          'A parent (2 different numbers) is not getting the login OTP. Retried '
          'several times over 15 minutes.',
      category: 'login_auth',
      status: SupportStatus.resolved,
      severity: SupportSeverity.sev2,
      moduleKey: 'parent',
      screenRoute: '/login',
      ageHours: 120,
      resolutionSummary:
          'SMS provider had a temporary delivery delay in your region; resolved '
          'by the provider. OTPs are now delivering normally.',
      supportReplies: const [
        'This was an upstream SMS delivery delay, now cleared. Please ask the '
            'parent to try again — it should arrive within a few seconds.',
      ],
    );
    _add(
      title: 'Timetable shows last year’s sections',
      description:
          'The class timetable for Grade 9 is still showing the previous '
          'academic year’s section split.',
      category: 'data_incorrect',
      status: SupportStatus.triaging,
      severity: SupportSeverity.sev3,
      moduleKey: 'management',
      screenRoute: '/management/timetable',
      ageHours: 8,
    );
    _add(
      title: 'App very slow on the admissions dashboard',
      description:
          'The admissions dashboard takes 20+ seconds to load the leads list in '
          'the morning.',
      category: 'performance',
      status: SupportStatus.newIncident,
      severity: SupportSeverity.sev3,
      moduleKey: 'admissions',
      screenRoute: '/admissions/dashboard',
      ageHours: 2,
      withScreenshot: true,
    );
    _add(
      title: 'Transport route not saving new stop',
      description:
          'Adding a new stop to Route 4 appears to save but disappears after I '
          'reopen the route.',
      category: 'data_incorrect',
      status: SupportStatus.closed,
      severity: SupportSeverity.sev4,
      moduleKey: 'transport',
      screenRoute: '/transport/routes',
      ageHours: 300,
      resolutionSummary: 'Fixed in the 1.8.2 update — please update the app.',
    );
  }

  void _add({
    required String title,
    required String description,
    required String category,
    required SupportStatus status,
    required SupportSeverity severity,
    required String moduleKey,
    required String screenRoute,
    required int ageHours,
    String? resolutionSummary,
    List<String> supportReplies = const [],
    bool withScreenshot = false,
  }) {
    final id = 'inc_$_seq';
    final ref = 'SUP-$_seq';
    _seq += 37;
    final created = _base.subtract(Duration(hours: ageHours));
    final updated = _base.subtract(Duration(hours: (ageHours / 3).floor()));

    _incidents.add(SupportIncident(
      id: id,
      publicRef: ref,
      title: title,
      description: description,
      category: category,
      status: status,
      severity: severity,
      createdAt: created,
      updatedAt: updated,
      reporterRole: 'schoolAdmin',
      moduleKey: moduleKey,
      screenRoute: screenRoute,
      appVersion: '1.8.1+42',
      platform: 'android',
      deviceModel: 'Samsung SM-G991B',
      osVersion: 'Android 14 (SDK 34)',
      resolvedAt: status == SupportStatus.resolved || status == SupportStatus.closed
          ? updated
          : null,
      resolutionSummary: resolutionSummary,
      firstSeenAt: created,
    ));

    final events = <SupportIncidentEvent>[
      SupportIncidentEvent(eventType: 'created', createdAt: created, toValue: 'new'),
      SupportIncidentEvent(
        eventType: 'evidence_collected',
        createdAt: created.add(const Duration(seconds: 2)),
      ),
    ];
    final messages = <SupportMessage>[];
    for (var i = 0; i < supportReplies.length; i++) {
      final at = created.add(Duration(hours: i + 1));
      messages.add(SupportMessage(
        id: '${id}_m$i',
        senderKind: SupportSenderKind.support,
        visibility: 'school_visible',
        body: supportReplies[i],
        createdAt: at,
        senderUserId: 'akshara_support',
      ));
      events.add(SupportIncidentEvent(
        eventType: 'message_posted',
        createdAt: at,
        actorUserId: 'akshara_support',
      ));
    }
    if (status == SupportStatus.resolved) {
      events.add(SupportIncidentEvent(
        eventType: 'resolved',
        createdAt: updated,
        fromValue: 'in_progress',
        toValue: 'resolved',
      ));
    }

    _events[id] = events;
    _messages[id] = messages;
    _attachments[id] = withScreenshot
        ? [
            SupportAttachment(
              id: '${id}_a0',
              kind: AttachmentKind.screenshot,
              fileName: 'screenshot.png',
              contentType: 'image/png',
              sizeBytes: 184320,
              createdAt: created.add(const Duration(seconds: 5)),
            ),
          ]
        : [];
  }

  /// Always throws — there is no support channel behind this repository, so a
  /// report cannot be created and no reference number may be invented.
  @override
  Future<SupportIncident> createIncident({
    required RepositoryQuery query,
    required CreateSupportIncidentInput input,
  }) async {
    await _latency();
    throw const SupportDeliveryFailure.notConfigured();
  }

  @override
  Future<PaginatedResult<SupportIncident>> listIncidents({
    required RepositoryQuery query,
    SupportStatus? status,
  }) async {
    await _latency();
    final filtered = status == null
        ? _incidents
        : _incidents.where((i) => i.status == status).toList();
    final sorted = [...filtered]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return PaginatedResult.fromItems(
      sorted,
      page: query.page,
      pageSize: query.pageSize,
    );
  }

  @override
  Future<SupportIncidentDetail> getIncident({
    required RepositoryQuery query,
    required String incidentId,
  }) async {
    await _latency();
    final incident = _incidents.firstWhere(
      (i) => i.id == incidentId,
      orElse: () => throw StateError('Incident not found: $incidentId'),
    );
    return SupportIncidentDetail(
      incident: incident,
      events: List.of(_events[incidentId] ?? const []),
      messages: List.of(_messages[incidentId] ?? const []),
      attachments: List.of(_attachments[incidentId] ?? const []),
    );
  }

  /// Always throws — a reply that Akshara Support will never read must not be
  /// rendered back to the reporter as if it had been sent.
  @override
  Future<SupportMessage> postMessage({
    required RepositoryQuery query,
    required String incidentId,
    required String body,
  }) async {
    await _latency();
    throw const SupportDeliveryFailure.notConfigured();
  }

  /// Always throws — nothing is uploaded anywhere.
  @override
  Future<SupportAttachment> uploadAttachment({
    required RepositoryQuery query,
    required String incidentId,
    required AttachmentKind kind,
    required String fileName,
    required String contentType,
    required List<int> bytes,
  }) async {
    await _latency();
    throw const SupportDeliveryFailure.notConfigured();
  }

  Future<void> _latency() =>
      Future<void>.delayed(const Duration(milliseconds: 120));
}
