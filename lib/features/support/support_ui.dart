import 'package:flutter/material.dart';

import '../../theme/theme_extensions.dart';
import 'domain/support_models.dart';

/// Presentation helpers for the support surface — status/severity tones, compact
/// timestamps and timeline labels. Kept out of the screens so all three share
/// exactly one visual language.

KpiAccent supportStatusTone(SupportStatus status) => switch (status) {
      SupportStatus.newIncident => KpiAccent.neutral,
      SupportStatus.triaging => KpiAccent.indigo,
      SupportStatus.inProgress => KpiAccent.primary,
      SupportStatus.awaitingCustomer => KpiAccent.warning,
      SupportStatus.resolved => KpiAccent.success,
      SupportStatus.closed => KpiAccent.neutral,
    };

KpiAccent supportSeverityTone(SupportSeverity severity) => switch (severity) {
      SupportSeverity.sev1 => KpiAccent.error,
      SupportSeverity.sev2 => KpiAccent.warning,
      SupportSeverity.sev3 => KpiAccent.primary,
      SupportSeverity.sev4 => KpiAccent.neutral,
    };

const List<String> _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Compact relative timestamp ("just now", "5m ago", "3h ago", "2d ago", else a
/// short date) — no `intl` dependency required.
String supportRelativeTime(DateTime at, {DateTime? now}) {
  final ref = now ?? DateTime.now();
  final diff = ref.difference(at);
  if (diff.inSeconds < 45) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${at.day} ${_months[at.month - 1]}';
}

/// Absolute short date-time, e.g. `12 Jul 2026, 14:30`.
String supportDateTime(DateTime at) {
  final hh = at.hour.toString().padLeft(2, '0');
  final mm = at.minute.toString().padLeft(2, '0');
  return '${at.day} ${_months[at.month - 1]} ${at.year}, $hh:$mm';
}

/// Icon for a timeline event type.
IconData supportEventIcon(String eventType) => switch (eventType) {
      'created' => Icons.flag_outlined,
      'evidence_collected' => Icons.fact_check_outlined,
      'status_changed' => Icons.sync_alt,
      'assigned' => Icons.person_add_alt,
      'escalated' => Icons.priority_high,
      'ai_analyzed' => Icons.auto_awesome_outlined,
      'message_posted' => Icons.forum_outlined,
      'attachment_added' => Icons.attach_file,
      'resolved' => Icons.check_circle_outline,
      _ => Icons.circle_outlined,
    };

/// Human-readable timeline label for an event.
String supportEventLabel(SupportIncidentEvent event) {
  switch (event.eventType) {
    case 'created':
      return 'Issue reported';
    case 'evidence_collected':
      return 'Technical details collected automatically';
    case 'status_changed':
      final to = event.toValue == null
          ? ''
          : ' → ${SupportStatus.fromWire(event.toValue).label}';
      return 'Status changed$to';
    case 'assigned':
      return 'Assigned to support';
    case 'escalated':
      return 'Escalated';
    case 'ai_analyzed':
      return 'Investigated';
    case 'message_posted':
      return 'Message posted';
    case 'attachment_added':
      return 'Attachment added';
    case 'resolved':
      return 'Marked resolved';
    default:
      return event.eventType.replaceAll('_', ' ');
  }
}
