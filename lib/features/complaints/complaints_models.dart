// PRC-A Batch 2 — client models for Complaints / Internal Issues. Mirrors the
// server envelope exactly (supabase/functions/_shared/complaints/*); field
// names are camelCase because `complaintToApi`/`eventToApi` already convert
// from the DB's snake_case before this ever reaches the client.

/// category ∈ facilities|transport|academics|hostel|finance|safety|staff|other
const List<String> kComplaintCategories = [
  'facilities',
  'transport',
  'academics',
  'hostel',
  'finance',
  'safety',
  'staff',
  'other',
];

/// severity ∈ low|medium|high|critical
const List<String> kComplaintSeverities = ['low', 'medium', 'high', 'critical'];

/// status ∈ open|assigned|in_progress|resolved|closed|reopened
const List<String> kComplaintStatuses = [
  'open',
  'assigned',
  'in_progress',
  'resolved',
  'closed',
  'reopened',
];

/// Legal status transitions — mirrors `complaints_sla.ts` LEGAL_TRANSITIONS so
/// the UI can disable illegal targets instead of round-tripping a 422.
const Map<String, List<String>> kComplaintLegalTransitions = {
  'open': ['assigned', 'in_progress', 'closed'],
  'assigned': ['in_progress', 'resolved', 'closed'],
  'in_progress': ['resolved', 'closed'],
  'resolved': ['closed', 'reopened'],
  'closed': ['reopened'],
  'reopened': ['assigned', 'in_progress', 'resolved', 'closed'],
};

/// SLA read-time state, computed server-side and surfaced honestly.
const String kSlaOnTrack = 'onTrack';
const String kSlaBreached = 'breached';

class Complaint {
  const Complaint({
    required this.id,
    required this.category,
    required this.title,
    required this.description,
    required this.severity,
    required this.status,
    required this.raisedBy,
    required this.raisedByRole,
    required this.slaDueAt,
    required this.slaState,
    required this.reopenedCount,
    this.relatedStudentId,
    this.assignedTo,
    this.assignedAt,
    this.assignedBy,
    this.firstResponseAt,
    this.resolvedAt,
    this.resolvedBy,
    this.resolutionNote,
    this.vendorId,
    this.repairCost,
    this.photoPath,
    this.createdAt,
    this.updatedAt,
    this.events = const [],
  });

  final String id;
  final String category;
  final String title;
  final String description;
  final String severity;
  final String status;
  final String raisedBy;
  final String raisedByRole;
  final String? relatedStudentId;
  final String? assignedTo;
  final String? assignedAt;
  final String? assignedBy;
  final String slaDueAt;
  final String slaState; // 'onTrack' | 'breached'
  final String? firstResponseAt;
  final String? resolvedAt;
  final String? resolvedBy;
  final String? resolutionNote;
  final int reopenedCount;
  final String? vendorId;
  final double? repairCost;
  final String? photoPath;
  final String? createdAt;
  final String? updatedAt;

  /// Only populated on the detail (`GET /complaints/{id}`) response.
  final List<ComplaintEvent> events;

  bool get isBreached => slaState == kSlaBreached;
  bool get isAssigned => (assignedTo ?? '').isNotEmpty;

  List<String> get legalNextStatuses => kComplaintLegalTransitions[status] ?? const [];

  factory Complaint.fromJson(Map<String, dynamic> json) {
    final rawEvents = json['events'];
    return Complaint(
      id: (json['id'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      severity: (json['severity'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      raisedBy: (json['raisedBy'] ?? '').toString(),
      raisedByRole: (json['raisedByRole'] ?? '').toString(),
      relatedStudentId: (json['relatedStudentId'])?.toString(),
      assignedTo: (json['assignedTo'])?.toString(),
      assignedAt: (json['assignedAt'])?.toString(),
      assignedBy: (json['assignedBy'])?.toString(),
      slaDueAt: (json['slaDueAt'] ?? '').toString(),
      slaState: (json['slaState'] ?? kSlaOnTrack).toString(),
      firstResponseAt: (json['firstResponseAt'])?.toString(),
      resolvedAt: (json['resolvedAt'])?.toString(),
      resolvedBy: (json['resolvedBy'])?.toString(),
      resolutionNote: (json['resolutionNote'])?.toString(),
      reopenedCount: _asInt(json['reopenedCount']),
      vendorId: (json['vendorId'])?.toString(),
      repairCost: json['repairCost'] == null ? null : _asDouble(json['repairCost']),
      photoPath: (json['photoPath'])?.toString(),
      createdAt: (json['createdAt'])?.toString(),
      updatedAt: (json['updatedAt'])?.toString(),
      events: [
        if (rawEvents is List)
          for (final e in rawEvents)
            if (e is Map) ComplaintEvent.fromJson(e.cast<String, dynamic>()),
      ],
    );
  }
}

class ComplaintEvent {
  const ComplaintEvent({
    required this.id,
    required this.complaintId,
    required this.eventType,
    required this.actorId,
    required this.occurredAt,
    this.actorName,
    this.note,
    this.metadata,
  });

  final String id;
  final String complaintId;
  final String eventType;
  final String actorId;
  final String? actorName;
  final String? note;
  final Map<String, dynamic>? metadata;
  final String occurredAt;

  factory ComplaintEvent.fromJson(Map<String, dynamic> json) => ComplaintEvent(
        id: (json['id'] ?? '').toString(),
        complaintId: (json['complaintId'] ?? '').toString(),
        eventType: (json['eventType'] ?? '').toString(),
        actorId: (json['actorId'] ?? '').toString(),
        actorName: (json['actorName'])?.toString(),
        note: (json['note'])?.toString(),
        metadata: json['metadata'] is Map
            ? (json['metadata'] as Map).cast<String, dynamic>()
            : null,
        occurredAt: (json['occurredAt'] ?? '').toString(),
      );
}

/// Filters for the complaints queue — a record so it can key a Riverpod
/// `.family` provider directly via structural equality.
typedef ComplaintsFilter = ({
  String? status,
  String? category,
  String? assignedTo,
  String? severity,
});

const ComplaintsFilter kNoComplaintsFilter = (
  status: null,
  category: null,
  assignedTo: null,
  severity: null,
);

int _asInt(dynamic v) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

double _asDouble(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}
